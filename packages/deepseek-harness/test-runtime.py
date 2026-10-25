"""Keyless checks of the installed CLI, native PTY, and an actual Web response."""
import http.cookiejar
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import time
import urllib.request

command, runtime, node = sys.argv[1:]
with tempfile.TemporaryDirectory(prefix="dsh-runtime-check-") as temporary:
    env = dict(os.environ, HOME=temporary, DSH_HOME=str(Path(temporary) / "dsh"), DSH_TELEMETRY_MODE="DISABLED")
    for args in [["--version"], ["--help"], ["--profile", "headless", "--dump-config"]]:
        subprocess.run([command, *args], env=env, check=True, timeout=30, stdout=subprocess.DEVNULL)
    script = r"""
      const {createRequire} = require('node:module');
      const r = createRequire(process.argv[1] + '/package.json');
      r('koffi'); r('node-addon-require-builtin');
      const p = r('node-pty').spawn(process.env.SHELL, ['-c', 'printf nix-dsh-pty-ok'], {cols:80,rows:24});
      let text = ''; const timeout = setTimeout(() => {p.kill();process.exit(1)}, 5000);
      p.onData(x => text += x);
      p.onExit(({exitCode}) => {clearTimeout(timeout);process.exit(exitCode === 0 && text.includes('nix-dsh-pty-ok') ? 0 : 1)});
    """
    subprocess.run([node, "-e", script, runtime], env=env, check=True, timeout=15)
    log = Path(temporary) / "web.log"
    browser = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()))
    with log.open("w") as output:
        process = subprocess.Popen([command, "web", "--host", "127.0.0.1", "--port", "0", "--no-open"], env=env, stdout=output, stderr=subprocess.STDOUT, start_new_session=True)
        try:
            deadline = time.monotonic() + 45
            while time.monotonic() < deadline:
                text = log.read_text()
                match = re.search(r"https?://127\.0\.0\.1:\d+[^\s]*", text)
                if match:
                    with browser.open(match.group(0), timeout=5) as response:
                        assert response.status == 200
                        assert b"<html" in response.read().lower()
                    break
                if process.poll() is not None:
                    raise RuntimeError(text)
                time.sleep(0.2)
            else:
                raise TimeoutError(log.read_text())
        finally:
            process.terminate()
            try:
                process.wait(timeout=10)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
    print("PASS installed CLI, composed profile, native PTY, and Web HTTP response")
