// Kayıp Kuleler — deterministik ızgara fizik motoru (render'dan bağımsız).
// Aynı kurallar Godot sürümünde godot/scripts/logic.gd içinde birebir uygulanır.
export const DIRS = [[1, 0, 0], [0, 0, 1], [-1, 0, 0], [0, 0, -1]];
const K = (x, y, z) => x + ',' + y + ',' + z;
const KP = (p) => p[0] + ',' + p[1] + ',' + p[2];
const add = (a, b) => [a[0] + b[0], a[1] + b[1], a[2] + b[2]];
const eq = (a, b) => a && b && a[0] === b[0] && a[1] === b[1] && a[2] === b[2];
const UP = [0, 1, 0], DOWN = [0, -1, 0];

export function loadLevel(def) {
  const L = { def, statics: new Map(), minY: 0 };
  let minY = 1e9;
  const put = (x, y, z, v) => { L.statics.set(K(x, y, z), v); if (y < minY) minY = y; };
  for (const b of def.boxes || []) {
    const [x1, y1, z1, x2, y2, z2] = b;
    for (let x = Math.min(x1, x2); x <= Math.max(x1, x2); x++)
      for (let y = Math.min(y1, y2); y <= Math.max(y1, y2); y++)
        for (let z = Math.min(z1, z2); z <= Math.max(z1, z2); z++) put(x, y, z, { t: 'b' });
  }
  for (const b of def.blocks || []) put(b[0], b[1], b[2], { t: 'b' });
  for (const s of def.stairs || []) put(s.p[0], s.p[1], s.p[2], { t: 's', d: s.d });
  for (const r of def.remove || []) L.statics.delete(KP(r));
  (def.scales || []).forEach(sc => { def.sliders[sc.a].scale = true; def.sliders[sc.b].scale = true; });
  L.minY = minY === 1e9 ? 0 : minY;
  L.killY = L.minY - 3;
  return L;
}

export function initialState(L) {
  const d = L.def;
  const s = {
    p: d.start.slice(), f: d.startDir || 0,
    crates: (d.crates || []).map(c => c.slice()),
    balls: (d.balls || []).map(b => ({ p: b.slice(), d: -1 })),
    levers: (d.levers || []).map(l => !!l.on),
    rots: (d.rotators || []).map(r => r.rot || 0),
    slides: (d.sliders || []).map(s => s.pos || 0),
    bridges: (d.bridges || []).map(b => false),
    crumbles: (d.crumbles || []).map(() => 0),
    view: d.view || 0, dead: false, moves: 0,
  };
  settle(L, s, null);
  return s;
}

export function cloneState(s) {
  return {
    p: s.p.slice(), f: s.f,
    crates: s.crates.map(c => c && c.slice()),
    balls: s.balls.map(b => b && { p: b.p.slice(), d: b.d }),
    levers: s.levers.slice(), rots: s.rots.slice(), slides: s.slides.slice(),
    bridges: s.bridges.slice(), crumbles: s.crumbles.slice(),
    view: s.view, dead: s.dead, moves: s.moves,
  };
}

export function stateKey(s) {
  return KP(s.p) + '|' + s.crates.map(c => c ? KP(c) : 'x').join(';') + '|' +
    s.balls.map(b => b ? KP(b.p) : 'x').join(';') + '|' + s.levers.map(Number).join('') + '|' +
    s.rots.join('') + '|' + s.slides.join(',') + '|' + s.bridges.map(Number).join('') + '|' +
    s.crumbles.join('') + '|' + s.view;
}

// ---- dinamik blok konumları ----
export function rotatorCells(L, i, rot) {
  const r = L.def.rotators[i];
  const [px, pz] = r.pivot;
  return r.blocks.map(b => {
    let dx = b[0] - px, dz = b[2] - pz;
    for (let k = 0; k < ((rot % 4) + 4) % 4; k++) { const t = dx; dx = dz; dz = -t; }
    return [px + dx, b[1], pz + dz];
  });
}
export function rotPoint(pivot, p, steps) {
  let dx = p[0] - pivot[0], dz = p[2] - pivot[1];
  for (let k = 0; k < ((steps % 4) + 4) % 4; k++) { const t = dx; dx = dz; dz = -t; }
  return [pivot[0] + dx, p[1], pivot[1] + dz];
}
export function sliderCells(L, i, pos) {
  const s = L.def.sliders[i];
  return s.blocks.map(b => [b[0] + s.axis[0] * pos, b[1] + s.axis[1] * pos, b[2] + s.axis[2] * pos]);
}

// Dünya: katı hücreler haritası (statik + dinamik), varlıklar haritası
export function buildWorld(L, s, skip) {
  const solid = new Map();
  for (const [k, v] of L.statics) solid.set(k, v);
  const d = L.def;
  (d.bridges || []).forEach((b, i) => { if (s.bridges[i]) for (const c of b.cells) solid.set(KP(c), { t: 'br', i }); });
  (d.rotators || []).forEach((r, i) => { if (!(skip && skip.rot === i)) for (const c of rotatorCells(L, i, s.rots[i])) solid.set(KP(c), { t: 'rot', i }); });
  (d.sliders || []).forEach((r, i) => { if (!(skip && skip.slide === i)) for (const c of sliderCells(L, i, s.slides[i])) solid.set(KP(c), { t: 'sl', i }); });
  (d.crumbles || []).forEach((c, i) => { if (!s.crumbles[i]) solid.set(KP(c), { t: 'cr', i }); });
  (d.levers || []).forEach((l, i) => solid.set(KP(l.p), { t: 'lv', i }));
  const ents = new Map();
  if (!s.dead) ents.set(KP(s.p), { k: 'p' });
  s.crates.forEach((c, i) => { if (c) ents.set(KP(c), { k: 'c', i }); });
  s.balls.forEach((b, i) => { if (b) ents.set(KP(b.p), { k: 'b', i }); });
  return { solid, ents };
}

const supported = (W, p) => { const k = K(p[0], p[1] - 1, p[2]); return W.solid.has(k) || W.ents.has(k); };
const free = (W, p) => !W.solid.has(KP(p)) && !W.ents.has(KP(p));

function signals(L, s, W) {
  const sig = {};
  (L.def.plates || []).forEach(pl => { sig[pl.id] = (sig[pl.id] || false) || W.ents.has(KP(pl.p)); });
  (L.def.levers || []).forEach((lv, i) => { sig[lv.id] = s.levers[i]; });
  return sig;
}
function evalSig(sig, expr) {
  if (expr == null) return false;
  if (Array.isArray(expr)) return expr.every(e => evalSig(sig, e));
  if (expr[0] === '!') return !sig[expr.slice(1)];
  return !!sig[expr];
}
export function currentSignals(L, s) { return signals(L, s, buildWorld(L, s)); }
export function evalSignal(sig, expr) { return evalSig(sig, expr); }

function getEnt(s, e) { return e.k === 'p' ? s.p : e.k === 'c' ? s.crates[e.i] : s.balls[e.i].p; }
function setEnt(s, e, p) { if (e.k === 'p') s.p = p; else if (e.k === 'c') s.crates[e.i] = p; else s.balls[e.i].p = p; }

// Platform hücrelerinin üstünde duran (ve üst üste yığılmış) varlıklar
function carried(W, cells) {
  const out = []; const seen = new Set();
  let frontier = cells.map(c => [c[0], c[1] + 1, c[2]]);
  while (frontier.length) {
    const nf = [];
    for (const p of frontier) {
      const k = KP(p);
      if (seen.has(k)) continue;
      const e = W.ents.get(k);
      if (e) { seen.add(k); out.push({ e, p }); nf.push([p[0], p[1] + 1, p[2]]); }
    }
    frontier = nf;
  }
  return out;
}

// Platformu taşı: newCells ve varlık dönüşümü f. Başarılıysa true.
function movePlatform(L, s, skip, oldCells, newCells, f, dirTurn) {
  const W = buildWorld(L, s, skip);
  const car = carried(W, oldCells);
  const carKeys = new Set(car.map(c => KP(c.p)));
  const newSet = new Set(newCells.map(KP));
  for (const c of newCells) {
    const k = KP(c);
    if (W.solid.has(k)) return false;
    if (W.ents.has(k) && !carKeys.has(k)) return false;
  }
  const moved = car.map(c => ({ e: c.e, np: f(c.p) }));
  for (const m of moved) {
    const k = KP(m.np);
    if (W.solid.has(k) || newSet.has(k)) return false;
    if (W.ents.has(k) && !carKeys.has(k)) return false;
  }
  for (const m of moved) { setEnt(s, m.e, m.np); if (m.e.k === 'p' && dirTurn) s.f = (s.f + dirTurn + 4) % 4; }
  return true;
}

function tryRotate(L, s, i, dir) {
  const r = L.def.rotators[i];
  const oldC = rotatorCells(L, i, s.rots[i]);
  const newC = rotatorCells(L, i, s.rots[i] + dir);
  const ok = movePlatform(L, s, { rot: i }, oldC, newC, p => rotPoint(r.pivot, p, dir), dir > 0 ? 3 : 1);
  if (ok) s.rots[i] = ((s.rots[i] + dir) % 4 + 4) % 4;
  return ok;
}
function trySlide(L, s, i, dir) {
  const sl = L.def.sliders[i];
  const np = s.slides[i] + dir;
  if (np < sl.min || np > sl.max) return false;
  const a = sl.axis.map(v => v * dir);
  const ok = movePlatform(L, s, { slide: i }, sliderCells(L, i, s.slides[i]), sliderCells(L, i, np), p => add(p, a), 0);
  if (ok) s.slides[i] = np;
  return ok;
}

function weightOn(L, s, i) {
  const W = buildWorld(L, s);
  return carried(W, sliderCells(L, i, s.slides[i])).length;
}

// Yerçekimi, top yuvarlanması, köprüler, sürülen platformlar — kararlı olana kadar tik tik.
function settle(L, s, frames) {
  const d = L.def;
  for (let tick = 0; tick < 200; tick++) {
    let changed = false;
    let W = buildWorld(L, s);
    const sig = signals(L, s, W);
    // köprüler / kapılar
    (d.bridges || []).forEach((b, i) => {
      const want = evalSig(sig, b.on);
      if (want && !s.bridges[i]) {
        if (b.cells.every(c => !W.ents.has(KP(c)))) { s.bridges[i] = true; changed = true; }
      } else if (!want && s.bridges[i]) { s.bridges[i] = false; changed = true; }
    });
    // sürülen kaydırıcılar (asansör) ve teraziler
    (d.sliders || []).forEach((sl, i) => {
      let target = null;
      if (sl.on != null) target = evalSig(sig, sl.on) ? sl.max : sl.min;
      if (target != null && target !== s.slides[i]) {
        if (trySlide(L, s, i, target > s.slides[i] ? 1 : -1)) changed = true;
      }
    });
    (d.scales || []).forEach(sc => {
      const wa = weightOn(L, s, sc.a), wb = weightOn(L, s, sc.b);
      const sg = Math.sign(wa - wb);
      const ta = -sg, tb = sg;
      if (s.slides[sc.a] !== ta || s.slides[sc.b] !== tb) {
        // iki kefe birlikte hareket eder
        const da = Math.sign(ta - s.slides[sc.a]), db = Math.sign(tb - s.slides[sc.b]);
        const backup = cloneState(s);
        let ok = true;
        if (da) ok = trySlide(L, s, sc.a, da);
        if (ok && db) ok = trySlide(L, s, sc.b, db);
        if (ok) changed = true; else Object.assign(s, backup);
      }
    });
    W = buildWorld(L, s);
    // yerçekimi + yuvarlanma (alttan üste)
    const ents = [];
    if (!s.dead) ents.push({ k: 'p' });
    s.crates.forEach((c, i) => c && ents.push({ k: 'c', i }));
    s.balls.forEach((b, i) => b && ents.push({ k: 'b', i }));
    ents.sort((a, b) => getEnt(s, a)[1] - getEnt(s, b)[1]);
    for (const e of ents) {
      const p = getEnt(s, e);
      if (!supported(W, p)) {
        const np = add(p, DOWN);
        W.ents.delete(KP(p));
        if (np[1] < L.killY) {
          if (e.k === 'p') s.dead = true; else if (e.k === 'c') s.crates[e.i] = null; else s.balls[e.i] = null;
        } else { setEnt(s, e, np); W.ents.set(KP(np), e); }
        changed = true;
      } else if (e.k === 'b' && s.balls[e.i].d >= 0) {
        const b = s.balls[e.i];
        const np = add(p, DIRS[b.d]);
        const sv = W.solid.get(KP(np));
        if (!sv && !W.ents.has(KP(np))) {
          W.ents.delete(KP(p)); b.p = np; W.ents.set(KP(np), e); changed = true;
        } else {
          if (sv && sv.t === 'lv') { s.levers[sv.i] = !s.levers[sv.i]; }
          b.d = -1; changed = true;
        }
      }
    }
    if (!changed) return;
    if (frames) frames.push(cloneState(s));
  }
}

// Saf yürüme hedefi (itme/kol yok). Yol bulma ve hareket için.
export function walkTarget(L, s, W, P, d) {
  const dv = DIRS[d];
  const Q = add(P, dv);
  for (const ln of L.def.links || []) {
    if (ln.view !== s.view) continue;
    if (eq(P, ln.a) && d === ln.d && free(W, ln.b) && supported(W, ln.b)) return ln.b.slice();
    if (eq(P, ln.b) && d === (ln.d + 2) % 4 && free(W, ln.a) && supported(W, ln.a)) return ln.a.slice();
  }
  const qs = W.solid.get(KP(Q));
  if (!qs && !W.ents.has(KP(Q))) {
    if (supported(W, Q)) return Q;
    const below = W.solid.get(K(P[0], P[1] - 1, P[2]));
    const Q2 = add(Q, DOWN);
    if (below && below.t === 's' && d === (below.d + 2) % 4 && free(W, Q2) && supported(W, Q2)) return Q2;
    return null;
  }
  if (qs && qs.t === 's' && qs.d === d) {
    const Q2 = add(Q, UP);
    if (free(W, Q2)) return Q2;
  }
  return null;
}

// Eylemler: {t:'move',d} {t:'rot',i,s} {t:'slide',i,s} {t:'view',s}
export function step(L, s0, a) {
  if (s0.dead) return { ok: false };
  const s = cloneState(s0);
  const frames = [];
  if (a.t === 'move') {
    const W = buildWorld(L, s);
    const P = s.p; const d = a.d; const Q = add(P, DIRS[d]);
    s.f = d;
    const e = W.ents.get(KP(Q));
    const sv = W.solid.get(KP(Q));
    let moved = false;
    if (e && e.k === 'c') {
      const C = add(Q, DIRS[d]);
      if (!free(W, C)) return { ok: false };
      s.crates[e.i] = C; s.p = Q; moved = true;
      if (!supported(buildWorld(L, s), Q)) { /* oyuncu altındaki kutuyu ittiyse */ }
    } else if (e && e.k === 'b') {
      const C = add(Q, DIRS[d]);
      if (!free(W, C)) {
        const cv = W.solid.get(KP(C));
        if (cv && cv.t === 'lv') { s.levers[cv.i] = !s.levers[cv.i]; }
        else return { ok: false };
      } else s.balls[e.i].d = d;
    } else if (sv && sv.t === 'lv') {
      s.levers[sv.i] = !s.levers[sv.i];
    } else {
      const T = walkTarget(L, s, W, P, d);
      if (!T) return { ok: false };
      s.p = T; moved = true;
    }
    if (moved) {
      // çöken zemin: oyuncu üstünden ayrılınca düşer
      const below = W.solid.get(K(P[0], P[1] - 1, P[2]));
      if (below && below.t === 'cr' && !eq(s.p, P)) s.crumbles[below.i] = 1;
    }
  } else if (a.t === 'rot') {
    if (!tryRotate(L, s, a.i, a.s)) return { ok: false };
  } else if (a.t === 'slide') {
    const sl = L.def.sliders[a.i];
    if (!isManual(sl)) return { ok: false };
    if (!trySlide(L, s, a.i, a.s)) return { ok: false };
  } else if (a.t === 'view') {
    s.view = ((s.view + a.s) % 4 + 4) % 4;
    return { ok: true, state: s, frames: [cloneState(s)] };
  } else return { ok: false };
  s.moves++;
  frames.push(cloneState(s));
  settle(L, s, frames);
  return { ok: true, state: s, frames };
}

export function isManual(sl) { return sl.on == null && !sl.scale; }

export function isWin(L, s) { return !s.dead && eq(s.p, L.def.goal); }

// Oyuncunun yürüyerek ulaşabileceği hücreler için BFS yol bulma
export function findPath(L, s, target) {
  const W = buildWorld(L, s);
  W.ents.delete(KP(s.p));
  const start = KP(s.p), goal = KP(target);
  if (start === goal) return [];
  const prev = new Map([[start, null]]);
  const q = [s.p];
  while (q.length) {
    const P = q.shift();
    for (let d = 0; d < 4; d++) {
      const T = walkTarget(L, s, W, P, d);
      if (!T) continue;
      const k = KP(T);
      if (prev.has(k)) continue;
      prev.set(k, { from: KP(P), d });
      if (k === goal) {
        const dirs = []; let cur = k;
        while (prev.get(cur)) { dirs.unshift(prev.get(cur).d); cur = prev.get(cur).from; }
        return dirs;
      }
      q.push(T);
    }
  }
  return null;
}

export function actionsFor(L) {
  const acts = [];
  for (let d = 0; d < 4; d++) acts.push({ t: 'move', d });
  (L.def.rotators || []).forEach((r, i) => { acts.push({ t: 'rot', i, s: 1 }); acts.push({ t: 'rot', i, s: -1 }); });
  (L.def.sliders || []).forEach((r, i) => { if (isManual(r)) { acts.push({ t: 'slide', i, s: 1 }); acts.push({ t: 'slide', i, s: -1 }); } });
  if ((L.def.links || []).length) { acts.push({ t: 'view', s: 1 }); acts.push({ t: 'view', s: -1 }); }
  return acts;
}

// Genişlik-öncelikli tam çözücü: en kısa eylem dizisini döndürür.
export function solve(L, maxStates = 400000) {
  const s0 = initialState(L);
  const acts = actionsFor(L);
  const k0 = stateKey(s0);
  const prev = new Map([[k0, null]]);
  let frontier = [s0];
  let n = 0;
  while (frontier.length) {
    const nf = [];
    for (const s of frontier) {
      for (const a of acts) {
        const r = step(L, s, a);
        if (!r.ok || r.state.dead) continue;
        const k = stateKey(r.state);
        if (prev.has(k)) continue;
        prev.set(k, { from: stateKey(s), a });
        if (isWin(L, r.state)) {
          const path = []; let cur = k;
          while (prev.get(cur)) { path.unshift(prev.get(cur).a); cur = prev.get(cur).from; }
          return { solved: true, path, states: prev.size };
        }
        if (++n > maxStates) return { solved: false, reason: 'limit', states: prev.size };
        nf.push(r.state);
      }
    }
    frontier = nf;
  }
  return { solved: false, reason: 'exhausted', states: prev.size };
}

export function actionText(a) {
  const dn = ['+X (doğu)', '+Z (güney)', '-X (batı)', '-Z (kuzey)'];
  if (a.t === 'move') return 'Adım ' + dn[a.d];
  if (a.t === 'rot') return 'Döner platform #' + (a.i + 1) + (a.s > 0 ? ' +90°' : ' -90°');
  if (a.t === 'slide') return 'Kaydırıcı #' + (a.i + 1) + (a.s > 0 ? ' ileri' : ' geri');
  if (a.t === 'view') return 'Kamerayı ' + (a.s > 0 ? 'sağa' : 'sola') + ' çevir';
  return JSON.stringify(a);
}
