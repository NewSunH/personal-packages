{
  lib,
  stdenv,
  callPackage,
  node-gyp,
  python3,
  nodejs_24,
  pnpm_11,
  pnpmConfigHook,
  autoPatchelfHook,
}:
let
  workspace = callPackage ./workspace.nix { };
  pnpm = pnpm_11.override { nodejs-slim = nodejs_24; };
in
stdenv.mkDerivation {
  pname = "deepseek-harness-runtime";
  inherit (workspace) version;
  outputs = [
    "out"
    "desktop"
  ];
  src = workspace;
  pnpmDeps = workspace.pnpmDeps;
  nativeBuildInputs = [
    nodejs_24
    node-gyp
    python3
    pnpm
    pnpmConfigHook
    autoPatchelfHook
  ];
  buildInputs = [ stdenv.cc.cc.lib ];
  env = {
    npm_config_nodedir = "${nodejs_24}";
    npm_config_build_from_source = "true";
    npm_config_manage_package_manager_versions = "false";
  };
  preConfigure = ''
    find . -name node_modules -prune -exec rm -rf {} +
    export HOME="$TMPDIR/deploy-home"
    mkdir -p "$HOME"
  '';
  buildPhase = ''
    node ${./deploy.mjs} "$out" "$desktop"
    for modules in \
      "$out/lib/deepseek-harness/node_modules" \
      "$desktop/lib/deepseek-harness-runtime/node_modules" \
      "$desktop/lib/deepseek-harness-desktop/node_modules"; do
      # This package targets glibc; Koffi also ships an unused musl binary.
      rm -rf "$modules/@koromix/koffi-linux-x64/musl_x64"
      if [ -d "$modules/node-pty/build" ]; then
        find "$modules/node-pty/build" -type f ! -name '*.node' ! -name spawn-helper -delete
        find "$modules/node-pty/build" -depth -type d -empty -delete
      fi
    done
  '';
  installPhase = "true";
  passthru = { inherit workspace; };
  meta = workspace.meta;
}
