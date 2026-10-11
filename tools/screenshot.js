// Screenshots of the panel pages that tests/demo.sh saved, through headless Chrome.
//
// Usage: node tools/screenshot.js <dir-with-html> <out-dir> [width] [height] [name-template]
//   node tools/screenshot.js docs/demo-html docs/screenshots 1000 900
//   node tools/screenshot.js docs/demo-html docs/screenshots 480 900 "mobile-{tab}.png"
//
// Every "<lang>-<tab>.html" in the input directory becomes "<lang>/<name>" in the output directory, with
// the RU language at the top level and EN in an "en" subdirectory — that is the layout README.md and
// README.en.md use. A file called "<lang>-login.html" is written as "login.png" (or its template) for the
// same reason: the names in the README are bare, without the language. The page is captured in full: the
// height is taken from the document, so the picture is not cut off at the fold, which is what a
// viewport-sized screenshot would do.
//
// Chrome is driven over its own DevTools protocol, so no npm package is needed: it is started with a remote
// debugging port and the few commands below are sent over a WebSocket (Node has a WebSocket client built in
// since v22).
import { spawn } from 'node:child_process';
import { mkdir, readdir, writeFile, mkdtemp, rm } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';

const [inDir, outDir, widthArg, heightArg, templateArg] = process.argv.slice(2);
if (!inDir || !outDir) {
  console.error('usage: node tools/screenshot.js <dir-with-html> <out-dir> [width] [height] [name-template]');
  process.exit(2);
}
const width = Number(widthArg || 1000);
const height = Number(heightArg || 900);
const template = templateArg || '{tab}.png';
const outName = (tab) => template.replace('{tab}', tab);

const CHROME = [
  'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe',
  'C:\\Program Files (x86)\\Google\\Chrome\\Application\\chrome.exe',
  'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe',
  'C:\\Program Files\\Microsoft\\Edge\\Application\\msedge.exe',
].find((p) => existsSync(p));
if (!CHROME) {
  console.error('no Chrome or Edge found: install one, or take the screenshots by hand');
  process.exit(2);
}

const port = 9222 + Math.floor(Math.random() * 500);
const profile = await mkdtemp(join(tmpdir(), 'flint-shot-'));
const chrome = spawn(CHROME, [
  '--headless=new',
  `--remote-debugging-port=${port}`,
  `--user-data-dir=${profile}`,
  '--no-first-run',
  '--no-default-browser-check',
  '--disable-extensions',
  '--hide-scrollbars',
  `--window-size=${width},${height}`,
], { stdio: 'ignore' });

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function debuggerUrl() {
  for (let i = 0; i < 60; i++) {
    try {
      const answer = await fetch(`http://127.0.0.1:${port}/json/version`);
      if (answer.ok) return (await answer.json()).webSocketDebuggerUrl;
    } catch {
      // Chrome is not listening yet.
    }
    await sleep(500);
  }
  throw new Error('Chrome did not open its debugging port');
}

// A minimal client for the browser-level DevTools socket: send an id, wait for the matching answer.
class CDP {
  constructor(ws) {
    this.ws = ws;
    this.id = 0;
    this.waiting = new Map();
    ws.addEventListener('message', (event) => {
      const message = JSON.parse(event.data);
      if (message.id && this.waiting.has(message.id)) {
        const { resolve, reject } = this.waiting.get(message.id);
        this.waiting.delete(message.id);
        message.error ? reject(new Error(message.error.message)) : resolve(message.result);
      }
    });
  }
  send(method, params = {}, sessionId) {
    const id = ++this.id;
    this.ws.send(JSON.stringify({ id, method, params, ...(sessionId ? { sessionId } : {}) }));
    return new Promise((resolve, reject) => this.waiting.set(id, { resolve, reject }));
  }
}

const socket = new WebSocket(await debuggerUrl());
await new Promise((resolve, reject) => {
  socket.addEventListener('open', resolve);
  socket.addEventListener('error', reject);
});
const cdp = new CDP(socket);

const pages = (await readdir(inDir)).filter((f) => f.endsWith('.html'));
if (pages.length === 0) throw new Error(`no .html files in ${inDir}: run tests/demo.sh first`);

let saved = 0;
for (const file of pages.sort()) {
  const match = /^(ru|en)-(.+)\.html$/.exec(file);
  if (!match) {
    console.log(`  ${file}: skipped (expected "<ru|en>-<tab>.html")`);
    continue;
  }
  const lang = match[1];
  const tab = match[2];
  const target = await cdp.send('Target.createTarget', { url: 'about:blank' });
  const attached = await cdp.send('Target.attachToTarget', { targetId: target.targetId, flatten: true });
  const session = attached.sessionId;

  await cdp.send('Emulation.setDeviceMetricsOverride', { width, height, deviceScaleFactor: 1, mobile: false }, session);
  await cdp.send('Page.enable', {}, session);
  await cdp.send('Page.navigate', { url: `file:///${resolve(inDir, file).replace(/\\/g, '/')}` }, session);
  // The panel is plain HTML with an inlined stylesheet: waiting for the load event is enough, and a short
  // pause covers the font and the SVG.
  await sleep(700);
  const metrics = await cdp.send('Page.getLayoutMetrics', {}, session);
  const full = Math.max(height, Math.ceil(metrics.cssContentSize?.height || metrics.contentSize?.height || height));
  const shot = await cdp.send('Page.captureScreenshot', { format: 'png', captureBeyondViewport: true, clip: { x: 0, y: 0, width, height: full, scale: 1 } }, session);
  await cdp.send('Target.closeTarget', { targetId: target.targetId });

  const dir = lang === 'en' ? join(outDir, 'en') : outDir;
  await mkdir(dir, { recursive: true });
  const out = join(dir, outName(tab));
  await writeFile(out, Buffer.from(shot.data, 'base64'));
  saved++;
  console.log(`  ${file} -> ${out} (${width}x${full})`);
}

socket.close();
chrome.kill();
await sleep(300);
await rm(profile, { recursive: true, force: true });
console.log(`saved ${saved} of ${pages.length} pages`);
