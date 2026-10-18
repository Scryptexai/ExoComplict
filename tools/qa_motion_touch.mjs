#!/usr/bin/env node
/*
 * WebAssembly portrait in-game motion and weapon feedback capture.
 * Start the project-root server first:
 *   python -m http.server 800 --bind 0.0.0.0
 * Then: npm ci --prefix tools && node tools/qa_motion_touch.mjs
 *
 * Capture the actual Blender hero under movement, ADS and firing in safe Explore.
 * Keyboard movement is used to keep the right thumb available for FIRE/ADS;
 * these screenshots and clip logs are NOT acceptance of animation quality.
 */
import chromium from '@sparticuz/chromium';
import puppeteer from 'puppeteer-core';
import fs from 'node:fs';
import path from 'node:path';
import zlib from 'node:zlib';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const OUT = path.join(ROOT, 'exports', 'qa-motion-touch');
const URL = process.argv.find(arg => arg.startsWith('--url='))?.slice(6) || 'http://127.0.0.1:800/';
const LIB_DIR = path.join(ROOT, 'tools', '.cache', 'al2023-lib', 'lib');
if (!fs.existsSync(path.join(LIB_DIR, 'libnss3.so'))) {
  const entry = path.dirname(fileURLToPath(import.meta.resolve('@sparticuz/chromium')));
  const compressed = path.join(entry, '..', 'bin', 'al2023.tar.br');
  const tar = path.join(ROOT, 'tools', '.cache', 'al2023.tar');
  fs.mkdirSync(path.dirname(LIB_DIR), { recursive: true });
  fs.writeFileSync(tar, zlib.brotliDecompressSync(fs.readFileSync(compressed)));
  execFileSync('tar', ['-xf', tar, '-C', path.dirname(LIB_DIR)]);
  fs.rmSync(tar);
}
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));
const browser = await puppeteer.launch({
  executablePath: await chromium.executablePath(),
  args: [...chromium.args, '--no-sandbox', '--disable-dev-shm-usage'],
  headless: true,
  protocolTimeout: 300000,
  env: { ...process.env, LD_LIBRARY_PATH: [LIB_DIR, process.env.LD_LIBRARY_PATH].filter(Boolean).join(':') },
});
fs.mkdirSync(OUT, { recursive: true });
try {
  const page = await browser.newPage();
  await page.setViewport({ width: 390, height: 844, hasTouch: true, isMobile: true, deviceScaleFactor: 1 });
  const lines = [];
  const errors = [];
  page.on('console', message => {
    const line = message.text();
    lines.push(line);
    if (/Encounter:|Progression:|Armory:/.test(line)) console.log(line);
    if (/SCRIPT ERROR:|Parse Error:/.test(line)) errors.push(line);
  });
  page.on('pageerror', error => errors.push(String(error)));
  const waitForCount = async (text, count = 1, ms = 180000) => {
    if (lines.filter(line => line.includes(text)).length >= count) return;
    await new Promise((resolve, reject) => {
      const timeout = setTimeout(() => { page.off('console', check); reject(new Error(`Timeout waiting for ${text} #${count}`)); }, ms);
      const check = () => {
        if (lines.filter(line => line.includes(text)).length >= count) {
          clearTimeout(timeout);
          page.off('console', check);
          resolve();
        }
      };
      page.on('console', check);
    });
  };
  const waitFor = (text, ms = 180000) => waitForCount(text, 1, ms);
  const shot = async name => {
    await delay(350);
    await page.screenshot({ path: path.join(OUT, `${name}.png`) });
    console.log('FRAME', name);
  };
  const preview = URL.includes('?') ? URL + '&qa_camera' : URL + '?qa_camera';
  await page.goto(preview, { waitUntil: 'domcontentloaded', timeout: 90000 });
  await waitFor('Encounter: Explore safe', 90000);
  await shot('01-idle');
  await page.touchscreen.touchStart(334, 640); // ADS icon, not FIRE
  await delay(900);
  await shot('02-ads-held');
  await page.touchscreen.touchEnd();
  await page.touchscreen.touchStart(323, 746);
  await delay(750);
  await shot('03-fire-held');
  await page.touchscreen.touchEnd();
  await page.keyboard.down('KeyW');
  await delay(1000);
  await shot('04-move');
  await page.touchscreen.touchStart(323, 746);
  await delay(850);
  await shot('05-move-fire-held');
  await page.touchscreen.touchEnd();
  await page.keyboard.up('KeyW');
  const traces = lines.filter(line => line.startsWith('Camera QA:'));
  console.log('CLIP TRACE', traces.slice(-15).join('\n'));
  if (errors.length) throw new Error(errors.join('\n'));
  if (!traces.some(line => line.includes('aim=true'))
      || !traces.some(line => line.includes('fire=true'))
      || !traces.some(line => line.includes('clip=aim_run'))) {
    throw new Error('Camera trace never observed ADS, held FIRE and Blender aim_run in gameplay');
  }
  console.log('PASS: actual Explore inputs and camera/clip traces captured; human motion/VFX review remains OPEN');

} finally {
  await browser.close();
}
