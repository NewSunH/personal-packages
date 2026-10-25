{
  lib,
  stdenv,
  stdenvNoCC,
  callPackage,
  nodejs_24,
  pnpm_11,
  fetchPnpmDeps,
  pnpmConfigHook,
  python3,
  makeWrapper,
  util-linux,
  libnotify,
  autoPatchelfHook,
  node-gyp,
  coreutils,
}:
let
  upstream = callPackage ../deepseek-harness/package.nix { };
  version = upstream.version;
  nodejs = nodejs_24;
  packageManager = pnpm_11.override { nodejs-slim = nodejs; };
  hashes = builtins.fromJSON (builtins.readFile ./deps.json);
  buildProject =
    name: directory: extraBuild: extraInstall:
    stdenv.mkDerivation {
      pname = "dsh-${name}";
      inherit version;
      src = ./source;
      postUnpack = ''sourceRoot="$sourceRoot/${directory}"'';
      pnpmDeps = fetchPnpmDeps {
        pnpm = packageManager;
        pname = "dsh-${name}";
        inherit version;
        src = ./source;
        postUnpack = ''sourceRoot="$sourceRoot/${directory}"'';
        fetcherVersion = 4;
        hash = hashes.${name};
      };
      nativeBuildInputs = [
        nodejs
        node-gyp
        packageManager
        pnpmConfigHook
        python3
        autoPatchelfHook
      ];
      buildInputs = [ stdenv.cc.cc.lib ];
      env.npm_config_nodedir = "${nodejs}";
      env.npm_config_build_from_source = "true";
      buildPhase = ''
        runHook preBuild
        if [ -d node_modules/node-pty ]; then
          (cd node_modules/node-pty && npm run install --offline)
        fi
        ${extraBuild}
        runHook postBuild
      '';
      installPhase = ''
        runHook preInstall
        mkdir -p "$out/lib/dsh"
        cp -a node_modules package.json "$out/lib/dsh/"
        ${extraInstall}
        runHook postInstall
      '';
    };
  notification =
    buildProject "notification" "vendor/dsh-notify-on-complete" "pnpm run build"
      ''cp -a lib cordis.patch.yml LICENSE "$out/lib/dsh/"'';
  linkCore = ''
    node ${./link-core.mjs} ${upstream.workspace}/lib/deepseek-harness/package.json "$out/lib/dsh/node_modules"
  '';
  tui = buildProject "tui" ".runtime/dsh/profiles/dsh-tui" "" ''
    rm -rf "$out/lib/dsh/node_modules/dsh-notify-on-complete"
    ln -s ${notification}/lib/dsh "$out/lib/dsh/node_modules/dsh-notify-on-complete"
    ${linkCore}
  '';
  web = buildProject "web" ".runtime/dsh/profiles/web" "" linkCore;
  profilePackages = {
    dsh-tui = tui;
    inherit web;
  };
  manifest =
    name:
    builtins.fromJSON (builtins.readFile (./source/.runtime/dsh/profiles + "/${name}/package.json"));
  profileBundles = lib.genAttrs [ "dsh-tui" "web" ] (name: (manifest name).dsh.profile.bundles);
  profilePlugins = lib.mapAttrs (
    name: package:
    map (
      plugin:
      package
      // {
        dshPlugin = {
          name = plugin;
          path = "${package}/lib/dsh/node_modules/${plugin}";
        };
      }
    ) (builtins.attrNames (manifest name).dependencies)
  ) profilePackages;
in
stdenvNoCC.mkDerivation {
  pname = "dsh";
  inherit version;
  dontUnpack = true;
  nativeBuildInputs = [ makeWrapper ];
  installPhase = ''
    mkdir -p "$out/bin" "$out/libexec" "$out/share/dsh"
    cp -r ${./source/config} "$out/share/dsh/config"
    cp -r ${./source/skills} "$out/share/dsh/skills"
    substitute ${./init.mjs} "$out/libexec/init.mjs" \
      --replace-fail '@tui@' '${tui}/lib/dsh' \
      --replace-fail '@web@' '${web}/lib/dsh' \
      --replace-fail '@defaults@' "$out/share/dsh"
    substitute ${./launcher.sh} "$out/libexec/launcher" \
      --replace-fail '@node@' '${nodejs}/bin/node' \
      --replace-fail '@upstream@' '${upstream}/bin/dsh' \
      --replace-fail '@out@' "$out" \
      --replace-fail '@flock@' '${util-linux}/bin/flock'
    chmod +x "$out/libexec/launcher"
    for command in dsh dsh-web dsh-raw; do
      makeWrapper "$out/libexec/launcher" "$out/bin/$command" \
        --add-flags "$command" \
        --prefix PATH : ${
          lib.makeBinPath [
            nodejs
            libnotify
            coreutils
          ]
        }
    done
  '';
  doInstallCheck = true;
  nativeInstallCheckInputs = [ python3 ];
  installCheckPhase = ''
    export HOME=$(mktemp -d)
    export DSH_HOME="$HOME/dsh"
    "$out/bin/dsh" --dump-config > tui.yml
    "$out/bin/dsh-raw" --profile web --dump-config > web.yml
    grep -q 'dsh-tui' tui.yml
    grep -q 'better-sidebar' web.yml
    "$out/bin/dsh-raw" --version
    ${python3}/bin/python3 ${./check-initialization.py} "$out"
  '';
  passthru = {
    inherit
      upstream
      profilePackages
      profileBundles
      profilePlugins
      ;
    dshCommands = [
      "dsh"
      "dsh-web"
      "dsh-raw"
    ];
  };
  meta = upstream.meta // {
    description = "DeepSeek Harness with pinned personal TUI and Web plugins";
    license = lib.licenses.unfree;
    mainProgram = "dsh";
  };
}
