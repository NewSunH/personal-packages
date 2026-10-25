import fs from 'node:fs';
import path from 'node:path';

const home = process.env.DSH_HOME;
const defaults = '@defaults@';
const exists = filename => {
  try { fs.lstatSync(filename); return true; } catch (error) { if (error.code !== 'ENOENT') throw error; return false; }
};
const link = (target, filename) => {
  const temporary = filename + '.nix-tmp';
  if (exists(temporary)) fs.unlinkSync(temporary);
  fs.symlinkSync(target, temporary);
  fs.renameSync(temporary, filename);
};
for (const [name, source] of [['dsh-tui', '@tui@'], ['web', '@web@']]) {
  const profile = path.join(home, 'profiles', name);
  fs.mkdirSync(profile, { recursive: true, mode: 0o700 });
  const manifest = path.join(profile, 'package.json');
  const modules = path.join(profile, 'node_modules');
  const marker = path.join(profile, '.nix-package');
  const previous = exists(marker) ? fs.readFileSync(marker, 'utf8') : undefined;
  if (!exists(manifest)) {
    if (exists(modules) && !(previous && fs.lstatSync(modules).isSymbolicLink() && fs.readlinkSync(modules) === path.join(previous, 'node_modules'))) throw new Error(`Existing unmanaged profile at ${profile}; migrate it before installing Nix profiles.`);
    link(path.join(source, 'package.json'), manifest);
    link(path.join(source, 'node_modules'), modules);
    fs.writeFileSync(marker, source, { mode: 0o600 });
  } else if (!fs.lstatSync(manifest).isSymbolicLink() || !fs.readlinkSync(manifest).startsWith('/nix/store/')) {
    throw new Error(`Existing unmanaged profile at ${profile}; migrate it before installing Nix profiles.`);
  } else if (fs.readlinkSync(manifest) === path.join(source, 'package.json')
    || previous && fs.readlinkSync(manifest) === path.join(previous, 'package.json')) {
    // Update only links this bootstrap owns. Repair interrupted generation changes.
    link(path.join(source, 'package.json'), manifest);
    if (!exists(modules) || fs.lstatSync(modules).isSymbolicLink()
      && [path.join(previous ?? source, 'node_modules'), path.join(source, 'node_modules')].includes(fs.readlinkSync(modules))) {
      link(path.join(source, 'node_modules'), modules);
    }
    fs.writeFileSync(marker, source, { mode: 0o600 });
  }
  const patch = path.join(profile, 'cordis.patch.yml');
  if (!exists(patch)) {
    const filename = `dsh-${name === 'web' ? 'web' : 'tui'}.patch.yml`;
    fs.writeFileSync(patch, fs.readFileSync(path.join(defaults, 'config', filename)), { mode: 0o600 });
  }
}
const skills = path.join(home, 'skills');
if (!exists(skills)) fs.symlinkSync(path.join(defaults, 'skills'), skills);
