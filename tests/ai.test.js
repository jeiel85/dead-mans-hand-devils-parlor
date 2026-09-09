import { test } from 'node:test';
import assert from 'node:assert/strict';

import { createRun, startFloor, beginRound, play, drainEvents } from '../src/rules.js';
import { dealerDecidePlay, dealerDecideRespond, estimatePlayerLie } from '../src/ai.js';
import { JOKER, MAX_PLAY } from '../src/data.js';

function roundWithDealerTurn(seed) {
  const s = createRun({ seed });
  startFloor(s);
  beginRound(s);
  drainEvents(s);
  return s;
}

test('dealer never plays more than 3 cards or cards it does not hold', () => {
  for (let i = 0; i < 100; i++) {
    const s = roundWithDealerTurn('AIPLAY' + i);
    s.round.turn = 'dealer';
    const ids = dealerDecidePlay(s);
    assert.ok(ids.length >= 1 && ids.length <= MAX_PLAY);
    for (const id of ids) assert.ok(s.round.hands.dealer.some((c) => c.id === id));
  }
});

test('dealer with an empty hand always calls', () => {
  const s = roundWithDealerTurn('AICALL');
  play(s, 'player', [s.round.hands.player[0].id]);
  s.round.hands.dealer = [];
  assert.equal(dealerDecideRespond(s), 'call');
});

test('impossible claims are always called', () => {
  const s = roundWithDealerTurn('AIIMPOSSIBLE');
  const rank = s.round.tableRank;
  // Give the dealer all 6 of the table rank + both jokers: nothing truthful can be outside.
  s.round.hands.dealer = [
    ...Array.from({ length: 6 }, (_, i) => ({ id: 100 + i, rank })),
    { id: 200, rank: JOKER },
    { id: 201, rank: JOKER },
  ];
  play(s, 'player', [s.round.hands.player[0].id]);
  assert.equal(estimatePlayerLie(s), 1);
  assert.equal(dealerDecideRespond(s), 'call');
});

test('a cursed (revealed) player is read perfectly', () => {
  const s = roundWithDealerTurn('AICURSE');
  s.round.revealed.player = true;
  const rank = s.round.tableRank;
  const liar = s.round.hands.player.find((c) => c.rank !== rank && c.rank !== JOKER);
  const honest = s.round.hands.player.find((c) => c.rank === rank || c.rank === JOKER);
  if (liar) {
    play(s, 'player', [liar.id]);
    assert.equal(estimatePlayerLie(s), 1);
  } else if (honest) {
    play(s, 'player', [honest.id]);
    assert.equal(estimatePlayerLie(s), 0);
  }
});

test('when the player is out of cards the dealer prefers honest plays', () => {
  for (let i = 0; i < 50; i++) {
    const s = roundWithDealerTurn('AIOUT' + i);
    s.round.turn = 'dealer';
    s.round.hands.player = [];
    const rank = s.round.tableRank;
    const truthful = s.round.hands.dealer.filter((c) => c.rank === rank || c.rank === JOKER);
    const ids = dealerDecidePlay(s);
    if (truthful.length > 0) {
      const played = ids.map((id) => s.round.hands.dealer.find((c) => c.id === id));
      assert.ok(played.every((c) => c.rank === rank || c.rank === JOKER), 'seed ' + i);
    }
  }
});
