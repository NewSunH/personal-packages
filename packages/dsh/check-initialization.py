from pathlib import Path
import os
import subprocess
import sys
import tempfile

package = Path(sys.argv[1]).resolve()
with tempfile.TemporaryDirectory(prefix='dsh-init-check-') as temporary:
    root = Path(temporary)
    env = dict(os.environ, HOME=temporary, DSH_HOME=str(root / 'state'))
    command = [str(package / 'bin/dsh'), '--dump-config']
    processes = [subprocess.Popen(command, env=env, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE) for _ in range(2)]
    for process in processes:
        _, errors = process.communicate(timeout=30)
        assert process.returncode == 0, errors.decode()
    profile = root / 'state/profiles/dsh-tui'
    assert (profile / 'package.json').is_symlink()
    assert (profile / 'node_modules').is_symlink()
    # Simulate a generation change interrupted between the manifest and module links.
    (profile / '.nix-package').write_text('/nix/store/retired-profile/lib/dsh')
    (profile / 'node_modules').unlink()
    (profile / 'node_modules').symlink_to('/nix/store/retired-profile/lib/dsh/node_modules')
    subprocess.run(command, env=env, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, check=True)
    assert (profile / 'node_modules').is_dir()
    runtime = profile / 'cordis.patch.yml'
    runtime.write_text(runtime.read_text() + '\n# application preference\n')
    subprocess.run(command, env=env, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, check=True)
    assert '# application preference' in runtime.read_text()
    skills = root / 'state/skills'
    skills.unlink()
    custom = root / 'custom-skills'
    custom.mkdir()
    skills.symlink_to(custom)
    subprocess.run(command, env=env, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, check=True)
    assert skills.resolve() == custom
    result = subprocess.run([str(package / 'bin/dsh'), 'plugin', '--profile', 'dsh-tui', '--version'], env=env, capture_output=True)
    assert result.returncode != 0
    old = root / 'old/profiles/dsh-tui'
    (old / 'node_modules').mkdir(parents=True)
    manifest = old / 'package.json'
    manifest.write_text('{"preserve":true}\n')
    result = subprocess.run(command, env=dict(env, DSH_HOME=str(root / 'old')), capture_output=True)
    assert result.returncode != 0 and b'Existing unmanaged profile' in result.stderr
    assert manifest.read_text() == '{"preserve":true}\n'
    print('PASS concurrent bootstrap, immutable plugins, writable preferences, custom skills, existing-profile protection')
