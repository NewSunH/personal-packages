"""Check that seeding preserves user edits, symlinks, modes, and retries failed input."""
import json
from pathlib import Path
import stat
import subprocess
import sys
import tempfile

script = Path(__file__).with_name("seed-config.py")
with tempfile.TemporaryDirectory() as temporary:
    root = Path(temporary)
    source = root / "source.yml"
    source.write_text("[]\n")
    target = root / "profile" / "cordis.patch.yml"
    manifest = root / "seeds.json"
    manifest.write_text(json.dumps([dict(source=str(source), target=str(target))]))
    def seed():
        return subprocess.run([sys.executable, str(script), str(manifest)], capture_output=True)
    assert seed().returncode == 0
    assert target.read_text() == "[]\n"
    assert stat.S_IMODE(target.stat().st_mode) == 0o600
    target.write_text("# edited by application\n")
    source.write_text("# new generation\n")
    assert seed().returncode == 0
    assert target.read_text() == "# edited by application\n"
    target.unlink()
    target.symlink_to(root / "missing-target")
    assert seed().returncode == 0 and target.is_symlink()
    target.unlink()
    source.unlink()
    assert seed().returncode != 0 and not target.exists()
    print("PASS seed initialization, file permissions, user edits, dangling links and failed-input recovery")
