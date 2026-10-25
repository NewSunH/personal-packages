"""Exercise the module's real links, plugin composition and package-write rejection."""
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

generation, executable = sys.argv[1:]
with tempfile.TemporaryDirectory(prefix="dsh-module-runtime-") as temporary:
    home = Path(temporary) / ".dsh"
    shutil.copytree(Path(generation) / "home-files/.dsh", home, symlinks=True)
    # Store directories are read-only; Home Manager creates writable home directories.
    for directory, _, _ in os.walk(home, followlinks=False):
        os.chmod(directory, 0o700)
    env = dict(os.environ, HOME=temporary, DSH_HOME=str(home), DSH_TELEMETRY_MODE="DISABLED")
    manifest = home / "profiles/web/package.json"
    modules = home / "profiles/web/node_modules"
    original_manifest = os.readlink(manifest)
    original_modules = os.readlink(modules)
    config = subprocess.run([executable, "--profile", "web", "--dump-config"], env=env, capture_output=True, text=True, timeout=30)
    assert config.returncode == 0, config.stderr
    assert "fixture" in config.stdout and "preference: zh" in config.stdout
    result = subprocess.run([executable, "plugin", "--profile", "web", "--version"], env=env, capture_output=True, text=True, timeout=30)
    assert result.returncode != 0 and "Nix-managed profile" in result.stderr, result.stderr
    assert os.readlink(manifest) == original_manifest
    assert os.readlink(modules) == original_modules
    print("PASS external YAML links, Nix plugin bundle composition and managed-profile package write protection")
