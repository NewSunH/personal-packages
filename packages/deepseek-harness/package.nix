{
  lib,
  callPackage,
  stdenvNoCC,
  makeWrapper,
  nodejs-slim_24,
  pnpm_11,
  bashInteractive,
  python3,
  xdg-user-dirs,
}:
let
  workspace = callPackage ./runtime.nix { };
  nodejs = nodejs-slim_24;
  pnpm = pnpm_11.override { nodejs-slim = nodejs; };
in
stdenvNoCC.mkDerivation {
  pname = "deepseek-harness";
  inherit (workspace) version;
  dontUnpack = true;
  nativeBuildInputs = [ makeWrapper ];
  installPhase = ''
    mkdir -p "$out/bin"
    makeWrapper ${lib.getExe nodejs} "$out/bin/dsh" \
      --add-flags --expose-internals \
      --add-flags ${workspace}/lib/deepseek-harness/lib/bin.js \
      --prefix PATH : ${
        lib.makeBinPath [
          nodejs
          pnpm
          bashInteractive
          xdg-user-dirs
        ]
      }
  '';
  doInstallCheck = true;
  nativeInstallCheckInputs = [ python3 ];
  installCheckPhase = ''
    ${python3}/bin/python3 ${./test-runtime.py} "$out/bin/dsh" ${workspace}/lib/deepseek-harness ${lib.getExe nodejs}
  '';
  passthru = { inherit workspace nodejs pnpm; };
  meta = workspace.meta // {
    description = "DeepSeek's plugin-based agent harness with CLI and Web interfaces";
    mainProgram = "dsh";
  };
}
