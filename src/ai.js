// Dealer AI. Pure functions over the engine state; randomness via state.rng.
// Each dealer persona is parameterised in data.js; gimmicks add behaviour.

import { JOKER, DECK_SPEC, MAX_PLAY } from './data.js';

function truthful(cards, rank) {
  return cards.filter((c) => c.rank === rank || c.rank === JOKER);
}
function lies(cards, rank) {
  return cards.filter((c) => c.rank !== rank && c.rank !== JOKER);
}

export function totalTruthfulInDeck(state) {
  const jokers = state.player.relics.includes('blackCat') ? DECK_SPEC.J + 1 : DECK_SPEC.J;
  return DECK_SPEC[state.round.tableRank] + jokers;
}

// Estimate the probability that the player's last play was a lie.
export function estimatePlayerLie(state) {
  const r = state.round;
  const d = state.dealer;
  const lp = r.lastPlay;
  if (!lp || lp.by !== 'player') return 0;
  if (r.revealed.player) return lp.lie ? 1 : 0;

  const n = lp.claim;
  const total = totalTruthfulInDeck(state);
  const mine = truthful(r.hands.dealer, r.tableRank).length;
  const claimedByPlayer = r.claimed.player;
  // Impossible claim: more truthful cards claimed than can exist outside my hand.
  if (mine + claimedByPlayer > total) return 1;

  const remaining = total - mine;
  const unseen = 20 - r.hands.dealer.length; // cards not in dealer hand (approx.)
  const expectedInPlayerHand = (remaining / Math.max(1, unseen)) * 5;
  const base = { 1: 0.3, 2: 0.45, 3: 0.65 }[n] ?? 0.65;
  let p = base + 0.12 * (claimedByPlayer - expectedInPlayerHand);

  // Card counters learn the player's bluffing habits across rounds.
  const mem = d.memory;
  if (mem.playerPlays >= 2) {
    const ratio = mem.playerLies / mem.playerPlays;
    const weight = d.gimmick === 'counter' ? 0.5 : 0.2;
    p += (ratio - 0.4) * weight;
  }
  return clamp(p, 0.02, 0.98);
}

export function nextLiveChance(state) {
  const cyl = state.cylinder;
  const remaining = cyl.chambers.length - cyl.index;
  if (remaining <= 0) return cyl.composition.live / cyl.chambers.length;
  const spentLive = cyl.spent.filter((b) => b === 'live').length;
  return (cyl.composition.live - spentLive) / remaining;
}

export function dealerDecideRespond(state) {
  const r = state.round;
  const d = state.dealer;
  const hand = r.hands.dealer;
  if (hand.length === 0) return 'call';

  const pLie = estimatePlayerLie(state);
  if (pLie >= 1) return 'call';
  const pLive = nextLiveChance(state);
  let score = pLie + d.callBias - 0.25 * (pLive - 0.5);

  // If the player is out of cards, whoever plays next gets force-called.
  const mine = truthful(hand, r.tableRank).length;
  if (r.hands.player.length === 0) {
    score += mine > 0 ? -0.35 : 0.35;
  }
  if (d.noise > 0) score += (state.rng.next() * 2 - 1) * d.noise;
  return score >= 0.5 ? 'call' : 'pass';
}

export function dealerDecidePlay(state) {
  const r = state.round;
  const d = state.dealer;
  const hand = r.hands.dealer;
  const rank = r.tableRank;
  const truth = truthful(hand, rank).sort((a, b) => (a.rank === JOKER) - (b.rank === JOKER));
  const lie = lies(hand, rank);
  const playerOut = r.hands.player.length === 0;

  const pick = (arr, k) => arr.slice(0, Math.max(1, Math.min(k, arr.length, MAX_PLAY))).map((c) => c.id);

  // Player has no cards: this play will be force-called, so never bluff if avoidable.
  if (playerOut && truth.length > 0) return pick(truth, truth.length);

  const wantBluff = lie.length > 0 && (truth.length === 0 || state.rng.chance(d.bluffRate));
  if (!wantBluff) {
    // Honest play: 1-2 cards normally, keep jokers for later.
    const k = 1 + state.rng.int(Math.min(2, truth.length));
    return pick(truth, k);
  }
  // Bluff: minimal exposure unless greedy persona.
  const maxK = d.gimmick === 'aggressive' ? d.greed : 1 + state.rng.int(2);
  const k = Math.min(maxK, lie.length);
  return pick(lie, k);
}

function clamp(x, lo, hi) {
  return Math.max(lo, Math.min(hi, x));
}
