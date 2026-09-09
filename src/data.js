// Static game data. Numbers here are the single source of truth for the
// prototype and are mirrored in docs/GDD.md (section 8, balance tables).

export const RANKS = ['K', 'Q', 'A'];
export const JOKER = 'J';
export const DECK_SPEC = { K: 6, Q: 6, A: 6, J: 2 };
export const HAND_SIZE = 5;
export const MAX_PLAY = 3;
export const CYLINDER_SIZE = 6;
export const CHALLENGE_SECONDS = 15;
export const PLAYER_MAX_HP = 3;

export const BULLET = Object.freeze({ LIVE: 'live', BLANK: 'blank', CURSE: 'curse' });

// Cheat items. baseDetect is multiplied by the dealer's focus.
// phases: when the player may use it during their own turn.
export const CHEATS = Object.freeze({
  mirror: { id: 'mirror', baseDetect: 0.1, phases: ['play', 'respond'] },
  bottomDeal: { id: 'bottomDeal', baseDetect: 0.15, phases: ['play'] },
  leadWeight: { id: 'leadWeight', baseDetect: 0.25, phases: ['play', 'respond'] },
  pact: { id: 'pact', baseDetect: 0, phases: ['play'] },
});
export const CHEAT_IDS = Object.keys(CHEATS);

export const STARTING_ITEMS = Object.freeze({ mirror: 1, bottomDeal: 1, leadWeight: 1, pact: 0 });
export const FLOOR_CLEAR_HEAL = 1;

export const FLOORS = [
  { id: 'b1', level: 1, dealer: 'jack', hp: 1, cylinder: { live: 2, blank: 4, curse: 0 } },
  { id: 'b2', level: 2, dealer: 'martha', hp: 2, cylinder: { live: 2, blank: 4, curse: 0 } },
  { id: 'b3', level: 3, dealer: 'dominic', hp: 3, cylinder: { live: 3, blank: 2, curse: 1 } },
  { id: 'b4', level: 4, dealer: 'ida', hp: 3, cylinder: { live: 3, blank: 3, curse: 0 } },
  { id: 'b5', level: 5, dealer: 'bela', hp: 3, cylinder: { live: 3, blank: 2, curse: 1 } },
  { id: 'b6', level: 6, dealer: 'grimm', hp: 4, cylinder: { live: 4, blank: 2, curse: 0 } },
  { id: 'b7', level: 7, dealer: 'devil', hp: 4, cylinder: { live: 4, blank: 1, curse: 1 } },
];

// focus: cheat-detection multiplier. bluffRate: chance to bluff when a truthful
// play exists. callBias: added to the call score. noise: random jitter on the
// call score. greed: max cards per play when bluffing/aggressive.
export const DEALERS = Object.freeze({
  jack: { id: 'jack', focus: 0.5, bluffRate: 0.5, callBias: -0.15, noise: 0.3, greed: 2, gimmick: 'drunk' },
  martha: { id: 'martha', focus: 0.8, bluffRate: 0.6, callBias: -0.05, noise: 0.1, greed: 3, gimmick: 'aggressive' },
  dominic: { id: 'dominic', focus: 1.0, bluffRate: 0.3, callBias: 0.05, noise: 0.05, greed: 2, gimmick: 'counter' },
  ida: { id: 'ida', focus: 1.6, bluffRate: 0.3, callBias: 0.05, noise: 0.05, greed: 2, gimmick: 'hawkeye' },
  bela: { id: 'bela', focus: 1.0, bluffRate: 0.4, callBias: 0.0, noise: 0.1, greed: 2, gimmick: 'mender' },
  grimm: { id: 'grimm', focus: 1.3, bluffRate: 0.25, callBias: 0.1, noise: 0.05, greed: 2, gimmick: 'verdict' },
  devil: { id: 'devil', focus: 1.5, bluffRate: 0.45, callBias: 0.1, noise: 0.05, greed: 3, gimmick: 'proprietor' },
});

export const RELIC_IDS = [
  'cigaretteCase', // +1 max HP, heal 1
  'hipFlask', // once per run, a lethal live round leaves you at 1 HP
  'leatherGloves', // cheat detection x0.6
  'markedDeck', // at round start, see one random dealer card
  'pocketBible', // 25% chance a live round against you misfires (counts as blank)
  'snakeOil', // heal 1 when a floor is cleared
  'loadedDice', // the mirror is never detected
  'blackCat', // deck holds 3 jokers instead of 2
];

export const RELIC_EFFECTS = Object.freeze({
  leatherGlovesMultiplier: 0.6,
  pocketBibleMisfire: 0.25,
});
