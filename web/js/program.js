// Kayıp Kuleler — programlama katmanı.
// Robo'nun komutları, koşullar, fonksiyon çağrıları ve yorumlayıcı. Render'dan bağımsızdır;
// hem oyun hem de tools/build.mjs (çözüm doğrulayıcı) bu dosyayı kullanır.
import * as E from './engine.js';

const add = (a, b) => [a[0] + b[0], a[1] + b[1], a[2] + b[2]];
const KP = (p) => p[0] + ',' + p[1] + ',' + p[2];
const eq = (a, b) => a[0] === b[0] && a[1] === b[1] && a[2] === b[2];

// Komut kataloğu. `key`: kaynak kodlamasındaki harf.
export const COMMANDS = {
  F: { name: 'İleri', desc: 'Baktığı yöne bir kare yürür. Merdivenleri çıkar/iner.' },
  L: { name: 'Sola dön', desc: 'Olduğu yerde 90° sola döner.' },
  R: { name: 'Sağa dön', desc: 'Olduğu yerde 90° sağa döner.' },
  J: { name: 'Zıpla', desc: 'Önündeki bir kat yüksek bloğa çıkar ya da bir kat aşağı atlar.' },
  A: { name: 'Kullan', desc: 'Önündeki kolu çevirir, çarkı döndürür, kutuyu iter, topa vurur.' },
  W: { name: 'Mola', desc: 'Programı duraklatır. Bu sırada dünyayı döndürebilir, sonra ▶ ile devam edebilirsin.' },
  1: { name: 'F1', desc: 'F1 fonksiyonunu çağırır. Bir fonksiyon kendini de çağırabilir (döngü).' },
  2: { name: 'F2', desc: 'F2 fonksiyonunu çağırır.' },
};
export const CONDS = {
  '': { name: 'Her zaman' },
  o: { name: 'Önü açıksa', desc: 'Komut yalnızca Robo ileri yürüyebiliyorsa çalışır.' },
  x: { name: 'Önü kapalıysa', desc: 'Komut yalnızca Robo ileri yürüyemiyorsa çalışır.' },
};

// 'F', 'o:F', 'x:1' -> {c, k}
export function parseIns(str) {
  if (typeof str !== 'string') return { c: str.c, k: str.k || '' };
  const i = str.indexOf(':');
  return i < 0 ? { c: str, k: '' } : { c: str.slice(i + 1), k: str.slice(0, i) };
}
export function insToStr(ins) { return ins.k ? ins.k + ':' + ins.c : ins.c; }
export function parseProgram(src) {
  return { main: (src.main || []).map(parseIns), p1: (src.p1 || []).map(parseIns), p2: (src.p2 || []).map(parseIns) };
}
export function programToSrc(p) {
  const o = { main: p.main.map(insToStr) };
  if (p.p1.length) o.p1 = p.p1.map(insToStr);
  if (p.p2.length) o.p2 = p.p2.map(insToStr);
  return o;
}
export function blockCount(p) { return p.main.length + p.p1.length + p.p2.length; }

export function frontOpen(L, s) {
  if (s.dead) return false;
  const W = E.buildWorld(L, s);
  return !!E.walkTarget(L, s, W, s.p, s.f);
}

function jumpTarget(L, s, W) {
  const P = s.p, dv = E.DIRS[s.f];
  const Q = add(P, dv);
  const kq = KP(Q);
  const isSolid = W.solid.has(kq) || W.ents.has(kq);
  const free = (p) => !W.solid.has(KP(p)) && !W.ents.has(KP(p));
  const sup = (p) => { const k = KP([p[0], p[1] - 1, p[2]]); return W.solid.has(k) || W.ents.has(k); };
  if (isSolid) {
    const up = add(Q, [0, 1, 0]);
    if (free(up) && free(add(P, [0, 1, 0]))) return up;
    return null;
  }
  if (sup(Q)) return Q;
  const dn = add(Q, [0, -1, 0]);
  if (free(dn) && sup(dn)) return dn;
  return null;
}

// Tek bir komutu uygular. Dönüş: {state, frames, bump, kind}
// Engelle karşılaşan komutlar "bump" olur: durum değişmez, program devam eder.
export function cmdStep(L, s0, c) {
  const s = E.cloneState(s0);
  const frames = [];
  const bump = () => ({ state: s0, frames: [], bump: true, kind: c });
  if (s.dead) return bump();
  if (c === 'L' || c === 'R') {
    s.f = (s.f + (c === 'L' ? 3 : 1)) % 4;
    return { state: s, frames: [s], bump: false, kind: c };
  }
  if (c === 'W') return { state: s0, frames: [], bump: false, kind: c, pause: true };
  const W = E.buildWorld(L, s);
  const P = s.p;
  const leave = () => {
    const below = W.solid.get(KP([P[0], P[1] - 1, P[2]]));
    if (below && below.t === 'cr' && !eq(s.p, P)) s.crumbles[below.i] = 1;
  };
  if (c === 'F' || c === 'J') {
    const T = c === 'F' ? E.walkTarget(L, s, W, P, s.f) : jumpTarget(L, s, W);
    if (!T) return bump();
    s.p = T; leave();
  } else if (c === 'A') {
    const dv = E.DIRS[s.f];
    const Q = add(P, dv);
    const e = W.ents.get(KP(Q));
    const sv = W.solid.get(KP(Q));
    if (e && e.k === 'c') {
      const C = add(Q, dv);
      if (W.solid.has(KP(C)) || W.ents.has(KP(C))) return bump();
      s.crates[e.i] = C;
    } else if (e && e.k === 'b') {
      const C = add(Q, dv);
      const cv = W.solid.get(KP(C));
      if (cv && cv.t === 'lv') s.levers[cv.i] = !s.levers[cv.i];
      else if (cv || W.ents.has(KP(C))) return bump();
      else s.balls[e.i].d = s.f;
    } else if (sv && sv.t === 'lv') {
      s.levers[sv.i] = !s.levers[sv.i];
    } else if (sv && sv.t === 'ck') {
      const ck = L.def.cranks[sv.i];
      if (!E.tryRotate(L, s, ck.rot, ck.dir || 1)) return bump();
    } else return bump();
  } else return bump();
  s.moves++;
  frames.push(E.cloneState(s));
  E.settle(L, s, frames);
  frames[frames.length - 1] = s;
  return { state: s, frames, bump: false, kind: c };
}

export const MAX_STEPS = 300;
const MAX_DEPTH = 60;

// Yorumlayıcı: çağrı yığını + program sayacı. Kuyruk çağrıları yığını büyütmez
// (bu sayede "F1: İleri, F1" gibi özyinelemeli döngüler sınırsız sürebilir).
export class Runner {
  constructor(prog) {
    this.prog = prog;
    this.stack = [{ p: 'main', pc: 0 }];
    this.steps = 0;
    this.error = null;
  }
  get finished() { return !this.stack.length; }
  // Bir sonraki eylem komutunu döndürür (çağrıları ve koşulları çözerek) ya da null.
  next(L, s) {
    this.skipped = [];
    for (let guard = 0; guard < 2000; guard++) {
      const top = this.stack[this.stack.length - 1];
      if (!top) return null;
      const list = this.prog[top.p];
      if (top.pc >= list.length) { this.stack.pop(); continue; }
      const idx = top.pc++;
      const ins = list[idx];
      if (ins.k) {
        const open = frontOpen(L, s);
        if ((ins.k === 'o' && !open) || (ins.k === 'x' && open)) { this.skipped.push({ proc: top.p, idx }); continue; }
      }
      if (ins.c === '1' || ins.c === '2') {
        if (top.pc >= list.length) this.stack.pop();
        if (this.stack.length >= MAX_DEPTH) { this.error = 'depth'; this.stack = []; return null; }
        this.stack.push({ p: ins.c === '1' ? 'p1' : 'p2', pc: 0 });
        continue;
      }
      if (++this.steps > MAX_STEPS) { this.error = 'limit'; this.stack = []; return null; }
      return { ins, proc: top.p, idx };
    }
    this.error = 'loop'; this.stack = [];
    return null;
  }
}

// Bir dünya işlemini (oyuncunun eli) uygular: {t:'rot'|'slide'|'view', i, s}
export function worldOp(L, s, op) {
  if (op.t === 'rot' && L.def.rotators[op.i].fixed) return { ok: false };
  return E.step(L, s, op);
}

// Tüm programı (mola noktalarında `ops` ile) çalıştırır. Doğrulayıcı ve testler kullanır.
// ops[0]: çalıştırmadan önce, ops[k]: k. moladan sonra uygulanacak dünya işlemleri.
export function runProgram(L, src, ops = [], s0 = null) {
  let s = s0 || E.initialState(L);
  const apply = (list) => { for (const op of list || []) { const r = worldOp(L, s, op); if (!r.ok) throw new Error('dünya işlemi başarısız: ' + JSON.stringify(op)); s = r.state; } };
  apply(ops[0]);
  const run = new Runner(parseProgram(src));
  let pauses = 0;
  const trail = [s.p.slice()];
  while (true) {
    if (E.isWin(L, s)) return { result: 'win', state: s, steps: run.steps, trail };
    const n = run.next(L, s);
    if (!n) return { result: run.error || 'end', state: s, steps: run.steps, trail };
    const r = cmdStep(L, s, n.ins.c);
    if (r.pause) { pauses++; apply(ops[pauses]); continue; }
    s = r.state;
    trail.push(s.p.slice());
    if (s.dead) return { result: 'dead', state: s, steps: run.steps, trail };
  }
}
