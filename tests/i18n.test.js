import test from 'node:test';
import assert from 'node:assert/strict';
import { applyJosa, batchimOf, BATCHIM, JOSA_PAIRS, DICT } from '../src/i18n.js';

// Korean particles are written with both forms ("{who}이(가)") and resolved after
// interpolation. Mirrors _test_josa() in godot/test/test_runner.gd.

test('josa picks the form from the preceding 받침', () => {
  assert.equal(applyJosa('잭이(가) 온다'), '잭이 온다');
  assert.equal(applyJosa('당신이(가) 온다'), '당신이 온다');
  assert.equal(applyJosa('에이스이(가) 온다'), '에이스가 온다');
  assert.equal(applyJosa('킹을(를) 냈다'), '킹을 냈다');
  assert.equal(applyJosa('조커을(를) 냈다'), '조커를 냈다');
  assert.equal(applyJosa('잭은(는) 취했다'), '잭은 취했다');
  assert.equal(applyJosa('조커은(는) 취했다'), '조커는 취했다');
  assert.equal(applyJosa('잭와(과) 함께'), '잭과 함께');
  assert.equal(applyJosa('조커와(과) 함께'), '조커와 함께');
});

test('으로/로 takes the vowel form after ㄹ', () => {
  assert.equal(applyJosa('서울으로(로) 간다'), '서울로 간다');
  assert.equal(applyJosa('지하으로(로) 간다'), '지하로 간다');
  assert.equal(applyJosa('빈민가골목으로(로) 간다'), '빈민가골목으로 간다');
});

test('unresolvable text is left exactly as written', () => {
  assert.equal(applyJosa('Jack이(가) 온다'), 'Jack이(가) 온다');
  assert.equal(applyJosa('이(가) 온다'), '이(가) 온다');
  assert.equal(applyJosa('42이(가) 온다'), '42이(가) 온다');
});

test('every occurrence is resolved, not just the first', () => {
  assert.equal(applyJosa('잭이(가) 잭이(가)'), '잭이 잭이');
  assert.equal(applyJosa('킹을(를) 내고 조커을(를) 냈다'), '킹을 내고 조커를 냈다');
});

test('batchimOf classifies syllables', () => {
  assert.equal(batchimOf(''), BATCHIM.UNKNOWN);
  assert.equal(batchimOf('A'), BATCHIM.UNKNOWN);
  assert.equal(batchimOf('가'), BATCHIM.NONE);
  assert.equal(batchimOf('각'), BATCHIM.YES);
  assert.equal(batchimOf('갈'), BATCHIM.RIEUL);
});

test('no Korean string ships a particle it cannot resolve', () => {
  for (const [key, value] of Object.entries(DICT.ko)) {
    if (typeof value !== 'string') continue;
    for (const [token] of JOSA_PAIRS) {
      const idx = value.indexOf(token);
      if (idx <= 0) continue;
      const prev = value[idx - 1];
      // Resolvable means a Hangul syllable, or a placeholder substituted first.
      assert.ok(
        batchimOf(prev) !== BATCHIM.UNKNOWN || prev === '}',
        `ko[${key}]: ${token} preceded by unresolvable "${prev}"`,
      );
    }
  }
});

// Action-button visibility. Mirrors _test_action_buttons() in the Godot runner.
test('the dealer turn never stacks all three action buttons', async () => {
  const { showsRespondButtons } = await import('../src/render.js');
  assert.equal(showsRespondButtons('player', 'respond'), true);
  assert.equal(showsRespondButtons('player', 'play'), false);
  assert.equal(showsRespondButtons('dealer', 'play'), true);
  assert.equal(showsRespondButtons('dealer', 'respond'), false);
});
