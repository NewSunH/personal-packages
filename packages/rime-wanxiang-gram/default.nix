{
  lib,
  stdenvNoCC,
  fetchurl,
}:

let
  source = builtins.fromJSON (builtins.readFile ./source.json);
in
stdenvNoCC.mkDerivation {
  pname = "rime-wanxiang-lts-gram";
  inherit (source) version;

  src = fetchurl {
    inherit (source) url hash;
  };
  dontUnpack = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/rime-data
    cp $src $out/share/rime-data/wanxiang-lts-zh-hans.gram
    runHook postInstall
  '';

  meta = {
    description = "Wanxiang LMDG LTS language model (zh-hans)";
    homepage = "https://github.com/amzxyz/RIME-LMDG";
    license = lib.licenses.gpl3Plus;
    platforms = lib.platforms.all;
  };
}
