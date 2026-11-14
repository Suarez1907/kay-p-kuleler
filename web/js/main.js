// Kayıp Kuleler — Three.js istemcisi
import * as THREE from 'three';
import { RoundedBoxGeometry } from '../vendor/RoundedBoxGeometry.js';
import * as E from './engine.js';
import { LEVELS } from './levels.js';
import { initAudio, sfx, setSound, soundOn } from './audio.js';
import { FX } from './fx.js';

const $ = (id) => document.getElementById(id);
const DIRS = E.DIRS;
const SAVE_KEY = 'kayipKuleler.v1';

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

// ---------- Kurulum ----------
const canvas = $('c');
const renderer = new THREE.WebGLRenderer({ canvas, antialias: true, alpha: true });
renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
renderer.shadowMap.enabled = true;
renderer.shadowMap.type = THREE.PCFSoftShadowMap;
renderer.outputColorSpace = THREE.SRGBColorSpace;
const scene = new THREE.Scene();
const hemi = new THREE.HemisphereLight('#fff6ee', '#9f8fc7', 2.2);
scene.add(hemi);
const sun = new THREE.DirectionalLight('#fff3e0', 2.6);
sun.castShadow = true;
sun.shadow.mapSize.set(2048, 2048);
sun.shadow.camera.left = -16; sun.shadow.camera.right = 16; sun.shadow.camera.top = 16; sun.shadow.camera.bottom = -16;
sun.shadow.camera.near = 1; sun.shadow.camera.far = 80;
sun.shadow.bias = -0.0008; sun.shadow.normalBias = 0.02;
scene.add(sun); scene.add(sun.target);
const camera = new THREE.OrthographicCamera(-10, 10, 10, -10, 0.1, 400);
const fx = new FX(scene);
const root = new THREE.Group(); scene.add(root);

const EL = Math.atan(1 / Math.SQRT2);
const cam = { az: 45, azCur: 45, drag: 0, zoom: 1, target: new THREE.Vector3(), half: 8 };

function resize() {
  const w = window.innerWidth, h = window.innerHeight;
  renderer.setSize(w, h, false);
  const a = w / h;
  let half = cam.half;
  if (a < 1) half = half / a * 0.78;
  camera.left = -half * a; camera.right = half * a; camera.top = half; camera.bottom = -half;
  camera.updateProjectionMatrix();
}
window.addEventListener('resize', resize);

function updateCamera(dt) {
  const target = cam.az + cam.drag;
  cam.azCur += (target - cam.azCur) * Math.min(1, dt * 9);
  if (Math.abs(target - cam.azCur) < 0.01) cam.azCur = target;
  const a = THREE.MathUtils.degToRad(cam.azCur);
  const off = new THREE.Vector3(Math.cos(EL) * Math.cos(a), Math.sin(EL), Math.cos(EL) * Math.sin(a)).multiplyScalar(60);
  camera.position.copy(cam.target).add(off);
  camera.lookAt(cam.target);
  camera.zoom += (cam.zoom - camera.zoom) * Math.min(1, dt * 8);
  camera.updateProjectionMatrix();
  sun.position.copy(cam.target).add(new THREE.Vector3(8, 18, 5));
  sun.target.position.copy(cam.target);
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

// ---------- Robo ----------
function makeRobot(accent) {
  const g = new THREE.Group();
  const body = new THREE.Mesh(new RoundedBoxGeometry(0.46, 0.42, 0.4, 3, 0.1), mat('#fffaf2'));
  body.position.y = 0.33; g.add(body);
  const face = new THREE.Mesh(new RoundedBoxGeometry(0.36, 0.22, 0.04, 2, 0.02), mat('#3b3555', { roughness: 0.4 }));
  face.position.set(0, 0.37, 0.2); g.add(face);
  const eyeM = new THREE.MeshBasicMaterial({ color: '#7ff3ff' });
  for (const x of [-0.08, 0.08]) { const e = new THREE.Mesh(new THREE.SphereGeometry(0.035, 12, 8), eyeM); e.position.set(x, 0.38, 0.225); g.add(e); }
  const ant = new THREE.Mesh(new THREE.CylinderGeometry(0.015, 0.015, 0.16), mat('#8a8299')); ant.position.y = 0.62; g.add(ant);
  const bulb = new THREE.Mesh(new THREE.SphereGeometry(0.05, 12, 8), new THREE.MeshStandardMaterial({ color: accent, emissive: accent, emissiveIntensity: 0.6 }));
  bulb.position.y = 0.72; g.add(bulb);
  for (const x of [-0.12, 0.12]) { const f = new THREE.Mesh(new RoundedBoxGeometry(0.12, 0.1, 0.18, 2, 0.03), mat('#8a8299')); f.position.set(x, 0.06, 0.02); g.add(f); }
  for (const x of [-0.27, 0.27]) { const a = new THREE.Mesh(new THREE.CapsuleGeometry(0.04, 0.14, 4, 8), mat(accent)); a.position.set(x, 0.3, 0); g.add(a); }
  g.traverse(o => { if (o.isMesh) { o.castShadow = true; } });
  g.userData.bulb = bulb; g.userData.body = body;
  return g;
}

// ---------- Oyun durumu ----------
let L = null, state = null, levelIdx = 0, pal = PALETTES[0];
let undoStack = [], queue = [], anim = null, pathQueue = [], winShown = false, deadTimer = null;
let objs = null, pickables = [];
let instant = false;
let progress = loadProgress();

function loadProgress() {
  try { return Object.assign({ unlocked: 1, best: {} }, JSON.parse(localStorage.getItem(SAVE_KEY) || '{}')); }
  catch (e) { return { unlocked: 1, best: {} }; }
}
function saveProgress() { try { localStorage.setItem(SAVE_KEY, JSON.stringify(progress)); } catch (e) {} }

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

function buildLevel(i) {
  levelIdx = i;
  const def = LEVELS[i];
  pal = PALETTES[(def.palette ?? i) % PALETTES.length];
  $('bg').style.background = `linear-gradient(${pal.bg[0]}, ${pal.bg[1]})`;
  document.body.classList.toggle('dark', !!pal.dark);
  root.clear(); fx.clear(); pickables = [];
  L = E.loadLevel(def);
  state = E.initialState(L);
  undoStack = []; queue = []; anim = null; pathQueue = []; winShown = false;
  clearTimeout(deadTimer);
  objs = { crates: [], balls: [], levers: [], plates: [], bridges: [], rotators: [], sliders: [], crumbles: [], links: [] };
  // sınırlar
  const box = new THREE.Box3();
  const addB = (p) => box.expandByPoint(new THREE.Vector3(p[0], p[1], p[2]));
  const staticCells = [];
  for (const [k, v] of L.statics) {
    const p = k.split(',').map(Number); addB(p); staticCells.push(p);
    if (v.t === 'b') {
      const m = shadowed(new THREE.Mesh(geoBlock, mat(blockColor(p[0], p[1], p[2]))));
      m.position.set(p[0], p[1], p[2]); root.add(m); addPick(m, { kind: 'block' });
    } else {
      const g = makeStair(blockColor(p[0], p[1] + 1, p[2]));
      g.position.set(p[0], p[1], p[2]); g.rotation.y = STAIR_ROT[v.d]; root.add(g);
      g.children.forEach(c => addPick(c, { kind: 'block', cell: p }));
    }
  }
  fx.setStatics(staticCells);
  // köprüler / kapılar
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
  // döner platformlar
  (def.rotators || []).forEach((r, ri) => {
    const g = new THREE.Group(); g.position.set(r.pivot[0], 0, r.pivot[1]);
    for (const b of r.blocks) {
      addB(b);
      const m = shadowed(new THREE.Mesh(geoBlock, mat(pal.mech)));
      m.position.set(b[0] - r.pivot[0], b[1], b[2] - r.pivot[1]); g.add(m); addPick(m, { kind: 'rot', i: ri });
      addB([r.pivot[0] + (b[2] - r.pivot[1]), b[1], r.pivot[1] + (b[0] - r.pivot[0])]);
      addB([r.pivot[0] - (b[2] - r.pivot[1]), b[1], r.pivot[1] - (b[0] - r.pivot[0])]);
    }
    const hy = r.handle ? r.handle[1] : r.blocks[0][1] - 1;
    const hg = new THREE.Group(); hg.position.set(0, hy + 0.15, 0);
    const wheel = shadowed(new THREE.Mesh(new THREE.TorusGeometry(0.95, 0.09, 10, 40), mat(pal.accent)));
    wheel.rotation.x = Math.PI / 2; hg.add(wheel);
    for (let k = 0; k < 4; k++) { const sp = new THREE.Mesh(new THREE.BoxGeometry(1.9, 0.08, 0.1), mat(pal.accent)); sp.rotation.y = k * Math.PI / 4; hg.add(sp); }
    for (let k = 0; k < 4; k++) { const kn = new THREE.Mesh(new THREE.SphereGeometry(0.14, 12, 8), mat('#fff6e8')); kn.position.set(Math.cos(k * Math.PI / 2) * 0.95, 0, Math.sin(k * Math.PI / 2) * 0.95); hg.add(kn); addPick(kn, { kind: 'handle', i: ri }); }
    const shaft = new THREE.Mesh(new THREE.CylinderGeometry(0.1, 0.1, Math.abs(r.blocks[0][1] - hy) + 0.2), mat('#b8aecb'));
    shaft.position.y = (r.blocks[0][1] - hy) / 2 - 0.15; hg.add(shaft);
    hg.children.forEach(c => { if (!c.userData.pick) addPick(c, { kind: 'handle', i: ri }); });
    g.add(hg);
    root.add(g); objs.rotators.push(g);
  });
  // kaydırıcılar
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
    // ray
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
    // ok tutamakları (yalnızca elle kaydırılanlar)
    if (E.isManual(s)) {
      for (const sg of [-1, 1]) {
        const cone = shadowed(new THREE.Mesh(new THREE.ConeGeometry(0.22, 0.45, 16), mat(pal.accent)));
        const ax = new THREE.Vector3(...s.axis).multiplyScalar(sg);
        const ends = s.blocks.map(b => new THREE.Vector3(b[0], b[1], b[2]).dot(ax));
        const bi = ends.indexOf(Math.max(...ends));
        const bp = s.blocks[bi];
        cone.position.set(bp[0], bp[1], bp[2]).addScaledVector(ax, 0.85);
        if (s.axis[1] !== 0) { cone.position.addScaledVector(ax, -0.85); cone.position.z += 0.75; }
        cone.quaternion.setFromUnitVectors(new THREE.Vector3(0, 1, 0), ax);
        g.add(cone); addPick(cone, { kind: 'sarrow', i: si, s: sg });
      }
    }
    root.add(g); objs.sliders.push(g);
  });
  // çöken taşlar
  (def.crumbles || []).forEach((c, ci) => {
    addB(c);
    const m = shadowed(new THREE.Mesh(geoBlock, new THREE.MeshStandardMaterial({ map: crackTex, roughness: 0.9, transparent: true })));
    m.position.set(c[0], c[1], c[2]); root.add(m); addPick(m, { kind: 'crumble', i: ci });
    objs.crumbles.push(m);
  });
  // plakalar
  (def.plates || []).forEach((p) => {
    const m = new THREE.Mesh(new THREE.CylinderGeometry(0.36, 0.4, 0.08, 28), new THREE.MeshStandardMaterial({ color: pal.mech, roughness: 0.4, emissive: pal.mech, emissiveIntensity: 0 }));
    m.receiveShadow = true; m.position.set(p.p[0], p.p[1] - 0.46, p.p[2]); root.add(m); addPick(m, { kind: 'cellof', cell: p.p });
    objs.plates.push(m);
  });
  // kollar
  (def.levers || []).forEach((lv, li) => {
    const g = new THREE.Group(); g.position.set(lv.p[0], lv.p[1] - 0.5, lv.p[2]);
    const base = shadowed(new THREE.Mesh(new RoundedBoxGeometry(0.6, 0.18, 0.4, 2, 0.05), mat('#8a7fa3')));
    base.position.y = 0.09; g.add(base); addPick(base, { kind: 'lever', i: li });
    const arm = new THREE.Group(); arm.position.y = 0.16; g.add(arm);
    const stick = shadowed(new THREE.Mesh(new THREE.CylinderGeometry(0.04, 0.04, 0.55), mat('#d8d0e6')));
    stick.position.y = 0.27; arm.add(stick); addPick(stick, { kind: 'lever', i: li });
    const knob = shadowed(new THREE.Mesh(new THREE.SphereGeometry(0.11, 14, 10), mat(pal.accent)));
    knob.position.y = 0.56; arm.add(knob); addPick(knob, { kind: 'lever', i: li });
    root.add(g); objs.levers.push(arm);
  });
  // göz yanılması geçitleri
  (def.links || []).forEach((ln) => {
    for (const c of [ln.a, ln.b]) {
      const m = new THREE.Mesh(new THREE.RingGeometry(0.22, 0.34, 24), new THREE.MeshBasicMaterial({ color: pal.accent, transparent: true, opacity: 0.3, side: THREE.DoubleSide }));
      m.rotation.x = -Math.PI / 2; m.position.set(c[0], c[1] - 0.48, c[2]); root.add(m);
      objs.links.push({ m, view: ln.view });
    }
  });
  // hedef
  {
    const g = new THREE.Group(); const gp = def.goal; g.position.set(gp[0], gp[1] - 0.5, gp[2]);
    const gem = new THREE.Mesh(new THREE.OctahedronGeometry(0.22), new THREE.MeshStandardMaterial({ color: pal.accent, emissive: pal.accent, emissiveIntensity: 0.55, roughness: 0.3 }));
    gem.position.y = 0.55; gem.castShadow = true; g.add(gem); addPick(gem, { kind: 'cellof', cell: gp });
    const ring = new THREE.Mesh(new THREE.RingGeometry(0.28, 0.42, 32), new THREE.MeshBasicMaterial({ color: '#ffffff', transparent: true, opacity: 0.8, side: THREE.DoubleSide }));
    ring.rotation.x = -Math.PI / 2; ring.position.y = 0.03; g.add(ring); addPick(ring, { kind: 'cellof', cell: gp });
    root.add(g); objs.goal = g; objs.gem = gem; addB(gp);
  }
  // varlıklar
  state.crates.forEach((c, ci) => {
    const m = shadowed(new THREE.Mesh(geoCrate, new THREE.MeshStandardMaterial({ map: crateTex, roughness: 0.8, transparent: true })));
    root.add(m); addPick(m, { kind: 'crate', i: ci }); objs.crates.push(m);
  });
  state.balls.forEach((b, bi) => {
    const m = shadowed(new THREE.Mesh(geoBall, new THREE.MeshStandardMaterial({ map: ballTex, roughness: 0.35, transparent: true })));
    m.userData.q = new THREE.Quaternion(); root.add(m); addPick(m, { kind: 'ball', i: bi }); objs.balls.push(m);
  });
  objs.player = makeRobot(pal.accent); root.add(objs.player); addB(state.p);
  // gölge zemini
  const sh = new THREE.Mesh(new THREE.PlaneGeometry(80, 80), new THREE.ShadowMaterial({ opacity: 0.12 }));
  sh.rotation.x = -Math.PI / 2; sh.position.y = L.minY - 2.5; sh.receiveShadow = true; root.add(sh);
  // marker
  objs.marker = new THREE.Mesh(new THREE.RingGeometry(0.3, 0.4, 32), new THREE.MeshBasicMaterial({ color: '#ffffff', transparent: true, opacity: 0, side: THREE.DoubleSide, depthTest: false }));
  objs.marker.rotation.x = -Math.PI / 2; objs.marker.renderOrder = 10; root.add(objs.marker);

  const c = box.getCenter(new THREE.Vector3()); const sz = box.getSize(new THREE.Vector3());
  cam.target.copy(c);
  cam.half = Math.max(4.5, (Math.max(sz.x, sz.z) * 0.62 + sz.y * 0.45) * 0.62 + 1.6);
  const vAz = 45 + 90 * state.view;
  cam.az = vAz; cam.azCur = vAz + 25; cam.drag = 0; cam.zoom = 1;
  resize();
  applyVisual(state, state, 1);
  buildMechPanel();
  updateHud();
  $('hintBox').classList.add('hidden');
}

// ---------- Görsel interpolasyon ----------
function lerp(a, b, t) { return a + (b - a) * t; }
function ease(t) { return t < 0.5 ? 2 * t * t : 1 - Math.pow(-2 * t + 2, 2) / 2; }
function rotDelta(a, b) { let d = ((b - a) % 4 + 4) % 4; if (d === 3) d = -1; return d; }

function entityPos(pA, pB, t, sA, sB, out) {
  if (!pA && !pB) return null;
  if (!pB) { out.set(pA[0], pA[1] - 0.5 - t * t * 6, pA[2]); return out; }
  if (!pA) pA = pB;
  // döner platformla taşınma: yay boyunca
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
function applyVisual(sA, sB, t) {
  const te = ease(t);
  // oyuncu
  {
    const p = entityPos(sA.dead ? null : sA.p, sB.dead ? null : sB.p, sB.dead ? t : te, sA, sB, tmpV);
    const pl = objs.player;
    if (p) {
      pl.visible = true; pl.position.copy(p);
      const horiz = sA.p[1] === sB.p[1] && (sA.p[0] !== sB.p[0] || sA.p[2] !== sB.p[2]) && sA.rots.join() === sB.rots.join() && sA.slides.join() === sB.slides.join();
      if (horiz) pl.position.y += Math.sin(Math.PI * t) * 0.14;
      const dv = DIRS[sB.f]; const target = Math.atan2(dv[0], dv[2]);
      let cur = pl.rotation.y; let diff = target - cur; diff = Math.atan2(Math.sin(diff), Math.cos(diff));
      pl.rotation.y = cur + diff * Math.min(1, t * 2 + 0.25);
    } else pl.visible = false;
  }
  objs.crates.forEach((m, i) => {
    const p = entityPos(sA.crates[i], sB.crates[i], te, sA, sB, tmpV);
    m.visible = !!p; if (p) m.position.set(p.x, p.y + 0.42, p.z);
    m.material.opacity = sB.crates[i] ? 1 : 1 - t;
  });
  objs.balls.forEach((m, i) => {
    const a = sA.balls[i] && sA.balls[i].p, b = sB.balls[i] && sB.balls[i].p;
    const p = entityPos(a, b, b ? t : t, sA, sB, tmpV);
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
  objs.rotators.forEach((g, i) => {
    const d = rotDelta(sA.rots[i], sB.rots[i]);
    g.rotation.y = (sA.rots[i] + d * te) * Math.PI / 2;
  });
  objs.sliders.forEach((g, i) => {
    const ax = L.def.sliders[i].axis; const v = lerp(sA.slides[i], sB.slides[i], te);
    g.position.set(ax[0] * v, ax[1] * v, ax[2] * v);
  });
  objs.bridges.forEach((ms, i) => {
    const a = sA.bridges[i] ? 1 : 0, b = sB.bridges[i] ? 1 : 0; const v = lerp(a, b, te);
    for (const m of ms) { m.material.opacity = 0.16 + 0.84 * v; m.scale.setScalar(0.86 + 0.14 * v); m.material.depthWrite = v > 0.5; m.castShadow = v > 0.5; }
  });
  objs.crumbles.forEach((m, i) => {
    const gone = sB.crumbles[i];
    m.visible = !gone;
  });
  const sigA = E.currentSignals(L, sA), sigB = E.currentSignals(L, sB);
  (L.def.levers || []).forEach((lv, i) => {
    const a = sA.levers[i] ? 0.6 : -0.6, b = sB.levers[i] ? 0.6 : -0.6;
    objs.levers[i].rotation.z = lerp(a, b, te);
  });
  (L.def.plates || []).forEach((pl, i) => {
    const pr = lerp(sigA[pl.id] && plateDown(sA, pl) ? 1 : 0, plateDown(sB, pl) ? 1 : 0, te);
    const m = objs.plates[i]; m.position.y = pl.p[1] - 0.46 - pr * 0.035; m.material.emissiveIntensity = pr * 0.7;
  });
  objs.links.forEach(o => { o.m.material.opacity = sB.view === o.view ? 0.95 : 0.22; });
}
function plateDown(s, pl) {
  const k = pl.p.join(',');
  if (!s.dead && s.p.join(',') === k) return true;
  if (s.crates.some(c => c && c.join(',') === k)) return true;
  return s.balls.some(b => b && b.p.join(',') === k);
}

// ---------- Eylem kuyruğu ----------
function frameDuration(a, b, first, action) {
  if (instant) return 0;
  if (first) {
    if (action.t === 'rot') return 0.42;
    if (action.t === 'slide') return 0.26;
    if (action.t === 'view') return 0;
    return 0.19;
  }
  if (a.slides.join() !== b.slides.join()) return 0.24;
  if (a.bridges.join() !== b.bridges.join()) return 0.22;
  const ballOnly = a.p.join() === b.p.join() && JSON.stringify(a.crates) === JSON.stringify(b.crates);
  if (ballOnly) return 0.075;
  return 0.1;
}
function enqueue(frames, action) {
  let prev = queue.length ? queue[queue.length - 1].to : (anim ? anim.to : displayed);
  frames.forEach((f, k) => { queue.push({ from: prev, to: f, dur: frameDuration(prev, f, k === 0, action), t: 0 }); prev = f; });
}
let displayed = null;

function soundsFor(a, b, action, first) {
  if (first) {
    if (action.t === 'move') {
      const pushed = JSON.stringify(a.crates) !== JSON.stringify(b.crates);
      if (pushed) sfx.push();
      else if (a.levers.join() !== b.levers.join()) sfx.click();
      else if (a.p.join() === b.p.join()) sfx.kick();
      else sfx.step();
    } else if (action.t === 'rot' || action.t === 'slide') sfx.mech();
  } else {
    if (a.slides.join() !== b.slides.join()) sfx.mech();
    if (a.levers.join() !== b.levers.join()) sfx.click();
  }
  if (!a.bridges.every((v, i) => v === b.bridges[i])) sfx.bridge();
  b.crumbles.forEach((v, i) => { if (v && !a.crumbles[i]) { sfx.crumble(); fx.shatter(L.def.crumbles[i], '#d9c2a3'); } });
  b.crates.forEach((c, i) => { const ca = a.crates[i]; if (c && ca && c[1] < ca[1] && !first) { /* düşüş */ } if (!c && ca) sfx.fail(); });
  if (b.dead && !a.dead) sfx.fail();
}

function doAction(action, { record = true } = {}) {
  if (!state || state.dead) return false;
  const res = E.step(L, state, action);
  if (!res.ok) { return false; }
  state = res.state;
  res.frames[res.frames.length - 1] = state;
  enqueue(res.frames, action);
  queue.lastAction = action;
  updateHud();
  return true;
}
function snapshot() { undoStack.push(E.cloneState(state)); if (undoStack.length > 300) undoStack.shift(); }

function command(fn) {
  if (!state || winShown) return;
  initAudio();
  if (state.dead) return;
  snapshot();
  const before = undoStack.length;
  const ok = fn();
  if (!ok) { undoStack.pop(); sfx.nope(); }
}

function updateQueue(dt) {
  while (true) {
    if (!anim) {
      if (!queue.length) break;
      anim = queue.shift();
      anim.first = anim.from === displayed && true;
      soundsFor(anim.from, anim.to, queue.lastAction || { t: 'move' }, anim.dur > 0.15 && anim.from.moves !== anim.to.moves);
    }
    anim.t += anim.dur > 0 ? dt / anim.dur : 1;
    dt = 0;
    if (anim.t >= 1) {
      applyVisual(anim.from, anim.to, 1);
      displayed = anim.to; anim = null;
      if (!queue.length) break;
      if (!instant) break;
    } else { applyVisual(anim.from, anim.to, anim.t); break; }
  }
  if (!anim && !queue.length) {
    if (pathQueue.length && state && !state.dead && !winShown) {
      const d = pathQueue.shift();
      if (!doAction({ t: 'move', d })) pathQueue = [];
      return;
    }
    if (state && displayed === state) checkEnd();
  }
}
function checkEnd() {
  if (winShown) return;
  if (E.isWin(L, state)) { winShown = true; onWin(); return; }
  if (state.dead && !deadTimer) {
    toast('Robo düştü! Bir adım geri alınıyor...');
    deadTimer = setTimeout(() => { deadTimer = null; undo(); }, instant ? 0 : 1100);
  }
}

function undo() {
  if (!undoStack.length) return;
  pathQueue = []; queue = []; anim = null;
  state = undoStack.pop(); displayed = state;
  applyVisual(state, state, 1); syncView(); updateHud();
}
function restart() {
  if (!L) return;
  snapshot();
  pathQueue = []; queue = []; anim = null;
  state = E.initialState(L); displayed = state; winShown = false;
  applyVisual(state, state, 1); syncView(); updateHud();
}
function syncView() {
  const want = 45 + 90 * state.view;
  let cur = cam.az; let d = ((want - cur) % 360 + 540) % 360 - 180; cam.az = cur + d;
}
function rotateView(s) {
  if (!state || state.dead || winShown) return;
  initAudio();
  if (anim || queue.length) return;
  doAction({ t: 'view', s });
  cam.az += 90 * s;
  sfx.click();
}

// ---------- Kazanma ----------
function onWin() {
  sfx.win();
  fx.confetti(L.def.goal, [pal.accent, pal.mech, pal.slide, pal.bridge, '#ffffff']);
  const par = L.def.par || state.moves;
  const stars = state.moves <= par ? 3 : state.moves <= Math.ceil(par * 1.4) ? 2 : 1;
  const prev = progress.best[levelIdx];
  if (!prev || state.moves < prev.moves) progress.best[levelIdx] = { moves: state.moves, stars };
  progress.unlocked = Math.max(progress.unlocked, Math.min(LEVELS.length, levelIdx + 2));
  saveProgress();
  setTimeout(() => {
    $('stars').innerHTML = [0, 1, 2].map(k => `<span class="${k < stars ? '' : 'off'}">★</span>`).join('');
    $('winText').textContent = `${state.moves} hamlede tamamladın (par: ${par}).` + (levelIdx === LEVELS.length - 1 ? ' Tüm kuleleri fethettin! 🎉' : '');
    $('btnNext').classList.toggle('hidden', levelIdx >= LEVELS.length - 1);
    show('screenWin');
  }, instant ? 0 : 900);
}

// ---------- Etkileşim ----------
const ray = new THREE.Raycaster();
const ndc = new THREE.Vector2();
function pick(x, y) {
  ndc.set(x / window.innerWidth * 2 - 1, -(y / window.innerHeight) * 2 + 1);
  ray.setFromCamera(ndc, camera);
  const hits = ray.intersectObjects(pickables, false);
  for (const h of hits) {
    if (!h.object.visible) continue;
    const info = h.object.userData.pick;
    if (info.kind === 'bridge' && h.object.material.opacity < 0.5) continue;
    let o = h.object, vis = true; while (o) { if (!o.visible) vis = false; o = o.parent; }
    if (!vis) continue;
    return { info, hit: h, obj: h.object };
  }
  return null;
}
function cellOf(obj) {
  const p = new THREE.Vector3(); obj.getWorldPosition(p);
  return [Math.round(p.x), Math.round(p.y), Math.round(p.z)];
}
function worldNormal(h) {
  const n = h.face.normal.clone().transformDirection(h.object.matrixWorld);
  return n;
}
function showMarker(c, ok = true) {
  objs.marker.position.set(c[0], c[1] - 0.47, c[2]);
  objs.marker.material.color.set(ok ? '#ffffff' : '#ff5a6e');
  objs.marker.material.opacity = 1; objs.marker.scale.setScalar(1.3);
}
function approachAndAct(objCell, preferDir) {
  // objCell'e komşu bir hücreye yürü, sonra objeye doğru hareket et (it/tekmele/çevir)
  let best = null;
  const order = [0, 1, 2, 3];
  if (preferDir != null) { order.splice(order.indexOf(preferDir), 1); order.unshift(preferDir); }
  for (const d of order) {
    const c = [objCell[0] - DIRS[d][0], objCell[1], objCell[2] - DIRS[d][2]];
    const path = E.findPath(L, state, c);
    if (path == null) continue;
    const cost = path.length + (d === preferDir ? -0.5 : 0);
    if (!best || cost < best.cost) best = { path, d, cost };
  }
  if (!best) return false;
  pathQueue = best.path.concat([best.d]);
  return true;
}
function handleClick(pk) {
  if (!pk || !state || winShown || state.dead) return;
  initAudio();
  const { info, hit, obj } = pk;
  if (info.kind === 'handle') { command(() => doAction({ t: 'rot', i: info.i, s: 1 })); return; }
  if (info.kind === 'sarrow') { command(() => doAction({ t: 'slide', i: info.i, s: info.s })); return; }
  snapshot();
  let ok = false;
  pathQueue = [];
  if (info.kind === 'lever') {
    ok = approachAndAct(L.def.levers[info.i].p, null);
  } else if (info.kind === 'crate' || info.kind === 'ball') {
    const c = info.kind === 'crate' ? state.crates[info.i] : state.balls[info.i].p;
    const n = worldNormal(hit);
    if (info.kind === 'crate' && n.y > 0.6) {
      const t = [c[0], c[1] + 1, c[2]]; const p = E.findPath(L, state, t);
      if (p) { pathQueue = p; ok = true; showMarker(t); }
    } else {
      let pref = null;
      if (Math.abs(n.y) < 0.6) {
        const v = [-Math.round(n.x), -Math.round(n.z)];
        pref = DIRS.findIndex(d => d[0] === v[0] && d[2] === v[1]); if (pref < 0) pref = null;
      }
      ok = approachAndAct(c, pref);
    }
  } else {
    const cell = info.cell && info.kind === 'cellof' ? info.cell : null;
    let target;
    if (cell) target = cell;
    else { const c = info.cell || cellOf(obj); target = [c[0], c[1] + 1, c[2]]; }
    const p = E.findPath(L, state, target);
    if (p && p.length) { pathQueue = p; ok = true; showMarker(target); }
    else if (!p) showMarker(target, false);
  }
  if (!ok) { undoStack.pop(); sfx.nope(); }
}

// işaretçi: tıkla, sürükle (mekanizma ya da kamera)
let ptr = null;
canvas.addEventListener('contextmenu', e => e.preventDefault());
// çoklu dokunma: iki parmakla yakınlaştırma (pinch)
const touches = new Map();
let pinch = null;
function pinchDist() { const [a, b] = [...touches.values()]; return Math.hypot(a.x - b.x, a.y - b.y); }
canvas.addEventListener('pointerdown', (e) => {
  initAudio();
  canvas.setPointerCapture(e.pointerId);
  if (e.isPrimary) { touches.clear(); pinch = null; }
  touches.set(e.pointerId, { x: e.clientX, y: e.clientY });
  if (touches.size === 2) {
    if (ptr && ptr.snap && !ptr.did) undoStack.pop();
    cam.drag = 0; ptr = null;
    pinch = { d0: pinchDist(), z0: cam.zoom };
    return;
  }
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
    if (k === 'rot' || k === 'handle') ptr.mode = 'rot';
    else if ((k === 'slide' || k === 'sarrow') && E.isManual(L.def.sliders[ptr.pk.info.i])) ptr.mode = 'slide';
    else ptr.mode = 'cam';
    if (ptr.mode !== 'cam') snapshot(), ptr.snap = true;
  }
  if (!ptr.moved) return;
  if (ptr.mode === 'cam') { cam.drag = dx * 0.35; }
  else if (ptr.mode === 'rot') {
    const want = Math.trunc(dx / 70);
    while (ptr.steps !== want && !anim && !queue.length) { const s = Math.sign(want - ptr.steps); if (doAction({ t: 'rot', i: ptr.pk.info.i, s })) ptr.steps += s, ptr.did = true; else { ptr.steps = want; sfx.nope(); } }
  } else if (ptr.mode === 'slide') {
    const i = ptr.pk.info.i; const ax = L.def.sliders[i].axis;
    const g = objs.sliders[i]; const p0 = new THREE.Vector3(...L.def.sliders[i].blocks[0]).add(g.position);
    const a = p0.clone().project(camera), b = p0.clone().add(new THREE.Vector3(...ax)).project(camera);
    const sv = new THREE.Vector2((b.x - a.x) * window.innerWidth / 2, -(b.y - a.y) * window.innerHeight / 2);
    const len = sv.length() || 1;
    const want = Math.round((dx * sv.x + dy * sv.y) / len / len);
    while (ptr.steps !== want && !anim && !queue.length) { const s = Math.sign(want - ptr.steps); if (doAction({ t: 'slide', i, s })) ptr.steps += s, ptr.did = true; else { ptr.steps = want; break; } }
  }
});
function endTouch(e) { touches.delete(e.pointerId); if (touches.size < 2 && pinch) { if (touches.size === 0) pinch = null; return true; } return !!pinch; }
canvas.addEventListener('pointercancel', (e) => { endTouch(e); if (ptr && ptr.snap && !ptr.did) undoStack.pop(); if (ptr && ptr.mode === 'cam') cam.drag = 0; ptr = null; });
canvas.addEventListener('pointerup', (e) => {
  if (endTouch(e)) { ptr = null; return; }
  if (!ptr) return;
  if (!ptr.moved) { if (ptr.button === 0) handleClick(ptr.pk); }
  else if (ptr.mode === 'cam') {
    const steps = Math.round(cam.drag / 90);
    cam.az += cam.drag; cam.drag = 0;
    const snapTo = 45 + 90 * Math.round((cam.az - 45) / 90);
    cam.az = snapTo;
    if (steps && state && !state.dead) { for (let k = 0; k < Math.abs(steps); k++) doAction({ t: 'view', s: Math.sign(steps) }); }
    if (state) { const v = (((Math.round((cam.az - 45) / 90)) % 4) + 4) % 4; if (v !== state.view) { state = Object.assign(E.cloneState(state), { view: v }); displayed = state; } }
  } else if (ptr.snap && !ptr.did) undoStack.pop();
  ptr = null;
});
canvas.addEventListener('wheel', (e) => { cam.zoom = THREE.MathUtils.clamp(cam.zoom * (e.deltaY > 0 ? 0.9 : 1.1), 0.5, 2.5); }, { passive: true });

function camDir(screen) {
  const fwd = new THREE.Vector3(); camera.getWorldDirection(fwd); fwd.y = 0; fwd.normalize();
  const right = new THREE.Vector3().crossVectors(fwd, new THREE.Vector3(0, 1, 0)).normalize();
  const want = { up: fwd.clone().add(right), right: right.clone().sub(fwd), down: fwd.clone().add(right).negate(), left: fwd.clone().sub(right) }[screen];
  let best = 0, bd = -1e9;
  DIRS.forEach((d, i) => { const v = d[0] * want.x + d[2] * want.z; if (v > bd) { bd = v; best = i; } });
  return best;
}
window.addEventListener('keydown', (e) => {
  if ($('hud').classList.contains('hidden')) { if (e.key === 'Enter' && !$('screenWin').classList.contains('hidden')) $('btnNext').click(); return; }
  const k = e.key.toLowerCase();
  const map = { arrowup: 'up', w: 'up', arrowdown: 'down', s: 'down', arrowleft: 'left', a: 'left', arrowright: 'right', d: 'right' };
  if (map[k]) { e.preventDefault(); if (anim || queue.length) return; pathQueue = []; const d = camDir(map[k]); command(() => doAction({ t: 'move', d })); return; }
  if (k === 'z' || (e.ctrlKey && k === 'z')) undo();
  else if (k === 'r') restart();
  else if (k === 'q') rotateView(-1);
  else if (k === 'e') rotateView(1);
  else if (k === 'h') toggleHint();
  else if (k === 'm') openLevels();
  else if (k === '?' || k === 'f1') toggleHelp();
});

// ---------- HUD / ekranlar ----------
function buildMechPanel() {
  const p = $('mechPanel'); p.innerHTML = '';
  (L.def.rotators || []).forEach((r, i) => {
    const d = document.createElement('div'); d.className = 'mech';
    d.innerHTML = `Döner ${i + 1} <button data-a="rot" data-i="${i}" data-s="-1">↺</button><button data-a="rot" data-i="${i}" data-s="1">↻</button>`;
    p.appendChild(d);
  });
  (L.def.sliders || []).forEach((s, i) => {
    if (!E.isManual(s)) return;
    const vert = s.axis[1] !== 0;
    const d = document.createElement('div'); d.className = 'mech';
    d.innerHTML = `${vert ? 'Asansör' : 'Kaydırıcı'} ${i + 1} <button data-a="slide" data-i="${i}" data-s="-1">${vert ? '▼' : '◀'}</button><button data-a="slide" data-i="${i}" data-s="1">${vert ? '▲' : '▶'}</button>`;
    p.appendChild(d);
  });
  p.querySelectorAll('button').forEach(b => b.addEventListener('click', () => {
    if (anim || queue.length) return;
    command(() => doAction({ t: b.dataset.a, i: +b.dataset.i, s: +b.dataset.s }));
  }));
}
function updateHud() {
  if (!L) return;
  $('lvlNum').textContent = 'Seviye ' + (levelIdx + 1);
  $('lvlName').textContent = L.def.name;
  $('moves').textContent = state.moves;
  $('par').textContent = L.def.par || '?';
}
function toggleHint() { const h = $('hintBox'); h.textContent = '💡 ' + (L.def.hint || 'İpucu yok.'); h.classList.toggle('hidden'); }
let toastT = null;
function toast(msg) { const t = $('toast'); t.textContent = msg; t.classList.remove('hidden'); clearTimeout(toastT); toastT = setTimeout(() => t.classList.add('hidden'), 1600); }
function show(id) {
  for (const s of ['screenTitle', 'screenLevels', 'screenWin']) $(s).classList.toggle('hidden', s !== id);
  $('hud').classList.toggle('hidden', id !== null);
  $('help').classList.toggle('hidden', id !== null || !helpOpen);
}
let helpOpen = false;
function toggleHelp(v) { helpOpen = v ?? !helpOpen; $('help').classList.toggle('hidden', !helpOpen); }
function openLevels() {
  const g = $('levelGrid'); g.innerHTML = '';
  LEVELS.forEach((lv, i) => {
    const locked = i >= progress.unlocked;
    const best = progress.best[i];
    const d = document.createElement('div'); d.className = 'lvl' + (locked ? ' locked' : '');
    d.innerHTML = `<div class="n">${locked ? '🔒' : i + 1}</div><div class="nm">${lv.name}</div><div class="st">${best ? '★'.repeat(best.stars) + '☆'.repeat(3 - best.stars) : (locked ? '' : '☆☆☆')}</div>`;
    if (!locked) d.addEventListener('click', () => startLevel(i));
    g.appendChild(d);
  });
  show('screenLevels');
}
function startLevel(i) { helpOpen = i === 0 && !instant; buildLevel(i); displayed = state; show(null); if (i === 0 && !instant) setTimeout(() => toggleHint(), 400); }

$('btnPlay').onclick = () => { initAudio(); openLevels(); };
$('btnBackTitle').onclick = () => show('screenTitle');
$('btnReset').onclick = () => { if (confirm('Tüm ilerleme silinsin mi?')) { progress = { unlocked: 1, best: {} }; saveProgress(); openLevels(); } };
$('btnMenu').onclick = openLevels;
$('btnUndo').onclick = undo;
$('btnRestart').onclick = restart;
$('btnCamL').onclick = () => rotateView(-1);
$('btnCamR').onclick = () => rotateView(1);
$('btnHint').onclick = toggleHint;
$('btnHelp').onclick = () => toggleHelp();
$('btnSound').onclick = () => { setSound(!soundOn()); $('btnSound').textContent = soundOn() ? '🔊' : '🔇'; };
$('btnNext').onclick = () => startLevel(Math.min(LEVELS.length - 1, levelIdx + 1));
$('btnWinRetry').onclick = () => startLevel(levelIdx);
$('btnWinLevels').onclick = openLevels;

// ---------- Döngü ----------
const clock = new THREE.Clock();
function loop() {
  const dt = Math.min(0.05, clock.getDelta());
  const time = clock.elapsedTime;
  updateCamera(dt);
  if (objs) {
    updateQueue(dt);
    objs.gem.rotation.y = time * 1.6; objs.gem.position.y = 0.55 + Math.sin(time * 2.4) * 0.07;
    if (objs.player.userData.body) objs.player.userData.body.position.y = 0.33 + Math.sin(time * 4) * 0.012;
    const mk = objs.marker; if (mk.material.opacity > 0) { mk.material.opacity = Math.max(0, mk.material.opacity - dt * 1.5); mk.scale.setScalar(Math.max(0.8, mk.scale.x - dt * 0.6)); }
    objs.rotators.forEach(g => { const h = g.children[g.children.length - 1]; if (h) h.children.forEach(c => {}); });
  }
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
  state: () => state,
  isWin: () => E.isWin(L, state),
  winShown: () => winShown,
  setInstant(v) { instant = v; },
  act(a) { return doAction(a); },
  busy: () => !!(anim || queue.length || pathQueue.length),
  clickCell(cell) { const p = E.findPath(L, state, cell); if (p) pathQueue = p; return !!p; },
  project(cell) { const v = new THREE.Vector3(cell[0], cell[1] - 0.5, cell[2]).project(camera); return { x: (v.x + 1) / 2 * window.innerWidth, y: (1 - v.y) / 2 * window.innerHeight }; },
  setView(v) { state.view = v; cam.az = 45 + 90 * v; cam.azCur = cam.az; },
  showLevels: openLevels,
  progress: () => progress,
  zoom: () => cam.zoom,
  rots: () => state.rots.slice(),
  dbg: () => ({ touches: touches.size, pinch: !!pinch, ptr: !!ptr, busy: !!(anim || queue.length) }),
  objWorld(kind, i) { const o = kind === 'rot' ? objs.rotators[i].children[2] : null; const v = new THREE.Vector3(); o.getWorldPosition(v); v.y += 0.5; v.project(camera); return { x: (v.x + 1) / 2 * window.innerWidth, y: (1 - v.y) / 2 * window.innerHeight }; },
};
// Android uygulaması geri tuşuna basınca bunu çağırır; true dönerse oyun tuşu tüketmiştir.
window.__onBack = () => {
  const visible = (id) => !$(id).classList.contains('hidden');
  if (!$('hintBox').classList.contains('hidden')) { $('hintBox').classList.add('hidden'); return true; }
  if (visible('hud') || visible('screenWin')) { openLevels(); return true; }
  if (visible('screenLevels')) { show('screenTitle'); return true; }
  return false; // başlık ekranı: uygulamadan çık
};
// ?level=N ile doğrudan seviye aç
const qs = new URLSearchParams(location.search);
if (qs.has('level')) { const n = Math.max(1, Math.min(LEVELS.length, +qs.get('level'))) - 1; startLevel(n); }
