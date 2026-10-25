// pnpm owns external dependencies; fill only workspace runtime peers omitted by deploy.
import { cpSync, existsSync, globSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { spawnSync } from 'node:child_process';

const [cliOutput, desktopOutput] = process.argv.slice(2);
const root = process.cwd();
const workspace = new Map();
for (const filename of [
  ...globSync('vendor/*/package.json'),
  ...globSync('packages/*/*/package.json'),
  ...globSync('native/system/package.json'),
  ...globSync('native/system/packages/*/package.json'),
  ...globSync('apps/*/package.json'),
]) {
  const manifest = JSON.parse(readFileSync(filename));
  workspace.set(manifest.name, { manifest, directory: dirname(filename) });
}

function run(command, args, cwd = root) {
  const result = spawnSync(command, args, { cwd, stdio: 'inherit', env: { ...process.env, pnpm_config_ignore_scripts: 'true' } });
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error(`${command} exited ${result.status}: ${args.join(' ')}`);
}

const packs = resolve('.nix-packs');
mkdirSync(packs);
function pack(name, destination) {
  const entry = workspace.get(name);
  if (!entry) throw new Error(`Missing workspace package ${name}`);
  const archive = join(packs, name.replaceAll('/', '-').replaceAll('@', '') + '.tgz');
  if (!existsSync(archive)) run('pnpm', ['--dir', entry.directory, 'pack', '--out', archive]);
  mkdirSync(destination, { recursive: true });
  run('tar', ['-xzf', archive, '--strip-components=1', '-C', destination]);
}

function deploy(name, destination) {
  run('pnpm', ['--offline', '--ignore-scripts', '--filter', name, '--prod',
    '--config.inject-workspace-packages=true', '--config.node-linker=hoisted', 'deploy', destination]);
  pack(name, destination);
  const modules = join(destination, 'node_modules');
  const pending = [name];
  const visited = new Set();
  while (pending.length) {
    const current = pending.shift();
    if (visited.has(current)) continue;
    visited.add(current);
    const entry = workspace.get(current);
    if (!entry) continue;
    const dependencies = new Set(Object.keys(entry.manifest.dependencies ?? {}));
    for (const peer of Object.keys(entry.manifest.peerDependencies ?? {})) {
      if (!entry.manifest.peerDependenciesMeta?.[peer]?.optional) dependencies.add(peer);
    }
    for (const dependency of dependencies) {
      if (!workspace.has(dependency)) {
        if (!existsSync(join(modules, dependency))) throw new Error(`${current}: runtime dependency missing: ${dependency}`);
        continue;
      }
      if (!existsSync(join(modules, dependency))) pack(dependency, join(modules, dependency));
      pending.push(dependency);
    }
  }
  // Runtime metadata contains build-directory paths and is unnecessary after deployment.
  for (const file of ['.modules.yaml', '.pnpm/lock.yaml', '.pnpm-workspace-state-v1.json']) {
    rmSync(join(modules, file), { force: true });
  }
  const pty = join(modules, 'node-pty');
  if (existsSync(pty)) run('node-gyp', ['rebuild'], pty);
  const subprocess = join(modules, '@deepseek-ai/dsh-subprocess-local');
  if (existsSync(join(subprocess, 'scripts/ensure-spawn-helper.mjs'))) {
    run('node', ['scripts/ensure-spawn-helper.mjs'], subprocess);
  }
  return destination;
}

const cli = deploy('@deepseek-ai/dsh', join(cliOutput, 'lib', 'deepseek-harness'));
const host = deploy('@deepseek-ai/dsh-desktop-host', join(desktopOutput, 'lib', 'deepseek-harness-runtime'));
// The Host resolves the CLI from its installation anchor, not a user's profile.
if (!existsSync(join(host, 'node_modules', '@deepseek-ai', 'dsh'))) {
  pack('@deepseek-ai/dsh', join(host, 'node_modules', '@deepseek-ai', 'dsh'));
}
pack('@deepseek-ai/dsh-desktop-host', join(host, 'node_modules', '@deepseek-ai', 'dsh-desktop-host'));
const shell = deploy('@deepseek-ai/dsh-desktop', join(desktopOutput, 'lib', 'deepseek-harness-desktop'));
for (const path of ['lib', 'renderer', 'resources', 'scripts/node-bin']) {
  const source = join(root, 'apps', 'desktop', path);
  if (existsSync(source)) cpSync(source, join(shell, path), { recursive: true });
}
const { DESKTOP_HOST_PROTOCOL_VERSION } = await import(join(root, 'apps/desktop/src/host-protocol.ts'));
const { version } = JSON.parse(readFileSync(join(root, 'package.json')));
const sharedPackages = [...workspace.keys()].filter(name => existsSync(join(host, 'node_modules', name, 'package.json')))
  .map(name => ({ name, version: JSON.parse(readFileSync(join(host, 'node_modules', name, 'package.json'))).version, path: `node_modules/${name}` }));
writeFileSync(join(host, 'desktop-runtime.json'), JSON.stringify({
  schemaVersion: 1,
  release: { schemaVersion: 1, version, hostProtocolVersion: DESKTOP_HOST_PROTOCOL_VERSION,
    nodeVersion: process.versions.node, pnpmVersion: JSON.parse(readFileSync(join(root, 'node_modules/pnpm/package.json'))).version },
  platform: process.platform, arch: process.arch, sharedPackages, files: [],
}, null, 2));
