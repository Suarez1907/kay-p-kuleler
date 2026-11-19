// WebAudio sentezleyici + prosedürel pastel ambiyans müziği + Android titreşim köprüsü.
let ctx = null, master = null, musicGain = null, enabled = true, musicEnabled = true, musicTimer = null;
const SCALE = [261.63, 293.66, 329.63, 392.0, 440.0, 493.88, 523.25, 587.33, 659.25];
let noteIdx = 0;

export function initAudio() {
  if (ctx) { if (ctx.state === 'suspended') ctx.resume(); startAmbient(); return; }
  try {
    ctx = new (window.AudioContext || window.webkitAudioContext)();
    master = ctx.createGain(); master.gain.value = 0.25; master.connect(ctx.destination);
    musicGain = ctx.createGain(); musicGain.gain.value = (enabled && musicEnabled) ? 0.26 : 0; musicGain.connect(master);
    startAmbient();
  } catch (e) { ctx = null; }
}
function syncMusicGain() {
  if (!ctx || !musicGain) return;
  const target = (enabled && musicEnabled) ? 0.26 : 0;
  musicGain.gain.setTargetAtTime(target, ctx.currentTime, 0.25);
}
export function setSound(on) { enabled = on; syncMusicGain(); }
export function soundOn() { return enabled; }
export function setMusic(on) { musicEnabled = on; syncMusicGain(); }
export function musicOn() { return musicEnabled; }

function playPad(freq, dur, vol = 0.14, delay = 0) {
  if (!ctx || !musicGain || !enabled || !musicEnabled || document.hidden) return;
  const t = ctx.currentTime + delay;
  const o = ctx.createOscillator(), g = ctx.createGain();
  o.type = 'sine'; o.frequency.setValueAtTime(freq, t);
  g.gain.setValueAtTime(0.0001, t);
  g.gain.linearRampToValueAtTime(vol, t + dur * 0.35);
  g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
  o.connect(g); g.connect(musicGain); o.start(t); o.stop(t + dur + 0.08);
}
function startAmbient() {
  if (musicTimer || !ctx) return;
  const tick = () => {
    if (!ctx || !enabled || !musicEnabled || document.hidden || ctx.state !== 'running') return;
    const base = SCALE[noteIdx % SCALE.length];
    const fifth = SCALE[(noteIdx + 2) % SCALE.length];
    noteIdx = (noteIdx + 1 + ((noteIdx % 3 === 0) ? 2 : 0)) % SCALE.length;
    playPad(base * 0.5, 4.4, 0.13, 0);
    playPad(base, 3.6, 0.1, 0.35);
    playPad(fifth, 3.2, 0.07, 1.1);
  };
  musicTimer = setInterval(tick, 3400);
}

export function haptic(kind = 'tap') {
  try {
    if (window.AndroidBridge && typeof window.AndroidBridge.haptic === 'function') {
      window.AndroidBridge.haptic(kind);
    }
  } catch (e) {}
}

function tone(freq, dur, type = 'sine', vol = 0.5, slide = 0, delay = 0) {
  if (!ctx || !enabled) return;
  const t = ctx.currentTime + delay;
  const o = ctx.createOscillator(), g = ctx.createGain();
  o.type = type; o.frequency.setValueAtTime(freq, t);
  if (slide) o.frequency.exponentialRampToValueAtTime(Math.max(30, freq + slide), t + dur);
  g.gain.setValueAtTime(0, t); g.gain.linearRampToValueAtTime(vol, t + 0.01);
  g.gain.exponentialRampToValueAtTime(0.001, t + dur);
  o.connect(g); g.connect(master); o.start(t); o.stop(t + dur + 0.05);
}
function noise(dur, vol = 0.4, freq = 600) {
  if (!ctx || !enabled) return;
  const t = ctx.currentTime;
  const buf = ctx.createBuffer(1, Math.floor(ctx.sampleRate * dur), ctx.sampleRate);
  const d = buf.getChannelData(0);
  for (let i = 0; i < d.length; i++) d[i] = (Math.random() * 2 - 1) * (1 - i / d.length);
  const src = ctx.createBufferSource(); src.buffer = buf;
  const f = ctx.createBiquadFilter(); f.type = 'lowpass'; f.frequency.value = freq;
  const g = ctx.createGain(); g.gain.value = vol;
  src.connect(f); f.connect(g); g.connect(master); src.start(t);
}
export const sfx = {
  step() { tone(520 + Math.random() * 60, 0.07, 'triangle', 0.25, -120); },
  push() { noise(0.18, 0.5, 400); tone(140, 0.15, 'sine', 0.4, -40); haptic('heavy'); },
  kick() { tone(300, 0.12, 'square', 0.15, 300); noise(0.08, 0.3, 1500); haptic('tap'); },
  roll() { noise(0.12, 0.15, 300); },
  click() { tone(880, 0.06, 'square', 0.12); tone(1320, 0.06, 'square', 0.08, 0, 0.05); haptic('tap'); },
  mech() { tone(220, 0.25, 'sawtooth', 0.08, 110); noise(0.2, 0.15, 800); haptic('tap'); },
  bridge() { [523, 659, 784].forEach((f, i) => tone(f, 0.25, 'sine', 0.25, 0, i * 0.06)); },
  portal() {
    tone(440, 0.28, 'sine', 0.22, 440, 0);
    tone(660, 0.3, 'triangle', 0.18, 660, 0.06);
    tone(1320, 0.25, 'sine', 0.12, 0, 0.12);
    haptic('confirm');
  },
  thud() { tone(90, 0.2, 'sine', 0.5, -40); noise(0.1, 0.3, 300); },
  crumble() { noise(0.4, 0.5, 900); haptic('heavy'); },
  fail() { tone(400, 0.6, 'triangle', 0.3, -330); haptic('reject'); },
  turn() { tone(660, 0.05, 'triangle', 0.14, 120); },
  jump() { tone(330, 0.18, 'triangle', 0.25, 500); },
  tick() { tone(1200, 0.04, 'sine', 0.12); haptic('tick'); },
  del() { tone(500, 0.07, 'triangle', 0.12, -200); haptic('tick'); },
  run() { [392, 523].forEach((f, i) => tone(f, 0.12, 'triangle', 0.18, 0, i * 0.07)); haptic('tap'); },
  pause() { [523, 392].forEach((f, i) => tone(f, 0.12, 'triangle', 0.18, 0, i * 0.07)); haptic('tap'); },
  bump() { tone(150, 0.12, 'square', 0.1, -40); haptic('reject'); },
  nope() { tone(180, 0.12, 'square', 0.12); haptic('reject'); },
  win() {
    [523, 659, 784, 1046].forEach((f, i) => tone(f, 0.6, 'triangle', 0.25, 0, i * 0.1));
    tone(1568, 0.9, 'sine', 0.15, 0, 0.45);
    haptic('confirm');
  },
};
