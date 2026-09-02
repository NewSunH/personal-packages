{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:

let
  source = builtins.fromJSON (builtins.readFile ./source.json);
in
stdenvNoCC.mkDerivation {
  pname = "doq";
  inherit (source) version;

  src = fetchFromGitHub {
    owner = "shivaprsd";
    repo = "doq";
    inherit (source) rev hash;
  };

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/doq
    cp -r addon lib $out/share/doq/
    install -Dm644 LICENSE.txt $out/share/licenses/doq/LICENSE.txt

    runHook postInstall
  '';

  meta = {
    description = "Reader mode and color schemes add-on for PDF.js";
    homepage = "https://github.com/shivaprsd/doq";
    license = lib.licenses.mit;
    platforms = lib.platforms.all;
  };
}
