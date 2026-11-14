// Uçtan uca doğrulama: headless Chrome'da oyunu yükler, konsol hatalarını toplar,
// her seviyenin çözümünü gerçek oyun eylem hattından oynatır ve ekran görüntüleri alır.
import { chromium } from 'playwright-core';
import fs from 'fs';
const PAGE_URL = process.env.URL || 'http://localhost:8765/';
const SHOTS = new URL('../screenshots/', import.meta.url).pathname;
fs.mkdirSync(SHOTS, { recursive: true });
const browser = await chromium.launch({ executablePath: process.env.CHROME_PATH || '/usr/bin/google-chrome', headless: true, args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
const page = await browser.newPage({ viewport: { width: 1280, height: 800 }, deviceScaleFactor: 1 });
const errors = [];
page.on('console', m => { if (m.type() === 'error' || m.type() === 'warning') errors.push(`[${m.type()}] ${m.text()}`); });
page.on('pageerror', e => errors.push('[pageerror] ' + e.message));
page.on('requestfailed', r => errors.push('[requestfailed] ' + r.url()));
await page.goto(PAGE_URL, { waitUntil: 'networkidle' });
await page.waitForFunction(() => window.__game);
await page.waitForTimeout(800);
await page.screenshot({ path: SHOTS + '00-baslik.png' });
const n = await page.evaluate(() => window.__game.count);
const results = [];
const waitIdle = () => page.waitForFunction(() => !window.__game.busy(), null, { timeout: 20000 });
for (let i = 0; i < n; i++) {
  await page.evaluate((i) => { window.__game.setInstant(true); window.__game.start(i); }, i);
  const sol = await page.evaluate((i) => window.__game.levels[i].solution, i);
  let okAll = true;
  for (const a of sol) {
    const ok = await page.evaluate((a) => window.__game.act(a), a);
    if (!ok) { okAll = false; break; }
    await waitIdle();
  }
  await page.waitForTimeout(100);
  const r = await page.evaluate(() => ({ win: window.__game.isWin(), shown: window.__game.winShown(), moves: window.__game.state().moves }));
  results.push({ level: i + 1, steps: sol.length, ...r, okAll });
  console.log(`Seviye ${i + 1}: ${r.win && r.shown && okAll ? 'TAMAMLANDI' : 'BAŞARISIZ'} (${r.moves} hamle)`);
}
// Gerçek fare tıklaması ile tıkla-yürü testi (Seviye 1)
await page.evaluate(() => { window.__game.setInstant(false); window.__game.start(0); });
await page.waitForTimeout(1200);
await page.click('#hintBox').catch(() => {});
const g = await page.evaluate(() => window.__game.project(window.__game.levels[0].goal));
await page.mouse.click(g.x, g.y - 4);
await page.waitForTimeout(400);
await page.screenshot({ path: SHOTS + '01-seviye1-yurume.png' });
await page.waitForFunction(() => window.__game.winShown(), null, { timeout: 15000 }).then(() => console.log('Fare tıklamasıyla Seviye 1: TAMAMLANDI')).catch(() => console.log('Fare tıklamasıyla Seviye 1: BAŞARISIZ'));
await page.waitForTimeout(1200);
await page.screenshot({ path: SHOTS + '02-seviye-tamamlandi.png' });
// Oynanış görüntüleri: çözümün ortasında
async function midShot(i, frac, name, view) {
  await page.evaluate((i) => { window.__game.setInstant(true); window.__game.start(i); }, i);
  const sol = await page.evaluate((i) => window.__game.levels[i].solution, i);
  const k = Math.floor(sol.length * frac);
  for (const a of sol.slice(0, k)) { await page.evaluate((a) => window.__game.act(a), a); await waitIdle(); }
  await page.evaluate(() => window.__game.setInstant(false));
  await page.waitForTimeout(900);
  await page.screenshot({ path: SHOTS + name });
}
await midShot(4, 0.5, '03-doner-kopru.png');
await midShot(8, 0.6, '04-terazi.png');
await midShot(10, 0.5, '05-imkansiz-gecit.png');
await midShot(14, 0.55, '06-son-kule.png');
await page.evaluate(() => window.__game.showLevels());
await page.waitForTimeout(400);
await page.screenshot({ path: SHOTS + '07-seviye-secimi.png' });
await browser.close();
console.log('\nKonsol hataları/uyarıları:', errors.length ? '\n' + errors.join('\n') : 'YOK');
const pass = results.every(r => r.win && r.shown && r.okAll) && errors.filter(e => !e.includes('GPU stall') && !e.includes('GL Driver')).length === 0;
fs.writeFileSync(new URL('../screenshots/test-sonuclari.json', import.meta.url).pathname, JSON.stringify({ results, errors }, null, 2));
console.log(pass ? 'TEST GEÇTİ' : 'TEST BAŞARISIZ');
process.exit(pass ? 0 : 1);
