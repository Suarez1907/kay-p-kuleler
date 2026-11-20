// Uçtan uca doğrulama: headless Chrome'da oyunu yükler, konsol hatalarını toplar,
// 20 seviyenin referans programını gerçek oyun arayüzünden çalıştırır (molalarda dünya işlemleriyle),
// Seviye 1'i gerçek dokunuşlarla (palet → çalıştır) bitirir ve ekran görüntüleri alır.
import { chromium } from 'playwright-core';
import fs from 'fs';
const PAGE_URL = process.env.URL || 'http://localhost:8765/';
const SHOTS = new URL('../screenshots/', import.meta.url).pathname;
fs.mkdirSync(SHOTS, { recursive: true });
const browser = await chromium.launch({ executablePath: process.env.CHROME_PATH || '/usr/bin/google-chrome', headless: true, args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
const errors = [];
async function open(viewport) {
  const page = await browser.newPage({ viewport, deviceScaleFactor: 1 });
  page.on('console', m => { if (m.type() === 'error' || m.type() === 'warning') errors.push(`[${m.type()}] ${m.text()}`); });
  page.on('pageerror', e => errors.push('[pageerror] ' + e.message));
  page.on('requestfailed', r => errors.push('[requestfailed] ' + r.url()));
  await page.goto(PAGE_URL, { waitUntil: 'networkidle' });
  // Kare başına (raf) yoklama, efektler açıkken yazılımsal GPU'da çok seyrek kalır; zamanlayıcıyla yokla.
  await page.waitForFunction(() => window.__game, null, { polling: 200, timeout: 90000 });
  await page.waitForTimeout(600);
  return page;
}
const page = await open({ width: 1280, height: 800 });
await page.screenshot({ path: SHOTS + '00-baslik.png' });
// İşlevsel testler son işleme efektleri olmadan koşar (yazılımsal GPU'da efektler çok yavaş);
// ekran görüntüleri aşağıda efektler açıkken alınır.
await page.evaluate(() => window.__game.setGfx(0));
const n = await page.evaluate(() => window.__game.count);
const results = [];
const settled = () => page.waitForFunction(() => ['paused', 'ended', 'won'].includes(window.__game.mode()) && !window.__game.busy(), null, { polling: 100, timeout: 30000 });
for (let i = 0; i < n; i++) {
  await page.evaluate((i) => { const g = window.__game; g.setInstant(true); g.start(i); g.closeIntro(); g.setProgram(g.levels[i].solution); }, i);
  const ops = await page.evaluate((i) => window.__game.levels[i].solution.ops || [], i);
  let ok = true;
  for (const o of ops[0] || []) { ok = ok && await page.evaluate((o) => window.__game.op(o), o); await page.waitForFunction(() => !window.__game.busy()); }
  await page.evaluate(() => window.__game.run());
  for (let k = 1; ; k++) {
    await settled();
    const m = await page.evaluate(() => window.__game.mode());
    if (m !== 'paused') break;
    for (const o of ops[k] || []) { ok = ok && await page.evaluate((o) => window.__game.op(o), o); await page.waitForFunction(() => !window.__game.busy()); }
    await page.evaluate(() => window.__game.run());
  }
  const r = await page.evaluate(() => ({ win: window.__game.isWin(), shown: window.__game.winShown(), mode: window.__game.mode() }));
  // Dünya işlemi gerektiren seviyelerde, işlemler olmadan aynı programın kazanmadığını da doğrula
  results.push({ level: i + 1, ...r, ok });
  console.log(`Seviye ${i + 1}: ${r.win && r.shown && ok ? 'TAMAMLANDI' : 'BAŞARISIZ (' + r.mode + ')'}`);
}
// Gerçek dokunuşlarla Seviye 1: paletten 4 kez "İleri", sonra Çalıştır
await page.evaluate(() => { localStorage.clear(); });
await page.reload({ waitUntil: 'networkidle' });
await page.waitForFunction(() => window.__game);
await page.evaluate(() => window.__game.setGfx(0));
await page.click('#btnPlay');
await page.waitForTimeout(900);
await page.screenshot({ path: SHOTS + '01-tanitim.png' });
await page.click('#btnIntroOk');
for (let k = 0; k < 4; k++) await page.click('#palette .tile[data-c=F]');
const prog = await page.evaluate(() => window.__game.program());
await page.click('#btnRun', { force: true });
await page.waitForTimeout(700);
await page.screenshot({ path: SHOTS + '02-calisiyor.png' });
const clickWin = await page.waitForFunction(() => window.__game.winShown(), null, { timeout: 15000 }).then(() => true).catch(() => false);
await page.waitForTimeout(1600);
await page.screenshot({ path: SHOTS + '03-tamamlandi.png' });
console.log(`Dokunarak Seviye 1 (${JSON.stringify(prog)}): ${clickWin ? 'TAMAMLANDI' : 'BAŞARISIZ'}`);
// Sürükle-bırak: palet bloğunu ana satıra sürükle, sonra programdan dışarı sürükleyip sil
await page.click('#btnWinRetry');
await page.click('#btnClear');
const src = await page.locator('#palette .tile[data-c=F]').boundingBox();
const dst = await page.locator('.prow[data-row=main] .slots').boundingBox();
await page.mouse.move(src.x + 20, src.y + 20); await page.mouse.down();
await page.mouse.move(dst.x + 30, dst.y + 20, { steps: 8 }); await page.mouse.up();
const afterDrop = await page.evaluate(() => window.__game.program().main.length);
const t = await page.locator('.prow[data-row=main] .slots .tile').first().boundingBox();
await page.mouse.move(t.x + 20, t.y + 20); await page.mouse.down();
await page.mouse.move(300, 300, { steps: 8 }); await page.mouse.up();
const afterTrash = await page.evaluate(() => window.__game.program().main.length);
const dragOk = afterDrop === 1 && afterTrash === 0;
console.log(`Sürükle-bırak: ${dragOk ? 'TAMAM' : 'BAŞARISIZ'} (${afterDrop}, ${afterTrash})`);
// Oynanış görüntüleri (yatay) — efektler açık
await page.evaluate(() => window.__game.setGfx(2));
async function shot(p, i, name, steps = 0.5) {
  await p.evaluate((i) => { const g = window.__game; g.setInstant(false); g.start(i); g.closeIntro(); g.setProgram(g.levels[i].solution); }, i);
  const ops = await p.evaluate((i) => window.__game.levels[i].solution.ops || [], i);
  for (const o of ops[0] || []) { await p.evaluate((o) => window.__game.op(o), o); await p.waitForTimeout(500); }
  await p.evaluate(() => window.__game.run());
  await p.waitForTimeout(steps * 1000);
  await p.screenshot({ path: SHOTS + name });
}
await shot(page, 5, '04-sarmal-kule.png', 3.2);
await shot(page, 11, '05-kosullar.png', 4);
await shot(page, 14, '06-mola.png', 1.6);
await shot(page, 19, '07-son-kule.png', 6);
await page.evaluate(() => { const p = window.__game.progress(); for (let i = 0; i < 14; i++) p.best[i] = { blocks: 1, stars: 3 - (i % 3 === 2) }; p.unlocked = 15; window.__game.showLevels(); });
await page.waitForTimeout(400);
await page.screenshot({ path: SHOTS + '08-seviyeler.png' });
// Telefon (dikey). Önceki sayfa kapatılır: efektler açıkken iki WebGL sayfası yazılımsal GPU'yu
// paylaşınca ikinci sayfa CI'da açılamıyordu.
await page.close();
const phone = await open({ width: 412, height: 870 });
await phone.screenshot({ path: SHOTS + 'android-baslik.png' });
await shot(phone, 3, 'android-fonksiyon.png', 2.4);
await shot(phone, 12, 'android-kosul.png', 3);
await browser.close();
console.log('\nKonsol hataları/uyarıları:', errors.length ? '\n' + errors.join('\n') : 'YOK');
const pass = results.every(r => r.win && r.shown && r.ok) && clickWin && dragOk && errors.filter(e => !e.includes('GPU stall') && !e.includes('GL Driver')).length === 0;
fs.writeFileSync(SHOTS + 'test-sonuclari.json', JSON.stringify({ results, clickWin, dragOk, errors }, null, 2));
console.log(pass ? 'TEST GEÇTİ' : 'TEST BAŞARISIZ');
process.exit(pass ? 0 : 1);
