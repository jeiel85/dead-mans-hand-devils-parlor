// Controller: wires the engine to the DOM, paces dealer turns, animates events.

import { t, setLang, getLang } from './i18n.js';
import { sfx, setEnabled as setSound } from './audio.js';
import { FLOORS, CHALLENGE_SECONDS, JOKER } from './data.js';
import { randomSeed } from './rng.js';
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
  isTruthful,
  PHASE,
} from './rules.js';
import {
  esc,
  whoName,
  rankName,
  cardHtml,
  heartsHtml,
  portraitSvg,
  cylinderSvg,
  oddsHtml,
  pileHtml,
  itemsHtml,
  relicsHtml,
  floorLabel,
  statsHtml,
  showsRespondButtons,
} from './render.js';

const $ = (sel) => document.querySelector(sel);
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const STORAGE = 'dmh-devils-parlor';

const settings = loadSettings();
let game = null;
let selected = new Set();
let busy = false;
let dealerTimer = null;
let timer = { handle: null, deadline: 0 };
let logLines = [];

// ---------------------------------------------------------------------------
// Settings & persistence
// ---------------------------------------------------------------------------

function loadSettings() {
  const def = { lang: navigator.language?.startsWith('ko') ? 'ko' : 'en', sound: true, timer: true, bestFloor: 0 };
  try {
    const raw = localStorage.getItem(STORAGE);
    return raw ? { ...def, ...JSON.parse(raw) } : def;
  } catch {
    return def;
  }
}
function saveSettings() {
  try {
    localStorage.setItem(STORAGE, JSON.stringify(settings));
  } catch {
    /* storage unavailable: settings live for this session only */
  }
}

// ---------------------------------------------------------------------------
// Boot
// ---------------------------------------------------------------------------

function boot() {
  setLang(settings.lang);
  setSound(settings.sound);
  document.documentElement.lang = getLang();
  bindStatic();
  renderStatic();
  showTitle();
}

function bindStatic() {
  $('#btn-lang').addEventListener('click', () => {
    settings.lang = getLang() === 'ko' ? 'en' : 'ko';
    setLang(settings.lang);
    document.documentElement.lang = getLang();
    saveSettings();
    renderStatic();
    renderAll();
    if (!$('#overlay').hidden) rerenderOverlay();
  });
  $('#btn-sound').addEventListener('click', () => {
    settings.sound = !settings.sound;
    setSound(settings.sound);
    saveSettings();
    renderStatic();
    if (settings.sound) sfx.chip();
  });
  $('#btn-timer').addEventListener('click', () => {
    settings.timer = !settings.timer;
    saveSettings();
    renderStatic();
    if (!settings.timer) stopTimer();
    else if (game && game.phase === PHASE.ROUND && game.round.turn === 'player' && game.round.phase === 'respond') startTimer();
  });
  $('#btn-help').addEventListener('click', () => showHelp());

  $('#player-hand').addEventListener('click', (e) => {
    const el = e.target.closest('[data-card]');
    if (!el || busy) return;
    toggleSelect(Number(el.dataset.card));
  });
  $('#player-hand').addEventListener('keydown', (e) => {
    if (e.key !== 'Enter' && e.key !== ' ') return;
    const el = e.target.closest('[data-card]');
    if (!el || busy) return;
    e.preventDefault();
    toggleSelect(Number(el.dataset.card));
  });
  $('#items').addEventListener('click', (e) => {
    const el = e.target.closest('[data-item]');
    if (!el || busy) return;
    onCheat(el.dataset.item);
  });
  $('#btn-play').addEventListener('click', onPlay);
  $('#btn-call').addEventListener('click', () => onRespond('call'));
  $('#btn-pass').addEventListener('click', () => onRespond('pass'));
  document.addEventListener('keydown', (e) => {
    if (busy || !game || game.phase !== PHASE.ROUND || !$('#overlay').hidden) return;
    if (e.key === 'Enter' && !$('#btn-play').disabled) onPlay();
    if ((e.key === 'c' || e.key === 'C') && !$('#btn-call').disabled) onRespond('call');
    if ((e.key === 'p' || e.key === 'P') && !$('#btn-pass').disabled) onRespond('pass');
  });
  document.addEventListener('pointerdown', () => sfx.unlock(), { once: true });
}

function renderStatic() {
  $('#btn-lang').textContent = getLang() === 'ko' ? 'EN' : '한국어';
  $('#btn-sound').textContent = settings.sound ? '🔊' : '🔇';
  $('#btn-sound').setAttribute('aria-label', `${t('set.sound')} ${settings.sound ? t('set.on') : t('set.off')}`);
  $('#btn-timer').textContent = settings.timer ? '⏱' : '⏱̸';
  $('#btn-timer').classList.toggle('off', !settings.timer);
  $('#btn-timer').setAttribute('aria-label', `${t('set.timer')} ${settings.timer ? t('set.on') : t('set.off')}`);
  $('#btn-help').setAttribute('aria-label', t('help.title'));
  $('#btn-play').textContent = t('btn.play');
  $('#btn-call').textContent = t('btn.call');
  $('#btn-pass').textContent = t('btn.pass');
  $('#lbl-hand').textContent = t('hud.yourHand');
  $('#lbl-pile').textContent = t('hud.pile');
  $('#lbl-cyl').textContent = t('hud.cylinder');
  $('#lbl-items').textContent = t('hud.items');
  $('#lbl-relics').textContent = t('hud.relics');
  $('#lbl-log').textContent = t('hud.log');
  $('#lbl-rank').textContent = t('hud.tableRank');
  $('#brand-sub').textContent = t('app.subtitle');
}

// ---------------------------------------------------------------------------
// Overlays
// ---------------------------------------------------------------------------

let overlayKind = null;
let overlayData = null;

function openOverlay(kind, data, html) {
  overlayKind = kind;
  overlayData = data;
  const ov = $('#overlay');
  $('#modal').innerHTML = html;
  ov.hidden = false;
  const first = $('#modal').querySelector('button, input');
  if (first) first.focus();
}
function closeOverlay() {
  $('#overlay').hidden = true;
  overlayKind = null;
  overlayData = null;
}
function rerenderOverlay() {
  const k = overlayKind;
  const d = overlayData;
  if (k === 'title') showTitle();
  else if (k === 'help') showHelp();
  else if (k === 'intro') showFloorIntro();
  else if (k === 'reward') showReward();
  else if (k === 'over') showGameOver(d);
  else if (k === 'win') showVictory();
}

function showTitle() {
  stopTimer();
  clearTimeout(dealerTimer);
  const best = settings.bestFloor ? t('seed.best', { floor: settings.bestFloor }) : t('seed.none');
  openOverlay(
    'title',
    null,
    `<div class="title-card">
      <div class="title-art">${cylinderArt()}</div>
      <h1 class="title">${t('app.title')}</h1>
      <h2 class="subtitle">${esc(t('app.subtitle'))}</h2>
      <p class="tagline">${esc(t('app.tagline'))}</p>
      <label class="seed-row"><span>${t('seed.label')}</span><input id="seed-input" maxlength="24" placeholder="${esc(t('seed.placeholder'))}" autocomplete="off" spellcheck="false"></label>
      <div class="row">
        <button class="primary" id="btn-start">${t('btn.newRun')}</button>
        <button id="btn-rules">${t('btn.howToPlay')}</button>
      </div>
      <p class="muted small">${esc(best)} · ${esc(t('app.prototype'))}</p>
    </div>`,
  );
  $('#btn-start').addEventListener('click', () => {
    const v = $('#seed-input').value.trim();
    startRun(v || randomSeed());
  });
  $('#seed-input').addEventListener('keydown', (e) => {
    if (e.key === 'Enter') $('#btn-start').click();
  });
  $('#btn-rules').addEventListener('click', () => showHelp('title'));
}

function cylinderArt() {
  return `<svg viewBox="0 0 120 120" class="title-cyl" aria-hidden="true">
    <circle cx="60" cy="60" r="54" fill="#231d1a" stroke="#6b5a48" stroke-width="3"/>
    ${[0, 1, 2, 3, 4, 5]
      .map((i) => {
        const a = (i / 6) * Math.PI * 2 - Math.PI / 2;
        const x = 60 + Math.cos(a) * 34;
        const y = 60 + Math.sin(a) * 34;
        return `<circle cx="${x}" cy="${y}" r="11" fill="${i === 2 ? '#7a1f1f' : '#1b1614'}" stroke="#5a4a3a" stroke-width="1.5"/>`;
      })
      .join('')}
    <circle cx="60" cy="60" r="8" fill="#0f0c0b" stroke="#6b5a48" stroke-width="2"/>
  </svg>`;
}

function showHelp(returnTo) {
  const body = t('help.body');
  openOverlay(
    'help',
    returnTo,
    `<div class="help">
      <h2>${t('help.title')}</h2>
      <ol>${body.map((l) => `<li>${esc(l)}</li>`).join('')}</ol>
      <div class="row"><button class="primary" id="btn-close-help">${t('btn.close')}</button></div>
    </div>`,
  );
  $('#btn-close-help').addEventListener('click', () => {
    if (returnTo === 'title' || !game) showTitle();
    else if (game.phase === PHASE.FLOOR_INTRO) showFloorIntro();
    else if (game.phase === PHASE.REWARD) showReward();
    else closeOverlay();
  });
}

function showFloorIntro() {
  const f = FLOORS[game.floorIndex];
  const d = game.dealer;
  openOverlay(
    'intro',
    null,
    `<div class="intro">
      <div class="intro-portrait">${portraitSvg(d.id)}</div>
      <p class="eyebrow">${esc(t('intro.title', { level: f.level, name: t(`floor.${f.id}`) }))}</p>
      <h2>${esc(t(`dealer.${d.id}.name`))}</h2>
      <p class="muted">${esc(t(`dealer.${d.id}.title`))}</p>
      <blockquote>“${esc(t(`dealer.${d.id}.intro`))}”</blockquote>
      <p class="gimmick">${esc(t(`dealer.${d.id}.gimmick`))}</p>
      <p class="small">${esc(t('intro.cylinder', f.cylinder))} · ${esc(t('intro.hp', { hp: f.hp }))}</p>
      <div class="row"><button class="primary" id="btn-enter">${t('btn.enter')}</button></div>
    </div>`,
  );
  $('#btn-enter').addEventListener('click', () => {
    closeOverlay();
    sfx.card();
    beginRound(game);
    afterEngineStep();
  });
}

function showReward() {
  const d = game.dealer;
  const cards = game.rewards
    .map((r, i) => {
      const name = r.kind === 'heal' ? t('reward.heal.name') : r.kind === 'item' ? t(`item.${r.id}.name`) : t(`relic.${r.id}.name`);
      const desc = r.kind === 'heal' ? t('reward.heal.desc') : r.kind === 'item' ? t(`item.${r.id}.desc`) : t(`relic.${r.id}.desc`);
      const kind = r.kind === 'heal' ? '' : r.kind === 'item' ? t('reward.item') : t('reward.relic');
      return `<button class="reward-card kind-${r.kind}" data-reward="${i}">
        <span class="reward-icon icon-${r.id}"></span>
        <span class="reward-kind">${esc(kind)}</span>
        <span class="reward-name">${esc(name)}</span>
        <span class="reward-desc">${esc(desc)}</span>
      </button>`;
    })
    .join('');
  openOverlay(
    'reward',
    null,
    `<div class="reward">
      <h2>${t('reward.title')}</h2>
      <p class="muted">${esc(t('reward.sub', { name: t(`dealer.${d.id}.name`) }))}</p>
      <div class="reward-row">${cards}</div>
      <div class="hp-line">${heartsHtml(game.player.hp, game.player.maxHp)}</div>
    </div>`,
  );
  $('#modal').querySelectorAll('[data-reward]').forEach((b) =>
    b.addEventListener('click', () => {
      sfx.chip();
      chooseReward(game, Number(b.dataset.reward));
      afterEngineStep();
    }),
  );
}

function showGameOver(data) {
  const f = FLOORS[game.floorIndex];
  openOverlay(
    'over',
    data,
    `<div class="end over">
      <h2>${t('over.title')}</h2>
      <p class="muted">${esc(t('over.sub', { level: f.level, name: t(`floor.${f.id}`) }))}</p>
      ${statsHtml(game)}
      <div class="row"><button class="primary" id="btn-retry">${t('btn.retry')}</button><button id="btn-to-title">${t('btn.title')}</button></div>
    </div>`,
  );
  $('#btn-retry').addEventListener('click', () => startRun(randomSeed()));
  $('#btn-to-title').addEventListener('click', showTitle);
}

function showVictory() {
  openOverlay(
    'win',
    null,
    `<div class="end win">
      <h2>${t('win.title')}</h2>
      <p class="muted">${esc(t('win.sub'))}</p>
      ${statsHtml(game)}
      <div class="row"><button class="primary" id="btn-retry">${t('btn.retry')}</button><button id="btn-to-title">${t('btn.title')}</button></div>
    </div>`,
  );
  $('#btn-retry').addEventListener('click', () => startRun(randomSeed()));
  $('#btn-to-title').addEventListener('click', showTitle);
}

function showReveal(ev, fireEvents, extra) {
  return new Promise((resolve) => {
    const cards = ev.cards.map((c) => cardHtml(c, { small: true, id: false })).join('');
    const title = ev.lie ? t('reveal.title.lie') : t('reveal.title.truth');
    let results = '';
    for (const f of fireEvents) {
      const key = f.effect === 'misfire' ? 'reveal.result.misfire' : `reveal.result.${f.bullet}`;
      results += `<p class="fire-result ${f.effect}">${esc(t(key, { who: whoName(game, f.who) }))}</p>`;
    }
    if (extra) results += extra;
    openOverlay(
      'reveal',
      null,
      `<div class="reveal ${ev.lie ? 'lie' : 'truth'}">
        <p class="eyebrow">${esc(t('reveal.claim', { who: whoName(game, ev.by), rank: rankName(ev.tableRank), n: ev.cards.length }))}</p>
        <div class="reveal-cards">${cards}</div>
        <h2>${title}</h2>
        <p class="shooter">${esc(t('reveal.shooter', { who: whoName(game, ev.shooter), s: ev.shooter === 'player' ? '' : 's' }))}</p>
        <div class="results" id="reveal-results" hidden>${results}</div>
        <div class="row"><button class="primary" id="btn-reveal-continue" hidden>${t('btn.continue')}</button></div>
      </div>`,
    );
    const finish = () => {
      closeOverlay();
      resolve();
    };
    (async () => {
      await sleep(900);
      $('#reveal-results') && ($('#reveal-results').hidden = false);
      for (const f of fireEvents) {
        sfx.hammer();
        await sleep(450);
        playFireSfx(f);
        flash(f);
        await sleep(300);
      }
      const btn = $('#btn-reveal-continue');
      if (btn) {
        btn.hidden = false;
        btn.focus();
        btn.addEventListener('click', finish);
      } else finish();
    })();
  });
}

function playFireSfx(f) {
  if (f.effect === 'misfire') sfx.misfire();
  else if (f.bullet === 'live') sfx.bang();
  else if (f.bullet === 'curse') sfx.curse();
  else sfx.click();
}

function flash(f) {
  const el = document.body;
  const cls = f.effect === 'live' ? 'flash-live' : f.bullet === 'curse' ? 'flash-curse' : 'flash-blank';
  el.classList.add(cls);
  setTimeout(() => el.classList.remove(cls), 500);
}

// ---------------------------------------------------------------------------
// Run lifecycle
// ---------------------------------------------------------------------------

function startRun(seed) {
  stopTimer();
  clearTimeout(dealerTimer);
  game = createRun({ seed });
  selected = new Set();
  logLines = [];
  startFloor(game);
  consumeEvents();
  renderAll();
  showFloorIntro();
}

function afterEngineStep() {
  const events = drainEvents(game);
  processEvents(events).then(() => {
    renderAll();
    scheduleNext();
  });
}

function scheduleNext() {
  clearTimeout(dealerTimer);
  if (game.phase === PHASE.FLOOR_INTRO) {
    showFloorIntro();
    return;
  }
  if (game.phase === PHASE.REWARD) {
    showReward();
    return;
  }
  if (game.phase === PHASE.GAME_OVER) {
    settings.bestFloor = Math.max(settings.bestFloor, FLOORS[game.floorIndex].level);
    saveSettings();
    sfx.lose();
    showGameOver();
    return;
  }
  if (game.phase === PHASE.VICTORY) {
    settings.bestFloor = 7;
    saveSettings();
    sfx.win();
    showVictory();
    return;
  }
  if (game.round.turn === 'dealer') {
    setHint(game.round.phase === 'respond' ? t('hint.dealerThinking') : t('hint.dealerPlaying'));
    setSpeech(t('say.think'), true);
    const delay = 700 + Math.random() * 700;
    dealerTimer = setTimeout(() => {
      const res = dealerAct(game);
      if (res.action === 'call') setSpeech(t('say.call'));
      else if (res.action === 'pass') setSpeech(t('say.pass'));
      else setSpeech('');
      afterEngineStep();
    }, delay);
  } else if (game.round.phase === 'respond' && settings.timer) {
    startTimer();
  }
}

// ---------------------------------------------------------------------------
// Player input
// ---------------------------------------------------------------------------

function toggleSelect(id) {
  if (!game || game.phase !== PHASE.ROUND) return;
  const la = legalActions(game);
  if (!la.play && !la.cheats.includes('bottomDeal')) return;
  if (selected.has(id)) selected.delete(id);
  else {
    if (selected.size >= 3) return;
    selected.add(id);
  }
  sfx.select();
  renderHand();
  renderActions();
}

function onPlay() {
  if (busy || !game) return;
  const la = legalActions(game);
  if (!la.play || selected.size === 0) return;
  const ids = [...selected];
  selected = new Set();
  busy = true;
  sfx.card();
  try {
    play(game, 'player', ids);
  } catch (err) {
    busy = false;
    console.error(err);
    return;
  }
  busy = false;
  afterEngineStep();
}

function onRespond(action) {
  if (busy || !game) return;
  const la = legalActions(game);
  if ((action === 'call' && !la.call) || (action === 'pass' && !la.pass)) return;
  stopTimer();
  selected = new Set();
  busy = true;
  sfx.chip();
  try {
    respond(game, 'player', action);
  } catch (err) {
    busy = false;
    console.error(err);
    return;
  }
  busy = false;
  afterEngineStep();
}

function onCheat(id) {
  if (busy || !game) return;
  const la = legalActions(game);
  if (!la.cheats.includes(id)) return;
  const opts = {};
  if (id === 'bottomDeal') {
    if (selected.size !== 1) {
      setHint(t('hint.selectCard'), true);
      return;
    }
    const cardId = [...selected][0];
    const card = game.round.hands.player.find((c) => c.id === cardId);
    if (!card || isTruthful(card, game.round.tableRank)) {
      setHint(t('hint.selectLie'), true);
      return;
    }
    opts.cardId = cardId;
    selected = new Set();
  }
  busy = true;
  try {
    useCheat(game, id, opts);
  } catch (err) {
    busy = false;
    console.error(err);
    return;
  }
  busy = false;
  afterEngineStep();
}

// ---------------------------------------------------------------------------
// Challenge timer
// ---------------------------------------------------------------------------

function startTimer() {
  if (timer.handle) return; // already counting down this challenge window (e.g. after a cheat)
  const el = $('#timer');
  el.hidden = false;
  timer.deadline = performance.now() + CHALLENGE_SECONDS * 1000;
  let lastWhole = CHALLENGE_SECONDS;
  const tick = () => {
    const left = Math.max(0, timer.deadline - performance.now());
    const secs = Math.ceil(left / 1000);
    $('#timer-text').textContent = secs;
    $('#timer-arc').style.setProperty('--p', left / (CHALLENGE_SECONDS * 1000));
    el.classList.toggle('urgent', secs <= 5);
    if (secs !== lastWhole) {
      lastWhole = secs;
      if (secs <= 5 && secs > 0) sfx.tickUrgent();
      else if (secs > 0) sfx.tick();
    }
    if (left <= 0) {
      stopTimer();
      const la = legalActions(game);
      if (!la.call && !la.pass) return;
      const action = la.pass ? 'pass' : 'call';
      pushLog(t('log.timeout', { action: action === 'pass' ? t('btn.pass') : t('btn.call') }));
      setHint(t('hint.timeout'));
      onRespond(action);
      return;
    }
    timer.handle = requestAnimationFrame(tick);
  };
  timer.handle = requestAnimationFrame(tick);
}
function stopTimer() {
  if (timer.handle) cancelAnimationFrame(timer.handle);
  timer.handle = null;
  const el = $('#timer');
  if (el) el.hidden = true;
}

// ---------------------------------------------------------------------------
// Events -> log / sfx / modals
// ---------------------------------------------------------------------------

function consumeEvents() {
  for (const ev of drainEvents(game)) logEvent(ev);
}

async function processEvents(events) {
  busy = true;
  for (let i = 0; i < events.length; i++) {
    const ev = events[i];
    logEvent(ev);
    if (ev.type === 'reveal') {
      // Gather the shots and side effects that belong to this reveal.
      const fires = [];
      let extra = '';
      let j = i + 1;
      while (j < events.length && ['fire', 'hp', 'reload', 'gimmick', 'relicProc', 'pactBackfire'].includes(events[j].type)) {
        const e2 = events[j];
        logEvent(e2);
        if (e2.type === 'fire') fires.push(e2);
        if (e2.type === 'reload') extra += `<p class="fire-result reload">${esc(t('reveal.reload'))}</p>`;
        if (e2.type === 'pactBackfire') extra += `<p class="fire-result live">${esc(t('reveal.pactBackfire', { who: whoName(game, e2.by) }))}</p>`;
        if (e2.type === 'gimmick') extra += `<p class="fire-result gimmick">${esc(t(`log.gimmick.${e2.gimmick}`))}</p>`;
        if (e2.type === 'relicProc') extra += `<p class="fire-result gimmick">${esc(t(`log.relicProc.${e2.relic}`))}</p>`;
        j++;
      }
      i = j - 1;
      // Keep the pre-reveal table visible behind the modal; the new round renders after it closes.
      await showReveal(ev, fires, extra);
      if (ev.by === 'player') setSpeech(ev.lie ? t('say.caughtYou') : '');
    } else if (ev.type === 'cheat') {
      if (ev.caught) {
        sfx.caught();
        setSpeech(t('say.cheatCaught'));
        renderAll();
        await sleep(600);
        // Following fire events are handled in the next iterations.
      } else {
        sfx.chip();
      }
    } else if (ev.type === 'fire') {
      // Fire outside a reveal (caught cheat): animate inline.
      renderAll();
      sfx.hammer();
      await sleep(400);
      playFireSfx(ev);
      flash(ev);
      await sleep(500);
    } else if (ev.type === 'reload') {
      sfx.reload();
      renderAll();
      await sleep(500);
    } else if (ev.type === 'play') {
      if (ev.by === 'dealer') sfx.card();
    } else if (ev.type === 'pactStrike') {
      sfx.hurt();
      renderAll();
      await sleep(500);
    } else if (ev.type === 'hp' && ev.to > ev.from) {
      sfx.heal();
    } else if (ev.type === 'roundStart') {
      renderAll();
      sfx.card();
      await sleep(250);
    }
  }
  busy = false;
}

function logEvent(ev) {
  const W = (who) => whoName(game, who);
  const R = (r) => rankName(r);
  switch (ev.type) {
    case 'floorStart':
      return pushLog(t('log.floorStart', { level: ev.level, name: t(`floor.${ev.floor}`), dealer: t(`dealer.${ev.dealer}.name`) }), 'sys');
    case 'roundStart':
      return pushLog(t('log.roundStart', { n: ev.number, rank: R(ev.tableRank), who: W(ev.starter) }), 'sys');
    case 'play':
      return pushLog(t('log.play', { who: W(ev.by), rank: R(ev.tableRank), n: ev.count, left: ev.handLeft }), ev.by);
    case 'pass':
      return pushLog(t('log.pass', { who: W(ev.by) }), ev.by);
    case 'reveal': {
      const cards = ev.cards.map((c) => R(c.rank)).join(', ');
      pushLog(t('log.call', { who: W(ev.challenger) }), ev.challenger);
      return pushLog(t(ev.lie ? 'log.reveal.lie' : 'log.reveal.truth', { cards, who: W(ev.shooter), s: ev.shooter === 'player' ? '' : 's' }), 'sys');
    }
    case 'fire': {
      const key = ev.effect === 'misfire' ? 'log.fire.misfire' : `log.fire.${ev.bullet}`;
      return pushLog(t(key, { who: W(ev.who), n: ev.chamber, hp: ev.hp }), ev.bullet === 'live' && ev.effect !== 'misfire' ? 'danger' : 'sys');
    }
    case 'reload':
      return pushLog(t('log.reload', ev.composition), 'sys');
    case 'cheat': {
      const item = t(`item.${ev.cheat}.name`);
      const p = Math.round(ev.detectChance * 100);
      if (ev.caught) return pushLog(t('log.cheat.caught', { item, p }), 'danger');
      pushLog(t('log.cheat.ok', { item, p }), 'player');
      if (ev.cheat === 'mirror') return pushLog(t('log.cheat.mirror', { bullet: t(`bullet.${ev.bullet}`) }), 'player');
      if (ev.cheat === 'leadWeight') return pushLog(t(ev.swapped ? 'log.cheat.lead' : 'log.cheat.leadNoop'), 'player');
      if (ev.cheat === 'bottomDeal') return pushLog(ev.swapped ? t('log.cheat.bottom', { rank: R(ev.newCard.rank) }) : t('log.cheat.bottomFail'), 'player');
      if (ev.cheat === 'pact') return pushLog(t('log.cheat.pact'), 'player');
      return;
    }
    case 'pactStrike':
      return pushLog(t('log.pactStrike'), 'danger');
    case 'pactFizzle':
      return pushLog(t('log.pactFizzle'), 'sys');
    case 'pactBackfire':
      return pushLog(t('log.pactBackfire'), 'danger');
    case 'gimmick':
      return pushLog(t(`log.gimmick.${ev.gimmick}`), 'dealer');
    case 'relicProc':
      return pushLog(t(`log.relicProc.${ev.relic}`), 'player');
    case 'hp':
      return pushLog(t('log.hp', { who: W(ev.who), from: ev.from, to: ev.to }), ev.to < ev.from ? 'danger' : 'sys');
    case 'dealerDefeated':
      return pushLog(t('log.dealerDefeated', { dealer: t(`dealer.${ev.dealer}.name`) }), 'sys');
    case 'rewardTaken': {
      const r = ev.reward;
      const name = r.kind === 'heal' ? t('reward.heal.name') : r.kind === 'item' ? t(`item.${r.id}.name`) : t(`relic.${r.id}.name`);
      return pushLog(t('log.rewardTaken', { name }), 'sys');
    }
    case 'gameOver':
      return pushLog(t('log.gameOver'), 'danger');
    case 'victory':
      return pushLog(t('log.victory'), 'sys');
    default:
      return;
  }
}

function pushLog(text, cls = 'sys') {
  logLines.push({ text, cls });
  if (logLines.length > 80) logLines.shift();
  renderLog();
}

// ---------------------------------------------------------------------------
// Rendering
// ---------------------------------------------------------------------------

function renderAll() {
  if (!game || !game.dealer) return;
  $('#hud-floor').textContent = floorLabel(game);
  $('#hud-round').textContent = game.round ? t('hud.round', { n: game.round.number }) : '';
  $('#hud-seed').textContent = `${t('seed.label')} ${game.seed}`;
  renderDealer();
  renderCenter();
  renderSide();
  renderPlayer();
  renderHand();
  renderActions();
  renderLog();
}

function renderDealer() {
  const d = game.dealer;
  $('#dealer-portrait').innerHTML = portraitSvg(d.id);
  $('#dealer-name').textContent = t(`dealer.${d.id}.name`);
  $('#dealer-title').textContent = t(`dealer.${d.id}.title`);
  $('#dealer-hearts').innerHTML = heartsHtml(d.hp, d.maxHp);
  $('#dealer-focus').textContent = t('hud.focus', { focus: d.focus });
  const r = game.round;
  const hand = r ? r.hands.dealer : [];
  const revealed = r && r.revealed.dealer;
  $('#lbl-dealer-hand').textContent = t('hud.dealerHand', { n: hand.length });
  $('#dealer-hand').innerHTML = hand
    .map((c) => cardHtml(c, { faceDown: !revealed, small: true, id: false }))
    .join('');
  const notes = [];
  if (r && r.revealed.dealer) notes.push(t('hud.revealedDealer'));
  if (r && r.peekedDealerCard && !r.revealed.dealer && hand.some((c) => c.id === r.peekedDealerCard.id)) notes.push(t('hud.peeked', { rank: rankName(r.peekedDealerCard.rank) }));
  $('#dealer-notes').innerHTML = notes.map((n) => `<span class="note">${esc(n)}</span>`).join('');
}

function renderCenter() {
  const r = game.round;
  $('#table-rank-card').innerHTML = r ? cardHtml({ id: -1, rank: r.tableRank }, { id: false }) : '';
  $('#table-rank-name').textContent = r ? rankName(r.tableRank) : '';
  $('#pile').innerHTML = pileHtml(game);
}

function renderSide() {
  $('#cylinder').innerHTML = cylinderSvg(game);
  $('#odds').innerHTML = oddsHtml(game);
}

function renderPlayer() {
  $('#player-hearts').innerHTML = heartsHtml(game.player.hp, game.player.maxHp);
  $('#relics').innerHTML = relicsHtml(game);
  $('#items').innerHTML = itemsHtml(game);
  const r = game.round;
  const notes = [];
  if (r && r.revealed.player) notes.push(t('hud.revealedYou'));
  if (r && r.pact && r.pact.by === 'player') notes.push(t('hud.pactArmed'));
  $('#player-notes').innerHTML = notes.map((n) => `<span class="note warn">${esc(n)}</span>`).join('');
}

function renderHand() {
  const r = game.round;
  const hand = r ? r.hands.player : [];
  $('#player-hand').innerHTML = hand.map((c) => cardHtml(c, { selected: selected.has(c.id) })).join('');
  $('#lbl-selected').textContent = hand.length ? t('hud.selected', { n: selected.size }) : '';
}

function renderActions() {
  const la = legalActions(game);
  const r = game.round;
  $('#btn-play').disabled = !la.play || selected.size === 0;
  $('#btn-call').disabled = !la.call;
  $('#btn-pass').disabled = !la.pass;
  const respondSide =
    !!r && game.phase === PHASE.ROUND && showsRespondButtons(r.turn, r.phase);
  $('#btn-play').hidden = respondSide;
  $('#btn-call').hidden = !respondSide;
  $('#btn-pass').hidden = !respondSide;
  if (!r || game.phase !== PHASE.ROUND) return setHint('');
  if (r.turn !== 'player') return;
  if (la.play) setHint(t('hint.yourPlay', { rank: rankName(r.tableRank) }));
  else if (la.call && !la.pass) setHint(t('hint.mustCall'));
  else setHint(t('hint.yourRespond', { rank: rankName(r.tableRank), n: r.lastPlay.claim }));
}

function renderLog() {
  const el = $('#log');
  el.innerHTML = logLines.map((l) => `<div class="log-line ${l.cls}">${esc(l.text)}</div>`).join('');
  el.scrollTop = el.scrollHeight;
}

function setHint(text, transient = false) {
  const el = $('#hint');
  el.textContent = text;
  el.classList.toggle('transient', transient);
  if (transient) {
    clearTimeout(setHint._t);
    setHint._t = setTimeout(() => renderActions(), 1800);
  }
}

function setSpeech(text, thinking = false) {
  const el = $('#dealer-speech');
  el.textContent = text;
  el.classList.toggle('thinking', thinking);
  el.hidden = !text;
}

boot();
