// Seviye derleyici + çözücü doğrulama.
// Kullanım: node build.mjs        -> tüm seviyeleri çözer, levels.json / levels.js / SOLUTIONS.md yazar
import fs from 'fs';
import path from 'path';
import { loadLevel, solve, initialState, step, isWin, actionText } from '../web/js/engine.js';
import { LEVELS } from './levels.src.mjs';

const root = path.resolve(path.dirname(new URL(import.meta.url).pathname), '..');
const only = process.argv[2] ? +process.argv[2] : null;
const out = [];
let md = '# Seviye Çözümleri\n\nBu çözümler `tools/build.mjs` içindeki tam (BFS) çözücü tarafından otomatik bulunmuştur ve en kısa eylem dizileridir.\n\n';
let fail = 0;
for (let i = 0; i < LEVELS.length; i++) {
  const def = JSON.parse(JSON.stringify(LEVELS[i]));
  if (only && only !== i + 1) { out.push(def); continue; }
  const L = loadLevel(def);
  const t0 = Date.now();
  const r = solve(L, 3000000);
  const ms = Date.now() - t0;
  if (!r.solved) { console.log(`#${i + 1} ${def.name}: ÇÖZÜLEMEDİ (${r.reason}, ${r.states} durum)`); fail++; out.push(def); continue; }
  // tekrar oynat ve doğrula
  let s = initialState(L);
  for (const a of r.path) { const res = step(L, s, a); if (!res.ok) throw new Error('replay fail'); s = res.state; }
  if (!isWin(L, s)) throw new Error('replay not win');
  def.par = s.moves;
  def.solution = r.path;
  const kinds = {};
  r.path.forEach(a => kinds[a.t] = (kinds[a.t] || 0) + 1);
  console.log(`#${i + 1} ${def.name}: çözüldü — ${r.path.length} eylem, par ${def.par} hamle, ${r.states} durum, ${ms}ms`, JSON.stringify(kinds));
  md += `## ${i + 1}. ${def.name}\n\n${def.hint || ''}\n\nPar: **${def.par}** hamle\n\n` + r.path.map((a, j) => `${j + 1}. ${actionText(a)}`).join('\n') + '\n\n';
  out.push(def);
}
if (!only) {
  const json = JSON.stringify(out, null, 0);
  fs.writeFileSync(path.join(root, 'web/levels.json'), json);
  fs.writeFileSync(path.join(root, 'web/js/levels.js'), '// Otomatik üretildi: tools/build.mjs\nexport const LEVELS = ' + json + ';\n');
  fs.mkdirSync(path.join(root, 'godot/data'), { recursive: true });
  fs.writeFileSync(path.join(root, 'godot/data/levels.json'), json);
  fs.writeFileSync(path.join(root, 'SOLUTIONS.md'), md);
}
console.log(fail ? `${fail} seviye çözülemedi` : 'TÜM SEVİYELER ÇÖZÜLEBİLİR');
process.exit(fail ? 1 : 0);
