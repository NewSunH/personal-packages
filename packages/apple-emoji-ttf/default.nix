{
  lib,
  stdenvNoCC,
  fetchurl,
}:

let
  source = builtins.fromJSON (builtins.readFile ./source.json);
in
stdenvNoCC.mkDerivation {
  pname = "apple-emoji-ttf";
  inherit (source) version;

  src = fetchurl {
    inherit (source) url hash;
  };
  dontUnpack = true;

  installPhase = ''
    runHook preInstall
    install -Dm644 "$src" "$out/share/fonts/truetype/AppleColorEmoji-Linux.ttf"
    runHook postInstall
  '';

  meta = {
    description = "Apple Color Emoji font converted for Linux";
    homepage = "https://github.com/samuelngs/apple-emoji-ttf";
    license = lib.licenses.unfree;
    platforms = lib.platforms.linux;
  };
}
