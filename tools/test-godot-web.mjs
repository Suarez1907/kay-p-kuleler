import { chromium } from 'playwright-core';
const browser = await chromium.launch({ executablePath: '/usr/bin/google-chrome', headless: true, args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
const logs = [];
page.on('console', m => logs.push(`[${m.type()}] ${m.text()}`));
page.on('pageerror', e => logs.push('[pageerror] ' + e.message));
await page.goto('http://localhost:8766/index.html');
await page.waitForTimeout(25000);
await page.screenshot({ path: '../screenshots/godot-web-baslik.png' });
// "Oyna" -> seviye seçimi -> seviye 1
await page.mouse.click(640, 430); await page.waitForTimeout(1500);
await page.screenshot({ path: '/tmp/gw2.png' });
await page.mouse.click(359, 255); await page.waitForTimeout(3000);
await page.screenshot({ path: '../screenshots/godot-web-seviye1.png' });
// hedefe tıkla: Robo yürüsün
await page.keyboard.press('h');
await page.waitForTimeout(500);
console.log(logs.filter(l => !l.includes('[log]') || l.includes('ERROR')).join('\n'));
console.log('---- toplam log', logs.length);
await browser.close();
