// Run with Node 24: node test-desktop.mjs <desktop-package> <xvfb-run> [window-manager]
import { spawn } from 'node:child_process';
import { createServer } from 'node:net';
import { cpSync, rmSync, mkdtempSync, mkdirSync, openSync, readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import { setTimeout as delay } from 'node:timers/promises';

const [desktop, xvfb, windowManager] = process.argv.slice(2);
const temporary = mkdtempSync(join(tmpdir(), 'dsh-desktop-smoke-'));
mkdirSync(join(temporary, 'runtime'), { mode: 0o700 });
mkdirSync(join(temporary, 'config'));
mkdirSync(join(temporary, 'Documents'));
if (process.env.DSH_SMOKE_SEED_HOME) {
  cpSync(process.env.DSH_SMOKE_SEED_HOME, join(temporary, 'dsh'), { recursive: true });
  // Qualify imported state without using a real account token in the test instance.
  rmSync(join(temporary, 'dsh/.credentials.yaml'), { force: true });
}
writeFileSync(join(temporary, 'config/user-dirs.dirs'), `XDG_DOCUMENTS_DIR="${temporary}/Documents"\n`);
async function freePort() {
  const server = createServer();
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  const port = server.address().port;
  await new Promise(resolve => server.close(resolve));
  return port;
}
const port = await freePort();
const inspectorPort = await freePort();
const integrated = process.env.DSH_DESKTOP_TITLEBAR !== 'native';
const log = join(temporary, 'desktop.log');
const descriptor = openSync(log, 'w');
const application = [`${desktop}/bin/dsh-desktop`, `--remote-debugging-port=${port}`, `--inspect=127.0.0.1:${inspectorPort}`, '--ozone-platform=x11', '--disable-gpu'];
const displayCommand = windowManager
  ? ['/bin/sh', '-c', '"$1" >"$DSH_SMOKE_WM_LOG" 2>&1 & shift; exec "$@"', 'dsh-smoke', windowManager, ...application]
  : application;
const child = spawn(xvfb, ['-a', ...displayCommand], {
  detached: true, stdio: ['ignore', descriptor, descriptor],
  env: { ...process.env, HOME: temporary, XDG_CONFIG_HOME: join(temporary, 'config'),
    XDG_RUNTIME_DIR: join(temporary, 'runtime'), DSH_HOME: join(temporary, 'dsh'),
    DSH_SMOKE_WM_LOG: join(temporary, 'window-manager.log'), DSH_TELEMETRY_MODE: 'DISABLED', DEEPSEEK_API_KEY: '', WAYLAND_DISPLAY: '', LANG: 'en_US.UTF-8', LANGUAGE: 'en' },
});
const sockets = [];
async function until(operation, description, milliseconds = 60000) {
  const deadline = Date.now() + milliseconds;
  let error;
  while (Date.now() < deadline) {
    if (child.exitCode !== null) throw new Error(`Desktop exited ${child.exitCode}: ${readFileSync(log, 'utf8')}`);
    try { const value = await operation(); if (value) return value; } catch (failure) { error = failure; }
    await delay(250);
  }
  throw new Error(`Timed out waiting for ${description}: ${error ?? ''}\n${readFileSync(log, 'utf8')}`);
}
async function pages() { return (await fetch(`http://127.0.0.1:${port}/json/list`)).json(); }
async function connect(page) {
  const socket = new WebSocket(page.webSocketDebuggerUrl);
  sockets.push(socket);
  await new Promise((resolve, reject) => { socket.addEventListener('open', resolve, { once: true }); socket.addEventListener('error', reject, { once: true }); });
  let next = 0;
  const pending = new Map();
  socket.addEventListener('message', event => {
    const response = JSON.parse(event.data);
    const entry = pending.get(response.id);
    if (!entry) return;
    pending.delete(response.id);
    if (response.error) entry.reject(new Error(JSON.stringify(response.error))); else entry.resolve(response.result);
  });
  const send = (method, params) => new Promise((resolve, reject) => {
    const id = ++next;
    pending.set(id, { resolve, reject });
    socket.send(JSON.stringify({ id, method, params }));
  });
  return {
    send,
    evaluate: async expression => {
      const response = await send('Runtime.evaluate', { expression, returnByValue: true, awaitPromise: true });
      if (response.exceptionDetails) throw new Error(JSON.stringify(response.exceptionDetails));
      return response.result.value;
    },
  };
}
try {
  const inspector = await until(async () => (await (await fetch(`http://127.0.0.1:${inspectorPort}/json/list`)).json())[0], 'main process inspector');
  const mainProcess = await connect(inspector);
  const state = await until(() => mainProcess.evaluate(`(() => {
    const electron = process.getBuiltinModule('module').createRequire(process.execPath)('electron');
    if (!electron.Menu.getApplicationMenu() || !electron.BrowserWindow.getAllWindows().some(window => window.webContents.getURL().includes('welcome'))) return false;
    globalThis.__dshTestElectron = electron;
    return { platform: process.platform, packaged: electron.app.isPackaged,
      version: electron.app.getVersion(), visibleNativeMenus: electron.Menu.getApplicationMenu().items.filter(item => item.visible).length };
  })()`), 'application menu installation');
  if (state.platform !== 'linux' || !state.packaged || state.version !== '0.2.1-rc.3') throw new Error(JSON.stringify(state));
  if (integrated ? state.visibleNativeMenus !== 0 : state.visibleNativeMenus === 0) throw new Error(JSON.stringify(state));
  writeFileSync(join(temporary, 'package-state.json'), JSON.stringify(state, null, 2));
  const welcome = await until(async () => (await pages()).find(page => page.type === 'page' && page.url.includes('welcome')), 'welcome window');
  const welcomeClient = await connect(welcome);
  const welcomeText = await until(() => welcomeClient.evaluate('document.body?.innerText'), 'welcome content');
  writeFileSync(join(temporary, 'welcome.txt'), welcomeText);
  await until(() => welcomeClient.evaluate(`(() => {
    const button = [...document.querySelectorAll('button')].find(b => /set up later|稍后设置|稍后/i.test(b.innerText));
    if (!button) return false; button.click(); return true;
  })()`), 'Set up later button');
  const main = await until(async () => (await pages()).find(page => page.type === 'page' && page.url.startsWith('dsh-app://app')), 'main application');
  const mainClient = await connect(main);
  const text = await until(async () => {
    const body = await mainClient.evaluate('document.body?.innerText ?? ""');
    return body.length > 80 && !/^loading/i.test(body.trim()) ? body : false;
  }, 'rendered workspace', 90000);
  await until(() => {
    const state = JSON.parse(readFileSync(join(temporary, 'dsh/storages/workspace.json'), 'utf8'));
    return state.global.workspaceIds.length > 0;
  }, 'default workspace creation');
  const caption = await until(() => mainClient.evaluate(`(() => {
    const host = document.querySelector('[data-caption-menu]');
    return { marked: document.documentElement.hasAttribute('data-integrated-titlebar'),
      platform: document.documentElement.dataset.platform,
      buttons: host ? [...host.shadowRoot.querySelectorAll('button')].map(button => button.textContent) : [],
      draggable: [...document.querySelectorAll('[data-shell-overlay]')].some(element => getComputedStyle(element.parentElement, '::before').getPropertyValue('-webkit-app-region') === 'drag') };
  })()`), 'caption state');
  if (caption.platform !== 'linux' || caption.marked !== integrated || (integrated && (caption.buttons.length !== 2 || !caption.draggable))) throw new Error(JSON.stringify(caption));
  if (integrated) {
    // Capture the real validated renderer -> main IPC menu without blocking on a popup.
    await mainProcess.evaluate(`(() => {
      const { Menu } = globalThis.__dshTestElectron;
      globalThis.__dshTestPopup = Menu.prototype.popup;
      Menu.prototype.popup = function(options) {
        globalThis.__dshTestMenu = this.items.map(item => ({ label: item.label, role: item.role, type: item.type }));
        options.callback?.();
      };
    })()`);
    await mainClient.evaluate(`document.querySelector('[data-caption-menu]').shadowRoot.querySelector('button').click()`);
    const menu = await until(() => mainProcess.evaluate('globalThis.__dshTestMenu'), 'caption menu IPC');
    await mainProcess.evaluate('globalThis.__dshTestElectron.Menu.prototype.popup = globalThis.__dshTestPopup');
    if (menu.some(item => /reload|restart|updates|重载|重启|更新/i.test(item.label))) throw new Error(JSON.stringify(menu));
    if (!menu.some(item => item.role === 'about') || !menu.some(item => item.role === 'quit')) throw new Error(JSON.stringify(menu));
    writeFileSync(join(temporary, 'application-menu.json'), JSON.stringify(menu, null, 2));
  }
  if (windowManager) {
    await mainProcess.evaluate(`globalThis.__dshTestWindow = globalThis.__dshTestElectron.BrowserWindow.getAllWindows().find(window => window.webContents.getURL().startsWith('dsh-app://app'))`);
    for (const [operation, status, expected] of [
      ['maximize()', 'isMaximized()', true], ['unmaximize()', 'isMaximized()', false],
      ['minimize()', 'isMinimized()', true], ['restore()', 'isMinimized()', false],
      ['setFullScreen(true)', 'isFullScreen()', true],
    ]) {
      await mainProcess.evaluate(`globalThis.__dshTestWindow.${operation}`);
      await until(async () => await mainProcess.evaluate(`globalThis.__dshTestWindow.${status}`) === expected, operation);
    }
    if (integrated) await until(() => mainClient.evaluate('document.documentElement.hasAttribute("data-fullscreen")'), 'fullscreen renderer notification');
    await mainProcess.evaluate('globalThis.__dshTestWindow.setFullScreen(false)');
    await until(async () => !await mainProcess.evaluate('globalThis.__dshTestWindow.isFullScreen()'), 'exit fullscreen');
    if (integrated) await until(async () => !await mainClient.evaluate('document.documentElement.hasAttribute("data-fullscreen")'), 'exit fullscreen renderer notification');
    writeFileSync(join(temporary, 'window-controls.txt'), 'PASS maximize, unmaximize, minimize, restore, enter/leave fullscreen and renderer notification\n');
  }
  writeFileSync(join(temporary, 'caption-state.json'), JSON.stringify(caption, null, 2));
  writeFileSync(join(temporary, 'workspace.txt'), await mainClient.evaluate('document.body.innerText'));
  const screenshot = await mainClient.send('Page.captureScreenshot', { format: 'png' });
  writeFileSync(join(temporary, 'workspace.png'), Buffer.from(screenshot.data, 'base64'));
  if (/ERR_MODULE_NOT_FOUND|NODE_MODULE_VERSION|Nix-managed file/.test(readFileSync(log, 'utf8'))) throw new Error(readFileSync(log, 'utf8'));
  console.log(`PASS packaged Linux app, caption/menu IPC, Electron welcome, Desktop Host and workspace; artifacts: ${temporary}`);
} catch (error) {
  console.error(`Artifacts: ${temporary}`);
  throw error;
} finally {
  for (const socket of sockets) socket.close();
  try { process.kill(-child.pid, 'SIGTERM'); } catch (error) { if (error.code !== 'ESRCH') throw error; }
  await Promise.race([new Promise(resolve => child.once('exit', resolve)), delay(5000)]);
  try { process.kill(-child.pid, 'SIGKILL'); } catch (error) { if (error.code !== 'ESRCH') throw error; }
}
