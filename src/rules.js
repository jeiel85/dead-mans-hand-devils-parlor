// Pure game engine for Dead Man's Hand: Devil's Parlor (web prototype).
// No DOM, no timers. Every mutation appends events to state.events so the
// UI can animate them. All randomness flows through state.rng (seeded).

import {
  RANKS,
  JOKER,
  DECK_SPEC,
  HAND_SIZE,
  MAX_PLAY,
  CYLINDER_SIZE,
  PLAYER_MAX_HP,
  BULLET,
  CHEATS,
  STARTING_ITEMS,
  FLOORS,
  DEALERS,
  RELIC_IDS,
  RELIC_EFFECTS,
  FLOOR_CLEAR_HEAL,
} from './data.js';
import { createRng } from './rng.js';
import { dealerDecidePlay, dealerDecideRespond } from './ai.js';

export class IllegalAction extends Error {
  constructor(code, detail) {
    super(code);
    this.code = code;
    this.detail = detail;
  }
}

export const PHASE = Object.freeze({
  TITLE: 'title',
  FLOOR_INTRO: 'floorIntro',
  ROUND: 'round',
  REWARD: 'reward',
  GAME_OVER: 'gameOver',
  VICTORY: 'victory',
});

export const other = (who) => (who === 'player' ? 'dealer' : 'player');

// ---------------------------------------------------------------------------
// Construction
// ---------------------------------------------------------------------------

export function createRun({ seed }) {
  const rng = createRng(seed);
  return {
    seed: rng.seed,
    rng,
    phase: PHASE.TITLE,
    floorIndex: 0,
    player: {
      hp: PLAYER_MAX_HP,
      maxHp: PLAYER_MAX_HP,
      items: { ...STARTING_ITEMS },
      relics: [],
      cursed: false,
      hipFlaskUsed: false,
    },
    dealer: null,
    cylinder: null,
    round: null,
    rewards: null,
    roundNumber: 0,
    stats: {
      turns: 0,
      playerPlays: 0,
      playerBluffs: 0,
      playerCallsRight: 0,
      playerCallsWrong: 0,
      cheatsUsed: 0,
      cheatsCaught: 0,
      shotsTaken: 0,
      liveTaken: 0,
      dealersBeaten: 0,
    },
    events: [],
  };
}

export function startFloor(state) {
  const floor = FLOORS[state.floorIndex];
  if (!floor) throw new IllegalAction('noSuchFloor');
  const proto = DEALERS[floor.dealer];
  state.dealer = {
    ...proto,
    hp: floor.hp,
    maxHp: floor.hp,
    cursed: false,
    healUsed: false,
    memory: { playerPlays: 0, playerLies: 0 },
  };
  state.cylinder = makeCylinder(state, floor.cylinder);
  state.player.cursed = false;
  state.round = null;
  state.phase = PHASE.FLOOR_INTRO;
  state.nextStarter = 'player';
  push(state, { type: 'floorStart', floor: floor.id, level: floor.level, dealer: floor.dealer });
  return state;
}

function makeCylinder(state, composition) {
  const chambers = [];
  for (let i = 0; i < composition.live; i++) chambers.push(BULLET.LIVE);
  for (let i = 0; i < composition.blank; i++) chambers.push(BULLET.BLANK);
  for (let i = 0; i < composition.curse; i++) chambers.push(BULLET.CURSE);
  if (chambers.length !== CYLINDER_SIZE) throw new Error('cylinder composition must total 6');
  state.rng.shuffle(chambers);
  // composition = what is loaded right now (cheats may change it);
  // base = what every reload goes back to (floor spec, or escalated by a gimmick).
  return { chambers, index: 0, composition: { ...composition }, base: { ...composition }, spent: [], knownNext: null };
}

function reloadCylinder(state, composition = state.cylinder.base) {
  state.cylinder = makeCylinder(state, composition);
  push(state, { type: 'reload', composition: { ...composition } });
}

export function buildDeck(state) {
  const spec = { ...DECK_SPEC };
  if (hasRelic(state, 'blackCat')) spec.J += 1;
  const deck = [];
  let id = 0;
  for (const rank of Object.keys(spec)) {
    for (let i = 0; i < spec[rank]; i++) deck.push({ id: id++, rank });
  }
  return deck;
}

export function beginRound(state) {
  if (state.phase !== PHASE.FLOOR_INTRO && state.phase !== PHASE.ROUND) {
    throw new IllegalAction('wrongPhase', state.phase);
  }
  const deck = state.rng.shuffle(buildDeck(state));
  const tableRank = state.rng.pick(RANKS);
  const hands = { player: deck.splice(0, HAND_SIZE), dealer: deck.splice(0, HAND_SIZE) };
  state.roundNumber += 1;
  state.round = {
    number: state.roundNumber,
    tableRank,
    hands,
    deck,
    pile: [],
    lastPlay: null,
    claimed: { player: 0, dealer: 0 },
    turn: state.nextStarter,
    phase: 'play',
    cheatUsedThisTurn: false,
    pact: null,
    revealed: { player: state.player.cursed, dealer: state.dealer.cursed },
    peekedDealerCard: null,
  };
  state.player.cursed = false;
  state.dealer.cursed = false;
  state.cylinder.knownNext = null;
  if (hasRelic(state, 'markedDeck') && hands.dealer.length) {
    state.round.peekedDealerCard = state.rng.pick(hands.dealer);
  }
  state.phase = PHASE.ROUND;
  push(state, {
    type: 'roundStart',
    number: state.roundNumber,
    tableRank,
    starter: state.round.turn,
    revealed: { ...state.round.revealed },
  });
  return state;
}

// ---------------------------------------------------------------------------
// Queries
// ---------------------------------------------------------------------------

export function hasRelic(state, id) {
  return state.player.relics.includes(id);
}

export function isTruthful(card, tableRank) {
  return card.rank === tableRank || card.rank === JOKER;
}

export function playIsLie(cards, tableRank) {
  return cards.some((c) => !isTruthful(c, tableRank));
}

export function truthfulCount(cards, tableRank) {
  return cards.filter((c) => isTruthful(c, tableRank)).length;
}

export function nextChamberOdds(state) {
  const cyl = state.cylinder;
  const remaining = cyl.chambers.length - cyl.index;
  const spentCount = (t) => cyl.spent.filter((b) => b === t).length;
  const live = cyl.composition.live - spentCount(BULLET.LIVE);
  const curse = cyl.composition.curse - spentCount(BULLET.CURSE);
  const blank = cyl.composition.blank - spentCount(BULLET.BLANK);
  return { remaining, live, blank, curse, pLive: remaining ? live / remaining : 0 };
}

export function cheatDetectChance(state, cheatId) {
  const cheat = CHEATS[cheatId];
  if (!cheat) return 0;
  if (cheatId === 'mirror' && hasRelic(state, 'loadedDice')) return 0;
  let p = cheat.baseDetect * state.dealer.focus;
  if (hasRelic(state, 'leatherGloves')) p *= RELIC_EFFECTS.leatherGlovesMultiplier;
  return Math.min(0.95, p);
}

export function legalActions(state) {
  const r = state.round;
  if (!r || state.phase !== PHASE.ROUND || r.turn !== 'player') {
    return { play: false, call: false, pass: false, cheats: [] };
  }
  const hand = r.hands.player;
  const cheats = Object.keys(CHEATS).filter(
    (id) => state.player.items[id] > 0 && !r.cheatUsedThisTurn && CHEATS[id].phases.includes(r.phase),
  );
  if (r.phase === 'play') return { play: hand.length > 0, call: false, pass: false, cheats };
  return { play: false, call: true, pass: hand.length > 0, cheats };
}

// ---------------------------------------------------------------------------
// Actions
// ---------------------------------------------------------------------------

function assertTurn(state, who, phase) {
  if (state.phase !== PHASE.ROUND) throw new IllegalAction('wrongPhase', state.phase);
  if (state.round.turn !== who) throw new IllegalAction('notYourTurn', who);
  if (state.round.phase !== phase) throw new IllegalAction('wrongRoundPhase', state.round.phase);
}

export function play(state, who, cardIds) {
  assertTurn(state, who, 'play');
  const r = state.round;
  const hand = r.hands[who];
  const ids = [...new Set(cardIds)];
  if (ids.length < 1 || ids.length > MAX_PLAY) throw new IllegalAction('badCount', ids.length);
  const cards = ids.map((id) => hand.find((c) => c.id === id));
  if (cards.some((c) => !c)) throw new IllegalAction('cardNotInHand');
  r.hands[who] = hand.filter((c) => !ids.includes(c.id));
  const lie = playIsLie(cards, r.tableRank);
  const entry = { by: who, cards, claim: cards.length, lie, pact: r.pact && r.pact.by === who ? r.pact : null };
  r.pile.push(entry);
  r.lastPlay = entry;
  r.claimed[who] += cards.length;
  r.turn = other(who);
  r.phase = 'respond';
  r.cheatUsedThisTurn = false;
  state.stats.turns += 1;
  if (who === 'player') {
    state.stats.playerPlays += 1;
    if (lie) state.stats.playerBluffs += 1;
  }
  push(state, { type: 'play', by: who, count: cards.length, tableRank: r.tableRank, handLeft: r.hands[who].length });
  return state;
}

export function respond(state, who, action) {
  assertTurn(state, who, 'respond');
  const r = state.round;
  if (action === 'pass') {
    if (r.hands[who].length === 0) throw new IllegalAction('mustCall');
    push(state, { type: 'pass', by: who });
    const lp = r.lastPlay;
    if (lp.pact) {
      if (lp.lie) {
        push(state, { type: 'pactStrike', by: lp.by, target: who });
        damage(state, who, 2, 'pact');
        r.pact = null;
        if (checkMatchEnd(state)) return state;
      } else {
        push(state, { type: 'pactFizzle', by: lp.by });
        r.pact = null;
      }
    }
    r.turn = who;
    r.phase = 'play';
    r.cheatUsedThisTurn = false;
    return state;
  }
  if (action === 'call') {
    resolveChallenge(state, who);
    return state;
  }
  throw new IllegalAction('badAction', action);
}

function resolveChallenge(state, challenger) {
  const r = state.round;
  const lp = r.lastPlay;
  const liar = lp.lie;
  const shooter = liar ? lp.by : challenger;
  if (challenger === 'player') {
    if (liar) state.stats.playerCallsRight += 1;
    else state.stats.playerCallsWrong += 1;
  }
  if (lp.by === 'player') {
    state.dealer.memory.playerPlays += 1;
    if (liar) state.dealer.memory.playerLies += 1;
  }
  push(state, {
    type: 'reveal',
    by: lp.by,
    challenger,
    cards: lp.cards.map((c) => ({ ...c })),
    tableRank: r.tableRank,
    lie: liar,
    shooter,
  });
  if (lp.pact && liar) {
    push(state, { type: 'pactBackfire', by: lp.by });
    setHp(state, lp.by, 0, 'pact');
    r.pact = null;
    endRound(state, shooter);
    return;
  }
  r.pact = null;
  fire(state, shooter, 1, 'challenge');
  endRound(state, shooter);
}

function endRound(state, shooter) {
  state.round.phase = 'over';
  state.nextStarter = shooter;
  if (checkMatchEnd(state)) return;
  push(state, { type: 'roundEnd', nextStarter: shooter });
  beginRound(state);
}

function checkMatchEnd(state) {
  if (state.player.hp <= 0) {
    state.phase = PHASE.GAME_OVER;
    state.round.phase = 'over';
    push(state, { type: 'gameOver', floor: FLOORS[state.floorIndex].id, stats: { ...state.stats } });
    return true;
  }
  if (state.dealer.hp <= 0) {
    state.round.phase = 'over';
    state.stats.dealersBeaten += 1;
    push(state, { type: 'dealerDefeated', dealer: state.dealer.id, floor: FLOORS[state.floorIndex].id });
    heal(state, 'player', FLOOR_CLEAR_HEAL, 'floorClear');
    if (hasRelic(state, 'snakeOil')) heal(state, 'player', 1, 'snakeOil');
    if (state.floorIndex >= FLOORS.length - 1) {
      state.phase = PHASE.VICTORY;
      push(state, { type: 'victory', stats: { ...state.stats } });
    } else {
      state.phase = PHASE.REWARD;
      state.rewards = rollRewards(state);
      push(state, { type: 'rewardOffer', rewards: state.rewards.map((x) => ({ ...x })) });
    }
    return true;
  }
  return false;
}

// ---------------------------------------------------------------------------
// Revolver
// ---------------------------------------------------------------------------

export function fire(state, who, count = 1, reason = 'challenge') {
  for (let i = 0; i < count; i++) {
    const cyl = state.cylinder;
    const bullet = cyl.chambers[cyl.index];
    cyl.spent.push(bullet);
    cyl.index += 1;
    cyl.knownNext = null;
    if (who === 'player') state.stats.shotsTaken += 1;
    let effect = bullet;
    if (bullet === BULLET.LIVE) {
      if (who === 'player' && hasRelic(state, 'pocketBible') && state.rng.chance(RELIC_EFFECTS.pocketBibleMisfire)) {
        effect = 'misfire';
      } else {
        if (who === 'player') state.stats.liveTaken += 1;
        damage(state, who, 1, reason);
      }
    } else if (bullet === BULLET.CURSE) {
      if (who === 'player') state.player.cursed = true;
      else state.dealer.cursed = true;
    }
    push(state, { type: 'fire', who, bullet, effect, reason, chamber: cyl.index, hp: hpOf(state, who) });
    if (cyl.index >= cyl.chambers.length) reloadCylinder(state);
    if (hpOf(state, who) <= 0) break;
  }
}

function hpOf(state, who) {
  return who === 'player' ? state.player.hp : state.dealer.hp;
}

function setHp(state, who, hp, reason) {
  const target = who === 'player' ? state.player : state.dealer;
  const before = target.hp;
  target.hp = Math.max(0, Math.min(target.maxHp, hp));
  if (target.hp !== before) push(state, { type: 'hp', who, from: before, to: target.hp, reason });
}

function damage(state, who, amount, reason) {
  const target = who === 'player' ? state.player : state.dealer;
  let next = target.hp - amount;
  if (who === 'player' && next <= 0 && hasRelic(state, 'hipFlask') && !state.player.hipFlaskUsed) {
    state.player.hipFlaskUsed = true;
    next = 1;
    push(state, { type: 'relicProc', relic: 'hipFlask' });
  }
  setHp(state, who, next, reason);
  if (who === 'dealer') {
    if (state.dealer.gimmick === 'mender' && !state.dealer.healUsed && state.dealer.hp === 1) {
      state.dealer.healUsed = true;
      push(state, { type: 'gimmick', dealer: state.dealer.id, gimmick: 'mender' });
      heal(state, 'dealer', 1, 'mender');
    }
    if (state.dealer.gimmick === 'proprietor' && state.dealer.hp > 0) {
      const c = state.cylinder.base;
      const live = Math.min(5, c.live + 1);
      const curse = Math.min(c.curse, CYLINDER_SIZE - live);
      const blank = CYLINDER_SIZE - live - curse;
      push(state, { type: 'gimmick', dealer: state.dealer.id, gimmick: 'proprietor' });
      reloadCylinder(state, { live, blank, curse });
    }
  }
}

function heal(state, who, amount, reason) {
  setHp(state, who, hpOf(state, who) + amount, reason);
}

// ---------------------------------------------------------------------------
// Cheats
// ---------------------------------------------------------------------------

export function useCheat(state, cheatId, opts = {}) {
  if (state.phase !== PHASE.ROUND) throw new IllegalAction('wrongPhase', state.phase);
  const r = state.round;
  const cheat = CHEATS[cheatId];
  if (!cheat) throw new IllegalAction('noSuchCheat', cheatId);
  if (r.turn !== 'player') throw new IllegalAction('notYourTurn');
  if (!cheat.phases.includes(r.phase)) throw new IllegalAction('wrongRoundPhase', r.phase);
  if (r.cheatUsedThisTurn) throw new IllegalAction('cheatAlreadyUsed');
  if (!(state.player.items[cheatId] > 0)) throw new IllegalAction('noCharges', cheatId);

  if (cheatId === 'bottomDeal') {
    const card = r.hands.player.find((c) => c.id === opts.cardId);
    if (!card) throw new IllegalAction('cardNotInHand');
    if (isTruthful(card, r.tableRank)) throw new IllegalAction('cardAlreadyTruthful');
  }

  state.player.items[cheatId] -= 1;
  r.cheatUsedThisTurn = true;
  state.stats.cheatsUsed += 1;
  const p = cheatDetectChance(state, cheatId);
  const caught = p > 0 && state.rng.chance(p);
  const result = { type: 'cheat', cheat: cheatId, caught, detectChance: p };

  if (!caught) {
    if (cheatId === 'mirror') {
      const cyl = state.cylinder;
      cyl.knownNext = cyl.chambers[cyl.index];
      result.bullet = cyl.knownNext;
    } else if (cheatId === 'leadWeight') {
      const cyl = state.cylinder;
      const before = cyl.chambers[cyl.index];
      if (before !== BULLET.BLANK) {
        cyl.chambers[cyl.index] = BULLET.BLANK;
        cyl.composition = recount(cyl);
      }
      cyl.knownNext = BULLET.BLANK;
      result.swapped = before !== BULLET.BLANK;
    } else if (cheatId === 'bottomDeal') {
      const idx = r.hands.player.findIndex((c) => c.id === opts.cardId);
      const swapIdx = r.deck.findIndex((c) => c.rank === r.tableRank);
      const jokerIdx = swapIdx === -1 ? r.deck.findIndex((c) => c.rank === JOKER) : -1;
      const take = swapIdx !== -1 ? swapIdx : jokerIdx;
      if (take === -1) {
        result.swapped = false;
      } else {
        const [fresh] = r.deck.splice(take, 1);
        r.deck.push(r.hands.player[idx]);
        r.hands.player[idx] = fresh;
        result.swapped = true;
        result.newCard = { ...fresh };
      }
    } else if (cheatId === 'pact') {
      r.pact = { by: 'player' };
    }
  }
  push(state, result);
  if (caught) {
    state.stats.cheatsCaught += 1;
    const pulls = state.dealer.gimmick === 'verdict' ? 2 : 1;
    if (pulls === 2) push(state, { type: 'gimmick', dealer: state.dealer.id, gimmick: 'verdict' });
    fire(state, 'player', pulls, 'caught');
    if (state.player.hp <= 0) {
      checkMatchEnd(state);
    }
  }
  return result;
}

function recount(cyl) {
  const counts = { live: 0, blank: 0, curse: 0 };
  for (const b of cyl.chambers) counts[b] += 1;
  return counts;
}

// ---------------------------------------------------------------------------
// Dealer turn
// ---------------------------------------------------------------------------

export function dealerAct(state) {
  if (state.phase !== PHASE.ROUND) throw new IllegalAction('wrongPhase', state.phase);
  const r = state.round;
  if (r.turn !== 'dealer') throw new IllegalAction('notYourTurn', 'dealer');
  if (r.phase === 'play') {
    const ids = dealerDecidePlay(state);
    play(state, 'dealer', ids);
    return { action: 'play', count: ids.length };
  }
  const action = dealerDecideRespond(state);
  respond(state, 'dealer', action);
  return { action };
}

// ---------------------------------------------------------------------------
// Rewards
// ---------------------------------------------------------------------------

function rollRewards(state) {
  const pool = [];
  for (const id of Object.keys(CHEATS)) pool.push({ kind: 'item', id });
  for (const id of RELIC_IDS) if (!hasRelic(state, id)) pool.push({ kind: 'relic', id });
  state.rng.shuffle(pool);
  const picks = [{ kind: 'heal', id: 'heal' }, ...pool.slice(0, 2)];
  return picks;
}

export function chooseReward(state, index) {
  if (state.phase !== PHASE.REWARD) throw new IllegalAction('wrongPhase', state.phase);
  const reward = state.rewards[index];
  if (!reward) throw new IllegalAction('noSuchReward', index);
  if (reward.kind === 'heal') {
    heal(state, 'player', 1, 'reward');
  } else if (reward.kind === 'item') {
    state.player.items[reward.id] += 1;
  } else if (reward.kind === 'relic') {
    state.player.relics.push(reward.id);
    if (reward.id === 'cigaretteCase') {
      state.player.maxHp += 1;
      heal(state, 'player', 1, 'cigaretteCase');
    }
  }
  push(state, { type: 'rewardTaken', reward: { ...reward } });
  state.rewards = null;
  state.floorIndex += 1;
  startFloor(state);
  return state;
}

// ---------------------------------------------------------------------------
// Events
// ---------------------------------------------------------------------------

function push(state, ev) {
  state.events.push(ev);
}

export function drainEvents(state) {
  const out = state.events;
  state.events = [];
  return out;
}

// Convenience for tests / simulations: a fully self-playing run.
export function currentFloor(state) {
  return FLOORS[state.floorIndex];
}
