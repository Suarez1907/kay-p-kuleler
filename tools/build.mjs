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
import { runProgram, parseProgram, blockCount, COMMANDS } from '../web/js/program.js';
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
let chapter = null;
PROGRAM.forEach((src, i) => {
  const def = JSON.parse(JSON.stringify(src));
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
