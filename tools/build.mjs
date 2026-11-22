// Seviye derleyici + doğrulayıcı.
// Kullanım: node build.mjs
//  1) Programlama kampanyası (web / Android): tools/program-levels.src.mjs
//     - her referans programı gerçek yorumlayıcıda çalıştırır, kazandığını doğrular
//     - program kapasitelerine (slots) ve komut paletine (cmds) uyduğunu denetler
//     - dünya işlemi (mola / kurulum) gerektiren seviyelerde, işlemler olmadan kazanılamadığını denetler
//     - par = referans çözümün blok sayısı -> web/js/levels.js
//  2) Klasik (dokun-yürü) seviyeler (Godot sürümü): tools/levels.src.mjs
//     - BFS çözücüyle çözer, par hesaplar -> godot/data/levels.json
//  SOLUTIONS.md her ikisinin çözümlerini içerir.
import fs from 'fs';
import path from 'path';
import { loadLevel, solve, initialState, step, isWin, actionText } from '../web/js/engine.js';
import { runProgram, parseProgram, blockCount, COMMANDS, Runner, cmdStep, worldOp } from '../web/js/program.js';
import { LEVELS as CLASSIC } from './levels.src.mjs';
import { LEVELS as PROGRAM } from './program-levels.src.mjs';

const root = path.resolve(path.dirname(new URL(import.meta.url).pathname), '..');
let fail = 0;
let md = '# Seviye Çözümleri\n\n';

// ---------- 1) Programlama kampanyası ----------
md += '## Programlama kampanyası (Android / tarayıcı)\n\nAşağıdaki programlar `tools/build.mjs` tarafından gerçek yorumlayıcıda çalıştırılarak doğrulanmıştır. ' +
  '*Par*, referans çözümün blok sayısıdır; daha kısa bir program da 3 yıldız alır.\n\n' +
  'Gösterim: `İleri`, `Sola`, `Sağa`, `Zıpla`, `Kullan`, `Mola`, `F1`, `F2`; `[açıksa]` / `[kapalıysa]` koşullu bloktur.\n\n';
const name = (s) => {
  const [k, c] = s.includes(':') ? s.split(':') : ['', s];
  const n = { F: 'İleri', L: 'Sola', R: 'Sağa', J: 'Zıpla', A: 'Kullan', W: 'Mola', 1: 'F1', 2: 'F2' }[c];
  return k ? `${n}[${k === 'o' ? 'açıksa' : 'kapalıysa'}]` : n;
};
const opText = (op) => op.t === 'rot' ? `döner platform #${op.i + 1} ${op.s > 0 ? '+90°' : '−90°'}` :
  op.t === 'slide' ? `kaydırıcı #${op.i + 1} ${op.s > 0 ? 'ileri/yukarı' : 'geri/aşağı'}` : `kamera ${op.s > 0 ? 'sağa' : 'sola'}`;
const progOut = [];

// ---------- devre elemanları: çözümü bozmadan diyot ve direnç yerleştir ----------
// Referans çözüm adım adım yeniden oynatılır; Robo'nun tek bir yönde düz geçtiği karelerin altı diyot,
// bazı ziyaret edilen karelerin altı direnç olur. Sonra çözüm (ve varsa hatalı hazır program) yeniden sınanır.
const COMP_INTRO = {
  diode: { title: 'Diyot', text: 'Üstünde parlak ok olan bloklar <b>diyottur</b>: akım tek yönde akar! Robo bir diyota yalnızca ok yönünde girebilir ve yalnızca ok yönünde çıkabilir. Ters yönden girmeye çalışırsa geri seker.' },
  res: { title: 'Direnç', text: 'Renkli bantlı seramik bloklar <b>dirençtir</b>. Robo üstüne bastığında akım yavaşlar ve Robo bir adım bekler. Zamanlamalı devrelerde işine yarayacak.' },
  cap: { title: 'Kondansatör', text: 'Alüminyum silindir bir <b>kondansatördür</b>. Robo üstüne bastığı anda kondansatör boşalır ve Robo\'yu baktığı yönde bir kare ileri, bir kat yukarı fırlatır — Zıpla gerekmez!' },
  relay: { title: 'Röle', text: 'Şeffaf kapaklı, içinde bakır bobin olan blok bir <b>röledir</b>. Robo üstüne her bastığında röle konum değiştirir ve bağlı olduğu köprüyü açar ya da kapatır.' },
};
const hash = (str) => { let h = 2166136261; for (const ch of str) { h ^= ch.charCodeAt(0); h = Math.imul(h, 16777619); } return h >>> 0; };
function traceMoves(def) {
  const L = loadLevel(JSON.parse(JSON.stringify(def)));
  let s = initialState(L);
  const sol = def.solution, ops = sol.ops || [];
  for (const op of ops[0] || []) s = worldOp(L, s, op).state;
  const run = new Runner(parseProgram(sol));
  const ev = [];
  let pauses = 0;
  for (let g = 0; g < 400; g++) {
    if (s.p.join() === def.goal.join()) break;
    const n = run.next(L, s);
    if (!n) break;
    const r = cmdStep(L, s, n.ins.c);
    if (r.pause) { pauses++; for (const op of ops[pauses] || []) s = worldOp(L, s, op).state; ev.push({ t: 'world' }); continue; }
    if (r.bump) continue;
    const a = s.p, b = r.state.p;
    const plain = r.frames.length <= 1 && Math.abs(a[0] - b[0]) + Math.abs(a[2] - b[2]) === 1 && Math.abs(a[1] - b[1]) <= 1;
    ev.push({ t: plain ? 'step' : 'jump', a: a.slice(), b: b.slice(), d: s.f, c: n.ins.c, rots: r.state.rots.join() !== s.rots.join() });
    s = r.state;
  }
  return ev;
}
function assignComponents(def, idx) {
  if (idx < 2) return;
  const L = loadLevel(JSON.parse(JSON.stringify(def)));
  const ev = traceMoves(def);
  const info = new Map();
  const note = (p, k, v) => { const key = p.join(); if (!info.has(key)) info.set(key, { p, in: [], out: [], other: [] }); info.get(key)[k].push(v); };
  for (const e of ev) {
    if (e.t === 'step' && !e.rots) { note(e.a, 'out', e.d); note(e.b, 'in', e.d); }
    else if (e.a) { note(e.a, 'other', 1); note(e.b, 'other', 1); }
  }
  const blocked = new Set([def.start.join(), def.goal.join(), ...(def.crates || []).map(c => c.join()), ...(def.plates || []).map(p => p.p.join())]);
  const used = new Set((def.comps || []).map(c => c.p.join()));
  const diodes = [], res = [];
  for (const [key, it] of info) {
    if (blocked.has(key) || it.other.length) continue;
    const below = [it.p[0], it.p[1] - 1, it.p[2]];
    const bk = below.join();
    const st = L.statics.get(bk);
    if (!st || st.t !== 'b' || used.has(bk)) continue;
    const dirs = new Set([...it.in, ...it.out]);
    if (it.in.length === 1 && it.out.length === 1 && dirs.size === 1) diodes.push({ p: below, d: it.in[0], h: hash(def.name + key) });
    if (it.in.length >= 1) res.push({ p: below, h: hash(key + def.name) });
  }
  diodes.sort((a, b) => a.h - b.h);
  res.sort((a, b) => a.h - b.h);
  const add = [];
  diodes.slice(0, 1 + (idx % 2)).forEach(d => add.push({ p: d.p, t: 'diode', d: d.d }));
  if (idx >= 4) res.filter(r => !add.some(a => a.p.join() === r.p.join())).slice(0, idx % 3 === 0 ? 2 : 1).forEach(r => add.push({ p: r.p, t: 'res' }));
  if (!add.length) return;
  const trial = JSON.parse(JSON.stringify(def));
  trial.comps = [...(def.comps || []), ...add];
  const ok = (() => {
    try {
      const r = runProgram(loadLevel(JSON.parse(JSON.stringify(trial))), trial.solution, trial.solution.ops || []);
      if (r.result !== 'win') return false;
      if (trial.starter) { const r3 = runProgram(loadLevel(JSON.parse(JSON.stringify(trial))), trial.starter, []); if (r3.result === 'win') return false; }
      if ((trial.solution.ops || []).some(o => o && o.length)) {
        let r2; try { r2 = runProgram(loadLevel(JSON.parse(JSON.stringify(trial))), trial.solution, []); } catch (e) { r2 = { result: 'err' }; }
        if (r2.result === 'win') return false;
      }
      return true;
    } catch (e) { return false; }
  })();
  if (ok) def.comps = trial.comps;
}
const introSeen = new Set();
function compIntro(def) {
  for (const c of def.comps || []) {
    if (introSeen.has(c.t)) continue;
    if (def.intro) continue;
    def.intro = COMP_INTRO[c.t];
    introSeen.add(c.t);
  }
}
let chapter = null;
PROGRAM.forEach((src, i) => {
  const def = JSON.parse(JSON.stringify(src));
  assignComponents(def, i);
  compIntro(def);
  const L = loadLevel(def);
  const sol = def.solution;
  const p = parseProgram(sol);
  const errs = [];
  for (const k of ['main', 'p1', 'p2']) if (p[k].length > (def.slots[k] || 0)) errs.push(`${k} kapasitesi aşıldı (${p[k].length}/${def.slots[k]})`);
  for (const k of ['main', 'p1', 'p2']) for (const ins of p[k]) {
    if (!def.cmds.includes(ins.c)) errs.push(`'${ins.c}' komutu paletde yok`);
    if (ins.k && !def.conds) errs.push('koşul kullanılmış ama seviyede kapalı');
  }
  for (const c of def.cmds) if (!COMMANDS[c]) errs.push(`bilinmeyen komut ${c}`);
  const r = runProgram(L, sol, sol.ops || []);
  if (r.result !== 'win') errs.push('referans çözüm kazanmıyor: ' + r.result);
  const needsOps = (sol.ops || []).some(o => o && o.length);
  if (needsOps) {
    let r2; try { r2 = runProgram(L, sol, []); } catch (e) { r2 = { result: 'err' }; }
    if (r2.result === 'win') errs.push('dünya işlemleri olmadan da kazanılıyor');
  }
  if (def.starter) {
    const st = parseProgram(def.starter);
    for (const k of ['main', 'p1', 'p2']) if (st[k].length > (def.slots[k] || 0)) errs.push(`hazır program ${k} kapasitesini aşıyor`);
    for (const k of ['main', 'p1', 'p2']) for (const ins of st[k]) if (!def.cmds.includes(ins.c)) errs.push(`hazır programda '${ins.c}' paletde yok`);
    let r3; try { r3 = runProgram(L, def.starter, []); } catch (e) { r3 = { result: 'err' }; }
    if (r3.result === 'win') errs.push('hazır (hatalı) program zaten kazanıyor');
  }
  for (const ph of def.phantoms || []) for (const c of ph.cells) if (L.statics.has(c.join(','))) errs.push('hayalet blok statik bloğun içinde: ' + c);
  def.par = blockCount(p);
  if (errs.length) { fail++; console.log(`#${i + 1} ${def.name}: HATA — ${errs.join('; ')}`); }
  else console.log(`#${i + 1} ${def.name}: doğrulandı — par ${def.par} blok, ${r.steps} komut çalıştı`);
  progOut.push(def);
  if (def.chapter !== chapter) { chapter = def.chapter; md += `### Bölüm: ${chapter}\n\n`; }
  md += `#### ${i + 1}. ${def.name} — par ${def.par}\n\n`;
  if (sol.ops && sol.ops[0] && sol.ops[0].length) md += `* Başlamadan önce: ${sol.ops[0].map(opText).join(', ')}\n`;
  md += `* Ana: ${p.main.map(x => name(x.k ? x.k + ':' + x.c : x.c)).join(' → ')}\n`;
  if (p.p1.length) md += `* F1: ${sol.p1.map(name).join(' → ')}\n`;
  if (p.p2.length) md += `* F2: ${sol.p2.map(name).join(' → ')}\n`;
  (sol.ops || []).slice(1).forEach((ops, k) => { md += `* ${k + 1}. molada: ${ops.map(opText).join(', ')}\n`; });
  md += '\n';
});
const pjson = JSON.stringify(progOut);
fs.writeFileSync(path.join(root, 'web/js/levels.js'), '// Otomatik üretildi: tools/build.mjs (kaynak: tools/program-levels.src.mjs)\nexport const LEVELS = ' + pjson + ';\n');
fs.mkdirSync(path.join(root, 'godot-program/data'), { recursive: true });
fs.writeFileSync(path.join(root, 'godot-program/data/levels.json'), pjson);

// ---------- 2) Klasik seviyeler (Godot) ----------
md += '## Klasik seviyeler (Godot sürümü, dokun-yürü)\n\nBu çözümler tam (BFS) çözücü tarafından otomatik bulunmuştur ve en kısa eylem dizileridir.\n\n';
const classicOut = [];
for (let i = 0; i < CLASSIC.length; i++) {
  const def = JSON.parse(JSON.stringify(CLASSIC[i]));
  const L = loadLevel(def);
  const t0 = Date.now();
  const r = solve(L, 3000000);
  const ms = Date.now() - t0;
  if (!r.solved) { console.log(`klasik #${i + 1} ${def.name}: ÇÖZÜLEMEDİ (${r.reason}, ${r.states} durum)`); fail++; classicOut.push(def); continue; }
  let s = initialState(L);
  for (const a of r.path) { const res = step(L, s, a); if (!res.ok) throw new Error('replay fail'); s = res.state; }
  if (!isWin(L, s)) throw new Error('replay not win');
  def.par = s.moves;
  def.solution = r.path;
  console.log(`klasik #${i + 1} ${def.name}: çözüldü — par ${def.par} hamle, ${r.states} durum, ${ms}ms`);
  md += `### ${i + 1}. ${def.name}\n\n${def.hint || ''}\n\nPar: **${def.par}** hamle\n\n` + r.path.map((a, j) => `${j + 1}. ${actionText(a)}`).join('\n') + '\n\n';
  classicOut.push(def);
}
fs.mkdirSync(path.join(root, 'godot/data'), { recursive: true });
fs.writeFileSync(path.join(root, 'godot/data/levels.json'), JSON.stringify(classicOut, null, 0));
fs.writeFileSync(path.join(root, 'SOLUTIONS.md'), md);
console.log(fail ? `${fail} seviyede sorun var` : 'TÜM SEVİYELER DOĞRULANDI');
process.exit(fail ? 1 : 0);
