{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchPnpmDeps,
  pnpmConfigHook,
  pnpm_11,
  nodejs_24,
  node-gyp,
  python3,
  pkg-config,
  cmake,
  git,
  bashInteractive,
  pkgsStatic,
}:
let
  pnpm = pnpm_11.override { nodejs-slim = nodejs_24; };
in
stdenv.mkDerivation (finalAttrs: {
  pname = "deepseek-harness-workspace";
  version = "0.2.1-rc.3";
  src = fetchFromGitHub {
    owner = "deepseek-ai";
    repo = "deepseek-harness";
    tag = "dsh-v${finalAttrs.version}";
    hash = "sha256-wNwpit8WCjltafq+1JFTTFFbH05No60ImlmoJpVz2RQ=";
  };
  patches = [
    ./patches/0001-profile-resolution.patch
    ./patches/0002-preserve-managed-links.patch
    ./patches/0003-runtime-in-place.patch
    ./patches/0004-managed-profile-packages.patch
    ./patches/0005-desktop-tool-path.patch
    ./patches/0006-integrated-caption.patch
    ./patches/0007-distribution-updates.patch
  ];
  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    inherit pnpm;
    fetcherVersion = 4;
    hash = "sha256-C9Aw9AS4r7zubaEuT6mLXQ+AhhMVlTxPZRKTpzRUkcU=";
  };
  nativeBuildInputs = [
    nodejs_24
    node-gyp
    pnpm
    pnpmConfigHook
    python3
    pkg-config
    cmake
    git
  ];
  buildInputs = [ stdenv.cc.cc.lib ];
  dontUseCmakeConfigure = true;
  dontFixup = true;
  env = {
    ELECTRON_SKIP_BINARY_DOWNLOAD = "1";
    npm_config_nodedir = "${nodejs_24}";
    npm_config_build_from_source = "true";
    DSH_GATE_CONCURRENCY = "2";
  };
  preConfigure = ''
    export HOME="$TMPDIR/build-home"
    mkdir -p "$HOME"
  '';
  postPatch = ''
    substituteInPlace package.json \
      --replace-fail "tsx native/system/scripts/build.ts --host-addon-only" "tsx native/system/scripts/build.ts"
    substituteInPlace native/system/scripts/build.ts \
      --replace-fail "'musl-gcc'" "'${lib.getExe pkgsStatic.stdenv.cc}'"
    substituteInPlace packages/terminal/terminal-bash/src/config.ts \
      --replace-fail "DEFAULT_BASH_SHELL = '/bin/bash'" "DEFAULT_BASH_SHELL = '${lib.getExe bashInteractive}'"
  '';
  buildPhase = ''
    runHook preBuild
    export DSH_CLIENT_COMMIT_HASH="1f81c047fc48fa190a683e469daa699857e9afe8"
    pnpm rebuild node-pty
    pnpm run build:artifacts
    pnpm run build:check
    env -u DSH_CLIENT_COMMIT_HASH pnpm exec vitest run \
      apps/desktop/tests/caption-layout.spec.ts \
      apps/desktop/tests/preload-menu.client.spec.ts \
      apps/desktop/tests/preload-windows.client.spec.ts \
      apps/desktop/tests/preload-app.spec.ts \
      apps/desktop/tests/main-startup.spec.ts \
      packages/client/ui-layout/tests/app-frame.client.spec.tsx \
      packages/client/ui-sidebar/tests/sidebar-root.client.spec.tsx \
      packages/client/ui-dockkit/tests/components.client.spec.tsx
    runHook postBuild
  '';
  installPhase = ''
    runHook preInstall
    mkdir -p "$out"
    cp -a . "$out/"
    runHook postInstall
  '';
  passthru = {
    inherit pnpm;
    nodejs = nodejs_24;
  };
  meta = {
    description = "Built official DeepSeek Harness CLI and desktop resources";
    homepage = "https://github.com/deepseek-ai/deepseek-harness";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [
      fromSource
      binaryNativeCode
    ];
    platforms = [ "x86_64-linux" ];
  };
})
