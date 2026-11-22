// Kayıp Kuleler — 10–15. bölümlerin (60 seviye) üreticisi.
// Her seviye önce Robo'nun izleyeceği çözüm planından kurulur: "Builder" Robo'yu boş bir dünyada adım adım
// yürütür, bastığı yere blok, merdiven, kol, kutu, çark, döner platform, asansör, ışınlayıcı, göz yanılması
// geçidi ve hayalet bloklar yerleştirir; komutları ve molalardaki dünya işlemlerini kaydeder. Düz komut listesi
// sonra F1/F2'ye sıkıştırılır ve program kapasiteleri buna göre dar tutulur (fonksiyonlar zorunlu olur).
// Üretim tohumlu ve deterministiktir; her aday gerçek yorumlayıcıda çalıştırılır, kazanmayanlar atılır.
// Çıktı: tools/program-levels.src.mjs içindeki kampanyanın sonuna eklenen seviye tanımları.
import { loadLevel } from '../web/js/engine.js';
import { runProgram } from '../web/js/program.js';

const DIRS = [[1, 0, 0], [0, 0, 1], [-1, 0, 0], [0, 0, -1]];
const VIEWD = [[1, 1, 1], [-1, 1, 1], [-1, 1, -1], [1, 1, -1]];
const K = (c) => c.join(',');
const add = (a, b) => [a[0] + b[0], a[1] + b[1], a[2] + b[2]];
const mul = (a, k) => [a[0] * k, a[1] * k, a[2] * k];
const UP = [0, 1, 0], DOWN = [0, -1, 0];

function rng(seed) {
  let s = seed >>> 0 || 1;
  const f = () => { s ^= s << 13; s >>>= 0; s ^= s >>> 17; s ^= s << 5; s >>>= 0; return s / 4294967296; };
  f.int = (a, b) => a + Math.floor(f() * (b - a + 1));
  f.pick = (arr) => arr[Math.floor(f() * arr.length)];
  return f;
}

class Fail extends Error {}

class Builder {
  constructor() {
    this.p = [0, 1, 0]; this.d = 0;
    this.blocks = new Map();     // K -> 'b'
    this.stairs = [];
    this.empty = new Set();      // boş kalması gereken hücreler (Robo'nun yolu, baş boşluğu, boşluklar)
    this.cmds = [];
    this.ops = [[]];
    this.view = 0; this.view0 = 0; this.viewTouched = false;
    this.levers = []; this.bridges = []; this.crates = []; this.cranks = []; this.rotators = [];
    this.sliders = []; this.portals = []; this.links = []; this.phantoms = []; this.comps = [];
    this.feat = new Set();
    this.solid(add(this.p, DOWN));
    this.keep(this.p);
  }
  // ---- hücre rezervasyonu ----
  solid(c) {
    const k = K(c);
    if (this.empty.has(k)) throw new Fail('solid on empty ' + k);
    this.blocks.set(k, 'b');
  }
  keep(c) {   // Robo'nun duracağı hücre + baş boşluğu
    for (const q of [c, add(c, UP)]) {
      const k = K(q);
      if (this.blocks.has(k)) throw new Fail('keep on solid ' + k);
      this.empty.add(k);
    }
  }
  hole(c) { const k = K(c); if (this.blocks.has(k)) throw new Fail('hole on solid'); this.empty.add(k); }
  isFree(c) { const k = K(c); return !this.blocks.has(k) && !this.empty.has(k); }
  get fwd() { return DIRS[this.d]; }
  side(s) { return DIRS[(this.d + (s === 'L' ? 3 : 1)) % 4]; }
  pause(ops) { this.cmds.push('W'); this.ops.push(ops); this.feat.add('W'); }
  // ---- hareket ----
  F(n = 1) {
    for (let i = 0; i < n; i++) {
      const q = add(this.p, this.fwd);
      this.solid(add(q, DOWN)); this.keep(q); this.p = q; this.cmds.push('F');
    }
    return this;
  }
  turn(s) { this.d = (this.d + (s === 'L' ? 3 : 1)) % 4; this.cmds.push(s); return this; }
  up() {   // merdivenle bir kat çık
    const q = add(this.p, this.fwd);
    this.solid(q); this.solid(add(q, DOWN));
    this.stairs.push({ p: q, d: this.d });
    const r = add(q, UP); this.keep(r); this.p = r; this.cmds.push('F'); this.feat.add('stair');
    return this;
  }
  down() {   // merdivenle bir kat in (iki adım)
    const q = add(this.p, this.fwd);
    const st = add(q, DOWN);
    this.solid(st); this.stairs.push({ p: st, d: (this.d + 2) % 4 });
    this.keep(q); this.p = q; this.cmds.push('F');
    const r = add(add(q, this.fwd), DOWN);
    this.solid(add(r, DOWN)); this.keep(r); this.p = r; this.cmds.push('F'); this.feat.add('stair');
    return this;
  }
  jumpUp() {
    const q = add(this.p, this.fwd);
    this.solid(q); this.solid(add(q, DOWN));
    const r = add(q, UP); this.keep(r); this.p = r; this.cmds.push('J'); this.feat.add('J');
    return this;
  }
  jumpDown() {
    const q = add(this.p, this.fwd);
    this.hole(q);
    const r = add(q, DOWN); this.solid(add(r, DOWN)); this.keep(r); this.p = r; this.cmds.push('J'); this.feat.add('J');
    return this;
  }
  // ---- mekanizmalar ----
  leverGap(len, s) {   // yanda kol, önde kolla açılan köprü
    const lp = add(this.p, this.side(s));
    if (!this.isFree(lp) || !this.isFree(add(lp, UP))) throw new Fail('lever');
    this.solid(add(lp, DOWN)); this.blocks.set(K(lp), 'b'); this.empty.add(K(add(lp, UP)));
    const id = 'L' + (this.levers.length + 1);
    this.levers.push({ id, p: lp });
    const cells = [];
    for (let i = 1; i <= len; i++) { const c = add(add(this.p, mul(this.fwd, i)), DOWN); this.hole(c); cells.push(c); }
    this.bridges.push({ cells, on: id });
    this.turn(s); this.cmds.push('A'); this.turn(s === 'L' ? 'R' : 'L');
    this._bridgeCells = (this._bridgeCells || []).concat(cells.map(K));
    for (let i = 0; i < len; i++) { const q = add(this.p, this.fwd); this.keep(q); this.p = q; this.cmds.push('F'); }
    this.F(1); this.feat.add('lever');
    return this;
  }
  crateGap() {   // önde kutu, kutunun ardında boşluk: Kullan ile itilen kutu boşluğa düşüp zemin olur
    const c = add(this.p, this.fwd), g = add(c, this.fwd);
    this.solid(add(c, DOWN)); this.keep(c);
    this.hole(add(g, DOWN)); this.solid(add(g, mul(DOWN, 2))); this.keep(g);
    this.crates.push(c);
    this.cmds.push('A', 'F', 'F'); this.p = g; this.feat.add('crate');
    return this;
  }
  crankBridge(s) {   // yandaki çark, önündeki üç blokluk döner köprüyü yola hizalar
    const cp = add(this.p, this.side(s));
    if (!this.isFree(cp)) throw new Fail('crank');
    this.solid(add(cp, DOWN)); this.blocks.set(K(cp), 'b'); this.empty.add(K(add(cp, UP)));
    const f = this.fwd, sd = DIRS[(this.d + 1) % 4];
    const pivot = add(this.p, mul(f, 2));
    const blocks = [add(add(pivot, sd), DOWN), add(pivot, DOWN), add(add(pivot, mul(sd, -1)), DOWN)];
    for (const b of blocks) this.solid(b);
    for (const i of [1, 3]) this.hole(add(add(this.p, mul(f, i)), DOWN));
    const ri = this.rotators.length;
    this.rotators.push({ pivot: [pivot[0], pivot[2]], blocks, rot: 0, fixed: true });
    this.cranks.push({ p: cp, rot: ri, dir: 1 });
    this.turn(s); this.cmds.push('A'); this.turn(s === 'L' ? 'R' : 'L');
    for (let i = 0; i < 3; i++) { const q = add(this.p, f); this.keep(q); this.p = q; this.cmds.push('F'); }
    // dönüşten önceki uç hücreler (blocks[0], blocks[2]) rezerve kalır; toDef onları statik saymaz
    this._rotCells = (this._rotCells || []).concat(blocks.map(K));
    this.F(1); this.feat.add('crank');
    return this;
  }
  ride(s) {   // döner platforma bin, molada çevir: platform Robo'yu yeni yöne taşır
    const f = this.fwd;
    const cells = [add(this.p, f), add(this.p, mul(f, 2)), add(this.p, mul(f, 3))].map(c => add(c, DOWN));
    for (const c of cells) this.solid(c);
    const pivot = add(this.p, mul(f, 2));
    const ri = this.rotators.length;
    this.rotators.push({ pivot: [pivot[0], pivot[2]], blocks: cells, rot: 0, handle: add(pivot, [0, -2, 0]) });
    this.hole(add(pivot, [0, -2, 0]));
    this.keep(add(this.p, f)); this.keep(pivot);
    this.cmds.push('F', 'F'); this.p = pivot;
    const sgn = s === 'L' ? 1 : -1;       // rot +1 Robo'yu sola çevirir
    this.pause([{ t: 'rot', i: ri, s: sgn }]);
    this.d = (this.d + (s === 'L' ? 3 : 1)) % 4;
    const nf = this.fwd;
    const nc = [add(pivot, nf), add(pivot, mul(nf, -1))].map(c => add(c, DOWN));
    for (const c of nc) { if (!this.isFree(c)) throw new Fail('ride rot'); this.hole(add(c, UP)); }
    for (const c of nc) this.blocks.set(K(c), 'b');
    this._rotCells = (this._rotCells || []).concat(nc.map(K));
    // eski uç hücreler dönüşte boşalır; yeni uç hücreler dolar
    this.blocks.delete(K(cells[0])); this.blocks.delete(K(cells[2]));
    this.hole(cells[0]); this.hole(cells[2]);
    const q = add(pivot, nf); this.keep(q); this.p = q; this.cmds.push('F');
    this.F(1); this.feat.add('ride');
    return this;
  }
  lift(h) {   // asansör: üstüne çık, molada h kat yükselt
    const f = this.fwd;
    const sc = add(this.p, f);
    const base = add(sc, DOWN);
    this.hole(base);
    for (let k = 0; k <= h + 1; k++) this.hole(add(sc, mul(UP, k)));
    const si = this.sliders.length;
    this.sliders.push({ blocks: [base], axis: [0, 1, 0], min: 0, max: h, pos: 0 });
    for (let k = 1; k <= h; k++) this.hole(add(base, mul(UP, k)));
    this.cmds.push('F'); this.p = sc;
    this.pause(Array.from({ length: h }, () => ({ t: 'slide', i: si, s: 1 })));
    this.p = add(sc, mul(UP, h));
    this._sliderCol = (this._sliderCol || []).concat([K(base)]);
    this.F(1); this.feat.add('lift');
    return this;
  }
  portal(off) {   // önündeki ışınlayıcı Robo'yu uzaktaki eşine taşır (aynı yönde devam eder)
    const a = add(this.p, this.fwd);
    const b = add(a, off);
    this.solid(add(a, DOWN)); this.keep(a);
    if (!this.isFree(b) || !this.isFree(add(b, DOWN))) throw new Fail('portal');
    this.solid(add(b, DOWN)); this.keep(b);
    this.portals.push({ a, b });
    this.cmds.push('F'); this.p = b; this.feat.add('portal');
    return this;
  }
  needView(v) {
    if (this.view === v) return;
    let diff = ((v - this.view) % 4 + 4) % 4;
    const ops = diff === 3 ? [{ t: 'view', s: -1 }] : Array.from({ length: diff }, () => ({ t: 'view', s: 1 }));
    if (!this.viewTouched && this.cmds.length === 0) this.ops[0].push(...ops);
    else this.pause(ops);
    this.view = v; this.viewTouched = true;
  }
  illusion(v, k) {   // göz yanılması: v açısından bakınca birleşen geçit
    this.needView(v);
    const a = this.p;
    const b = add(add(a, this.fwd), mul(VIEWD[v], k));
    if (!this.isFree(b) || !this.isFree(add(b, DOWN)) || b[1] < -6) throw new Fail('link');
    this.solid(add(b, DOWN)); this.keep(b);
    this.hole(add(a, this.fwd));
    this.links.push({ a, b, d: this.d, view: v });
    this.cmds.push('F'); this.p = b; this.feat.add('link');
    return this;
  }
  phantomGap(len, v) {   // yalnızca v açısında katı hayalet köprü
    this.needView(v);
    const cells = [];
    for (let i = 1; i <= len; i++) { const c = add(add(this.p, mul(this.fwd, i)), DOWN); if (!this.isFree(c)) throw new Fail('ph'); cells.push(c); }
    for (const c of cells) this.empty.add(K(c));   // statik blok konmasın
    this.phantoms.push({ cells, view: v });
    for (let i = 0; i < len; i++) { const q = add(this.p, this.fwd); this.keep(q); this.p = q; this.cmds.push('F'); }
    this.F(1); this.feat.add('phantom');
    return this;
  }
  cap() {   // kondansatör: üstüne basan Robo bir kare ileri + bir kat yukarı fırlar
    const q = add(this.p, this.fwd);
    const cb = add(q, DOWN);
    this.solid(cb); this.keep(q);
    const step = add(q, this.fwd);
    this.solid(step); this.solid(add(step, DOWN));
    const r = add(step, UP); this.keep(r);
    this.comps.push({ p: cb, t: 'cap' });
    this.cmds.push('F'); this.p = r; this.feat.add('cap');
    return this;
  }
  relayGap(len) {   // röle: üstüne basınca köprü belirir
    const q = add(this.p, this.fwd);
    const rb = add(q, DOWN);
    this.solid(rb); this.keep(q);
    const id = 'R' + (this.comps.filter(c => c.t === 'relay').length + 1);
    this.comps.push({ p: rb, t: 'relay', id });
    this.cmds.push('F'); this.p = q;
    const cells = [];
    for (let i = 1; i <= len; i++) { const c = add(add(this.p, mul(this.fwd, i)), DOWN); this.hole(c); cells.push(c); }
    this.bridges.push({ cells, on: id });
    for (let i = 0; i < len; i++) { const n = add(this.p, this.fwd); this.keep(n); this.p = n; this.cmds.push('F'); }
    this.F(1); this.feat.add('relay');
    return this;
  }
  // ---- seviye tanımı ----
  toDef() {
    const skip = new Set([...(this._bridgeCells || []), ...(this._rotCells || []), ...(this._sliderCol || [])]);
    const ph = new Set(this.phantoms.flatMap(p => p.cells.map(K)));
    const rot = new Set(this.rotators.flatMap(r => r.blocks.map(K)));
    const lev = new Set([...this.levers.map(l => K(l.p)), ...this.cranks.map(c => K(c.p))]);
    const boxes = [];
    for (const [k] of this.blocks) {
      if (skip.has(k) || ph.has(k) || rot.has(k) || lev.has(k)) continue;
      const c = k.split(',').map(Number);
      boxes.push([...c, ...c]);
    }
    const st = new Set(this.stairs.map(s => K(s.p)));
    const def = { boxes: boxes.filter(b => !st.has(K(b.slice(0, 3)))), stairs: this.stairs, start: [0, 1, 0], startDir: 0, goal: this.p.slice() };
    if (this.levers.length) { def.levers = this.levers; def.bridges = this.bridges; }
    if (this.crates.length) def.crates = this.crates;
    if (this.rotators.length) def.rotators = this.rotators;
    if (this.cranks.length) def.cranks = this.cranks;
    if (this.sliders.length) def.sliders = this.sliders;
    if (this.portals.length) def.portals = this.portals;
    if (this.links.length) def.links = this.links;
    if (this.phantoms.length) def.phantoms = this.phantoms;
    if (this.comps.length) def.comps = this.comps;
    if (this.bridges.length && !def.bridges) def.bridges = this.bridges;
    if (this.links.length || this.phantoms.length) def.view = this.view0;
    return def;
  }
}

// ---------- sıkıştırma: düz komut listesini F1/F2'ye böl ----------
function bestRepeat(seq, maxLen, avoid = []) {
  let best = null;
  for (let len = 2; len <= maxLen; len++) {
    for (let i = 0; i + len <= seq.length; i++) {
      const pat = seq.slice(i, i + len);
      if (pat.some(c => avoid.includes(c))) continue;
      let occ = 0;
      for (let j = 0; j + len <= seq.length;) {
        if (seq.slice(j, j + len).every((c, t) => c === pat[t])) { occ++; j += len; } else j++;
      }
      const save = occ * (len - 1) - len;
      if (occ >= 2 && save > 0 && (!best || save > best.save || (save === best.save && len > best.pat.length))) best = { pat, save };
    }
  }
  return best;
}
function replace(seq, pat, sym) {
  const out = [];
  for (let j = 0; j < seq.length;) {
    if (j + pat.length <= seq.length && seq.slice(j, j + pat.length).every((c, t) => c === pat[t])) { out.push(sym); j += pat.length; }
    else out.push(seq[j++]);
  }
  return out;
}
export function compress(cmds, { p1Max = 6, p2Max = 5, useP2 = true } = {}) {
  let main = cmds.slice();
  let p1 = [], p2 = [];
  const b1 = bestRepeat(main, p1Max);
  if (b1) { p1 = b1.pat; main = replace(main, p1, '1'); }
  if (useP2) {
    const b2 = bestRepeat(main, p2Max);
    if (b2) { p2 = b2.pat; main = replace(main, p2, '2'); }
  }
  return { main, p1, p2 };
}

// ---------- seviye tamamlama + doğrulama ----------
function cmdsUsed(sol, extra = []) {
  const set = new Set(['F', 'L', 'R', ...extra]);
  for (const k of ['main', 'p1', 'p2']) for (const s of sol[k] || []) { const c = s.includes(':') ? s.split(':')[1] : s; set.add(c); }
  const order = ['F', 'L', 'R', 'J', 'A', 'W', '1', '2'];
  return order.filter(c => set.has(c));
}
function verify(def) {
  const d = JSON.parse(JSON.stringify(def));
  try {
    const L = loadLevel(d);
    const r = runProgram(L, d.solution, d.solution.ops || []);
    if (r.result !== 'win') return false;
    if ((d.solution.ops || []).some(o => o && o.length)) {
      let r2; try { r2 = runProgram(loadLevel(JSON.parse(JSON.stringify(def))), d.solution, []); } catch (e) { r2 = { result: 'err' }; }
      if (r2.result === 'win') return false;
    }
    if (d.starter) {
      let r3; try { r3 = runProgram(loadLevel(JSON.parse(JSON.stringify(def))), d.starter, []); } catch (e) { r3 = { result: 'err' }; }
      if (r3.result === 'win') return false;
    }
    return true;
  } catch (e) { return false; }
}

// Plan: Builder üzerinde çalışan adım listesi. Rastgele denemelerden ilk doğrulananı döndürür.
function make(seed, planFn, finish) {
  for (let attempt = 0; attempt < 400; attempt++) {
    const R = rng(seed * 7919 + attempt * 104729 + 17);
    const b = new Builder();
    try { planFn(b, R); } catch (e) { if (e instanceof Fail) continue; throw e; }
    const def = finish(b, R);
    if (def && verify(def)) return def;
  }
  throw new Error('üretilemedi: tohum ' + seed);
}
function slotsFor(sol, slack = 1) {
  return { main: sol.main.length + slack, p1: (sol.p1 || []).length, p2: (sol.p2 || []).length };
}
const finishCompressed = (opts = {}) => (b) => {
  const c = compress(b.cmds, opts);
  const def = b.toDef();
  def.solution = { main: c.main };
  if (c.p1.length) def.solution.p1 = c.p1;
  if (c.p2.length) def.solution.p2 = c.p2;
  if (b.ops.some(o => o.length)) def.solution.ops = b.ops;
  def.cmds = cmdsUsed(def.solution, opts.extraCmds || []);
  def.slots = slotsFor(def.solution, opts.slack ?? 1);
  if (opts.requireFn && !c.p1.length) return null;
  return def;
};

// ---------- rastgele yol parçaları ----------
function walkSegs(b, R, n, { turns = true, stairs = 0, jumps = 0, mech = [] } = {}) {
  const menu = ['run', 'run'];
  if (turns) menu.push('turn', 'turn');
  for (let i = 0; i < stairs; i++) menu.push('up', 'down');
  for (let i = 0; i < jumps; i++) menu.push('jup', 'jdown');
  for (const m of mech) menu.push(m);
  for (let i = 0; i < n; i++) {
    const s = R.pick(menu);
    if (s === 'run') b.F(R.int(1, 3));
    else if (s === 'turn') { b.turn(R() < 0.5 ? 'L' : 'R'); b.F(R.int(1, 2)); }
    else if (s === 'up') b.up();
    else if (s === 'down') b.down();
    else if (s === 'jup') b.jumpUp();
    else if (s === 'jdown') b.jumpDown();
    else segMech(b, R, s);
  }
}
function segMech(b, R, s) {
  if (s === 'lever') b.leverGap(R.int(1, 2), R() < 0.5 ? 'L' : 'R');
  else if (s === 'crate') b.crateGap();
  else if (s === 'crank') b.crankBridge(R() < 0.5 ? 'L' : 'R');
  else if (s === 'ride') b.ride(R() < 0.5 ? 'L' : 'R');
  else if (s === 'lift') b.lift(R.int(1, 3));
  else if (s === 'portal') b.portal([R.int(-2, 2) || 3, R.int(-2, 2), R.pick([-5, -4, 4, 5])]);
  else if (s === 'link') b.illusion((b.view + R.int(1, 3)) % 4, R.pick([1, 2, -1]));
  else if (s === 'cap') b.cap();
  else if (s === 'relay') b.relayGap(R.int(1, 2));
  else if (s === 'phantom') b.phantomGap(R.int(1, 3), (b.view + R.int(1, 3)) % 4);
}

// Desen tekrarı (özyinelemeli döngü): F1 = desen + F1
function patternLevel(seed, patLen, reps, kinds) {
  return make(seed, (b, R) => {
    const pat = [];
    for (let i = 0; i < patLen; i++) pat.push(R.pick(kinds));
    if (!pat.some(k => k === 'turnL' || k === 'turnR')) pat.push(R() < 0.5 ? 'turnL' : 'turnR');
    if (pat.filter(k => k.startsWith('turn')).length >= pat.length - 1) pat.unshift('F');
    b._pat = pat;
    for (let r = 0; r < reps; r++) for (const k of pat) {
      if (k === 'F') b.F(1); else if (k === 'turnL') b.turn('L'); else if (k === 'turnR') b.turn('R');
      else if (k === 'up') b.up(); else if (k === 'J') b.jumpUp(); else if (k === 'Jd') b.jumpDown();
    }
  }, (b) => {
    const cmds = b.cmds.slice();
    const per = cmds.length / reps;
    const p = cmds.slice(0, per);
    // son adım bir dönüşse hedef dönüşten önceki karede biter
    const def = b.toDef();
    def.solution = { main: ['1'], p1: [...p, '1'] };
    def.cmds = cmdsUsed(def.solution);
    def.slots = { main: 2, p1: p.length + 1, p2: 0 };
    return def;
  });
}

// Duvar izleyici labirent: kesişmeyen rastgele yol, izleyici programla çözülür
function mazeLevel(seed, len, follower, opts = {}) {
  return make(seed, (b, R) => {
    let steps = 0;
    while (steps < len) {
      const turn = R();
      if (steps > 0 && turn < 0.45) {
        const s = opts.only || (R() < 0.5 ? 'L' : 'R');
        b.turn(s);
      }
      const r = R.int(1, 3);
      for (let i = 0; i < r && steps < len; i++) {
        const k = R();
        if (opts.stairs && k < 0.15) b.up();
        else if (opts.stairs && k < 0.25 && steps > 2) b.down();
        else if (opts.crates && k > 0.86) b.crateGap();
        else b.F(1);
        steps++;
      }
    }
  }, (b) => {
    const def = b.toDef();
    def.solution = { main: ['1'], p1: follower };
    def.conds = true;
    def.cmds = cmdsUsed(def.solution, ['L', 'R']);
    def.slots = { main: 2, p1: follower.length, p2: 0 };
    return def;
  });
}

// Koridor genelleme: "önü açık oldukça yürü" + dönüşler
function corridorLevel(seed, n) {
  return make(seed, (b, R) => {
    b._turns = [];
    for (let i = 0; i < n; i++) {
      const L = R.int(2, 5);
      for (let k = 0; k < L; k++) { if (R() < 0.18 && k > 0) b.up(); else b.F(1); }
      if (i < n - 1) { const s = R() < 0.5 ? 'L' : 'R'; b._turns.push(s); b.turn(s); }
    }
  }, (b) => {
    const def = b.toDef();
    const main = [];
    b._turns.forEach(s => main.push('1', s));
    main.push('1');
    def.solution = { main, p1: ['o:F', 'o:1'] };
    def.conds = true;
    def.cmds = ['F', 'L', 'R', '1'];
    def.slots = { main: main.length, p1: 2, p2: 0 };
    return def;
  });
}

// Hata ayıklama: üretilmiş bir seviyenin çözümüne hata sok
function withBug(def, R) {
  const sol = def.solution;
  const rows = ['main', 'p1', 'p2'].filter(k => (sol[k] || []).length);
  for (let t = 0; t < 60; t++) {
    const st = JSON.parse(JSON.stringify({ main: sol.main, p1: sol.p1 || [], p2: sol.p2 || [] }));
    const row = R.pick(rows);
    const arr = st[row];
    const i = R.int(0, arr.length - 1);
    const kind = R.int(0, 2);
    if (kind === 0 && (arr[i] === 'L' || arr[i] === 'R')) arr[i] = arr[i] === 'L' ? 'R' : 'L';
    else if (kind === 1 && arr.length > 1 && i + 1 < arr.length && arr[i] !== arr[i + 1]) { const x = arr[i]; arr[i] = arr[i + 1]; arr[i + 1] = x; }
    else if (kind === 2 && arr[i] === 'F' && def.cmds.includes('J')) arr[i] = 'J';
    else continue;
    const d2 = { ...def, starter: {} };
    for (const k of ['main', 'p1', 'p2']) if (st[k].length) d2.starter[k] = st[k];
    if (verify(d2)) return d2;
  }
  return null;
}

// =====================================================================
// Bölüm tanımları
const NAMES = {
  zaman: ['Kum Saati', 'Gölge Çubuğu', 'Öğle Vakti', 'Dönen Kadran', 'Asansör Ritmi', 'İkindi Kulesi', 'Saat Kulesi', 'Zaman Ayarı', 'Gece Yarısı', 'Sonsuz Çark'],
  paralel: ['Ayna Yolu', 'İkiz Kapılar', 'Yıldız Haritası', 'Gözlem Kubbesi', 'Mercek', 'Paralel Evren', 'Kuyruklu Yıldız', 'Takımyıldız', 'Tutulma', 'Teleskop'],
  kule: ['Temel Taşı', 'Kaldıraç', 'Kutu Yolu', 'Çarklar', 'Dişli Köprü', 'Kinetik', 'Denge', 'Mekanizma', 'İnşa', 'Heykel'],
  hata: ['Ters Dönüş', 'Kayıp Adım', 'Yanlış Sıra', 'Böcek Avı', 'Kırık Döngü', 'Gizli Hata', 'Röntgen', 'Test Et', 'Hata Ayıkla', 'Temiz Kod'],
  optim: ['Tek Taş', 'Az Çoktur', 'Desen', 'Zen', 'Akış', 'Labirent Bilgesi', 'Taş Bahçesi', 'Sade Yol', 'Duvar Takipçisi', 'Sonsuz Desen'],
  final: ['Başlangıç', 'Yükseliş', 'Kavşak', 'Fırtına Kulesi', 'Kozmos', 'Porselen', 'Sınav', 'Ustalık', 'Zirve', 'Kayıp Kule'],
};
const INTROS = {
  'Zamanlama': { title: 'Zamanlama', text: 'Bu bölümde her şey <b>doğru anda</b> olmalı. Robo döner platformlara biner, asansörlerle yükselir; sen de <b>Mola</b> blokları sırasında dünyayı çevirirsin. Molayı ne zaman vereceğin, programın kendisi kadar önemli!' },
  'Paralel Yollar': { title: 'Paralel yollar', text: 'Işınlayıcılar, göz yanılması geçitleri ve hayalet bloklar aynı dünyada birden çok yol açar. Doğru açıyı doğru anda seç: bazen başlamadan önce, bazen bir <b>Mola</b> sırasında.' },
  'Kuleyi Kodlamak': { title: 'Kuleyi kodlamak', text: 'Kollar köprü açar, kutular boşluk doldurur, çarklar köprüyü döndürür. Bu bölümde çözümler uzun ama hep <b>tekrar eden desenler</b> var: onları F1 ve F2\'ye taşı, yoksa program sığmaz!' },
  'Hata Avcısı': { title: 'Hata avcısı', text: 'Nova her seviyeye <b>neredeyse doğru</b> bir program hazırladı; her birinde tek bir hata var: yanlış yöne dönüş, yeri değişmiş iki blok ya da yanlış komut. Çalıştır, analizi oku, hatayı bul ve düzelt.', ai: true },
  'Optimizasyon': { title: 'Optimizasyon', text: 'En iyi program en kısa olanıdır. Bu bölümde yer çok az: ya bir desen bulup <b>kendini çağıran</b> bir fonksiyon yazacaksın, ya da her labirentte çalışan <b>genel bir algoritma</b> (koşullu yol izleyici).' },
  'Büyük Final': { title: 'Büyük final', text: 'Öğrendiğin her şey bir arada: fonksiyonlar, koşullar, mekanizmalar, molalar, ışınlayıcılar ve göz yanılmaları. Kayıp kuleleri tamamlamak için son on sınav!' },
};

const FOLLOW_R = ['o:F', 'x:R', 'x:L', 'x:L', '1'];
const FOLLOW_L = ['o:F', 'x:L', 'x:R', 'x:R', '1'];
const AGENT = ['o:F', 'x:A', 'x:R', 'x:L', 'x:L', '1'];

function hintFor(def) {
  const s = def.solution;
  const nm = { F: 'İleri', L: 'Sola', R: 'Sağa', J: 'Zıpla', A: 'Kullan', W: 'Mola', 1: 'F1', 2: 'F2' };
  const show = (arr) => arr.map(x => { const [k, c] = x.includes(':') ? x.split(':') : ['', x]; return (k === 'o' ? '[yeşil ' : k === 'x' ? '[turuncu ' : '') + nm[c] + (k ? ']' : ''); }).join(', ');
  const parts = [];
  if (s.p1 && s.p1.length) parts.push('F1: ' + show(s.p1) + '.');
  if (s.p2 && s.p2.length) parts.push('F2 deseni ' + s.p2.length + ' blok.');
  const ops = s.ops || [];
  const opText = (o) => o.t === 'rot' ? 'döner platformu çevir' : o.t === 'slide' ? 'asansörü kaldır' : 'kamerayı çevir';
  if (ops[0] && ops[0].length) parts.push('Başlamadan önce ' + opText(ops[0][0]) + '.');
  const pauses = ops.slice(1).filter(o => o && o.length).map(o => opText(o[0]));
  if (pauses.length) parts.push('Molalarda: ' + [...new Set(pauses)].join(', ') + '.');
  if (def.starter) parts.unshift('Hata tek bir yerde.');
  return parts.join(' ') || 'Yolu kare kare say.';
}

export function generate() {
  const out = [];
  const push = (chapter, name, palette, def) => {
    const d = { chapter, name, palette, ...def };
    d.hint = hintFor(d);
    if (!out.some(l => l.chapter === chapter) && INTROS[chapter]) d.intro = INTROS[chapter];
    // anahtar sırasını sabitle
    out.push(d);
  };
  // --- Bölüm 10: Zamanlama (döner platform sürüşü, asansör, molalar) ---
  {
    const ch = 'Zamanlama';
    const plans = [
      [['ride'], 2], [['lift'], 2], [['ride', 'lift'], 3], [['ride', 'ride'], 3], [['lift', 'lift'], 4],
      [['ride', 'lift', 'ride'], 4], [['ride', 'ride', 'lift'], 5], [['lift', 'ride', 'lift'], 5], [['ride', 'lift', 'ride', 'lift'], 6], [['ride', 'ride', 'lift', 'ride'], 6],
    ];
    plans.forEach(([mech, n], i) => {
      const def = make(1000 + i, (b, R) => {
        b.F(R.int(1, 2));
        for (const m of mech) { walkSegs(b, R, R.int(0, Math.max(1, n - 3)), { stairs: i > 4 ? 1 : 0 }); segMech(b, R, m); }
        walkSegs(b, R, R.int(1, 2));
      }, finishCompressed({ slack: 1 }));
      push(ch, NAMES.zaman[i], (i + 2) % 16, def);
    });
  }
  // --- Bölüm 11: Paralel Yollar (ışınlayıcı, göz yanılması, hayalet blok) ---
  {
    const ch = 'Paralel Yollar';
    const plans = [['portal'], ['link'], ['phantom'], ['portal', 'portal'], ['link', 'phantom'], ['portal', 'link'], ['phantom', 'phantom'], ['portal', 'phantom', 'link'], ['link', 'portal', 'phantom'], ['phantom', 'link', 'portal', 'link']];
    plans.forEach((mech, i) => {
      const def = make(2000 + i, (b, R) => {
        b.F(R.int(1, 2));
        for (const m of mech) { walkSegs(b, R, R.int(0, 2), { stairs: i > 3 ? 1 : 0 }); segMech(b, R, m); }
        walkSegs(b, R, R.int(1, 2));
      }, finishCompressed({ slack: 1 }));
      push(ch, NAMES.paralel[i], (i + 6) % 16, def);
    });
  }
  // --- Bölüm 12: Kuleyi Kodlamak (kol, kutu, çark; uzun programlar F1/F2 ile sıkıştırılır) ---
  {
    const ch = 'Kuleyi Kodlamak';
    const plans = [
      ['lever', 'lever'], ['crate', 'cap', 'crate'], ['crank', 'crank'], ['lever', 'crate', 'lever'], ['crank', 'relay', 'crank'],
      ['crate', 'crate', 'crate'], ['lever', 'crank', 'crate', 'lever'], ['cap', 'crank', 'relay', 'cap'], ['crate', 'lever', 'crate', 'lever'], ['crank', 'crate', 'lever', 'crank', 'crate'],
    ];
    plans.forEach((mech, i) => {
      const def = make(3000 + i, (b, R) => {
        b.F(R.int(1, 2));
        for (const m of mech) { segMech(b, R, m); walkSegs(b, R, R.int(0, 2), { stairs: i > 5 ? 1 : 0, jumps: i > 2 ? 1 : 0 }); }
      }, finishCompressed({ slack: 1, requireFn: true }));
      push(ch, NAMES.kule[i], (i + 10) % 16, def);
    });
  }
  // --- Bölüm 13: Hata Avcısı (hazır hatalı programlar) ---
  {
    const ch = 'Hata Avcısı';
    for (let i = 0; i < 10; i++) {
      const mechs = [[], ['lever'], ['crate'], [], ['crank'], ['ride'], ['lift'], ['portal'], ['lever', 'crate'], ['ride', 'crank']][i];
      let def = null;
      for (let s = 0; s < 40 && !def; s++) {
        const base = make(4000 + i * 50 + s, (b, R) => {
          b.F(R.int(1, 2));
          walkSegs(b, R, 3 + Math.floor(i / 3), { stairs: 1, jumps: i > 3 ? 1 : 0 });
          for (const m of mechs) { segMech(b, R, m); walkSegs(b, R, R.int(1, 2)); }
        }, finishCompressed({ slack: 0 }));
        def = withBug(base, rng(4000 + i * 50 + s));
      }
      push(ch, NAMES.hata[i], (i + 3) % 16, def);
    }
  }
  // --- Bölüm 14: Optimizasyon (özyinelemeli desenler, labirent algoritmaları) ---
  {
    const ch = 'Optimizasyon';
    out.push(...[]);
    const lv = [
      patternLevel(5000, 2, 5, ['F', 'turnL', 'turnR', 'up']),
      corridorLevel(5001, 4),
      mazeLevel(5002, 16, FOLLOW_R),
      patternLevel(5003, 3, 4, ['F', 'turnL', 'turnR', 'J', 'up']),
      mazeLevel(5004, 20, FOLLOW_L, { stairs: true }),
      corridorLevel(5005, 6),
      patternLevel(5006, 4, 4, ['F', 'F', 'turnL', 'turnR', 'J', 'up']),
      mazeLevel(5007, 24, FOLLOW_R, { stairs: true }),
      mazeLevel(5008, 22, AGENT, { crates: true }),
      patternLevel(5009, 5, 4, ['F', 'turnL', 'turnR', 'J', 'up', 'Jd']),
    ];
    lv.forEach((def, i) => push(ch, NAMES.optim[i], (i + 12) % 16, def));
  }
  // --- Bölüm 15: Büyük Final (her şey bir arada) ---
  {
    const ch = 'Büyük Final';
    const plans = [
      ['lever', 'ride'], ['crate', 'portal', 'lift'], ['crank', 'cap', 'link'], ['phantom', 'lever', 'ride'], ['lift', 'portal', 'crate'],
      ['link', 'crank', 'phantom'], ['ride', 'relay', 'portal', 'lift'], ['crate', 'phantom', 'crank', 'link'], ['lift', 'ride', 'relay', 'portal', 'cap'], ['crank', 'link', 'ride', 'phantom', 'lever', 'lift'],
    ];
    plans.forEach((mech, i) => {
      const def = make(6000 + i, (b, R) => {
        b.F(R.int(1, 2));
        for (const m of mech) { walkSegs(b, R, R.int(1, 2), { stairs: 1, jumps: 1 }); segMech(b, R, m); }
        walkSegs(b, R, R.int(1, 2));
      }, finishCompressed({ slack: 1 }));
      push(ch, NAMES.final[i], (i + 1) % 16, def);
    });
  }
  return out;
}
