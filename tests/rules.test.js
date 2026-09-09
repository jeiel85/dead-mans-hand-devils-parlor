import { test } from 'node:test';
import assert from 'node:assert/strict';

import {
  createRun,
  startFloor,
  beginRound,
  play,
  respond,
  useCheat,
  dealerAct,
  chooseReward,
  drainEvents,
  buildDeck,
  legalActions,
  nextChamberOdds,
  fire,
  IllegalAction,
  PHASE,
} from '../src/rules.js';
import { FLOORS, CYLINDER_SIZE, HAND_SIZE, JOKER, PLAYER_MAX_HP } from '../src/data.js';

function freshRound(seed = 'TEST01') {
  const s = createRun({ seed });
  startFloor(s);
  beginRound(s);
  drainEvents(s);
  return s;
}

test('deck has 6K/6Q/6A/2J = 20 cards', () => {
  const s = createRun({ seed: 'x' });
  const deck = buildDeck(s);
  assert.equal(deck.length, 20);
  const count = (r) => deck.filter((c) => c.rank === r).length;
  assert.deepEqual([count('K'), count('Q'), count('A'), count(JOKER)], [6, 6, 6, 2]);
  assert.equal(new Set(deck.map((c) => c.id)).size, 20);
});

test('same seed reproduces the same deal and cylinder', () => {
  const a = freshRound('SEED-A');
  const b = freshRound('SEED-A');
  assert.deepEqual(a.round.hands, b.round.hands);
  assert.deepEqual(a.cylinder.chambers, b.cylinder.chambers);
  assert.equal(a.round.tableRank, b.round.tableRank);
  const c = freshRound('SEED-B');
  assert.notDeepEqual(
    [a.round.hands, a.cylinder.chambers, a.round.tableRank],
    [c.round.hands, c.cylinder.chambers, c.round.tableRank],
  );
});

test('floor 1 cylinder matches its composition and every floor totals 6', () => {
  const s = freshRound();
  const counts = { live: 0, blank: 0, curse: 0 };
  for (const b of s.cylinder.chambers) counts[b] += 1;
  assert.deepEqual(counts, FLOORS[0].cylinder);
  for (const f of FLOORS) {
    assert.equal(f.cylinder.live + f.cylinder.blank + f.cylinder.curse, CYLINDER_SIZE, f.id);
  }
});

test('round start deals 5/5 and player starts floor', () => {
  const s = freshRound();
  assert.equal(s.round.hands.player.length, HAND_SIZE);
  assert.equal(s.round.hands.dealer.length, HAND_SIZE);
  assert.equal(s.round.turn, 'player');
  assert.equal(s.round.phase, 'play');
  assert.equal(s.player.hp, PLAYER_MAX_HP);
});

test('play validates count and ownership, then hands the turn over', () => {
  const s = freshRound();
  const hand = s.round.hands.player;
  assert.throws(() => play(s, 'player', []), IllegalAction);
  assert.throws(() => play(s, 'player', hand.slice(0, 4).map((c) => c.id)), IllegalAction);
  assert.throws(() => play(s, 'player', [999]), IllegalAction);
  play(s, 'player', [hand[0].id, hand[1].id]);
  assert.equal(s.round.hands.player.length, 3);
  assert.equal(s.round.turn, 'dealer');
  assert.equal(s.round.phase, 'respond');
  assert.equal(s.round.lastPlay.claim, 2);
});

test('a challenge makes the liar shoot; an honest play makes the challenger shoot', () => {
  for (const seed of ['L1', 'L2', 'L3', 'L4', 'L5', 'L6', 'L7', 'L8']) {
    const s = freshRound(seed);
    const rank = s.round.tableRank;
    const hand = s.round.hands.player;
    const liar = hand.find((c) => c.rank !== rank && c.rank !== JOKER);
    const honest = hand.find((c) => c.rank === rank || c.rank === JOKER);
    const card = liar || honest;
    play(s, 'player', [card.id]);
    respond(s, 'dealer', 'call');
    const evs = drainEvents(s);
    const reveal = evs.find((e) => e.type === 'reveal');
    const fire = evs.find((e) => e.type === 'fire');
    assert.ok(reveal && fire);
    assert.equal(reveal.lie, card === liar);
    assert.equal(fire.who, card === liar ? 'player' : 'dealer');
    assert.equal(reveal.shooter, fire.who);
    // A new round starts (or the match ends) right after the shot.
    assert.ok(s.phase !== PHASE.ROUND || s.round.number === 2);
  }
});

test('responder with an empty hand cannot pass', () => {
  const s = freshRound();
  s.round.hands.dealer = [];
  play(s, 'player', [s.round.hands.player[0].id]);
  assert.throws(() => respond(s, 'dealer', 'pass'), (e) => e.code === 'mustCall');
  assert.deepEqual(legalActions(s), { play: false, call: false, pass: false, cheats: [] });
});

test('legalActions for the player in respond phase forbids pass when out of cards', () => {
  const s = freshRound();
  s.round.turn = 'dealer';
  s.round.hands.player = [];
  s.round.hands.dealer = s.round.hands.dealer.slice(0, 2);
  play(s, 'dealer', [s.round.hands.dealer[0].id]);
  const la = legalActions(s);
  assert.equal(la.call, true);
  assert.equal(la.pass, false);
  assert.equal(la.play, false);
});

test('cylinder reloads after six pulls and reports odds', () => {
  const s = freshRound('RELOAD');
  const odds0 = nextChamberOdds(s);
  assert.equal(odds0.remaining, 6);
  assert.equal(odds0.live, FLOORS[0].cylinder.live);
  // Force pulls via caught cheats is awkward; drive the revolver directly.
  s.cylinder.index = 5;
  s.cylinder.spent = s.cylinder.chambers.slice(0, 5);
  const odds = nextChamberOdds(s);
  assert.equal(odds.remaining, 1);
  assert.equal(odds.live + odds.blank + odds.curse, 1);
});

test('mirror reveals the next chamber when not caught; lead weight swaps it to blank', () => {
  const s = freshRound('MIRROR');
  s.dealer.focus = 0; // never caught
  const before = s.cylinder.chambers[s.cylinder.index];
  const chargesBefore = s.player.items.mirror;
  const res = useCheat(s, 'mirror');
  assert.equal(res.caught, false);
  assert.equal(res.bullet, before);
  assert.equal(s.player.items.mirror, chargesBefore - 1);
  assert.throws(() => useCheat(s, 'bottomDeal', { cardId: 0 }), (e) => e.code === 'cheatAlreadyUsed');

  const t = freshRound('LEAD');
  t.dealer.focus = 0;
  t.player.items.leadWeight = 1;
  t.cylinder.chambers[t.cylinder.index] = 'live';
  const r2 = useCheat(t, 'leadWeight');
  assert.equal(r2.caught, false);
  assert.equal(r2.swapped, true);
  assert.equal(t.cylinder.chambers[t.cylinder.index], 'blank');
  assert.equal(t.cylinder.composition.live + t.cylinder.composition.blank + t.cylinder.composition.curse, 6);
});

test('lead weight does not change the composition used on reload', () => {
  const t = freshRound('LEADRELOAD');
  t.dealer.focus = 0;
  t.player.items.leadWeight = 1;
  t.cylinder.chambers = ['live', 'live', 'blank', 'blank', 'blank', 'blank'];
  t.cylinder.composition = { live: 2, blank: 4, curse: 0 };
  useCheat(t, 'leadWeight');
  assert.deepEqual(t.cylinder.composition, { live: 1, blank: 5, curse: 0 });
  assert.deepEqual(t.cylinder.base, FLOORS[0].cylinder);
  // Spend the whole cylinder: the reload must restore the floor composition.
  t.cylinder.index = 5;
  t.cylinder.spent = t.cylinder.chambers.slice(0, 5);
  fire(t, 'dealer', 1, 'test');
  assert.equal(t.cylinder.index, 0);
  assert.deepEqual(t.cylinder.composition, FLOORS[0].cylinder);
  assert.ok(drainEvents(t).some((e) => e.type === 'reload'));
});

test('bottom deal swaps a lying card for a truthful one', () => {
  const s = freshRound('BOTTOM');
  s.dealer.focus = 0;
  const rank = s.round.tableRank;
  const liar = s.round.hands.player.find((c) => c.rank !== rank && c.rank !== JOKER);
  if (!liar) return; // hand happened to be all truthful for this seed
  const res = useCheat(s, 'bottomDeal', { cardId: liar.id });
  assert.equal(res.caught, false);
  assert.equal(res.swapped, true);
  assert.ok(s.round.hands.player.every((c) => c.id !== liar.id));
  assert.ok(s.round.hands.player.some((c) => c.id === res.newCard.id));
  assert.ok(res.newCard.rank === rank || res.newCard.rank === JOKER);
  assert.equal(s.round.hands.player.length + s.round.hands.dealer.length + s.round.deck.length, 20);
});

test('a caught cheat fires the revolver at the player', () => {
  const s = freshRound('CAUGHT');
  s.dealer.focus = 100; // detect chance capped at 95%, force a caught roll by trying seeds
  let caughtSeen = false;
  for (let i = 0; i < 20 && !caughtSeen; i++) {
    const t = freshRound('CAUGHT' + i);
    t.dealer.focus = 100;
    const res = useCheat(t, 'mirror');
    if (res.caught) {
      caughtSeen = true;
      const evs = drainEvents(t);
      assert.ok(evs.some((e) => e.type === 'fire' && e.who === 'player' && e.reason === 'caught'));
      assert.equal(t.stats.cheatsCaught, 1);
    }
  }
  assert.ok(caughtSeen, 'expected at least one caught cheat across seeds');
  assert.ok(s);
});

test('pact: a called bluff kills the player; an accepted bluff deals 2 to the dealer', () => {
  const s = freshRound('PACT1');
  s.dealer.focus = 0;
  s.player.items.pact = 1;
  const rank = s.round.tableRank;
  const liar = s.round.hands.player.find((c) => c.rank !== rank && c.rank !== JOKER);
  if (liar) {
    useCheat(s, 'pact');
    play(s, 'player', [liar.id]);
    respond(s, 'dealer', 'call');
    assert.equal(s.player.hp, 0);
    assert.equal(s.phase, PHASE.GAME_OVER);
  }
  const t = freshRound('PACT2');
  t.dealer.focus = 0;
  t.player.items.pact = 1;
  t.dealer.hp = 3;
  t.dealer.maxHp = 3;
  const rank2 = t.round.tableRank;
  const liar2 = t.round.hands.player.find((c) => c.rank !== rank2 && c.rank !== JOKER);
  if (liar2) {
    useCheat(t, 'pact');
    play(t, 'player', [liar2.id]);
    respond(t, 'dealer', 'pass');
    assert.equal(t.dealer.hp, 1);
    assert.ok(drainEvents(t).some((e) => e.type === 'pactStrike'));
  }
});

test('beating a dealer offers heal + 2 rewards and choosing one advances the floor', () => {
  const s = freshRound('REWARD');
  s.dealer.hp = 1;
  s.cylinder.chambers = ['live', 'blank', 'blank', 'blank', 'blank', 'blank'];
  s.cylinder.composition = { live: 1, blank: 5, curse: 0 };
  const rank = s.round.tableRank;
  const honest = s.round.hands.player.find((c) => c.rank === rank || c.rank === JOKER);
  if (!honest) return;
  play(s, 'player', [honest.id]);
  respond(s, 'dealer', 'call');
  assert.equal(s.phase, PHASE.REWARD);
  assert.equal(s.rewards.length, 3);
  assert.equal(s.rewards[0].kind, 'heal');
  chooseReward(s, 1);
  assert.equal(s.floorIndex, 1);
  assert.equal(s.phase, PHASE.FLOOR_INTRO);
  assert.equal(s.dealer.id, FLOORS[1].dealer);
});

test('fuzz: 300 seeded self-play runs always terminate legally', () => {
  const rngPick = (seedN) => {
    let x = seedN * 2654435761;
    return () => {
      x = (x * 1664525 + 1013904223) >>> 0;
      return x / 4294967296;
    };
  };
  for (let n = 0; n < 300; n++) {
    const s = createRun({ seed: 'FUZZ' + n });
    const rnd = rngPick(n + 1);
    startFloor(s);
    beginRound(s);
    let guard = 0;
    while (s.phase !== PHASE.GAME_OVER && s.phase !== PHASE.VICTORY) {
      if (++guard > 5000) throw new Error('run did not terminate: ' + s.seed);
      if (s.phase === PHASE.REWARD) {
        chooseReward(s, Math.floor(rnd() * s.rewards.length));
        continue;
      }
      if (s.phase === PHASE.FLOOR_INTRO) {
        beginRound(s);
        continue;
      }
      if (s.round.turn === 'dealer') {
        dealerAct(s);
        continue;
      }
      const la = legalActions(s);
      if (la.cheats.length && rnd() < 0.3) {
        const cheat = la.cheats[Math.floor(rnd() * la.cheats.length)];
        if (cheat === 'bottomDeal') {
          const rank = s.round.tableRank;
          const liar = s.round.hands.player.find((c) => c.rank !== rank && c.rank !== JOKER);
          if (liar) useCheat(s, 'bottomDeal', { cardId: liar.id });
        } else {
          useCheat(s, cheat);
        }
        continue;
      }
      if (la.play) {
        const hand = s.round.hands.player;
        const k = 1 + Math.floor(rnd() * Math.min(3, hand.length));
        play(s, 'player', hand.slice(0, k).map((c) => c.id));
      } else if (la.call && (!la.pass || rnd() < 0.4)) {
        respond(s, 'player', 'call');
      } else if (la.pass) {
        respond(s, 'player', 'pass');
      } else {
        throw new Error('no legal action for player: ' + JSON.stringify(la));
      }
      // Invariants
      const r = s.round;
      if (s.phase === PHASE.ROUND) {
        const total = r.hands.player.length + r.hands.dealer.length + r.deck.length + r.pile.reduce((a, p) => a + p.cards.length, 0);
        assert.equal(total, s.player.relics.includes('blackCat') ? 21 : 20, 'card conservation ' + s.seed);
        assert.ok(s.cylinder.index >= 0 && s.cylinder.index < 6, 'cylinder index in range');
      }
      assert.ok(s.player.hp >= 0 && s.player.hp <= s.player.maxHp);
      assert.ok(s.dealer.hp >= 0 && s.dealer.hp <= s.dealer.maxHp);
    }
    assert.ok(s.events.length > 0);
  }
});
