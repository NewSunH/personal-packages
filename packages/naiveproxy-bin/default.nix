{
  lib,
  stdenvNoCC,
  fetchurl,
}:

let
  source = builtins.fromJSON (builtins.readFile ./source.json);
in
stdenvNoCC.mkDerivation {
  pname = "naiveproxy-bin";
  inherit (source) version;

  src = fetchurl {
    inherit (source) url hash;
  };

  dontConfigure = true;
  dontBuild = true;
  dontStrip = true;
  dontPatchELF = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 naive $out/bin/naive
    runHook postInstall
  '';

  meta = {
    description = "NaiveProxy client binary";
    homepage = "https://github.com/klzgrad/naiveproxy";
    license = lib.licenses.bsd3;
    mainProgram = "naive";
    platforms = [ "x86_64-linux" ];
  };
}
