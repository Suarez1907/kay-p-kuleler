// Kayıp Kuleler — Three.js istemcisi (programlama bulmacası)
import * as THREE from 'three';
import { RoundedBoxGeometry } from '../vendor/RoundedBoxGeometry.js';
import * as E from './engine.js';
import * as P from './program.js';
import { LEVELS } from './levels.js';
import { initAudio, sfx, setSound, soundOn } from './audio.js';
import { FX } from './fx.js';

const $ = (id) => document.getElementById(id);
const DIRS = E.DIRS;
const SAVE_KEY = 'kayipKuleler.v2';
const ROWS = ['main', 'p1', 'p2'];
const ROW_LABEL = { main: 'Ana', p1: 'F1', p2: 'F2' };
const SPEEDS = [1, 2, 4];

// ---------- Paletler (pastel diorama) ----------
const PALETTES = [
  { bg: ['#fde2d0', '#c8b6e8'], blocks: ['#f7e4c8', '#f2cdb4', '#e8b3a3', '#d99ba0'], accent: '#ff7f66', mech: '#7cc6c4', slide: '#8fb3e8', bridge: '#a7d8a8', door: '#e98aa4' },
  { bg: ['#d6f0ee', '#b5c8ef'], blocks: ['#eef3e2', '#cfe6d3', '#a9d3c8', '#8cbcc0'], accent: '#ff9f5a', mech: '#f2a7c3', slide: '#f7c96b', bridge: '#ffd27f', door: '#d77fa1' },
  { bg: ['#fff1c9', '#f6b6a5'], blocks: ['#fff3dc', '#f8d9b7', '#efbc97', '#df9e86'], accent: '#5aa9e6', mech: '#8bd0b4', slide: '#b49de8', bridge: '#9fd3f0', door: '#e57a7a' },
  { bg: ['#e4f5d4', '#9fd4c9'], blocks: ['#f5f0dc', '#e2e8c4', '#c6d9a8', '#a5c69a'], accent: '#ff6f91', mech: '#f6b26b', slide: '#7eb6e0', bridge: '#ffd166', door: '#ef8bb0' },
  { bg: ['#f3dcf5', '#a8b8f0'], blocks: ['#f6e8f4', '#e4cdee', '#cbb3e3', '#a99ad6'], accent: '#ffb347', mech: '#73d2c2', slide: '#ff9aa2', bridge: '#9de3c8', door: '#f28aa0' },
  { bg: ['#d9ecfb', '#f7c6d9'], blocks: ['#edf4fb', '#d3e4f3', '#b6cfe7', '#9ab6d9'], accent: '#ff8a5c', mech: '#ffcf70', slide: '#f497b4', bridge: '#a6e3b5', door: '#e8798f' },
  { bg: ['#ffe9d6', '#d5b4a1'], blocks: ['#fbeee0', '#f1d6bd', '#e3bb9b', '#cf9f82'], accent: '#4bb3a8', mech: '#88b6e8', slide: '#e59ac0', bridge: '#9ed9c4', door: '#d9727f' },
  { bg: ['#e2f7f1', '#c3a9e6'], blocks: ['#effaf4', '#d2efe2', '#b2dcd0', '#93c3c3'], accent: '#ff7b9c', mech: '#ffc46b', slide: '#9b8fe3', bridge: '#ffe08a', door: '#ee8aa8' },
  { bg: ['#fff4e0', '#a6d1e6'], blocks: ['#fff7e8', '#f6e3c2', '#e8cda0', '#d4b07f'], accent: '#e8637a', mech: '#6fc2b0', slide: '#87a8ec', bridge: '#b6e3a3', door: '#e07b8c' },
  { bg: ['#f5e1da', '#8fb8c9'], blocks: ['#f9ece4', '#ecd1c4', '#d9b2a5', '#bf9690'], accent: '#ffb84d', mech: '#74c0b9', slide: '#ad9ce0', bridge: '#a3d9b8', door: '#e3869b' },
  { dark: true, bg: ['#1f2a4a', '#5b4b8a'], blocks: ['#f2e6ff', '#d7c4f2', '#b9a3e3', '#9a86cf'], accent: '#ffd36e', mech: '#6fe0d0', slide: '#ff9bb3', bridge: '#9af0c8', door: '#ff8fa3' },
  { bg: ['#ffe0e9', '#ffd6a5'], blocks: ['#fff1f4', '#fbd9e2', '#f2bccc', '#e19fb4'], accent: '#4aa3df', mech: '#7bd3b0', slide: '#b29bf0', bridge: '#a8e6cf', door: '#e06c8a' },
];

// ---------- Komut simgeleri ----------
const ICON = {
  F: '<svg viewBox="0 0 24 24"><path d="M12 20V5M5.5 11.5 12 5l6.5 6.5"/></svg>',
  L: '<svg viewBox="0 0 24 24"><path d="M9.5 13.5 4.5 8.5l5-5"/><path d="M4.5 8.5H14a5.5 5.5 0 0 1 5.5 5.5V20"/></svg>',
  R: '<svg viewBox="0 0 24 24"><path d="m14.5 13.5 5-5-5-5"/><path d="M19.5 8.5H10A5.5 5.5 0 0 0 4.5 14V20"/></svg>',
  J: '<svg viewBox="0 0 24 24"><path d="M3.5 19.5C5 8 17 6 20 15"/><path d="m15.5 13.5 4.6 1.8 1.6-4.6"/><path d="M3 21h4"/></svg>',
  A: '<svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="3.2"/><path d="M12 2.5v3.2M12 18.3v3.2M2.5 12h3.2M18.3 12h3.2M5.3 5.3l2.2 2.2M16.5 16.5l2.2 2.2M5.3 18.7l2.2-2.2M16.5 7.5l2.2-2.2"/></svg>',
  W: '<svg viewBox="0 0 24 24"><path d="M9 5v14M15 5v14"/></svg>',
  1: '<b>F1</b>', 2: '<b>F2</b>',
};

// ---------- Kurulum ----------
const canvas = $('c');
const renderer = new THREE.WebGLRenderer({ canvas, antialias: true, alpha: true });
renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
renderer.shadowMap.enabled = true;
renderer.shadowMap.type = THREE.PCFSoftShadowMap;
renderer.outputColorSpace = THREE.SRGBColorSpace;
const scene = new THREE.Scene();
const hemi = new THREE.HemisphereLight('#fff6ee', '#9f8fc7', 2.1);
scene.add(hemi);
const sun = new THREE.DirectionalLight('#fff1dc', 2.7);
sun.castShadow = true;
sun.shadow.mapSize.set(2048, 2048);
sun.shadow.camera.left = -18; sun.shadow.camera.right = 18; sun.shadow.camera.top = 18; sun.shadow.camera.bottom = -18;
sun.shadow.camera.near = 1; sun.shadow.camera.far = 90;
sun.shadow.bias = -0.0008; sun.shadow.normalBias = 0.02;
scene.add(sun); scene.add(sun.target);
const rim = new THREE.DirectionalLight('#c9d6ff', 0.6); scene.add(rim);
const camera = new THREE.OrthographicCamera(-10, 10, 10, -10, 0.1, 400);
const fx = new FX(scene);
const root = new THREE.Group(); scene.add(root);
const sky = new THREE.Group(); scene.add(sky);

const EL = Math.atan(1 / Math.SQRT2);
const cam = { az: 45, azCur: 45, drag: 0, zoom: 1, target: new THREE.Vector3(), half: 8, spin: false };

// Görünür alan: program paneli ekranın bir kısmını kapladığı için sahne serbest alana ortalanır.
function freeRect() {
  const W = window.innerWidth, H = window.innerHeight;
  const hud = $('hud');
  if (hud.classList.contains('hidden')) return { x: 0, y: 0, w: W, h: H };
  const pr = $('panel').getBoundingClientRect();
  const top = 64;
  if (pr.left > W * 0.3) return { x: 0, y: top * 0.5, w: pr.left, h: H - top * 0.5 };
  return { x: 0, y: top, w: W, h: Math.max(120, pr.top - top) };
}
function resize() {
  const W = window.innerWidth, H = window.innerHeight;
  renderer.setSize(W, H, false);
  const f = freeRect();
  const a = f.w / f.h;
  let half = cam.half;
  if (a < 1) half = half / a * 0.85;
  const u = 2 * half / f.h;
  const cx = f.x + f.w / 2 - W / 2, cy = f.y + f.h / 2 - H / 2;
  camera.left = -W / 2 * u - cx * u; camera.right = W / 2 * u - cx * u;
  camera.top = H / 2 * u + cy * u; camera.bottom = -H / 2 * u + cy * u;
  camera.updateProjectionMatrix();
}
window.addEventListener('resize', resize);
new ResizeObserver(() => resize()).observe($('panel'));

function updateCamera(dt) {
  const target = cam.az + cam.drag;
  cam.azCur += (target - cam.azCur) * Math.min(1, dt * 8);
  if (Math.abs(target - cam.azCur) < 0.01) cam.azCur = target;
  const a = THREE.MathUtils.degToRad(cam.azCur);
  const off = new THREE.Vector3(Math.cos(EL) * Math.cos(a), Math.sin(EL), Math.cos(EL) * Math.sin(a)).multiplyScalar(60);
  camera.position.copy(cam.target).add(off);
  camera.lookAt(cam.target);
  camera.zoom += (cam.zoom - camera.zoom) * Math.min(1, dt * 8);
  camera.updateProjectionMatrix();
  sun.position.copy(cam.target).add(new THREE.Vector3(8, 20, 5));
  sun.target.position.copy(cam.target);
  rim.position.copy(cam.target).add(new THREE.Vector3(-10, 6, -8));
}

// ---------- Malzemeler / geometriler ----------
const geoBlock = new RoundedBoxGeometry(1, 1, 1, 2, 0.07);
const geoCrate = new RoundedBoxGeometry(0.84, 0.84, 0.84, 2, 0.08);
const geoBall = new THREE.SphereGeometry(0.36, 28, 18);
const matCache = new Map();
function mat(color, opts = {}) {
  const key = color + JSON.stringify(opts);
  if (!matCache.has(key)) matCache.set(key, new THREE.MeshStandardMaterial({ color, roughness: 0.85, metalness: 0, ...opts }));
  return matCache.get(key);
}
function canvasTex(draw, size = 128) {
  const c = document.createElement('canvas'); c.width = c.height = size;
  draw(c.getContext('2d'), size);
  const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace; return t;
}
const crateTex = canvasTex((g, s) => {
  g.fillStyle = '#d9a066'; g.fillRect(0, 0, s, s);
  g.strokeStyle = '#a8703f'; g.lineWidth = 10; g.strokeRect(8, 8, s - 16, s - 16);
  g.lineWidth = 8; g.beginPath(); g.moveTo(12, 12); g.lineTo(s - 12, s - 12); g.stroke();
  g.fillStyle = '#e8b57d'; for (let i = 0; i < 6; i++) g.fillRect(20, 22 + i * 15, s - 40, 3);
});
const ballTex = canvasTex((g, s) => {
  g.fillStyle = '#f4f1ff'; g.fillRect(0, 0, s, s);
  g.fillStyle = '#ff7f88'; g.fillRect(0, s * 0.42, s, s * 0.16);
  g.fillStyle = '#7f9cff'; g.fillRect(s * 0.42, 0, s * 0.16, s);
});
const crackTex = canvasTex((g, s) => {
  g.fillStyle = '#e9d8bf'; g.fillRect(0, 0, s, s);
  g.strokeStyle = '#8c6f58'; g.lineWidth = 3;
  const lines = [[10, 20, 50, 60, 64, 110], [64, 60, 110, 40, 120, 10], [50, 60, 20, 100], [80, 50, 100, 100, 90, 125]];
  for (const l of lines) { g.beginPath(); g.moveTo(l[0], l[1]); for (let i = 2; i < l.length; i += 2) g.lineTo(l[i], l[i + 1]); g.stroke(); }
});
// Monument Valley tarzı kemerli pencere çıkartması
const archTex = canvasTex((g, s) => {
  g.clearRect(0, 0, s, s);
  const w = s * 0.56, x = (s - w) / 2, top = s * 0.16, bot = s * 0.92;
  const path = () => { g.beginPath(); g.moveTo(x, bot); g.lineTo(x, top + w / 2); g.arc(s / 2, top + w / 2, w / 2, Math.PI, 0); g.lineTo(x + w, bot); g.closePath(); };
  path(); g.fillStyle = 'rgba(70,52,110,0.42)'; g.fill();
  g.save(); path(); g.clip(); g.fillStyle = 'rgba(255,255,255,0.18)'; g.fillRect(x, top, w * 0.35, bot - top); g.restore();
  g.lineWidth = 5; g.strokeStyle = 'rgba(255,255,255,0.45)'; path(); g.stroke();
}, 64);
const beamTex = canvasTex((g, s) => {
  const gr = g.createLinearGradient(0, 0, 0, s);
  gr.addColorStop(0, 'rgba(255,255,255,0)'); gr.addColorStop(0.7, 'rgba(255,255,255,0.55)'); gr.addColorStop(1, 'rgba(255,255,255,0.9)');
  g.fillStyle = gr; g.fillRect(0, 0, s, s);
}, 64);
const dotTex = canvasTex((g, s) => {
  const gr = g.createRadialGradient(s / 2, s / 2, 0, s / 2, s / 2, s / 2);
  gr.addColorStop(0, 'rgba(255,255,255,1)'); gr.addColorStop(1, 'rgba(255,255,255,0)');
  g.fillStyle = gr; g.fillRect(0, 0, s, s);
}, 64);

// ---------- Gökyüzü: bulut denizi ve süzülen tozlar ----------
const cloudMat = new THREE.MeshStandardMaterial({ color: '#ffffff', roughness: 1, transparent: true, opacity: 0.92 });
const cloudGeo = new THREE.SphereGeometry(1, 18, 12);
function buildSky(center, radius, floorY, dark) {
  sky.clear();
  cloudMat.color.set(dark ? '#8f88c4' : '#ffffff'); cloudMat.opacity = dark ? 0.45 : 0.75;
  const rnd = mulberry(7);
  for (let i = 0; i < 14; i++) {
    const g = new THREE.Group();
    const a = (i / 14) * Math.PI * 2 + rnd() * 0.3, r = radius * (0.9 + rnd() * 0.8);
    g.position.set(center.x + Math.cos(a) * r, floorY - 4 - rnd() * 3, center.z + Math.sin(a) * r);
    const n = 3 + Math.floor(rnd() * 3);
    for (let k = 0; k < n; k++) {
      const m = new THREE.Mesh(cloudGeo, cloudMat);
      const sc = 0.6 + rnd() * 0.8;
      m.scale.set(sc * 1.4, sc * 0.8, sc);
      m.position.set((k - n / 2) * 1.3 + rnd(), rnd() * 0.6, rnd() * 1.2);
      g.add(m);
    }
    g.userData.speed = 0.05 + rnd() * 0.08; g.userData.a = a; g.userData.r = r; g.userData.c = center.clone();
    sky.add(g);
  }
  const N = 70, pos = new Float32Array(N * 3);
  for (let i = 0; i < N; i++) {
    pos[i * 3] = center.x + (rnd() - 0.5) * radius * 2.4;
    pos[i * 3 + 1] = floorY + rnd() * radius * 1.2;
    pos[i * 3 + 2] = center.z + (rnd() - 0.5) * radius * 2.4;
  }
  const geo = new THREE.BufferGeometry(); geo.setAttribute('position', new THREE.BufferAttribute(pos, 3));
  const pts = new THREE.Points(geo, new THREE.PointsMaterial({ map: dotTex, size: 0.22, transparent: true, opacity: 0.7, depthWrite: false, color: dark ? '#fff2b0' : '#ffffff' }));
  pts.userData.dust = true; sky.add(pts);
}
function mulberry(a) { return () => { a |= 0; a = a + 0x6D2B79F5 | 0; let t = Math.imul(a ^ a >>> 15, 1 | a); t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t; return ((t ^ t >>> 14) >>> 0) / 4294967296; }; }

// ---------- Robo ----------
function makeRobot(accent) {
  const g = new THREE.Group();
  const body = new THREE.Mesh(new RoundedBoxGeometry(0.46, 0.42, 0.4, 3, 0.1), mat('#fffaf2'));
  body.position.y = 0.33; g.add(body);
  const face = new THREE.Mesh(new RoundedBoxGeometry(0.36, 0.22, 0.04, 2, 0.02), mat('#3b3555', { roughness: 0.4 }));
  face.position.set(0, 0.37, 0.2); g.add(face);
  const eyeM = new THREE.MeshBasicMaterial({ color: '#7ff3ff' });
  const eyes = new THREE.Group(); eyes.position.set(0, 0.38, 0.225); g.add(eyes);
  for (const x of [-0.08, 0.08]) { const e = new THREE.Mesh(new THREE.SphereGeometry(0.035, 12, 8), eyeM); e.position.x = x; eyes.add(e); }
  const ant = new THREE.Mesh(new THREE.CylinderGeometry(0.015, 0.015, 0.16), mat('#8a8299')); ant.position.y = 0.62; g.add(ant);
  const bulbMat = new THREE.MeshStandardMaterial({ color: accent, emissive: accent, emissiveIntensity: 0.7 });
  const bulb = new THREE.Mesh(new THREE.SphereGeometry(0.05, 12, 8), bulbMat);
  bulb.position.y = 0.72; g.add(bulb);
  for (const x of [-0.12, 0.12]) { const f = new THREE.Mesh(new RoundedBoxGeometry(0.12, 0.1, 0.18, 2, 0.03), mat('#8a8299')); f.position.set(x, 0.06, 0.02); g.add(f); }
  for (const x of [-0.27, 0.27]) { const a = new THREE.Mesh(new THREE.CapsuleGeometry(0.04, 0.14, 4, 8), mat(accent)); a.position.set(x, 0.3, 0); g.add(a); }
  g.traverse(o => { if (o.isMesh) o.castShadow = true; });
  // yön oku (ayak altı)
  const sh = new THREE.Shape(); sh.moveTo(0, 0.2); sh.lineTo(0.17, -0.02); sh.lineTo(0.07, -0.02); sh.lineTo(0.07, -0.16); sh.lineTo(-0.07, -0.16); sh.lineTo(-0.07, -0.02); sh.lineTo(-0.17, -0.02); sh.closePath();
  const arrow = new THREE.Mesh(new THREE.ShapeGeometry(sh), new THREE.MeshBasicMaterial({ color: '#ffffff', transparent: true, opacity: 0.95, depthWrite: false }));
  arrow.rotation.x = -Math.PI / 2; arrow.rotation.z = Math.PI; arrow.position.set(0, 0.025, 0.5); arrow.renderOrder = 3; g.add(arrow);
  const ring = new THREE.Mesh(new THREE.RingGeometry(0.34, 0.4, 36), new THREE.MeshBasicMaterial({ color: '#ffffff', transparent: true, opacity: 0.55, depthWrite: false, side: THREE.DoubleSide }));
  ring.rotation.x = -Math.PI / 2; ring.position.y = 0.02; g.add(ring);
  Object.assign(g.userData, { bulb, bulbMat, body, eyes, arrow, ring, accent });
  return g;
}

// ---------- Oyun durumu ----------
let L = null, state = null, setupState = null, levelIdx = 0, pal = PALETTES[0];
let queue = [], anim = null, displayed = null, winShown = false;
let objs = null, pickables = [];
let instant = false, preview = false;
let mode = 'edit';            // edit | running | paused | ended | won
let runner = null, stepOnce = false, speedIdx = 0, endReason = null;
let prog = { main: [], p1: [], p2: [] };
let activeRow = 'main', caret = 0, sel = null;
let undoStack = [];
let progress = loadProgress();

function loadProgress() {
  const d = { unlocked: 1, best: {}, progs: {}, seen: {}, sound: true };
  try { return Object.assign(d, JSON.parse(localStorage.getItem(SAVE_KEY) || '{}')); } catch (e) { return d; }
}
function saveProgress() { try { localStorage.setItem(SAVE_KEY, JSON.stringify(progress)); } catch (e) {} }
setSound(progress.sound !== false);

function addPick(mesh, info) { mesh.userData.pick = info; pickables.push(mesh); }
function shadowed(m) { m.castShadow = true; m.receiveShadow = true; return m; }
function blockColor(x, y, z) {
  const b = pal.blocks;
  const c = new THREE.Color(b[((y - L.minY) % b.length + b.length) % b.length]);
  if ((x + z) % 2 === 0) c.offsetHSL(0, 0, 0.025);
  return '#' + c.getHexString();
}
function makeStair(color) {
  const g = new THREE.Group();
  for (let k = 0; k < 3; k++) {
    const h = (k + 1) / 3;
    const m = shadowed(new THREE.Mesh(new RoundedBoxGeometry(1 / 3, h, 1, 1, 0.03), mat(color)));
    m.position.set(-1 / 3 + k / 3, -0.5 + h / 2, 0); g.add(m);
  }
  return g;
}
const STAIR_ROT = [0, -Math.PI / 2, Math.PI, Math.PI / 2];
const hash3 = (x, y, z, d) => (((x * 73856093) ^ (y * 19349663) ^ (z * 83492791) ^ (d * 2654435761)) >>> 0) % 97;

function buildLevel(i, opts = {}) {
  levelIdx = i;
  preview = !!opts.preview;
  const def = LEVELS[i];
  pal = PALETTES[(def.palette ?? i) % PALETTES.length];
  $('bg').style.background = `linear-gradient(${pal.bg[0]}, ${pal.bg[1]})`;
  document.body.classList.toggle('dark', !!pal.dark);
  document.querySelector('meta[name=theme-color]').content = pal.bg[0];
  root.clear(); fx.clear(); pickables = [];
  L = E.loadLevel(JSON.parse(JSON.stringify(def)));
  state = E.initialState(L);
  setupState = null;
  queue = []; anim = null; winShown = false; mode = 'edit'; runner = null; undoStack = [];
  objs = { crates: [], balls: [], levers: [], plates: [], bridges: [], rotators: [], sliders: [], crumbles: [], links: [], cranks: [], trail: [] };
  const box = new THREE.Box3();
  const addB = (p) => box.expandByPoint(new THREE.Vector3(p[0], p[1], p[2]));
  const staticCells = [];
  const has = (x, y, z) => L.statics.has(x + ',' + y + ',' + z);
  for (const [k, v] of L.statics) {
    const p = k.split(',').map(Number); addB(p); staticCells.push(p);
    if (v.t === 'b') {
      const m = shadowed(new THREE.Mesh(geoBlock, mat(blockColor(p[0], p[1], p[2]))));
      m.position.set(p[0], p[1], p[2]); root.add(m); addPick(m, { kind: 'block' });
      // kule duvarlarına kemerli pencereler
      if (has(p[0], p[1] + 1, p[2])) {
        DIRS.forEach((d, di) => {
          if (has(p[0] + d[0], p[1], p[2] + d[2]) || hash3(p[0], p[1], p[2], di) % 3) return;
          const w = new THREE.Mesh(new THREE.PlaneGeometry(0.42, 0.62), new THREE.MeshBasicMaterial({ map: archTex, transparent: true, depthWrite: false }));
          w.position.set(p[0] + d[0] * 0.505, p[1] - 0.05, p[2] + d[2] * 0.505);
          w.rotation.y = Math.atan2(d[0], d[2]); root.add(w);
        });
      }
    } else {
      const g = makeStair(blockColor(p[0], p[1] + 1, p[2]));
      g.position.set(p[0], p[1], p[2]); g.rotation.y = STAIR_ROT[v.d]; root.add(g);
      g.children.forEach(c => addPick(c, { kind: 'block', cell: p }));
    }
  }
  fx.setStatics(staticCells);
  (def.bridges || []).forEach((b, bi) => {
    const meshes = b.cells.map(c => {
      addB(c);
      const m = shadowed(new THREE.Mesh(geoBlock, new THREE.MeshStandardMaterial({ color: b.door ? pal.door : pal.bridge, roughness: 0.6, transparent: true })));
      m.position.set(c[0], c[1], c[2]); root.add(m); addPick(m, { kind: 'bridge', i: bi });
      if (b.door) { const bar = new THREE.Mesh(new THREE.BoxGeometry(0.12, 0.7, 1.02), mat('#ffffff', { transparent: true, opacity: 0.6 })); m.add(bar); }
      return m;
    });
    objs.bridges.push(meshes);
  });
  (def.rotators || []).forEach((r, ri) => {
    const g = new THREE.Group(); g.position.set(r.pivot[0], 0, r.pivot[1]);
    for (const b of r.blocks) {
      addB(b);
      const m = shadowed(new THREE.Mesh(geoBlock, mat(pal.mech)));
      m.position.set(b[0] - r.pivot[0], b[1], b[2] - r.pivot[1]); g.add(m); addPick(m, { kind: 'rot', i: ri });
      const dot = new THREE.Mesh(new THREE.CircleGeometry(0.12, 20), new THREE.MeshBasicMaterial({ color: '#ffffff', transparent: true, opacity: 0.7 }));
      dot.rotation.x = -Math.PI / 2; dot.position.y = 0.505; m.add(dot);
      addB([r.pivot[0] + (b[2] - r.pivot[1]), b[1], r.pivot[1] + (b[0] - r.pivot[0])]);
      addB([r.pivot[0] - (b[2] - r.pivot[1]), b[1], r.pivot[1] - (b[0] - r.pivot[0])]);
    }
    if (!r.fixed) {
      const hy = r.handle ? r.handle[1] : r.blocks[0][1] - 1;
      const hg = new THREE.Group(); hg.position.set(0, hy + 0.15, 0);
      const wheel = shadowed(new THREE.Mesh(new THREE.TorusGeometry(0.95, 0.09, 10, 40), mat(pal.accent)));
      wheel.rotation.x = Math.PI / 2; hg.add(wheel);
      for (let k = 0; k < 4; k++) { const sp = new THREE.Mesh(new THREE.BoxGeometry(1.9, 0.08, 0.1), mat(pal.accent)); sp.rotation.y = k * Math.PI / 4; hg.add(sp); }
      for (let k = 0; k < 4; k++) { const kn = new THREE.Mesh(new THREE.SphereGeometry(0.14, 12, 8), mat('#fff6e8')); kn.position.set(Math.cos(k * Math.PI / 2) * 0.95, 0, Math.sin(k * Math.PI / 2) * 0.95); hg.add(kn); }
      const shaft = new THREE.Mesh(new THREE.CylinderGeometry(0.1, 0.1, Math.abs(r.blocks[0][1] - hy) + 0.2), mat('#b8aecb'));
      shaft.position.y = (r.blocks[0][1] - hy) / 2 - 0.15; hg.add(shaft);
      hg.children.forEach(c => addPick(c, { kind: 'handle', i: ri }));
      g.add(hg);
    }
    root.add(g); objs.rotators.push(g);
  });
  (def.cranks || []).forEach((ck, ci) => {
    const g = new THREE.Group(); g.position.set(ck.p[0], ck.p[1] - 0.5, ck.p[2]);
    const base = shadowed(new THREE.Mesh(new THREE.CylinderGeometry(0.3, 0.36, 0.14, 24), mat('#8a7fa3')));
    base.position.y = 0.07; g.add(base); addPick(base, { kind: 'crank', i: ci });
    const post = shadowed(new THREE.Mesh(new THREE.CylinderGeometry(0.07, 0.07, 0.42), mat('#d8d0e6')));
    post.position.y = 0.33; g.add(post);
    const wheel = new THREE.Group(); wheel.position.y = 0.56; g.add(wheel);
    const rim = shadowed(new THREE.Mesh(new THREE.TorusGeometry(0.3, 0.05, 8, 28), mat(pal.mech)));
    rim.rotation.x = Math.PI / 2; wheel.add(rim);
    for (let k = 0; k < 3; k++) { const sp = new THREE.Mesh(new THREE.BoxGeometry(0.6, 0.05, 0.06), mat(pal.mech)); sp.rotation.y = k * Math.PI / 3; wheel.add(sp); }
    const knob = shadowed(new THREE.Mesh(new THREE.SphereGeometry(0.08, 12, 8), mat(pal.accent))); knob.position.set(0.3, 0.07, 0); wheel.add(knob);
    root.add(g); objs.cranks.push(wheel);
  });
  (def.sliders || []).forEach((s, si) => {
    const g = new THREE.Group();
    const col = !E.isManual(s) ? pal.mech : pal.slide;
    for (const b of s.blocks) {
      addB(b); addB([b[0] + s.axis[0] * s.max, b[1] + s.axis[1] * s.max, b[2] + s.axis[2] * s.max]);
      addB([b[0] + s.axis[0] * s.min, b[1] + s.axis[1] * s.min, b[2] + s.axis[2] * s.min]);
      const m = shadowed(new THREE.Mesh(geoBlock, mat(col)));
      m.position.set(b[0], b[1], b[2]); g.add(m); addPick(m, { kind: 'slide', i: si });
      const stripe = new THREE.Mesh(new THREE.BoxGeometry(1.01, 0.12, 1.01), mat('#ffffff', { roughness: 0.5 }));
      stripe.position.y = 0.25; m.add(stripe);
    }
    const b0 = s.blocks[0];
    const len = s.max - s.min;
    const railG = new THREE.BoxGeometry(0.1, 0.1, 0.1);
    for (const off of [-0.3, 0.3]) {
      const rail = new THREE.Mesh(railG, mat('#8a7fa3', { transparent: true, opacity: 0.55 }));
      const ax = new THREE.Vector3(...s.axis);
      const mid = new THREE.Vector3(b0[0], b0[1], b0[2]).addScaledVector(ax, (s.min + s.max) / 2);
      if (s.axis[1] !== 0) { rail.scale.set(1, len * 10 + 10, 1); mid.x += off; mid.z += 0.52; }
      else { rail.scale.set(s.axis[0] ? len * 10 + 10 : 1, 1, s.axis[2] ? len * 10 + 10 : 1); mid.y -= 0.55; if (s.axis[0]) mid.z += off; else mid.x += off; }
      rail.position.copy(mid); root.add(rail);
    }
    if (E.isManual(s)) {
      for (const sg of [-1, 1]) {
        const cone = shadowed(new THREE.Mesh(new THREE.ConeGeometry(0.22, 0.45, 16), mat(pal.accent)));
        const ax = new THREE.Vector3(...s.axis).multiplyScalar(sg);
        const ends = s.blocks.map(b => new THREE.Vector3(b[0], b[1], b[2]).dot(ax));
        const bp = s.blocks[ends.indexOf(Math.max(...ends))];
        cone.position.set(bp[0], bp[1], bp[2]).addScaledVector(ax, 0.85);
        if (s.axis[1] !== 0) { cone.position.addScaledVector(ax, -0.85); cone.position.z += 0.75; }
        cone.quaternion.setFromUnitVectors(new THREE.Vector3(0, 1, 0), ax);
        g.add(cone); addPick(cone, { kind: 'sarrow', i: si, s: sg });
      }
    }
    root.add(g); objs.sliders.push(g);
  });
  (def.crumbles || []).forEach((c, ci) => {
    addB(c);
    const m = shadowed(new THREE.Mesh(geoBlock, new THREE.MeshStandardMaterial({ map: crackTex, roughness: 0.9, transparent: true })));
    m.position.set(c[0], c[1], c[2]); root.add(m); addPick(m, { kind: 'crumble', i: ci });
    objs.crumbles.push(m);
  });
  (def.plates || []).forEach((p) => {
    const m = new THREE.Mesh(new THREE.CylinderGeometry(0.36, 0.4, 0.08, 28), new THREE.MeshStandardMaterial({ color: pal.mech, roughness: 0.4, emissive: pal.mech, emissiveIntensity: 0 }));
    m.receiveShadow = true; m.position.set(p.p[0], p.p[1] - 0.46, p.p[2]); root.add(m);
    objs.plates.push(m);
  });
  (def.levers || []).forEach((lv, li) => {
    const g = new THREE.Group(); g.position.set(lv.p[0], lv.p[1] - 0.5, lv.p[2]);
    const base = shadowed(new THREE.Mesh(new RoundedBoxGeometry(0.6, 0.18, 0.4, 2, 0.05), mat('#8a7fa3')));
    base.position.y = 0.09; g.add(base);
    const arm = new THREE.Group(); arm.position.y = 0.16; g.add(arm);
    const stick = shadowed(new THREE.Mesh(new THREE.CylinderGeometry(0.04, 0.04, 0.55), mat('#d8d0e6')));
    stick.position.y = 0.27; arm.add(stick);
    const knob = shadowed(new THREE.Mesh(new THREE.SphereGeometry(0.11, 14, 10), mat(pal.accent)));
    knob.position.y = 0.56; arm.add(knob);
    root.add(g); objs.levers.push(arm);
  });
  (def.links || []).forEach((ln) => {
    for (const c of [ln.a, ln.b]) {
      const m = new THREE.Mesh(new THREE.RingGeometry(0.22, 0.34, 24), new THREE.MeshBasicMaterial({ color: pal.accent, transparent: true, opacity: 0.3, side: THREE.DoubleSide }));
      m.rotation.x = -Math.PI / 2; m.position.set(c[0], c[1] - 0.48, c[2]); root.add(m);
      objs.links.push({ m, view: ln.view });
    }
  });
  {
    const g = new THREE.Group(); const gp = def.goal; g.position.set(gp[0], gp[1] - 0.5, gp[2]);
    const gem = new THREE.Mesh(new THREE.OctahedronGeometry(0.22), new THREE.MeshStandardMaterial({ color: pal.accent, emissive: pal.accent, emissiveIntensity: 0.6, roughness: 0.25 }));
    gem.scale.y = 1.35; gem.position.y = 0.6; gem.castShadow = true; g.add(gem);
    const ring = new THREE.Mesh(new THREE.RingGeometry(0.28, 0.4, 36), new THREE.MeshBasicMaterial({ color: '#ffffff', transparent: true, opacity: 0.8, side: THREE.DoubleSide, depthWrite: false }));
    ring.rotation.x = -Math.PI / 2; ring.position.y = 0.03; g.add(ring);
    const beam = new THREE.Mesh(new THREE.CylinderGeometry(0.12, 0.26, 3.2, 20, 1, true), new THREE.MeshBasicMaterial({ map: beamTex, color: pal.accent, transparent: true, opacity: pal.dark ? 0.45 : 0.3, depthWrite: false, side: THREE.DoubleSide, blending: THREE.AdditiveBlending }));
    beam.position.y = 1.6; g.add(beam);
    root.add(g); objs.goal = g; objs.gem = gem; objs.goalRing = ring; addB(gp);
  }
  state.crates.forEach((c, ci) => {
    const m = shadowed(new THREE.Mesh(geoCrate, new THREE.MeshStandardMaterial({ map: crateTex, roughness: 0.8, transparent: true })));
    root.add(m); objs.crates.push(m);
  });
  state.balls.forEach(() => {
    const m = shadowed(new THREE.Mesh(geoBall, new THREE.MeshStandardMaterial({ map: ballTex, roughness: 0.35, transparent: true })));
    m.userData.q = new THREE.Quaternion(); root.add(m); objs.balls.push(m);
  });
  objs.player = makeRobot(pal.accent); root.add(objs.player); addB(state.p);
  const sh = new THREE.Mesh(new THREE.PlaneGeometry(90, 90), new THREE.ShadowMaterial({ opacity: 0.1 }));
  sh.rotation.x = -Math.PI / 2; sh.position.y = L.minY - 2.5; sh.receiveShadow = true; root.add(sh);
  objs.trailGroup = new THREE.Group(); root.add(objs.trailGroup);

  const c = box.getCenter(new THREE.Vector3()); const sz = box.getSize(new THREE.Vector3());
  cam.target.copy(c);
  cam.half = Math.max(4.2, (Math.max(sz.x, sz.z) * 0.62 + sz.y * 0.45) * 0.6 + 1.5);
  const vAz = 45 + 90 * state.view;
  cam.az = vAz; cam.azCur = vAz + 30; cam.drag = 0; cam.zoom = 1;
  buildSky(c, Math.max(sz.x, sz.z) * 0.8 + 6, L.minY - 1, !!pal.dark);
  displayed = state;
  applyVisual(state, state, 1);
  resize();
}

// ---------- Görsel interpolasyon ----------
function lerp(a, b, t) { return a + (b - a) * t; }
function ease(t) { return t < 0.5 ? 2 * t * t : 1 - Math.pow(-2 * t + 2, 2) / 2; }
function rotDelta(a, b) { let d = ((b - a) % 4 + 4) % 4; if (d === 3) d = -1; return d; }
function entityPos(pA, pB, t, sA, sB, out) {
  if (!pA && !pB) return null;
  if (!pB) { out.set(pA[0], pA[1] - 0.5 - t * t * 6, pA[2]); return out; }
  if (!pA) pA = pB;
  for (let i = 0; i < sA.rots.length; i++) {
    if (sA.rots[i] === sB.rots[i]) continue;
    const d = rotDelta(sA.rots[i], sB.rots[i]);
    const pv = L.def.rotators[i].pivot;
    const rp = E.rotPoint(pv, pA, d);
    if (rp[0] === pB[0] && rp[1] === pB[1] && rp[2] === pB[2] && !(pA[0] === pB[0] && pA[2] === pB[2])) {
      const th = d * Math.PI / 2 * t; const dx = pA[0] - pv[0], dz = pA[2] - pv[1];
      out.set(pv[0] + dx * Math.cos(th) + dz * Math.sin(th), pA[1] - 0.5, pv[1] - dx * Math.sin(th) + dz * Math.cos(th));
      return out;
    }
  }
  out.set(lerp(pA[0], pB[0], t), lerp(pA[1], pB[1], t) - 0.5, lerp(pA[2], pB[2], t));
  return out;
}
const tmpV = new THREE.Vector3();
function applyVisual(sA, sB, t, extra) {
  const te = ease(t);
  {
    const linkJump = sA.p && sB.p && Math.abs(sA.p[0] - sB.p[0]) + Math.abs(sA.p[2] - sB.p[2]) > 1 && sA.rots.join() === sB.rots.join();
    const pl = objs.player;
    if (linkJump) {
      // göz yanılması geçidi: Robo bir noktada kaybolup ötekinde belirir
      const from = sA.p, to = sB.p; const k = t < 0.5 ? 0 : 1; const pp = k ? to : from;
      pl.visible = !sB.dead; pl.position.set(pp[0], pp[1] - 0.5, pp[2]);
      pl.scale.setScalar(Math.max(0.05, Math.abs(1 - 2 * t)));
    } else {
      pl.scale.setScalar(1);
      const p = entityPos(sA.dead ? null : sA.p, sB.dead ? null : sB.p, sB.dead ? t : te, sA, sB, tmpV);
      if (p) {
        pl.visible = true; pl.position.copy(p);
        const moved = sA.p[0] !== sB.p[0] || sA.p[2] !== sB.p[2] || sA.p[1] !== sB.p[1];
        const carried = sA.rots.join() !== sB.rots.join() || sA.slides.join() !== sB.slides.join();
        if (moved && !carried) pl.position.y += Math.sin(Math.PI * t) * (sA.p[1] !== sB.p[1] ? 0.3 : 0.14);
      } else pl.visible = false;
    }
    if (extra && extra.bump) {
      const dv = DIRS[sB.f]; const k = Math.sin(Math.PI * t) * 0.17;
      pl.position.x += dv[0] * k; pl.position.z += dv[2] * k;
    }
    const dv = DIRS[sB.f]; const target = Math.atan2(dv[0], dv[2]);
    const fa = DIRS[sA.f]; const from = Math.atan2(fa[0], fa[2]);
    let diff = target - from; diff = Math.atan2(Math.sin(diff), Math.cos(diff));
    pl.rotation.y = from + diff * te;
  }
  objs.crates.forEach((m, i) => {
    const p = entityPos(sA.crates[i], sB.crates[i], te, sA, sB, tmpV);
    m.visible = !!p; if (p) m.position.set(p.x, p.y + 0.42, p.z);
    m.material.opacity = sB.crates[i] ? 1 : 1 - t;
  });
  objs.balls.forEach((m, i) => {
    const a = sA.balls[i] && sA.balls[i].p, b = sB.balls[i] && sB.balls[i].p;
    const p = entityPos(a, b, t, sA, sB, tmpV);
    m.visible = !!p; if (!p) return;
    m.position.set(p.x, p.y + 0.36, p.z);
    m.material.opacity = b ? 1 : 1 - t;
    if (a && b && (a[0] !== b[0] || a[2] !== b[2])) {
      const mv = new THREE.Vector3(b[0] - a[0], 0, b[2] - a[2]);
      const axis = new THREE.Vector3(mv.z, 0, -mv.x).normalize();
      const q = new THREE.Quaternion().setFromAxisAngle(axis, mv.length() / 0.36 * t);
      m.quaternion.copy(q).multiply(m.userData.q);
      if (t >= 1) m.userData.q.copy(m.quaternion);
    } else m.quaternion.copy(m.userData.q);
  });
  objs.rotators.forEach((g, i) => { const d = rotDelta(sA.rots[i], sB.rots[i]); g.rotation.y = (sA.rots[i] + d * te) * Math.PI / 2; });
  objs.cranks.forEach((w, i) => { const ck = L.def.cranks[i]; const d = rotDelta(sA.rots[ck.rot], sB.rots[ck.rot]); w.rotation.y = (sA.rots[ck.rot] + d * te) * Math.PI; });
  objs.sliders.forEach((g, i) => { const ax = L.def.sliders[i].axis; const v = lerp(sA.slides[i], sB.slides[i], te); g.position.set(ax[0] * v, ax[1] * v, ax[2] * v); });
  objs.bridges.forEach((ms, i) => {
    const a = sA.bridges[i] ? 1 : 0, b = sB.bridges[i] ? 1 : 0; const v = lerp(a, b, te);
    for (const m of ms) { m.material.opacity = 0.16 + 0.84 * v; m.scale.setScalar(0.86 + 0.14 * v); m.material.depthWrite = v > 0.5; m.castShadow = v > 0.5; }
  });
  objs.crumbles.forEach((m, i) => { m.visible = !sB.crumbles[i]; });
  (L.def.levers || []).forEach((lv, i) => {
    const a = sA.levers[i] ? 0.6 : -0.6, b = sB.levers[i] ? 0.6 : -0.6;
    objs.levers[i].rotation.z = lerp(a, b, te);
  });
  (L.def.plates || []).forEach((pl, i) => {
    const pr = lerp(plateDown(sA, pl) ? 1 : 0, plateDown(sB, pl) ? 1 : 0, te);
    const m = objs.plates[i]; m.position.y = pl.p[1] - 0.46 - pr * 0.035; m.material.emissiveIntensity = pr * 0.7;
  });
  objs.links.forEach(o => { o.m.material.opacity = sB.view === o.view ? 0.95 : 0.22; o.m.scale.setScalar(sB.view === o.view ? 1.15 : 1); });
}
function plateDown(s, pl) {
  const k = pl.p.join(',');
  if (!s.dead && s.p.join(',') === k) return true;
  if (s.crates.some(c => c && c.join(',') === k)) return true;
  return s.balls.some(b => b && b.p.join(',') === k);
}

// ---------- Animasyon kuyruğu ----------
const speed = () => (mode === 'running' || mode === 'paused') ? SPEEDS[speedIdx] : 1;
function frameDuration(a, b, first, kind) {
  if (instant) return 0;
  let d;
  if (first) {
    d = { F: 0.34, J: 0.4, L: 0.22, R: 0.22, A: 0.3, rot: 0.42, slide: 0.26, view: 0, bump: 0.26 }[kind] ?? 0.3;
    if (kind === 'A' && a.rots.join() !== b.rots.join()) d = 0.5;
    if (Math.abs(a.p[0] - b.p[0]) + Math.abs(a.p[2] - b.p[2]) > 1 && a.rots.join() === b.rots.join()) d = 0.5;
  } else if (a.slides.join() !== b.slides.join()) d = 0.24;
  else if (a.bridges.join() !== b.bridges.join()) d = 0.22;
  else if (a.p.join() === b.p.join() && JSON.stringify(a.crates) === JSON.stringify(b.crates)) d = 0.075;
  else d = 0.1;
  return d / speed();
}
function enqueue(frames, kind, extra) {
  let prev = queue.length ? queue[queue.length - 1].to : (anim ? anim.to : displayed);
  frames.forEach((f, k) => { queue.push({ from: prev, to: f, dur: frameDuration(prev, f, k === 0, kind), t: 0, kind, first: k === 0, extra: k === 0 ? extra : null }); prev = f; });
}
function soundsFor(a, b, kind, first) {
  if (first) {
    if (kind === 'F') sfx.step();
    else if (kind === 'J') sfx.jump();
    else if (kind === 'L' || kind === 'R') sfx.turn();
    else if (kind === 'bump') sfx.bump();
    else if (kind === 'A') {
      if (JSON.stringify(a.crates) !== JSON.stringify(b.crates)) sfx.push();
      else if (a.levers.join() !== b.levers.join()) sfx.click();
      else if (a.rots.join() !== b.rots.join()) sfx.mech();
      else sfx.kick();
    } else if (kind === 'rot' || kind === 'slide') sfx.mech();
  } else {
    if (a.slides.join() !== b.slides.join()) sfx.mech();
    if (a.levers.join() !== b.levers.join()) sfx.click();
  }
  if (!a.bridges.every((v, i) => v === b.bridges[i])) sfx.bridge();
  b.crumbles.forEach((v, i) => { if (v && !a.crumbles[i]) { sfx.crumble(); fx.shatter(L.def.crumbles[i], '#d9c2a3'); } });
  b.crates.forEach((c, i) => { if (!c && a.crates[i]) sfx.fail(); });
  if (b.dead && !a.dead) sfx.fail();
}
function updateQueue(dt) {
  for (let guard = 0; guard < 4000; guard++) {
    if (!anim) {
      if (!queue.length) {
        if (mode === 'running' && state && displayed === state) {
          if (!tick()) break;
          if (!instant) continue;
          continue;
        }
        break;
      }
      anim = queue.shift();
      if (!instant) soundsFor(anim.from, anim.to, anim.kind, anim.first);
    }
    anim.t += anim.dur > 0 ? dt / anim.dur : 1;
    dt = 0;
    if (anim.t >= 1) {
      applyVisual(anim.from, anim.to, 1);
      displayed = anim.to; anim = null;
      if (!instant && queue.length) break;
    } else { applyVisual(anim.from, anim.to, anim.t, anim.extra); break; }
  }
}

// ---------- Yorumlayıcı sürücüsü ----------
// Bir sonraki komutu çalıştırır. false dönerse döngü bu karede durur.
function tick() {
  if (E.isWin(L, state)) { onWin(); return false; }
  if (state.dead) { endRun('dead'); return false; }
  if (stepOnce === 'done') { stepOnce = false; setMode('paused', true); return false; }
  const n = runner.next(L, state);
  markSkipped(runner.skipped);
  if (!n) { endRun(runner.error || 'end'); return false; }
  markExec(n.proc, n.idx);
  const r = P.cmdStep(L, state, n.ins.c);
  if (stepOnce) stepOnce = 'done';
  if (r.pause) { if (!instant) sfx.pause(); stepOnce = false; setMode('paused'); return false; }
  if (r.bump) { enqueue([state], 'bump', { bump: true }); return true; }
  if (n.ins.c === 'F' || n.ins.c === 'J') addTrail(state.p);
  state = r.state;
  enqueue(r.frames, n.ins.c);
  return true;
}
function addTrail(p) {
  if (instant) return;
  const m = new THREE.Mesh(new THREE.CircleGeometry(0.11, 18), new THREE.MeshBasicMaterial({ color: pal.accent, transparent: true, opacity: 0.75, depthWrite: false }));
  m.rotation.x = -Math.PI / 2; m.position.set(p[0], p[1] - 0.47, p[2]);
  objs.trailGroup.add(m);
}
function clearTrail() { if (objs) objs.trailGroup.clear(); }

function setMode(m, quiet) {
  mode = m;
  document.body.classList.toggle('running', m === 'running');
  $('panel').classList.toggle('panel-locked', m === 'running' || m === 'paused');
  $('runLabel').textContent = m === 'running' ? 'Duraklat' : m === 'paused' ? 'Devam' : 'Çalıştır';
  const st = $('status');
  st.className = '';
  if (m === 'paused') {
    st.classList.add('pause');
    st.textContent = quiet ? 'Adım adım: ⏭ sonraki komut, ▶ devam' : 'Mola — platformları çevirebilir, kamerayı döndürebilirsin. Sonra ▶';
  } else if (m === 'ended') {
    st.classList.add('fail');
    st.textContent = endReasonText(endReason);
  } else st.classList.add('hidden');
  if (objs) {
    const u = objs.player.userData;
    u.arrow.visible = u.ring.visible = m !== 'running';
    const col = m === 'running' ? '#57e39a' : m === 'paused' ? '#ffd36e' : m === 'ended' ? '#ff6b7a' : u.accent;
    u.bulbMat.color.set(col); u.bulbMat.emissive.set(col);
  }
  if (m === 'edit') clearExec();
  updateHud();
}
function endReasonText(r) {
  return {
    end: 'Program bitti ama Robo kristale ulaşmadı. Programı düzenle ve tekrar dene.',
    dead: 'Robo düştü! Programı düzenle ve tekrar dene.',
    limit: `Robo yoruldu: ${P.MAX_STEPS} komut sınırı aşıldı. Sonsuz bir döngü mü var?`,
    depth: 'Çok fazla iç içe fonksiyon çağrısı. Döngü için çağrıyı satırın SONUNA koy.',
    loop: 'Program hiçbir şey yapmadan dönüp duruyor (boş döngü).',
  }[r] || 'Program durdu.';
}
function startRun(step) {
  initAudio();
  if (!P.blockCount(prog)) { toast('Önce programa blok ekle'); sfx.nope(); return; }
  if (mode === 'ended') resetToSetup();
  sel = null; hidePopover();
  setupState = E.cloneState(state);
  runner = new P.Runner(P.parseProgram(P.programToSrc(prog)));
  clearTrail();
  stepOnce = !!step;
  $('hintBox').classList.add('hidden');
  if (!instant) sfx.run();
  setMode('running');
  renderRows();
}
function runToggle() {
  if (winShown) return;
  if (mode === 'edit' || mode === 'ended') startRun(false);
  else if (mode === 'running') { stepOnce = false; setMode('paused', true); if (!instant) sfx.pause(); }
  else if (mode === 'paused') { stepOnce = false; if (!instant) sfx.run(); setMode('running'); }
}
function stepBtn() {
  if (winShown) return;
  if (mode === 'edit' || mode === 'ended') startRun(true);
  else if (mode === 'paused') { stepOnce = true; setMode('running'); }
  else if (mode === 'running') { stepOnce = 'done'; }
}
function resetToSetup() {
  if (!setupState) return;
  queue = []; anim = null;
  state = setupState; setupState = null; displayed = state; runner = null;
  applyVisual(state, state, 1); syncView(); clearTrail();
  setMode('edit');
}
function stopRun() {
  if (mode === 'edit') return;
  resetToSetup();
}
function endRun(reason) {
  endReason = reason;
  if (!instant) { if (reason !== 'dead') sfx.fail(); }
  setMode('ended');
}
function markExec(proc, idx) {
  clearExec();
  const row = document.querySelector(`.prow[data-row="${proc}"]`);
  if (!row) return;
  row.classList.add('exec');
  const t = row.querySelectorAll('.slots .tile')[idx];
  if (t) { t.classList.add('run'); if (!instant) t.scrollIntoView({ block: 'nearest', inline: 'nearest' }); }
}
function markSkipped(list) {
  document.querySelectorAll('.tile.skip').forEach(t => t.classList.remove('skip'));
  for (const s of list || []) {
    const t = document.querySelectorAll(`.prow[data-row="${s.proc}"] .slots .tile`)[s.idx];
    if (t) t.classList.add('skip');
  }
}
function clearExec() {
  document.querySelectorAll('.tile.run,.tile.skip').forEach(t => t.classList.remove('run', 'skip'));
  document.querySelectorAll('.prow.exec').forEach(r => r.classList.remove('exec'));
}

// ---------- Dünya işlemleri (oyuncunun eli) ----------
function canEditWorld() {
  if (winShown || preview) return false;
  if (mode === 'ended') resetToSetup();
  if (mode === 'running') { toast('Program çalışıyor — dünyayı değiştirmek için duraklat ya da Mola bloğu kullan'); return false; }
  return true;
}
function worldOp(op, { undo = true } = {}) {
  if (!canEditWorld()) return false;
  if ((anim || queue.length) && op.t !== 'view') return false;
  if (op.t === 'rot' && L.def.rotators[op.i].fixed) { toast('Bu platform yalnızca çarkla döner — Robo\'ya Kullan dedir'); sfx.nope(); return false; }
  const before = E.cloneState(state);
  const r = P.worldOp(L, state, op);
  if (!r.ok) { sfx.nope(); return false; }
  if (undo && mode === 'edit') pushUndo(before);
  state = r.state;
  r.frames[r.frames.length - 1] = state;
  enqueue(r.frames, op.t);
  return true;
}
function syncView() {
  const want = 45 + 90 * state.view;
  const d = ((want - cam.az) % 360 + 540) % 360 - 180; cam.az += d;
}
function rotateView(s) {
  if (!state || preview) return;
  initAudio();
  if (mode === 'running') { toast('Program çalışırken bakış açısı kilitli — Mola ver'); sfx.nope(); return; }
  if (worldOp({ t: 'view', s })) { cam.az += 90 * s; sfx.click(); return true; }
  return false;
}

// ---------- Program düzenleme ----------
function rowsAvail() { return ROWS.filter(r => (L.def.slots[r] || 0) > 0); }
function cloneProg(p) { return { main: p.main.map(x => ({ ...x })), p1: p.p1.map(x => ({ ...x })), p2: p.p2.map(x => ({ ...x })) }; }
function pushUndo(worldBefore) {
  undoStack.push({ prog: cloneProg(prog), world: worldBefore || null });
  if (undoStack.length > 200) undoStack.shift();
}
function undo() {
  if (mode !== 'edit') { if (mode === 'ended') resetToSetup(); else return; }
  const u = undoStack.pop();
  if (!u) { sfx.nope(); return; }
  if (u.world) { queue = []; anim = null; state = u.world; displayed = state; applyVisual(state, state, 1); syncView(); }
  else { prog = u.prog; caret = Math.min(caret, prog[activeRow].length); sel = null; progChanged(false); }
  sfx.del();
}
function editable() {
  if (winShown || preview) return false;
  if (mode === 'ended') resetToSetup();
  return mode === 'edit';
}
function insertCmd(c, row = activeRow, at = null) {
  if (!editable()) return false;
  const cap = L.def.slots[row] || 0;
  if (prog[row].length >= cap) { flashRowFull(row); return false; }
  pushUndo();
  const idx = at == null ? (row === activeRow ? caret : prog[row].length) : at;
  prog[row].splice(idx, 0, { c, k: '' });
  activeRow = row; caret = idx + 1; sel = null;
  sfx.tick();
  progChanged();
  return true;
}
function flashRowFull(row) {
  sfx.nope();
  const el = document.querySelector(`.prow[data-row="${row}"]`);
  if (el) { el.animate([{ transform: 'translateX(0)' }, { transform: 'translateX(-6px)' }, { transform: 'translateX(6px)' }, { transform: 'translateX(0)' }], { duration: 260 }); }
  toast(`${ROW_LABEL[row]} satırı dolu (${L.def.slots[row]} blok)`);
}
function deleteAt(row, idx) {
  if (!editable()) return;
  pushUndo();
  prog[row].splice(idx, 1);
  if (row === activeRow && caret > idx) caret--;
  sel = null; sfx.del();
  progChanged();
}
function progChanged(save = true) {
  if (save) { progress.progs[levelIdx] = P.programToSrc(prog); saveProgress(); }
  renderRows(); updateHud();
}
function tileEl(ins, extra = '') {
  const d = document.createElement('div');
  d.className = 'tile ' + (ins.k ? 'k-' + ins.k : '') + ' ' + extra;
  d.dataset.c = ins.c;
  d.innerHTML = ICON[ins.c] + (ins.k ? `<span class="kb">${ins.k === 'o' ? '✓' : '✕'}</span>` : '');
  d.title = P.COMMANDS[ins.c].name + (ins.k ? ' — ' + P.CONDS[ins.k].name : '');
  return d;
}
function renderPalette() {
  const pEl = $('palette'); pEl.innerHTML = '';
  const prevCmds = new Set(levelIdx > 0 ? LEVELS[levelIdx - 1].cmds : []);
  for (const c of L.def.cmds) {
    const t = tileEl({ c, k: '' }, prevCmds.has(c) || levelIdx === 0 ? '' : 'new');
    t.dataset.src = 'pal';
    t.title = P.COMMANDS[c].name + ' — ' + P.COMMANDS[c].desc;
    pEl.appendChild(t);
  }
}
function renderRows() {
  const rEl = $('rows'); rEl.innerHTML = '';
  for (const row of rowsAvail()) {
    const cap = L.def.slots[row];
    const r = document.createElement('div'); r.className = 'prow' + (row === activeRow && mode === 'edit' ? ' active' : ''); r.dataset.row = row;
    const lbl = document.createElement('div'); lbl.className = 'lbl'; lbl.textContent = ROW_LABEL[row]; r.appendChild(lbl);
    const sl = document.createElement('div'); sl.className = 'slots';
    prog[row].forEach((ins, idx) => {
      if (row === activeRow && idx === caret && mode === 'edit' && !sel) sl.appendChild(caretEl());
      const t = tileEl(ins, sel && sel.row === row && sel.idx === idx ? 'sel' : '');
      t.dataset.src = 'prog'; t.dataset.row = row; t.dataset.idx = idx;
      sl.appendChild(t);
    });
    if (row === activeRow && caret >= prog[row].length && mode === 'edit' && !sel) sl.appendChild(caretEl());
    for (let k = prog[row].length; k < cap; k++) { const e = document.createElement('div'); e.className = 'slot'; sl.appendChild(e); }
    r.appendChild(sl);
    rEl.appendChild(r);
  }
  if (sel) showPopover(); else hidePopover();
}
function caretEl() { const c = document.createElement('div'); c.className = 'caret'; return c; }
// İşaretçinin altındaki satır ve ekleme indeksi
function dropTarget(x, y) {
  const el = document.elementFromPoint(x, y);
  const row = el && el.closest('.prow');
  if (!row) return null;
  const tiles = [...row.querySelectorAll('.slots .tile')];
  let idx = tiles.length;
  for (let i = 0; i < tiles.length; i++) {
    const r = tiles[i].getBoundingClientRect();
    if (y < r.top - 3) { idx = i; break; }
    if (y <= r.bottom + 3 && x < r.left + r.width / 2) { idx = i; break; }
  }
  return { row: row.dataset.row, idx };
}
function showPopover() {
  const pop = $('popover');
  const t = document.querySelector(`.prow[data-row="${sel.row}"] .slots .tile[data-idx="${sel.idx}"]`);
  if (!t) { hidePopover(); return; }
  pop.classList.remove('hidden');
  const ins = prog[sel.row][sel.idx];
  const cb = pop.querySelector('.cond-btn');
  cb.classList.toggle('hidden', !L.def.conds || ins.c === 'W');
  cb.className = 'cond-btn' + (ins.k ? ' k-' + ins.k : '') + (!L.def.conds || ins.c === 'W' ? ' hidden' : '');
  cb.querySelector('.ctext').textContent = P.CONDS[ins.k || ''].name;
  const pr = $('panel').getBoundingClientRect(), tr = t.getBoundingClientRect();
  const pw = pop.offsetWidth, ph = pop.offsetHeight;
  let left = tr.left + tr.width / 2 - pr.left - pw / 2;
  left = Math.max(6, Math.min(pr.width - pw - 6, left));
  let top = tr.top - pr.top - ph - 10;
  pop.classList.toggle('below', top < 2);
  if (top < 2) top = tr.bottom - pr.top + 10;
  pop.style.left = left + 'px'; pop.style.top = top + 'px';
  pop.style.setProperty('--ax', (tr.left + tr.width / 2 - pr.left - left) + 'px');
}
function hidePopover() { $('popover').classList.add('hidden'); }
$('popover').addEventListener('pointerdown', (e) => e.stopPropagation());
$('popover').addEventListener('click', (e) => {
  const b = e.target.closest('button'); if (!b || !sel || !editable()) return;
  const row = prog[sel.row]; const ins = row[sel.idx];
  if (b.dataset.op === 'del') { deleteAt(sel.row, sel.idx); return; }
  pushUndo();
  if (b.dataset.op === 'cond') { ins.k = { '': 'o', o: 'x', x: '' }[ins.k || '']; sfx.tick(); }
  else {
    const j = sel.idx + (b.dataset.op === 'left' ? -1 : 1);
    if (j < 0 || j >= row.length) { undoStack.pop(); sfx.nope(); return; }
    [row[sel.idx], row[j]] = [row[j], row[sel.idx]]; sel.idx = j; sfx.tick();
  }
  progChanged();
});

// panelde dokunma / sürükle-bırak
let pdrag = null;
$('panel').addEventListener('pointerdown', (e) => {
  initAudio();
  if (e.button > 0) return;
  const t = e.target.closest('.tile');
  const lbl = e.target.closest('.lbl');
  const rowEl = e.target.closest('.prow');
  if (!t && !lbl && rowEl && editable()) {
    const dt = dropTarget(e.clientX, e.clientY);
    if (dt) { activeRow = dt.row; caret = dt.idx; sel = null; renderRows(); }
    return;
  }
  if (lbl && editable()) { activeRow = rowEl.dataset.row; caret = prog[activeRow].length; sel = null; renderRows(); return; }
  if (!t || !t.dataset.src) return;
  pdrag = { t, src: t.dataset.src, c: t.dataset.c, row: t.dataset.row, idx: +t.dataset.idx, x: e.clientX, y: e.clientY, id: e.pointerId, started: false };
});
window.addEventListener('pointermove', (e) => {
  if (!pdrag || e.pointerId !== pdrag.id) return;
  if (!pdrag.started) {
    if (Math.hypot(e.clientX - pdrag.x, e.clientY - pdrag.y) < 9 || !editable()) return;
    pdrag.started = true; sel = null; hidePopover();
    const g = $('drag'); g.innerHTML = ''; g.appendChild(pdrag.t.cloneNode(true)); g.classList.remove('hidden');
    if (pdrag.src === 'prog') pdrag.t.classList.add('ghost');
  }
  const g = $('drag'); g.style.left = e.clientX + 'px'; g.style.top = e.clientY + 'px';
  const dt = dropTarget(e.clientX, e.clientY);
  g.classList.toggle('trash', !dt && pdrag.src === 'prog');
  document.querySelectorAll('.prow').forEach(r => r.classList.toggle('active', !!dt && r.dataset.row === dt.row));
});
function endPanelDrag(e, cancel) {
  if (!pdrag || e.pointerId !== pdrag.id) return;
  const d = pdrag; pdrag = null;
  $('drag').classList.add('hidden');
  if (!d.started) {
    if (cancel) return;
    if (d.src === 'pal') insertCmd(d.c);
    else if (editable()) {
      if (sel && sel.row === d.row && sel.idx === d.idx) { sel = null; activeRow = d.row; caret = d.idx + 1; }
      else { sel = { row: d.row, idx: d.idx }; activeRow = d.row; caret = d.idx + 1; }
      sfx.tick(); renderRows();
    }
    return;
  }
  const dt = cancel ? null : dropTarget(e.clientX, e.clientY);
  if (d.src === 'pal') { if (dt) insertCmd(d.c, dt.row, dt.idx); else renderRows(); return; }
  if (!dt) { deleteAt(d.row, d.idx); return; }
  if (dt.row !== d.row && prog[dt.row].length >= L.def.slots[dt.row]) { flashRowFull(dt.row); renderRows(); return; }
  pushUndo();
  const [ins] = prog[d.row].splice(d.idx, 1);
  let to = dt.idx; if (dt.row === d.row && to > d.idx) to--;
  prog[dt.row].splice(to, 0, ins);
  activeRow = dt.row; caret = to + 1; sfx.tick();
  progChanged();
}
window.addEventListener('pointerup', (e) => endPanelDrag(e, false));
window.addEventListener('pointercancel', (e) => endPanelDrag(e, true));

// ---------- Kazanma ----------
function starsFor(blocks, par) { return blocks <= par ? 3 : blocks <= par + 3 ? 2 : 1; }
function onWin() {
  if (winShown) return;
  winShown = true; mode = 'won';
  document.body.classList.remove('running');
  clearExec();
  if (!instant) { sfx.win(); fx.confetti(L.def.goal, [pal.accent, pal.mech, pal.slide, pal.bridge, '#ffffff']); }
  const blocks = P.blockCount(prog), par = L.def.par;
  const stars = starsFor(blocks, par);
  const prev = progress.best[levelIdx];
  if (!prev || blocks < prev.blocks) progress.best[levelIdx] = { blocks, stars };
  progress.unlocked = Math.max(progress.unlocked, Math.min(LEVELS.length, levelIdx + 2));
  progress.progs[levelIdx] = P.programToSrc(prog);
  saveProgress();
  setTimeout(() => {
    $('stars').innerHTML = [0, 1, 2].map(k => `<span class="${k < stars ? '' : 'off'}">★</span>`).join('');
    let txt = `<b>${blocks}</b> blokla çözdün · par <b>${par}</b>`;
    if (blocks < par) txt += '<br>Par\'dan da kısa — usta programcı!';
    else if (stars < 3) txt += `<br>3 yıldız için en fazla ${par} blok kullan. Fonksiyonlar ve döngüler yardımcı olur.`;
    if (levelIdx === LEVELS.length - 1) txt += '<br><br>Tüm kayıp kuleleri buldun! 🎉';
    $('winText').innerHTML = txt;
    $('btnNext').classList.toggle('hidden', levelIdx >= LEVELS.length - 1);
    show('screenWin');
  }, instant ? 0 : 1400);
}

// ---------- 3B sahnede dokunma ----------
const ray = new THREE.Raycaster();
const ndc = new THREE.Vector2();
function pick(x, y) {
  ndc.set(x / window.innerWidth * 2 - 1, -(y / window.innerHeight) * 2 + 1);
  ray.setFromCamera(ndc, camera);
  const hits = ray.intersectObjects(pickables, false);
  for (const h of hits) {
    const info = h.object.userData.pick;
    if (info.kind === 'bridge' && h.object.material.opacity < 0.5) continue;
    let o = h.object, vis = true; while (o) { if (!o.visible) vis = false; o = o.parent; }
    if (!vis) continue;
    return { info, hit: h, obj: h.object };
  }
  return null;
}
function handleClick(pk) {
  if (!pk || !state || winShown) return;
  const { info } = pk;
  if (info.kind === 'handle') worldOp({ t: 'rot', i: info.i, s: 1 });
  else if (info.kind === 'sarrow') worldOp({ t: 'slide', i: info.i, s: info.s });
  else if (info.kind === 'crank') toast('Çarkı Robo çevirir: önüne getirip Kullan bloğunu çalıştır');
  else if (info.kind === 'rot' && L.def.rotators[info.i].fixed) toast('Bu platform yalnızca çarkla döner');
}
let ptr = null;
canvas.addEventListener('contextmenu', e => e.preventDefault());
const touches = new Map();
let pinch = null;
function pinchDist() { const [a, b] = [...touches.values()]; return Math.hypot(a.x - b.x, a.y - b.y); }
canvas.addEventListener('pointerdown', (e) => {
  initAudio();
  if (preview) return;
  canvas.setPointerCapture(e.pointerId);
  if (e.isPrimary) { touches.clear(); pinch = null; }
  touches.set(e.pointerId, { x: e.clientX, y: e.clientY });
  if (sel) { sel = null; renderRows(); }
  if (touches.size === 2) { cam.drag = 0; ptr = null; pinch = { d0: pinchDist(), z0: cam.zoom }; return; }
  if (touches.size > 2 || pinch) return;
  const pk = e.button === 0 ? pick(e.clientX, e.clientY) : null;
  ptr = { x: e.clientX, y: e.clientY, pk, button: e.button, moved: false, steps: 0, mode: null };
});
canvas.addEventListener('pointermove', (e) => {
  if (touches.has(e.pointerId)) touches.set(e.pointerId, { x: e.clientX, y: e.clientY });
  if (pinch && touches.size >= 2) { cam.zoom = THREE.MathUtils.clamp(pinch.z0 * pinchDist() / Math.max(1, pinch.d0), 0.5, 2.5); camera.zoom = cam.zoom; return; }
  if (!ptr) return;
  const dx = e.clientX - ptr.x, dy = e.clientY - ptr.y;
  if (!ptr.moved && Math.hypot(dx, dy) > (e.pointerType === 'touch' ? 16 : 10)) {
    ptr.moved = true;
    const k = ptr.pk && ptr.pk.info.kind;
    if ((k === 'rot' && !L.def.rotators[ptr.pk.info.i].fixed) || k === 'handle') ptr.mode = 'rot';
    else if ((k === 'slide' || k === 'sarrow') && E.isManual(L.def.sliders[ptr.pk.info.i])) ptr.mode = 'slide';
    else ptr.mode = 'cam';
    if (ptr.mode !== 'cam' && !canEditWorld()) ptr.mode = 'none';
    if (ptr.mode !== 'cam' && ptr.mode !== 'none' && mode === 'edit') { pushUndo(E.cloneState(state)); ptr.undo = true; }
  }
  if (!ptr.moved) return;
  if (ptr.mode === 'cam') cam.drag = dx * 0.35;
  else if (ptr.mode === 'rot') {
    const want = Math.trunc(dx / 70);
    while (ptr.steps !== want && !anim && !queue.length) { const s = Math.sign(want - ptr.steps); if (worldOp({ t: 'rot', i: ptr.pk.info.i, s }, { undo: false })) ptr.steps += s, ptr.did = true; else { ptr.steps = want; } }
  } else if (ptr.mode === 'slide') {
    const i = ptr.pk.info.i; const ax = L.def.sliders[i].axis;
    const g = objs.sliders[i]; const p0 = new THREE.Vector3(...L.def.sliders[i].blocks[0]).add(g.position);
    const a = p0.clone().project(camera), b = p0.clone().add(new THREE.Vector3(...ax)).project(camera);
    const sv = new THREE.Vector2((b.x - a.x) * window.innerWidth / 2, -(b.y - a.y) * window.innerHeight / 2);
    const len = sv.length() || 1;
    const want = Math.round((dx * sv.x + dy * sv.y) / len / len);
    while (ptr.steps !== want && !anim && !queue.length) { const s = Math.sign(want - ptr.steps); if (worldOp({ t: 'slide', i, s }, { undo: false })) ptr.steps += s, ptr.did = true; else { ptr.steps = want; break; } }
  }
});
function endTouch(e) { touches.delete(e.pointerId); if (touches.size < 2 && pinch) { if (touches.size === 0) pinch = null; return true; } return !!pinch; }
function finishPtr() { if (ptr && ptr.undo && !ptr.did) undoStack.pop(); }
canvas.addEventListener('pointercancel', (e) => { endTouch(e); finishPtr(); if (ptr && ptr.mode === 'cam') cam.drag = 0; ptr = null; });
canvas.addEventListener('pointerup', (e) => {
  if (endTouch(e)) { ptr = null; return; }
  if (!ptr) return;
  if (!ptr.moved) { if (ptr.button === 0) handleClick(ptr.pk); }
  else if (ptr.mode === 'cam') {
    const steps = Math.round(cam.drag / 90);
    cam.drag = 0;
    if (steps) {
      if (mode === 'running') toast('Program çalışırken bakış açısı kilitli — Mola ver');
      else if (canEditWorld()) {
        if (mode === 'edit') pushUndo(E.cloneState(state));
        for (let k = 0; k < Math.abs(steps); k++) worldOpView(Math.sign(steps));
        cam.az += 90 * steps; sfx.click();
      }
    }
  }
  finishPtr();
  ptr = null;
});
function worldOpView(s) { const r = P.worldOp(L, state, { t: 'view', s }); if (r.ok) { state = r.state; displayed = state; applyVisual(state, state, 1); } }
canvas.addEventListener('wheel', (e) => { cam.zoom = THREE.MathUtils.clamp(cam.zoom * (e.deltaY > 0 ? 0.9 : 1.1), 0.5, 2.5); }, { passive: true });

window.addEventListener('keydown', (e) => {
  if ($('hud').classList.contains('hidden')) {
    if (e.key === 'Enter' && !$('screenWin').classList.contains('hidden')) $('btnNext').click();
    return;
  }
  if (!$('intro').classList.contains('hidden')) { if (e.key === 'Enter' || e.key === 'Escape' || e.key === ' ') { e.preventDefault(); $('btnIntroOk').click(); } return; }
  const k = e.key.toLowerCase();
  const add = { arrowup: 'F', arrowleft: 'L', arrowright: 'R', j: 'J', k: 'A', p: 'W', 1: '1', 2: '2' }[k];
  if (add) { e.preventDefault(); if (L.def.cmds.includes(add)) insertCmd(add); return; }
  if (k === ' ') { e.preventDefault(); runToggle(); }
  else if (k === 'n') stepBtn();
  else if (k === 's' || k === 'escape') { if (sel) { sel = null; renderRows(); } else stopRun(); }
  else if (k === 'backspace' || k === 'delete') {
    e.preventDefault();
    if (sel) deleteAt(sel.row, sel.idx);
    else if (caret > 0 && editable()) deleteAt(activeRow, caret - 1);
  }
  else if (k === 'tab') { e.preventDefault(); const r = rowsAvail(); activeRow = r[(r.indexOf(activeRow) + 1) % r.length]; caret = prog[activeRow].length; sel = null; renderRows(); }
  else if (k === 'z') undo();
  else if (k === 'r') resetWorld();
  else if (k === 'q') rotateView(-1);
  else if (k === 'e') rotateView(1);
  else if (k === 'h') toggleHint();
  else if (k === 'm') openLevels();
});

// ---------- HUD / ekranlar ----------
function updateHud() {
  if (!L || preview) return;
  const blocks = P.blockCount(prog);
  $('lvlChap').textContent = `Bölüm ${chapterIndex(levelIdx) + 1} · ${L.def.chapter}`;
  $('lvlNum').textContent = levelIdx + 1;
  $('lvlName').textContent = L.def.name;
  $('blockCount').textContent = blocks;
  $('par').textContent = L.def.par;
  const st = blocks ? starsFor(blocks, L.def.par) : 3;
  $('miniStars').innerHTML = [0, 1, 2].map(k => `<span class="${k < st ? '' : 'off'}">★</span>`).join('');
  $('btnRun').classList.toggle('attn', levelIdx === 0 && blocks >= 4 && mode === 'edit' && !progress.best[0]);
  $('btnStop').disabled = mode === 'edit';
  $('btnUndo').disabled = mode === 'running' || mode === 'paused';
  $('btnClear').disabled = mode === 'running' || mode === 'paused' || !blocks;
}
function chapterIndex(i) { const names = []; LEVELS.slice(0, i + 1).forEach(l => { if (names[names.length - 1] !== l.chapter) names.push(l.chapter); }); return names.length - 1; }
function toggleHint() { const h = $('hintBox'); h.textContent = L.def.hint || 'İpucu yok.'; h.classList.toggle('hidden'); }
$('hintBox').onclick = () => $('hintBox').classList.add('hidden');
let toastT = null;
function toast(msg) { if (instant) return; const t = $('toast'); t.textContent = msg; t.classList.remove('hidden'); clearTimeout(toastT); toastT = setTimeout(() => t.classList.add('hidden'), 1900); }
function show(id) {
  for (const s of ['screenTitle', 'screenLevels', 'screenWin']) $(s).classList.toggle('hidden', s !== id);
  $('hud').classList.toggle('hidden', id !== null);
  if (id !== null) $('intro').classList.add('hidden');
  cam.spin = id === 'screenTitle';
  resize();
}
function openLevels() {
  if (mode === 'running') setMode('paused', true);
  const g = $('levelGrid'); g.innerHTML = '';
  let chapter = null, grid = null, chIdx = 0, total = 0;
  LEVELS.forEach((lv, i) => {
    if (lv.chapter !== chapter) {
      chapter = lv.chapter; chIdx++;
      const ids = LEVELS.map((l, j) => l.chapter === chapter ? j : -1).filter(j => j >= 0);
      const got = ids.reduce((a, j) => a + (progress.best[j] ? progress.best[j].stars : 0), 0);
      const h = document.createElement('div'); h.className = 'chapter';
      h.innerHTML = `<span class="cn">Bölüm ${chIdx}</span><span class="ct">${chapter}</span><span class="cs">★ ${got}/${ids.length * 3}</span>`;
      g.appendChild(h);
      grid = document.createElement('div'); grid.className = 'lgrid'; g.appendChild(grid);
    }
    const locked = i >= progress.unlocked;
    const best = progress.best[i];
    if (best) total += best.stars;
    const p = PALETTES[(lv.palette ?? i) % PALETTES.length];
    const d = document.createElement('div'); d.className = 'lvl' + (locked ? ' locked' : '') + (i === progress.unlocked - 1 && !best ? ' cur' : '');
    d.style.setProperty('--a', p.dark ? '#d8d0f5' : p.bg[0]); d.style.setProperty('--b', p.dark ? '#a99ad6' : p.bg[1]);
    const stars = best ? [0, 1, 2].map(k => `<span class="${k < best.stars ? '' : 'off'}">★</span>`).join('') : '';
    const cmds = lv.cmds.map(c => `<i style="background:var(--c-${c})"></i>`).join('');
    d.innerHTML = `<div class="n">${locked ? '🔒' : i + 1}</div><div class="nm">${lv.name}</div><div class="cmds">${locked ? '' : cmds}</div><div class="st">${stars}</div>`;
    if (!locked) d.addEventListener('click', () => { initAudio(); startLevel(i); });
    grid.appendChild(d);
  });
  $('totalStars').textContent = `★ ${total} / ${LEVELS.length * 3}`;
  show('screenLevels');
}
function startLevel(i) {
  buildLevel(i);
  const saved = progress.progs[i];
  prog = saved ? P.parseProgram(saved) : { main: [], p1: [], p2: [] };
  for (const r of ROWS) if (prog[r].length > (L.def.slots[r] || 0)) prog[r] = prog[r].slice(0, L.def.slots[r] || 0);
  activeRow = 'main'; caret = prog.main.length; sel = null;
  show(null);
  renderPalette(); renderRows();
  setMode('edit');
  $('hintBox').classList.add('hidden');
  if (L.def.intro && !progress.seen[i] && !instant) {
    $('introTitle').textContent = L.def.intro.title;
    $('introText').innerHTML = L.def.intro.text;
    $('intro').classList.remove('hidden');
  }
  resize();
}
function resetWorld() {
  if (!L || preview) return;
  if (mode === 'running' || mode === 'paused' || mode === 'ended') resetToSetup();
  pushUndo(E.cloneState(state));
  queue = []; anim = null;
  state = E.initialState(L); displayed = state; applyVisual(state, state, 1); syncView();
  sfx.mech();
}
function showTitle() {
  buildLevel(5, { preview: true });
  cam.az = 20; cam.azCur = 20; cam.zoom = 0.85;
  const got = Object.values(progress.best).reduce((a, b) => a + b.stars, 0);
  $('titleProgress').textContent = got ? `★ ${got} / ${LEVELS.length * 3} yıldız` : 'Mekorama ve Monument Valley\'den esinlenen bir programlama bulmacası';
  show('screenTitle');
}

$('btnPlay').onclick = () => { initAudio(); const n = progress.unlocked - 1; if (!progress.best[n] && n < LEVELS.length) startLevel(n); else openLevels(); };
$('btnBackTitle').onclick = showTitle;
$('btnWipe').onclick = () => { if (confirm('Tüm ilerleme ve programlar silinsin mi?')) { progress = { unlocked: 1, best: {}, progs: {}, seen: {}, sound: soundOn() }; saveProgress(); openLevels(); } };
$('btnMenu').onclick = openLevels;
$('btnUndo').onclick = undo;
$('btnClear').onclick = () => { if (!editable() || !P.blockCount(prog)) return; pushUndo(); prog = { main: [], p1: [], p2: [] }; caret = 0; sel = null; sfx.del(); progChanged(); };
$('btnRun').onclick = runToggle;
$('btnStep').onclick = stepBtn;
$('btnStop').onclick = stopRun;
$('btnSpeed').onclick = () => {
  speedIdx = (speedIdx + 1) % SPEEDS.length; $('btnSpeed').textContent = SPEEDS[speedIdx] + '×';
  for (const q of queue) q.dur = q.dur * SPEEDS[(speedIdx + SPEEDS.length - 1) % SPEEDS.length] / SPEEDS[speedIdx];
};
$('btnReset').onclick = resetWorld;
$('btnCamL').onclick = () => rotateView(-1);
$('btnCamR').onclick = () => rotateView(1);
$('btnHint').onclick = toggleHint;
$('btnSound').onclick = () => { setSound(!soundOn()); progress.sound = soundOn(); saveProgress(); $('btnSound').classList.toggle('off', !soundOn()); };
$('btnSound').classList.toggle('off', !soundOn());
$('btnIntroOk').onclick = () => { progress.seen[levelIdx] = 1; saveProgress(); $('intro').classList.add('hidden'); };
$('btnNext').onclick = () => startLevel(Math.min(LEVELS.length - 1, levelIdx + 1));
$('btnWinRetry').onclick = () => { $('screenWin').classList.add('hidden'); winShown = false; show(null); resetToSetup(); setMode('edit'); renderRows(); };
$('btnWinLevels').onclick = openLevels;

// ---------- Döngü ----------
const clock = new THREE.Clock();
function loop() {
  const dt = Math.min(0.05, clock.getDelta());
  const time = clock.elapsedTime;
  if (cam.spin) cam.az += dt * 7;
  updateCamera(dt);
  if (objs) {
    updateQueue(dt);
    objs.gem.rotation.y = time * 1.6; objs.gem.position.y = 0.6 + Math.sin(time * 2.4) * 0.07;
    objs.goalRing.scale.setScalar(1 + Math.sin(time * 3) * 0.08);
    const u = objs.player.userData;
    u.body.position.y = 0.33 + Math.sin(time * 4) * 0.012;
    u.eyes.scale.y = (time % 3.7) < 0.12 ? 0.15 : 1;
    if (u.arrow.visible) u.arrow.material.opacity = 0.7 + Math.sin(time * 4) * 0.25;
    objs.trailGroup.children.forEach(m => { m.material.opacity = Math.max(0.25, m.material.opacity - dt * 0.05); });
  }
  sky.children.forEach(g => {
    if (g.userData.dust) { g.rotation.y += dt * 0.01; return; }
    g.userData.a += dt * g.userData.speed * 0.05;
    g.position.x = g.userData.c.x + Math.cos(g.userData.a) * g.userData.r;
    g.position.z = g.userData.c.z + Math.sin(g.userData.a) * g.userData.r;
  });
  fx.update(dt);
  renderer.render(scene, camera);
  requestAnimationFrame(loop);
}
resize();
loop();

// ---------- Test / hata ayıklama API'si ----------
window.__game = {
  count: LEVELS.length,
  levels: LEVELS,
  start(i) { startLevel(i); },
  setProgram(src) { prog = P.parseProgram(src); caret = prog.main.length; progChanged(false); },
  program: () => P.programToSrc(prog),
  run() { runToggle(); },
  step() { stepBtn(); },
  stop() { stopRun(); },
  op(o) { return o.t === 'view' ? rotateView(o.s) : worldOp(o); },
  mode: () => mode,
  state: () => state,
  isWin: () => E.isWin(L, state),
  winShown: () => winShown,
  setInstant(v) { instant = v; },
  busy: () => !!(anim || queue.length),
  insert: (c) => insertCmd(c),
  project(cell) { const v = new THREE.Vector3(cell[0], cell[1] - 0.5, cell[2]).project(camera); return { x: (v.x + 1) / 2 * window.innerWidth, y: (1 - v.y) / 2 * window.innerHeight }; },
  showLevels: openLevels,
  showTitle,
  progress: () => progress,
  closeIntro() { $('intro').classList.add('hidden'); },
};
// Android uygulaması geri tuşuna basınca bunu çağırır; true dönerse oyun tuşu tüketmiştir.
window.__onBack = () => {
  const visible = (id) => !$(id).classList.contains('hidden');
  if (visible('intro')) { $('btnIntroOk').click(); return true; }
  if (visible('hintBox')) { $('hintBox').classList.add('hidden'); return true; }
  if (sel) { sel = null; renderRows(); return true; }
  if (visible('hud') && (mode === 'running' || mode === 'paused' || mode === 'ended')) { stopRun(); return true; }
  if (visible('hud') || visible('screenWin')) { openLevels(); return true; }
  if (visible('screenLevels')) { showTitle(); return true; }
  return false;
};
const qs = new URLSearchParams(location.search);
if (qs.has('level')) { const n = Math.max(1, Math.min(LEVELS.length, +qs.get('level'))) - 1; startLevel(n); }
else showTitle();
