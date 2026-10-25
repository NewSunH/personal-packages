// Opening a saved conversation probes attachment metadata under the Host's
// Electron Node runtime. PNG encoding alone does not reproduce the GLib crash.
const assert = require('node:assert/strict');
const path = require('node:path');
const { readFileSync } = require('node:fs');
const sharpRoot = process.argv[2];
const [vipsVersion, vipsRoot, glibRoot] = process.argv.slice(3);
const sharp = require(sharpRoot);

async function main() {
  assert.ok(process.versions.electron, 'test must use the desktop Electron runtime');
  assert.ok(Object.keys(require.cache).some(file =>
    file.startsWith(path.join(sharpRoot, 'src/build/Release/')) && file.endsWith('.node')),
  'sharp must load its locally compiled addon');
  const source = { create: { width: 128, height: 96, channels: 4, background: '#123456' } };
  for (const format of ['png', 'jpeg', 'webp']) {
    const data = await sharp(source).toFormat(format).toBuffer();
    await Promise.all(Array.from({ length: 16 }, async () => {
      // Match dsh-attachment-local's read/probe options.
      const image = sharp(data, { failOn: 'error', limitInputPixels: false });
      const metadata = await image.metadata();
      assert.equal(metadata.format, format);
      assert.equal(metadata.width, 128);
      assert.equal(metadata.height, 96);
      await image.resize(64, 48).raw().toBuffer();
    }));
  }
  assert.equal(sharp.versions.vips, vipsVersion, 'sharp must use the pinned Nixpkgs libvips');
  const libraries = [...new Set(readFileSync('/proc/self/maps', 'utf8')
    .split('\n').map(line => line.trim().split(/\s+/).at(-1)))];
  for (const [name, root] of [['libvips-cpp.so', vipsRoot], ['libglib-2.0.so', glibRoot]]) {
    const loaded = libraries.filter(file => path.basename(file).startsWith(name));
    assert.equal(loaded.length, 1, `expected one shared ${name}`);
    assert.ok(loaded[0].startsWith(root + '/lib/'), `${name} must come from the pinned Nixpkgs library`);
  }
  console.log('Electron sharp attachment metadata/decode/resize: PASS');
}
main().catch(error => { console.error(error); process.exitCode = 1; });
