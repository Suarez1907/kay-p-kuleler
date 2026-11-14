// node shot.mjs <seviye> <eylem sayısı> <dosya> [view]
import { chromium } from 'playwright-core';
const [lv, k, file, view] = process.argv.slice(2);
const browser = await chromium.launch({ executablePath: '/usr/bin/google-chrome', headless: true, args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader'] });
const page = await browser.newPage({ viewport: { width: 1280, height: 800 } });
page.on('pageerror', e => console.log('ERR', e.message));
await page.goto('http://localhost:8765/', { waitUntil: 'networkidle' });
await page.waitForFunction(() => window.__game);
await page.evaluate(([i, k]) => { const g = window.__game; g.setInstant(true); g.start(i); for (const a of g.levels[i].solution.slice(0, k)) g.act(a); }, [+lv - 1, +k]);
await page.waitForFunction(() => !window.__game.busy());
if (view != null) await page.evaluate(v => window.__game.setView(+v), view);
await page.evaluate(() => window.__game.setInstant(false));
await page.waitForTimeout(1200);
await page.screenshot({ path: file });
await browser.close();
