// Balance simulator: plays N seeded runs with a simple heuristic player bot and
// prints per-floor survival. Usage: node tools/simulate.js [runs]
// The numbers in docs/GDD.md §8.4 come from this script.

import {
  createRun,
  startFloor,
  beginRound,
  play,
  respond,
  useCheat,
  dealerAct,
  chooseReward,
  legalActions,
  nextChamberOdds,
  PHASE,
} from '../src/rules.js';
import { FLOORS, JOKER } from '../src/data.js';
import { createRng } from '../src/rng.js';

const runs = Number(process.argv[2] || 2000);
const profile = process.argv[3] || 'both'; // naive | sharp | both

export function botTurn(s, rnd) {
  const la = legalActions(s);
  const r = s.round;
  const rank = r.tableRank;
  const hand = r.hands.player;
  const truthful = hand.filter((c) => c.rank === rank || c.rank === JOKER);
  const lying = hand.filter((c) => !(c.rank === rank || c.rank === JOKER));

  // Cheats: peek when about to decide a call, fix a bad hand before playing.
  if (la.cheats.includes('mirror') && r.phase === 'respond' && rnd.chance(0.6)) return useCheat(s, 'mirror');
  if (la.cheats.includes('bottomDeal') && r.phase === 'play' && truthful.length === 0 && lying.length) {
    return useCheat(s, 'bottomDeal', { cardId: lying[0].id });
  }
  if (la.cheats.includes('leadWeight') && r.phase === 'respond' && nextChamberOdds(s).pLive >= 0.5 && rnd.chance(0.7)) {
    return useCheat(s, 'leadWeight');
  }

  if (la.play) {
    if (truthful.length > 0 && (lying.length === 0 || rnd.chance(0.75))) {
      const k = Math.min(truthful.length, 1 + rnd.int(2));
      return play(s, 'player', truthful.slice(0, k).map((c) => c.id));
    }
    return play(s, 'player', [lying[0].id]);
  }
  // Respond: call more when the claim is large or the next chamber is likely blank.
  const lp = r.lastPlay;
  const odds = nextChamberOdds(s);
  const known = s.cylinder.knownNext;
  let pCall = 0.25 + 0.15 * (lp.claim - 1) - 0.2 * (odds.pLive - 0.5);
  if (known === 'blank') pCall += 0.4;
  if (known === 'live') pCall -= 0.4;
  if (r.revealed.dealer) pCall = lp.lie ? 1 : 0;
  if (!la.pass) return respond(s, 'player', 'call');
  return respond(s, 'player', rnd.chance(pCall) ? 'call' : 'pass');
}

// Sharp bot: estimates the dealer's lie chance from its own truthful count,
// the dealer's known bluff rate and claim size; spends items where they matter.
export function sharpTurn(s, rnd) {
  const la = legalActions(s);
  const r = s.round;
  const rank = r.tableRank;
  const hand = r.hands.player;
  const truthful = hand.filter((c) => c.rank === rank || c.rank === JOKER);
  const lying = hand.filter((c) => !(c.rank === rank || c.rank === JOKER));
  const odds = nextChamberOdds(s);

  if (la.play) {
    if (la.cheats.includes('bottomDeal') && truthful.length === 0 && lying.length && r.hands.dealer.length <= 2) {
      return useCheat(s, 'bottomDeal', { cardId: lying[0].id });
    }
    if (truthful.length > 0) {
      // Dump truthful cards fast; larger honest claims bait calls.
      const k = Math.min(truthful.length, 3);
      return play(s, 'player', truthful.slice(0, k).map((c) => c.id));
    }
    return play(s, 'player', [lying[0].id]);
  }

  const lp = r.lastPlay;
  const total = 8 + (s.player.relics.includes('blackCat') ? 1 : 0);
  const mine = truthful.length;
  let pLie;
  if (r.revealed.dealer) pLie = lp.lie ? 1 : 0;
  else if (mine + r.claimed.dealer > total) pLie = 1;
  else {
    const base = { 1: 0.3, 2: 0.45, 3: 0.65 }[lp.claim] ?? 0.65;
    const expected = ((total - mine) / 15) * 5;
    pLie = Math.max(0.05, Math.min(0.95, base + 0.12 * (r.claimed.dealer - expected) + (s.dealer.bluffRate - 0.35) * 0.5));
  }
  let known = s.cylinder.knownNext;
  if (!known && la.cheats.includes('mirror') && pLie > 0.35 && pLie < 0.75) {
    useCheat(s, 'mirror');
    known = s.cylinder.knownNext;
    if (s.phase !== PHASE.ROUND) return;
    return; // decide next tick with the new info
  }
  if (!known && la.cheats.includes('leadWeight') && odds.pLive >= 0.5 && pLie >= 0.5) {
    useCheat(s, 'leadWeight');
    return;
  }
  const pLive = known === 'blank' ? 0 : known === 'live' ? 1 : odds.pLive;
  // EV of calling: win if lie (dealer shoots), else I shoot with pLive.
  const callRisk = (1 - pLie) * pLive;
  const passRisk = hand.length === 0 ? 1 : 0.35 * pLive + (truthful.length === 0 ? 0.25 : 0.05);
  if (!la.pass) return respond(s, 'player', 'call');
  return respond(s, 'player', pLie >= 0.5 || callRisk < passRisk ? 'call' : 'pass');
}

function runProfile(name, turnFn) {
const reached = new Array(FLOORS.length + 1).fill(0); // index = floors cleared
let victories = 0;
let totalRounds = 0;
let cheats = 0;
let caught = 0;

for (let i = 0; i < runs; i++) {
  const s = createRun({ seed: 'SIM' + i });
  const rnd = createRng('BOT' + i);
  startFloor(s);
  beginRound(s);
  let guard = 0;
  while (s.phase !== PHASE.GAME_OVER && s.phase !== PHASE.VICTORY) {
    if (++guard > 20000) throw new Error('stuck ' + s.seed);
    if (s.phase === PHASE.REWARD) {
      // Prefer heal when hurt, otherwise a relic, otherwise an item.
      const hurt = s.player.hp < s.player.maxHp;
      let idx = 0;
      if (!hurt) {
        const relicIdx = s.rewards.findIndex((x) => x.kind === 'relic');
        idx = relicIdx >= 0 ? relicIdx : 1;
      }
      chooseReward(s, idx);
      continue;
    }
    if (s.phase === PHASE.FLOOR_INTRO) {
      beginRound(s);
      continue;
    }
    if (s.round.turn === 'dealer') dealerAct(s);
    else turnFn(s, rnd);
    s.events.length = 0;
  }
  const cleared = s.stats.dealersBeaten;
  reached[cleared] += 1;
  if (s.phase === PHASE.VICTORY) victories += 1;
  totalRounds += s.roundNumber;
  cheats += s.stats.cheatsUsed;
  caught += s.stats.cheatsCaught;
}

console.log(`[${name}] runs=${runs} victories=${victories} (${((victories / runs) * 100).toFixed(1)}%) avgRounds=${(totalRounds / runs).toFixed(1)} cheatCaughtRate=${cheats ? ((caught / cheats) * 100).toFixed(1) : 0}%`);
console.log('floor | died here | reach% | clear% (of those who reached)');
let alive = runs;
for (let f = 0; f < FLOORS.length; f++) {
  const diedHere = reached[f];
  const reachPct = ((alive / runs) * 100).toFixed(1);
  const clearPct = alive ? (((alive - diedHere) / alive) * 100).toFixed(1) : '0.0';
  console.log(`B${f + 1} (${FLOORS[f].dealer.padEnd(7)}) | ${String(diedHere).padStart(5)} | ${reachPct.padStart(6)} | ${clearPct.padStart(6)}`);
  alive -= diedHere;
}
}

if (process.env.SIM_LIB !== '1') {
  if (profile === 'naive' || profile === 'both') runProfile('naive', botTurn);
  if (profile === 'sharp' || profile === 'both') runProfile('sharp', sharpTurn);
}
