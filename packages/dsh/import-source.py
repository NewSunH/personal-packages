#!/usr/bin/env python3
"""Import only deployment inputs, never credentials, sessions or node_modules."""
import json
from pathlib import Path
import shutil
import subprocess
import sys

deployment = Path(sys.argv[1]).resolve()
destination = Path(__file__).resolve().parent / "source"
files = []
preserved = []
for profile in ("web", "dsh-tui"):
    preserved += [f".runtime/dsh/profiles/{profile}/{name}" for name in
              ("package.json", "pnpm-lock.yaml", "pnpm-workspace.yaml")]
for directory in ("config", "skills"):
    files += subprocess.check_output(
        ["git", "-C", str(deployment), "ls-files", directory], text=True).splitlines()
vendor = "vendor/dsh-notify-on-complete"
files += [f"{vendor}/{name}" for name in subprocess.check_output(
    ["git", "-C", str(deployment / vendor), "ls-files"], text=True).splitlines()]
for name in files:
    target = destination / name
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(deployment / name, target)
previous_metadata = destination.parent / "source.json"
if previous_metadata.exists():
    previous_files = json.loads(previous_metadata.read_text())["files"]
    for name in set(previous_files) - set(files) - set(preserved):
        stale = destination / name
        if stale.resolve().is_relative_to(destination.resolve()):
            stale.unlink(missing_ok=True)
metadata = {
    "repository": "https://github.com/NewSunH/dsh-deploy",
    "revision": subprocess.check_output(
        ["git", "-C", str(deployment), "rev-parse", "HEAD"], text=True).strip(),
    "notificationRevision": subprocess.check_output(
        ["git", "-C", str(deployment / vendor), "rev-parse", "HEAD"], text=True).strip(),
    "coreVersion": "0.2.1-rc.3",
    "tuiVersion": "0.17.0",
    "files": sorted(files + preserved),
}
(destination.parent / "source.json").write_text(json.dumps(metadata, indent=2) + "\n")
print(f"Imported {len(files)} explicitly selected files into {destination}")
