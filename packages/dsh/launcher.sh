#!/usr/bin/env bash
set -euo pipefail
launcher="$1"
shift
export DSH_HOME="${DSH_HOME:-$HOME/.dsh}"
export DSH_TELEMETRY_MODE=DISABLED
umask 077
mkdir -p "$DSH_HOME"
# Initialize one generation at a time, including simultaneous Web/TUI starts.
(
  @flock@ -x 9
  @node@ @out@/libexec/init.mjs
) 9>"$DSH_HOME/.nix-init.lock"
if [[ "$launcher" == dsh && "${1:-}" == web ]]; then
  launcher=dsh-web
  shift
fi
if [[ "${1:-}" == plugin ]]; then
  printf '%s\n' 'Update packaged profiles through Nix; use a separate DSH_HOME with upstream dsh for mutable plugins.' >&2
  exit 2
fi
case "$launcher" in
  dsh-web)
    set -- web --host 127.0.0.1 --port "${DSH_WEB_PORT:-3080}" "$@"
    ;;
  dsh)
    case "${1:-}" in
      --profile|--profile=*) ;;
      *) set -- --profile dsh-tui "$@" ;;
    esac
    ;;
esac
exec @upstream@ "$@"
