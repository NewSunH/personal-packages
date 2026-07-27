{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:

let
  source = builtins.fromJSON (builtins.readFile ./source.json);
  scriptDir = "$out/share/mpv/scripts/uosc_danmaku";
in
stdenvNoCC.mkDerivation {
  pname = "uosc-danmaku";
  inherit (source) version;

  src = fetchFromGitHub {
    owner = "Tony15246";
    repo = "uosc_danmaku";
    inherit (source) rev hash;
  };

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "${scriptDir}"
    install -m644 main.lua LICENSE README.md "${scriptDir}/"
    cp -R apis dicts modules sites "${scriptDir}/"

    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck

    for requiredFile in \
      main.lua \
      apis/dandanplay.lua \
      modules/options.lua \
      sites/bilibili.lua
    do
      test -f "${scriptDir}/$requiredFile"
    done

    runHook postInstallCheck
  '';

  passthru.scriptName = "uosc_danmaku";

  meta = {
    description = "Load DanDanPlay danmaku in mpv with uosc integration";
    homepage = "https://github.com/Tony15246/uosc_danmaku";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
}
