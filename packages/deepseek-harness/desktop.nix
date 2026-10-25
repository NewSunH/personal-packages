{
  lib,
  stdenv,
  callPackage,
  electron_44,
  node-gyp,
  python3,
  nodejs_24,
  pnpm_11,
  makeWrapper,
  makeDesktopItem,
  copyDesktopItems,
  autoPatchelfHook,
  xdg-user-dirs,
  pkg-config,
  vips,
  glib,
}:
let
  workspace = callPackage ./runtime.nix { };
  electron = electron_44;
  pnpm = pnpm_11.override { nodejs-slim = nodejs_24; };
  python = python3.withPackages (
    ps: with ps; [
      numpy
      pandas
      python-docx
      python-pptx
      openpyxl
      pillow
      lxml
      xlsxwriter
    ]
  );
in
stdenv.mkDerivation (finalAttrs: {
  pname = "deepseek-harness-desktop";
  inherit (workspace) version;
  dontUnpack = true;
  nativeBuildInputs = [
    nodejs_24
    node-gyp
    python3
    makeWrapper
    copyDesktopItems
    autoPatchelfHook
    pkg-config
  ];
  buildInputs = [
    stdenv.cc.cc.lib
    vips
  ];
  installPhase = ''
    runHook preInstall
    mkdir -p "$out/lib" "$out/bin" "$out/share/icons/hicolor/1024x1024/apps"
    cp -a ${workspace.desktop}/lib/. "$out/lib/"
    chmod -R u+w "$out/lib"
    app="$out/lib/deepseek-harness-desktop"
    runtime="$out/lib/deepseek-harness-runtime"
    electron_node_version=$(ELECTRON_RUN_AS_NODE=1 ${lib.getExe electron} -p process.versions.node)
    ${python3}/bin/python3 - "$runtime/desktop-runtime.json" "$electron_node_version" <<'PY'
    import json, sys
    filename, node_version = sys.argv[1:]
    with open(filename) as source:
        descriptor = json.load(source)
    descriptor['release']['nodeVersion'] = node_version
    descriptor['release']['pnpmVersion'] = '${pnpm.version}'
    with open(filename, 'w') as output:
        json.dump(descriptor, output, indent=2)
    PY
    resources="$out/lib/runtime"
    primary="$resources/primary-runtime"
    mkdir -p "$primary/dependencies/python/bin" "$primary/dependencies/python/lib" \
      "$primary/dependencies/node/bin" "$primary/dependencies/node/node_modules"
    makeWrapper ${python}/bin/python3 "$primary/dependencies/python/bin/python3"
    mkdir -p "$primary/dependencies/python/lib/python${python3.pythonVersion}"
    ln -s ${python}/${python3.sitePackages} "$primary/dependencies/python/lib/python${python3.pythonVersion}/site-packages"
    ln -s ${nodejs_24}/bin/node "$primary/dependencies/node/bin/node"
    ln -s ${pnpm}/libexec/pnpm "$primary/dependencies/pnpm"
    ln -s "$runtime/node_modules/@deepseek-ai/dsh-skill-office/assets" "$resources/office-skills"
    ${python}/bin/python3 - "$primary/runtime.json" <<'PY'
    import importlib.metadata, json, sys
    distributions = {d.metadata['Name']: d.version for d in importlib.metadata.distributions() if d.metadata['Name']}
    with open(sys.argv[1], 'w') as output:
        json.dump(dict(desktopVersion='${finalAttrs.version}', platform='linux', arch='x64',
                       python='${python3.version}', node='${nodejs_24.version}', pnpm='${pnpm.version}',
                       pythonPackages=distributions), output)
    PY
    # node-pty uses V8 bindings: compile separately for Electron's ABI.
    export npm_config_nodedir=${electron.headers}
    for addon in "$runtime/node_modules/node-pty" "$app/node_modules/node-pty"; do
      if [ -d "$addon" ]; then
        # The Nix node-gyp wrapper overrides npm_config_nodedir; invoke its JS entry directly.
        (cd "$addon" && ${nodejs_24}/bin/node ${node-gyp}/lib/node_modules/node-gyp/bin/node-gyp.js rebuild --nodedir=${electron.headers})
        find "$addon/build" -type f ! -name '*.node' ! -name spawn-helper -delete
        find "$addon/build" -depth -type d -empty -delete
      fi
    done
    # Electron exports GLib symbols. The npm libvips payload contains another
    # GLib and crashes in sharp.metadata(); use the same shared libraries as
    # Electron instead. Build the addon against Electron's Node headers too.
    for modules in "$runtime/node_modules" "$app/node_modules"; do
      if [ -d "$modules/sharp" ]; then
        # SHARP_FORCE_GLOBAL_LIBVIPS skips sharp's own compatibility check.
        ${nodejs_24}/bin/node - "$modules/sharp" '${vips.version}' <<'JS'
    const root = process.argv[2];
    const version = process.argv[3];
    const required = require(root + '/package.json').config.libvips;
    const semver = require(require.resolve('semver', { paths: [root] }));
    if (!semver.satisfies(version, required)) {
      throw new Error(`Nixpkgs libvips ''${version} does not satisfy sharp's requirement ''${required}`);
    }
    JS
        (cd "$modules/sharp/src" && SHARP_FORCE_GLOBAL_LIBVIPS=1 \
          ${nodejs_24}/bin/node ${node-gyp}/lib/node_modules/node-gyp/bin/node-gyp.js \
          rebuild --nodedir=${electron.headers})
        rm -rf "$modules/@img/sharp-linux-x64" "$modules/@img/sharp-libvips-linux-x64"
        find "$modules/sharp/src/build" -type f ! -name '*.node' -delete
        find "$modules/sharp/src/build" -depth -type d -empty -delete
      fi
    done
    # Upstream's Windows artwork has the same whale and light background with
    # rounded corners. Reuse it for Linux instead of the square default artwork.
    cp "$app/resources/icon-windows.svg" "$app/resources/icon.svg"
    cp "$app/resources/icon-windows.png" "$app/resources/icon.png"
    cp "$app/resources/icon.png" "$out/share/icons/hicolor/1024x1024/apps/deepseek-harness.png"
    install -Dm644 "$app/resources/icon.svg" \
      "$out/share/icons/hicolor/scalable/apps/deepseek-harness.svg"
    # A real application resources tree makes Electron select packaged behavior.
    # Copy the executable (a symlink would resolve resources in the shared Electron).
    electron_dir="$out/lib/electron"
    mkdir -p "$electron_dir"
    cp -rs ${electron.unwrapped}/libexec/electron/. "$electron_dir/"
    find "$electron_dir" -type d -exec chmod u+w {} +
    rm "$electron_dir/electron" "$electron_dir/resources/default_app.asar"
    cp ${electron.unwrapped}/libexec/electron/electron "$electron_dir/deepseek-harness"
    ln -s "$app" "$electron_dir/resources/app"
    ln -s "$runtime" "$app/dsh"
    ln -s "$resources" "$electron_dir/resources/runtime"
    ln -s "$app/scripts/node-bin" "$resources/bin"
    ln -s "$app/resources/icon.png" "$electron_dir/resources/icon.png"
    # Retain nixpkgs' GTK, GIO and sandbox environment around our private executable.
    cp ${lib.getExe electron} "$out/bin/dsh-desktop"
    chmod u+w "$out/bin/dsh-desktop"
    substituteInPlace "$out/bin/dsh-desktop" \
      --replace-fail '${electron.unwrapped}/libexec/electron/electron' "$electron_dir/deepseek-harness"
    wrapProgram "$out/bin/dsh-desktop" \
      --set DSH_DESKTOP_DISABLE_UPDATES 1 \
      --prefix PATH : ${lib.makeBinPath [ xdg-user-dirs ]} \
      --prefix DSH_NIX_PATH_PREFIX : ${lib.makeBinPath [ xdg-user-dirs ]}
    runHook postInstall
  '';
  # Electron is already linked by nixpkgs, including libraries loaded with dlopen.
  # Recheck our native modules; preserve Electron's complete, known-good RUNPATH.
  dontAutoPatchelf = true;
  postFixup = ''
    autoPatchelf "$out/lib/deepseek-harness-runtime" "$out/lib/deepseek-harness-desktop"
    patchelf --set-rpath "$(patchelf --print-rpath ${electron.unwrapped}/libexec/electron/electron)" \
      "$out/lib/electron/deepseek-harness"
  '';
  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    ELECTRON_RUN_AS_NODE=1 "$out/lib/electron/deepseek-harness" \
      ${./test-sharp.cjs} "$out/lib/deepseek-harness-runtime/node_modules/sharp" \
      '${vips.version}' '${lib.getLib vips}' '${lib.getLib glib}'
    runHook postInstallCheck
  '';
  desktopItems = [
    (makeDesktopItem {
      name = "deepseek-harness";
      desktopName = "DeepSeek Harness";
      exec = "dsh-desktop %u";
      icon = "deepseek-harness";
      categories = [ "Development" ];
      mimeTypes = [ "x-scheme-handler/dsh" ];
      startupWMClass = "DeepSeek Harness";
    })
  ];
  passthru = { inherit workspace electron; };
  meta = workspace.meta // {
    description = "DeepSeek Harness desktop application (experimental Linux packaging)";
    mainProgram = "dsh-desktop";
  };
})
