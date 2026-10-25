// Profile packages live outside DSH_HOME in the store. Node resolves imports
// from their real paths, so provide the installation fallback there as well
// as in DSH's writable runtime fallback directory.
import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';

const [installation, destination] = process.argv.slice(2);
const queue = [fs.realpathSync(installation)];
const seen = new Set();
while (queue.length) {
  const anchor = queue.shift();
  const manifest = JSON.parse(fs.readFileSync(anchor, 'utf8'));
  const require = createRequire(anchor);
  for (const name of Object.keys({ ...manifest.dependencies, ...manifest.peerDependencies })) {
    if (seen.has(name)) continue;
    seen.add(name);
    const directory = require.resolve.paths(name)?.map(base => path.join(base, name))
      .find(candidate => fs.existsSync(path.join(candidate, 'package.json')));
    if (!directory) continue;
    const link = path.join(destination, name);
    // Share the exact official core modules with every profile (Cordis singletons).
    if (name.startsWith('@deepseek-ai/') && fs.existsSync(link)) {
      fs.rmSync(link, { recursive: true, force: true });
    }
    if (!fs.existsSync(link)) {
      fs.mkdirSync(path.dirname(link), { recursive: true });
      fs.symlinkSync(fs.realpathSync(directory), link);
    }
    queue.push(path.join(fs.realpathSync(directory), 'package.json'));
  }
}
