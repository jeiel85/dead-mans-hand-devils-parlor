// Emits a deterministic action/event trace for cross-engine verification.
// The Godot port (godot/test/test_runner.gd) replays the same scripted policy
// with the same seeds and must produce byte-identical traces.
//
// Usage: node tools/trace.js > godot/test/fixtures/traces.json

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
  legalActions,
  PHASE,
} from '../src/rules.js';
import { JOKER, DEALERS } from '../src/data.js';

// Scripted player policy: deterministic, exercises cheats, plays and calls.
function scriptedTurn(s, step) {
  const la = legalActions(s);
  const r = s.round;
  const rank = r.tableRank;
  const hand = r.hands.player;
  const truthful = hand.filter((c) => c.rank === rank || c.rank === JOKER);
  const lying = hand.filter((c) => !(c.rank === rank || c.rank === JOKER));
  if (la.cheats.length && step % 4 === 1) {
    const cheat = la.cheats[step % la.cheats.length];
    if (cheat === 'bottomDeal') {
      if (lying.length) return useCheat(s, 'bottomDeal', { cardId: lying[0].id }), 'cheat:bottomDeal:' + lying[0].id;
    } else return useCheat(s, cheat), 'cheat:' + cheat;
  }
  if (la.play) {
    const k = 1 + (step % Math.min(3, hand.length));
    const pool = step % 3 === 0 && lying.length ? lying : truthful.length ? truthful : lying;
    const ids = pool.slice(0, Math.max(1, Math.min(k, pool.length))).map((c) => c.id);
    play(s, 'player', ids);
    return 'play:' + ids.join('.');
  }
  if (la.call && (!la.pass || step % 2 === 0)) return respond(s, 'player', 'call'), 'call';
  return respond(s, 'player', 'pass'), 'pass';
}

function compactEvent(e) {
  const out = { t: e.type };
  for (const k of ['by', 'count', 'tableRank', 'handLeft', 'challenger', 'lie', 'shooter', 'who', 'bullet', 'effect', 'chamber', 'hp', 'from', 'to', 'cheat', 'caught', 'swapped', 'number', 'starter', 'dealer', 'floor', 'level', 'gimmick', 'relic', 'nextStarter', 'target']) {
    if (e[k] !== undefined) out[k] = e[k];
  }
  if (e.cards) out.cards = e.cards.map((c) => c.id + c.rank).join(',');
  if (e.composition) out.comp = `${e.composition.live}/${e.composition.blank}/${e.composition.curse}`;
  if (e.reward) out.reward = e.reward.kind + ':' + e.reward.id;
  if (e.rewards) out.rewards = e.rewards.map((x) => x.kind + ':' + x.id).join(',');
  if (e.newCard) out.newCard = e.newCard.id + e.newCard.rank;
  return out;
}

// Seeds are fixed, not searched at generation time, so the fixture is stable and
// reviewable. The last two were picked to close coverage gaps the first five
// left: T2326 walks the scripted policy all the way to B7 (so every dealer's
// gimmick appears in a trace) and T1278 ends in victory (so the win transition
// is traced, not just game over). assertCoverage below fails generation if a
// future edit loses either property.
const SEEDS = ['TRACE-A', 'TRACE-B', 'TRACE-C', 'DEMO01', 'E2E-01', 'T2326', 'T1278'];

const traces = [];
for (const seed of SEEDS) {
  const s = createRun({ seed });
  startFloor(s);
  beginRound(s);
  const actions = [];
  const events = drainEvents(s).map(compactEvent);
  let step = 0;
  let guard = 0;
  while (s.phase !== PHASE.GAME_OVER && s.phase !== PHASE.VICTORY && guard++ < 2000) {
    if (s.phase === PHASE.REWARD) {
      const idx = step % s.rewards.length;
      chooseReward(s, idx);
      actions.push('reward:' + idx);
    } else if (s.phase === PHASE.FLOOR_INTRO) {
      beginRound(s);
      actions.push('begin');
    } else if (s.round.turn === 'dealer') {
      const res = dealerAct(s);
      actions.push('dealer:' + res.action);
    } else {
      actions.push(scriptedTurn(s, step));
      step++;
    }
    for (const e of drainEvents(s)) events.push(compactEvent(e));
  }
  traces.push({
    seed,
    final: { phase: s.phase, floor: s.floorIndex, hp: s.player.hp, dealerHp: s.dealer.hp, rounds: s.roundNumber, stats: s.stats },
    firstDeal: { rank: s.round?.tableRank, chambers: null },
    actions,
    events,
  });
}

function assertCoverage(all) {
  const seenDealers = new Set();
  const seenPhases = new Set();
  for (const tr of all) {
    seenPhases.add(tr.final.phase);
    for (const e of tr.events) if (e.dealer) seenDealers.add(e.dealer);
  }
  const allDealers = Object.keys(DEALERS);
  const missingDealers = allDealers.filter((id) => !seenDealers.has(id));
  const missingPhases = ['gameOver', 'victory'].filter((p) => !seenPhases.has(p));
  const problems = [];
  if (missingDealers.length) problems.push(`dealers never reached: ${missingDealers.join(', ')}`);
  if (missingPhases.length) problems.push(`run endings never reached: ${missingPhases.join(', ')}`);
  if (problems.length) {
    process.stderr.write(['trace.js: coverage gap', ...problems].join('\n  ') + '\n');
    process.exit(1);
  }
  process.stderr.write(
    `trace.js: ${all.length} seeds, ${all.reduce((n, t) => n + t.events.length, 0)} events, `
    + `${seenDealers.size}/${allDealers.length} dealers, endings: ${[...seenPhases].join('+')}\n`,
  );
}

assertCoverage(traces);
process.stdout.write(JSON.stringify(traces));
