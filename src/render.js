// DOM builders (pure: state -> HTML strings / elements). No game logic here.

import { t } from './i18n.js';
import { CHEATS, FLOORS } from './data.js';
import { nextChamberOdds, cheatDetectChance, legalActions } from './rules.js';

const RANK_GLYPH = { K: '♚', Q: '♛', A: 'A', J: '★' };

/**
 * Which pair of action buttons belongs on screen. Showing the set the player
 * will actually use next keeps the dealer's turn from stacking all three, and
 * avoids the buttons jumping around between turns.
 * Player + respond phase -> call/pass (their choice now)
 * Dealer + play phase    -> call/pass (their choice in a moment)
 * Everything else        -> play
 */
export function showsRespondButtons(turn, roundPhase) {
  return (roundPhase === 'respond') === (turn === 'player');
}

export function esc(s) {
  return String(s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);
}

export function whoName(state, who) {
  return who === 'player' ? t('who.you') : t(`dealer.${state.dealer.id}.name`);
}

export function rankName(rank) {
  return t(`rank.${rank}`);
}

export function cardHtml(card, { selected = false, faceDown = false, small = false, id = true } = {}) {
  const cls = ['card', faceDown ? 'back' : `rank-${card ? card.rank : 'x'}`, selected ? 'selected' : '', small ? 'small' : ''].join(' ');
  if (faceDown) return `<div class="${cls}"><div class="card-inner"></div></div>`;
  const glyph = RANK_GLYPH[card.rank] ?? card.rank;
  const label = card.rank === 'J' ? 'JOKER' : card.rank;
  return `<div class="${cls}" ${id ? `data-card="${card.id}"` : ''} role="button" tabindex="0" aria-label="${esc(rankName(card.rank))}">
    <div class="card-inner">
      <span class="corner tl">${label}</span>
      <span class="glyph">${glyph}</span>
      <span class="corner br">${label}</span>
    </div>
  </div>`;
}

export function heartsHtml(hp, maxHp) {
  let s = '';
  for (let i = 0; i < maxHp; i++) s += `<span class="heart ${i < hp ? 'full' : 'empty'}" aria-hidden="true"></span>`;
  return `<span class="hearts-row" aria-label="HP ${hp}/${maxHp}">${s}</span><span class="hp-num">${hp}/${maxHp}</span>`;
}

export function portraitSvg(dealerId) {
  const themes = {
    jack: { skin: '#c9a27c', coat: '#4a3b2a', hat: 'cap', eye: '#f2c14e', extra: 'bottle' },
    martha: { skin: '#d9b08c', coat: '#5b1f2a', hat: 'wide', eye: '#e86f51', extra: 'none' },
    dominic: { skin: '#b98b6a', coat: '#1f2a3a', hat: 'bowler', eye: '#7ec8e3', extra: 'glasses' },
    ida: { skin: '#e0c3a6', coat: '#2b2b2b', hat: 'none', eye: '#ffd166', extra: 'monocle' },
    bela: { skin: '#e8cbb8', coat: '#f0e6dc', hat: 'nurse', eye: '#c1121f', extra: 'none' },
    grimm: { skin: '#cbb3a0', coat: '#0f0f12', hat: 'wig', eye: '#e5e5e5', extra: 'none' },
    devil: { skin: '#7a1e1e', coat: '#120608', hat: 'horns', eye: '#ffb703', extra: 'smile' },
  };
  const th = themes[dealerId] ?? themes.jack;
  const hat = {
    cap: `<path d="M22 38 q28 -18 56 0 l0 6 l-56 0z" fill="#2e2a24"/>`,
    wide: `<ellipse cx="50" cy="40" rx="40" ry="8" fill="#2a1216"/><path d="M28 40 q22 -26 44 0z" fill="#3b1a20"/>`,
    bowler: `<ellipse cx="50" cy="42" rx="34" ry="6" fill="#111"/><path d="M28 42 q22 -30 44 0z" fill="#181818"/>`,
    none: ``,
    nurse: `<rect x="34" y="26" width="32" height="12" rx="2" fill="#fff"/><rect x="47" y="28" width="6" height="8" fill="#c1121f"/><rect x="44" y="31" width="12" height="2" fill="#c1121f"/>`,
    wig: `<path d="M22 44 q4 -30 28 -28 q24 -2 28 28 l-6 6 q-22 -14 -44 0z" fill="#dcdcdc"/>`,
    horns: `<path d="M30 40 q-10 -22 4 -30 q-2 16 6 26z" fill="#3a0a0a"/><path d="M70 40 q10 -22 -4 -30 q2 16 -6 26z" fill="#3a0a0a"/>`,
  }[th.hat];
  const extra = {
    bottle: `<rect x="78" y="70" width="8" height="22" rx="2" fill="#4c7a3a" opacity=".9"/>`,
    glasses: `<circle cx="40" cy="58" r="7" fill="none" stroke="#ccc" stroke-width="2"/><circle cx="60" cy="58" r="7" fill="none" stroke="#ccc" stroke-width="2"/><line x1="47" y1="58" x2="53" y2="58" stroke="#ccc" stroke-width="2"/>`,
    monocle: `<circle cx="61" cy="58" r="8" fill="none" stroke="#e5c07b" stroke-width="2"/><line x1="66" y1="64" x2="72" y2="80" stroke="#e5c07b" stroke-width="1.5"/>`,
    smile: `<path d="M38 74 q12 12 24 0" fill="none" stroke="#ffb703" stroke-width="2.5"/>`,
    none: ``,
  }[th.extra];
  return `<svg viewBox="0 0 100 110" class="portrait-svg" aria-hidden="true">
    <defs><radialGradient id="glow-${dealerId}" cx="50%" cy="40%" r="60%"><stop offset="0" stop-color="${th.eye}" stop-opacity=".25"/><stop offset="1" stop-color="#000" stop-opacity="0"/></radialGradient></defs>
    <rect width="100" height="110" fill="url(#glow-${dealerId})"/>
    <path d="M14 110 q6 -30 36 -32 q30 2 36 32z" fill="${th.coat}"/>
    <rect x="42" y="70" width="16" height="12" fill="${th.skin}"/>
    <ellipse cx="50" cy="56" rx="22" ry="26" fill="${th.skin}"/>
    <ellipse cx="41" cy="58" rx="3.5" ry="2.2" fill="${th.eye}"><animate attributeName="ry" values="2.2;2.2;0.3;2.2" dur="5s" repeatCount="indefinite"/></ellipse>
    <ellipse cx="59" cy="58" rx="3.5" ry="2.2" fill="${th.eye}"><animate attributeName="ry" values="2.2;2.2;0.3;2.2" dur="5s" repeatCount="indefinite"/></ellipse>
    ${hat}${extra}
  </svg>`;
}

export function cylinderSvg(state) {
  const cyl = state.cylinder;
  const n = cyl.chambers.length;
  const r = 34;
  const cx = 60;
  const cy = 60;
  let chambers = '';
  for (let i = 0; i < n; i++) {
    const ang = (i / n) * Math.PI * 2 - Math.PI / 2;
    const x = cx + Math.cos(ang) * r;
    const y = cy + Math.sin(ang) * r;
    const spent = i < cyl.index;
    const isNext = i === cyl.index;
    let fill = '#1b1614';
    let mark = '';
    if (spent) {
      const b = cyl.spent[i];
      fill = b === 'live' ? '#7a1f1f' : b === 'curse' ? '#4a2a6a' : '#3a3632';
      mark = b === 'live' ? `<text x="${x}" y="${y + 4}" text-anchor="middle" font-size="11" fill="#f5d5d5">●</text>` : b === 'curse' ? `<text x="${x}" y="${y + 4}" text-anchor="middle" font-size="11" fill="#e0c8ff">✦</text>` : `<text x="${x}" y="${y + 4}" text-anchor="middle" font-size="11" fill="#bbb">○</text>`;
    } else if (isNext && cyl.knownNext) {
      const b = cyl.knownNext;
      fill = b === 'live' ? '#a12626' : b === 'curse' ? '#6a3a9a' : '#5a5650';
      mark = `<text x="${x}" y="${y + 4}" text-anchor="middle" font-size="11" fill="#fff">${b === 'live' ? '●' : b === 'curse' ? '✦' : '○'}</text>`;
    }
    chambers += `<g class="chamber ${isNext ? 'next' : ''} ${spent ? 'spent' : ''}"><circle cx="${x}" cy="${y}" r="11" fill="${fill}" stroke="${isNext ? '#e5c07b' : '#5a4a3a'}" stroke-width="${isNext ? 2.5 : 1.5}"/>${mark}</g>`;
  }
  const rot = -(cyl.index / n) * 360;
  return `<svg viewBox="0 0 120 120" class="cylinder-svg" aria-hidden="true">
    <circle cx="60" cy="60" r="54" fill="#231d1a" stroke="#6b5a48" stroke-width="3"/>
    <circle cx="60" cy="60" r="8" fill="#0f0c0b" stroke="#6b5a48" stroke-width="2"/>
    <g class="cyl-rot" style="transform: rotate(${rot}deg); transform-origin: 60px 60px;">${chambers}</g>
    <path d="M60 2 l-6 10 h12z" fill="#e5c07b"/>
  </svg>`;
}

export function oddsHtml(state) {
  const o = nextChamberOdds(state);
  const p = Math.round(o.pLive * 100);
  const known = state.cylinder.knownNext;
  return `<div class="odds-main ${p >= 50 ? 'danger' : ''}">${t('hud.odds', { p })}</div>
    <div class="odds-sub">${t('hud.remaining', { n: o.remaining, live: o.live, blank: o.blank, curse: o.curse })}</div>
    ${known ? `<div class="odds-known">${t('hud.known', { bullet: t('bullet.' + known) })}</div>` : ''}`;
}

export function pileHtml(state) {
  const r = state.round;
  if (!r || r.pile.length === 0) return `<div class="pile-empty">${t('hud.pileEmpty')}</div>`;
  return r.pile
    .map((p, i) => {
      const last = i === r.pile.length - 1;
      let stack = '';
      for (let k = 0; k < p.cards.length; k++) stack += `<div class="mini back" style="--k:${k}"></div>`;
      return `<div class="pile-entry ${last ? 'last' : ''} by-${p.by}"><div class="stack">${stack}</div><div class="pile-label">${esc(t('hud.pileEntry', { who: whoName(state, p.by), rank: rankName(r.tableRank), n: p.claim }))}</div></div>`;
    })
    .join('');
}

export function itemsHtml(state) {
  const la = legalActions(state);
  return Object.keys(CHEATS)
    .map((id) => {
      const n = state.player.items[id];
      const p = state.dealer ? Math.round(cheatDetectChance(state, id) * 100) : Math.round(CHEATS[id].baseDetect * 100);
      const usable = la.cheats.includes(id);
      const detect = p === 0 ? t('item.detectNone') : t('item.detect', { p });
      return `<button class="item ${usable ? 'usable' : ''} ${n === 0 ? 'empty' : ''}" data-item="${id}" ${usable ? '' : 'disabled'} title="${esc(t(`item.${id}.desc`))}">
        <span class="item-icon icon-${id}"></span>
        <span class="item-name">${esc(t(`item.${id}.name`))}</span>
        <span class="item-meta">${t('item.charges', { n })} · ${detect}</span>
      </button>`;
    })
    .join('');
}

export function relicsHtml(state) {
  if (!state.player.relics.length) return `<span class="muted">${t('hud.noRelics')}</span>`;
  return state.player.relics
    .map((id) => `<span class="relic" title="${esc(t(`relic.${id}.desc`))}"><span class="relic-icon icon-${id}"></span>${esc(t(`relic.${id}.name`))}</span>`)
    .join('');
}

export function floorLabel(state) {
  const f = FLOORS[state.floorIndex];
  return t('hud.floor', { level: f.level, name: t(`floor.${f.id}`) });
}

export function statsHtml(state) {
  const s = state.stats;
  return `<ul class="stats">
    <li>${t('stat.rounds')}: ${state.roundNumber}</li>
    <li>${t('stat.bluffs', { b: s.playerBluffs, p: s.playerPlays })}</li>
    <li>${t('stat.calls', { r: s.playerCallsRight, w: s.playerCallsWrong })}</li>
    <li>${t('stat.cheats', { u: s.cheatsUsed, c: s.cheatsCaught })}</li>
    <li>${t('stat.shots', { s: s.shotsTaken, l: s.liveTaken })}</li>
    <li class="seed">${t('stat.seed', { seed: esc(state.seed) })}</li>
  </ul>`;
}
