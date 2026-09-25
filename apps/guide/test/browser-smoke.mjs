import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { createServer } from 'node:http';
import { existsSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { basename, extname, join, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';

const guide = resolve(fileURLToPath(new URL('..', import.meta.url)));
const output = resolve(guide, 'dist');
const chromePath = process.env.FRAMESHIFT_CHROME ||
  (process.platform === 'darwin' ?
    '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome' :
    '/usr/bin/google-chrome');
if (!existsSync(chromePath)) throw new Error(`Set FRAMESHIFT_CHROME to a Chrome executable: ${chromePath}`);
const types = {
  '.html': 'text/html; charset=utf-8', '.css': 'text/css; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8', '.svg': 'image/svg+xml',
  '.jpg': 'image/jpeg',
};
const csp = readFileSync(join(output, '_headers'), 'utf8')
  .match(/Content-Security-Policy: (.+)/)?.[1];
assert.ok(csp);
const server = createServer((request, response) => {
  const pathname = decodeURIComponent(new URL(request.url, 'http://localhost').pathname);
  const target = resolve(output, `.${pathname === '/' ? '/index.html' : pathname}`);
  if (!target.startsWith(`${output}${sep}`) || basename(target).startsWith('_')) {
    response.writeHead(403).end();
    return;
  }
  try {
    const data = readFileSync(target);
    response.setHeader('Content-Type', types[extname(target)] || 'application/octet-stream');
    response.setHeader('Content-Security-Policy', csp);
    response.end(data);
  } catch {
    response.writeHead(404).end();
  }
});
const profile = mkdtempSync(join(tmpdir(), 'frameshift-guide-chrome-'));
let chrome;
let socket;

const delay = ms => new Promise(resolve => setTimeout(resolve, ms));
async function waitFor(check, description) {
  for (let attempt = 0; attempt < 100; attempt += 1) {
    const value = await check();
    if (value) return value;
    await delay(50);
  }
  throw new Error(`Timed out waiting for ${description}`);
}

try {
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  const url = `http://127.0.0.1:${server.address().port}/`;
  chrome = spawn(chromePath, [
    '--headless=new', '--no-first-run', '--disable-gpu',
    '--remote-debugging-port=0', `--user-data-dir=${profile}`, url,
  ], { stdio: 'ignore' });
  const activePort = join(profile, 'DevToolsActivePort');
  await waitFor(() => existsSync(activePort), 'Chrome DevTools port');
  const port = Number(readFileSync(activePort, 'utf8').split('\n')[0]);
  const pages = await (await fetch(`http://127.0.0.1:${port}/json`)).json();
  const page = pages.find(item => item.type === 'page' && item.url === url);
  assert.ok(page, 'Chrome opened the guide');
  socket = new WebSocket(page.webSocketDebuggerUrl);
  await new Promise((resolveOpen, reject) => {
    socket.addEventListener('open', resolveOpen, { once: true });
    socket.addEventListener('error', reject, { once: true });
  });
  let sequence = 0;
  const pending = new Map();
  const exceptions = [];
  socket.addEventListener('message', event => {
    const message = JSON.parse(event.data);
    if (message.method === 'Runtime.exceptionThrown') exceptions.push(message.params.exceptionDetails.text);
    if (!message.id) return;
    const item = pending.get(message.id);
    if (!item) return;
    pending.delete(message.id);
    if (message.error) item.reject(new Error(message.error.message));
    else item.resolve(message.result);
  });
  const command = (method, params = {}) => new Promise((resolveCommand, reject) => {
    const id = ++sequence;
    pending.set(id, { resolve: resolveCommand, reject });
    socket.send(JSON.stringify({ id, method, params }));
  });
  const evaluate = async expression => {
    const value = await command('Runtime.evaluate', {
      expression, returnByValue: true, awaitPromise: true,
    });
    if (value.exceptionDetails) throw new Error(value.exceptionDetails.text);
    return value.result.value;
  };
  const screenshot = async name => {
    const directory = process.env.FRAMESHIFT_GUIDE_SCREENSHOT_DIR;
    if (!directory) return;
    const result = await command('Page.captureScreenshot', {
      format: 'png', captureBeyondViewport: false,
    });
    writeFileSync(join(directory, name), Buffer.from(result.data, 'base64'));
  };
  const press = async (key, code, virtualKeyCode) => {
    await command('Input.dispatchKeyEvent', {
      type: 'keyDown', key, code, windowsVirtualKeyCode: virtualKeyCode,
    });
    await command('Input.dispatchKeyEvent', {
      type: 'keyUp', key, code, windowsVirtualKeyCode: virtualKeyCode,
    });
  };

  await command('Page.enable');
  await command('Runtime.enable');
  await command('Emulation.setDeviceMetricsOverride', {
    width: 1440, height: 1200, deviceScaleFactor: 1, mobile: false,
  });
  await command('Page.reload');
  await waitFor(() => evaluate('document.querySelector("#profile-result")?.textContent'), 'desktop guide');
  await screenshot('Frameshift-guide-desktop.png');
  await command('Emulation.setDeviceMetricsOverride', {
    width: 390, height: 844, deviceScaleFactor: 1, mobile: true,
  });
  await command('Page.reload');
  await waitFor(() => evaluate('document.querySelector("#profile-result")?.textContent'), 'guide hydration');
  const widths = await evaluate('({viewport:innerWidth,document:document.documentElement.scrollWidth})');
  assert.equal(widths.document, widths.viewport, 'mobile has no horizontal overflow');
  assert.match(await evaluate('document.querySelector("#profile-result").textContent'), /not yet supported/);
  const accessibility = await command('Accessibility.getFullAXTree');
  const interactiveRoles = new Set(['button', 'link', 'textField', 'spinButton', 'comboBox']);
  const unnamed = accessibility.nodes.filter(node =>
    !node.ignored && interactiveRoles.has(node.role?.value) &&
    !String(node.name?.value || '').trim()
  );
  assert.deepEqual(unnamed.map(node => node.role?.value), [], 'interactive controls have names');
  await screenshot('Frameshift-guide-mobile.png');

  await evaluate('document.querySelector("[data-kind=photo]").focus()');
  await press(' ', 'Space', 32);
  assert.equal(
    await evaluate('document.querySelector("[data-kind=photo]").getAttribute("aria-pressed")'),
    'true'
  );
  await evaluate('document.querySelector("#queue").focus()');
  await press(' ', 'Space', 32);
  await evaluate('document.querySelector("[data-event=loss]").click()');
  assert.equal(
    await evaluate('document.querySelector("#handoff").getAttribute("href")'),
    'frameshift://setup?v=1&class=photo&profile=photo-srgb-rgb24'
  );
  assert.equal(await evaluate('document.querySelector("#current").textContent'), 'Previous still');
  assert.match(await evaluate('document.querySelector("#desired").textContent'), /pending/);
  await evaluate('document.querySelector("[data-event=version]").click();document.querySelector("[data-event=digest]").click();document.querySelector("[data-event=unknown]").click()');
  assert.equal(await evaluate('document.querySelector("#current").textContent'), 'Previous still');
  await evaluate('document.querySelector("[data-event=confirm]").click()');
  assert.equal(await evaluate('document.querySelector("#current").textContent'), 'Still 1');
  assert.equal(await evaluate('document.querySelector("#desired").textContent'), 'None queued');

  const root = await command('DOM.getDocument');
  const input = await command('DOM.querySelector', { nodeId: root.root.nodeId, selector: '#sample' });
  const invalidFile = join(profile, 'invalid.txt');
  writeFileSync(invalidFile, 'not an image');
  await command('DOM.setFileInputFiles', { nodeId: input.nodeId, files: [invalidFile] });
  await waitFor(() => evaluate('document.querySelector("#sample-detail").textContent.includes("Choose a PNG")'), 'invalid file refusal');
  assert.equal(await evaluate('document.querySelector("#preview").hidden'), true);
  const largeFile = join(profile, 'large.png');
  writeFileSync(largeFile, Buffer.alloc(8 * 1024 * 1024 + 1));
  await command('DOM.setFileInputFiles', { nodeId: input.nodeId, files: [largeFile] });
  assert.match(await evaluate('document.querySelector("#sample-detail").textContent'), /8 MiB/);
  await command('DOM.setFileInputFiles', {
    nodeId: input.nodeId, files: [join(guide, 'src/assets/photo.jpg')],
  });
  await waitFor(() => evaluate('!document.querySelector("#preview").hidden'), 'local preview');
  await evaluate('document.querySelector("#lab").scrollIntoView({behavior:"instant"})');
  await screenshot('Frameshift-guide-lab-mobile.png');
  await command('Emulation.setDeviceMetricsOverride', {
    width: 1440, height: 1100, deviceScaleFactor: 1, mobile: false,
  });
  await evaluate('document.querySelector("#lab").scrollIntoView({behavior:"instant"})');
  await screenshot('Frameshift-guide-lab-desktop.png');
  assert.deepEqual(exceptions, []);
  await new Promise(resolveClose => server.close(resolveClose));
  await evaluate('document.querySelector("#reset").click();document.querySelector("#queue").click();document.querySelector("[data-event=confirm]").click()');
  assert.equal(await evaluate('document.querySelector("#current").textContent'), 'Still 1');
  console.log('Chrome guide smoke passed: layout, accessible names, keyboard, file bounds, transfer recovery, and offline interaction.');
} finally {
  if (socket) socket.close();
  if (chrome && chrome.exitCode === null && chrome.signalCode === null) {
    await new Promise(resolveExit => {
      chrome.once('exit', resolveExit);
      chrome.kill();
    });
  }
  if (server.listening) await new Promise(resolveClose => server.close(resolveClose));
  rmSync(profile, { recursive: true, force: true, maxRetries: 10, retryDelay: 100 });
}
