// Procedural sound effects with the Web Audio API. No audio files.

let ctx = null;
let master = null;
let enabled = true;
let noiseBuffer = null;

function ensure() {
  if (!enabled) return null;
  if (!ctx) {
    const AC = window.AudioContext || window.webkitAudioContext;
    if (!AC) return null;
    ctx = new AC();
    master = ctx.createGain();
    master.gain.value = 0.5;
    master.connect(ctx.destination);
    noiseBuffer = ctx.createBuffer(1, ctx.sampleRate * 1.5, ctx.sampleRate);
    const d = noiseBuffer.getChannelData(0);
    for (let i = 0; i < d.length; i++) d[i] = Math.random() * 2 - 1;
  }
  if (ctx.state === 'suspended') ctx.resume();
  return ctx;
}

export function setEnabled(v) {
  enabled = v;
  if (!v && ctx && ctx.state === 'running') ctx.suspend();
  if (v && ctx && ctx.state === 'suspended') ctx.resume();
}
export function isEnabled() {
  return enabled;
}

function tone({ freq = 440, type = 'sine', dur = 0.2, gain = 0.3, attack = 0.005, slideTo = null, when = 0 }) {
  const c = ensure();
  if (!c) return;
  const t0 = c.currentTime + when;
  const o = c.createOscillator();
  const g = c.createGain();
  o.type = type;
  o.frequency.setValueAtTime(freq, t0);
  if (slideTo) o.frequency.exponentialRampToValueAtTime(slideTo, t0 + dur);
  g.gain.setValueAtTime(0.0001, t0);
  g.gain.linearRampToValueAtTime(gain, t0 + attack);
  g.gain.exponentialRampToValueAtTime(0.0001, t0 + dur);
  o.connect(g).connect(master);
  o.start(t0);
  o.stop(t0 + dur + 0.05);
}

function noise({ dur = 0.2, gain = 0.3, filter = 2000, q = 0.7, type = 'lowpass', when = 0, decay = true }) {
  const c = ensure();
  if (!c) return;
  const t0 = c.currentTime + when;
  const src = c.createBufferSource();
  src.buffer = noiseBuffer;
  const f = c.createBiquadFilter();
  f.type = type;
  f.frequency.value = filter;
  f.Q.value = q;
  const g = c.createGain();
  g.gain.setValueAtTime(gain, t0);
  if (decay) g.gain.exponentialRampToValueAtTime(0.0001, t0 + dur);
  src.connect(f).connect(g).connect(master);
  src.start(t0, Math.random() * 0.5);
  src.stop(t0 + dur + 0.05);
}

export const sfx = {
  unlock() {
    ensure();
  },
  select() {
    tone({ freq: 880, type: 'triangle', dur: 0.05, gain: 0.08 });
  },
  card() {
    noise({ dur: 0.12, gain: 0.25, filter: 3500, type: 'bandpass', q: 0.8 });
  },
  chip() {
    tone({ freq: 1600, type: 'square', dur: 0.03, gain: 0.05 });
    tone({ freq: 2100, type: 'square', dur: 0.04, gain: 0.05, when: 0.03 });
  },
  hammer() {
    noise({ dur: 0.05, gain: 0.35, filter: 5000, type: 'highpass' });
    tone({ freq: 1200, type: 'square', dur: 0.03, gain: 0.12 });
  },
  spin() {
    for (let i = 0; i < 10; i++) {
      tone({ freq: 2400 - i * 90, type: 'square', dur: 0.02, gain: 0.05, when: i * 0.045 });
    }
  },
  click() {
    noise({ dur: 0.06, gain: 0.5, filter: 4000, type: 'highpass' });
    tone({ freq: 900, type: 'square', dur: 0.04, gain: 0.2 });
    tone({ freq: 300, type: 'triangle', dur: 0.08, gain: 0.15, when: 0.01 });
  },
  bang() {
    noise({ dur: 0.5, gain: 1.0, filter: 900, q: 0.5 });
    noise({ dur: 0.25, gain: 0.7, filter: 6000, type: 'highpass' });
    tone({ freq: 140, type: 'sine', dur: 0.5, gain: 0.9, slideTo: 40 });
    tone({ freq: 60, type: 'sine', dur: 0.8, gain: 0.5, slideTo: 25, when: 0.02 });
  },
  curse() {
    tone({ freq: 220, type: 'sawtooth', dur: 0.9, gain: 0.15, slideTo: 110 });
    tone({ freq: 233, type: 'sawtooth', dur: 0.9, gain: 0.15, slideTo: 116 });
    noise({ dur: 0.9, gain: 0.15, filter: 600 });
  },
  misfire() {
    noise({ dur: 0.08, gain: 0.4, filter: 3000, type: 'highpass' });
    tone({ freq: 500, type: 'square', dur: 0.05, gain: 0.15 });
    tone({ freq: 700, type: 'sine', dur: 0.25, gain: 0.1, when: 0.1 });
  },
  hurt() {
    tone({ freq: 200, type: 'sawtooth', dur: 0.3, gain: 0.2, slideTo: 80 });
  },
  heal() {
    tone({ freq: 523, type: 'sine', dur: 0.15, gain: 0.15 });
    tone({ freq: 784, type: 'sine', dur: 0.25, gain: 0.15, when: 0.12 });
  },
  reload() {
    for (let i = 0; i < 6; i++) tone({ freq: 700 + i * 40, type: 'square', dur: 0.03, gain: 0.08, when: i * 0.07 });
    noise({ dur: 0.15, gain: 0.3, filter: 2500, type: 'bandpass', when: 0.45 });
  },
  caught() {
    tone({ freq: 660, type: 'square', dur: 0.08, gain: 0.15 });
    tone({ freq: 440, type: 'square', dur: 0.12, gain: 0.15, when: 0.09 });
    tone({ freq: 220, type: 'square', dur: 0.25, gain: 0.15, when: 0.2 });
  },
  win() {
    [523, 659, 784, 1046].forEach((f, i) => tone({ freq: f, type: 'triangle', dur: 0.35, gain: 0.18, when: i * 0.13 }));
  },
  lose() {
    [392, 349, 311, 233].forEach((f, i) => tone({ freq: f, type: 'sawtooth', dur: 0.5, gain: 0.12, when: i * 0.3 }));
    noise({ dur: 1.5, gain: 0.1, filter: 400, when: 0.2 });
  },
  tick() {
    tone({ freq: 1400, type: 'square', dur: 0.02, gain: 0.05 });
  },
  tickUrgent() {
    tone({ freq: 1800, type: 'square', dur: 0.03, gain: 0.09 });
  },
};
