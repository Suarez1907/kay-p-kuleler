// Basit WebAudio sentezleyici — dosya gerektirmez.
let ctx = null, master = null, enabled = true;
export function initAudio() {
  if (ctx) { if (ctx.state === 'suspended') ctx.resume(); return; }
  try {
    ctx = new (window.AudioContext || window.webkitAudioContext)();
    master = ctx.createGain(); master.gain.value = 0.25; master.connect(ctx.destination);
  } catch (e) { ctx = null; }
}
export function setSound(on) { enabled = on; }
export function soundOn() { return enabled; }
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
  push() { noise(0.18, 0.5, 400); tone(140, 0.15, 'sine', 0.4, -40); },
  kick() { tone(300, 0.12, 'square', 0.15, 300); noise(0.08, 0.3, 1500); },
  roll() { noise(0.12, 0.15, 300); },
  click() { tone(880, 0.06, 'square', 0.12); tone(1320, 0.06, 'square', 0.08, 0, 0.05); },
  mech() { tone(220, 0.25, 'sawtooth', 0.08, 110); noise(0.2, 0.15, 800); },
  bridge() { [523, 659, 784].forEach((f, i) => tone(f, 0.25, 'sine', 0.25, 0, i * 0.06)); },
  thud() { tone(90, 0.2, 'sine', 0.5, -40); noise(0.1, 0.3, 300); },
  crumble() { noise(0.4, 0.5, 900); },
  fail() { tone(400, 0.6, 'triangle', 0.3, -330); },
  nope() { tone(180, 0.12, 'square', 0.12); },
  win() { [523, 659, 784, 1046].forEach((f, i) => tone(f, 0.6, 'triangle', 0.25, 0, i * 0.1)); tone(1568, 0.9, 'sine', 0.15, 0, 0.45); },
};
