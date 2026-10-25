"""Initialize application-owned configuration without replacing existing files or links."""
import json
import os
from pathlib import Path
import sys

for entry in json.loads(Path(sys.argv[1]).read_text()):
    target = Path(entry["target"])
    target.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    try:
        descriptor = os.open(target, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    except FileExistsError:
        continue
    try:
        with os.fdopen(descriptor, "wb") as output:
            output.write(Path(entry["source"]).read_bytes())
    except BaseException:
        target.unlink(missing_ok=True)
        raise
