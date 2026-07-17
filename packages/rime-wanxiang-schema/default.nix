{
  lib,
  stdenvNoCC,
  rime-wanxiang-src,
}:

let
  schemaVersion = lib.strings.removeSuffix "\n" (
    builtins.readFile (rime-wanxiang-src + "/version.txt")
  );
in
stdenvNoCC.mkDerivation {
  pname = "rime-wanxiang";
  version = schemaVersion;

  src = rime-wanxiang-src;

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/rime-data
    cp -r . $out/share/rime-data/

    cd $out/share/rime-data
    rm -rf README.md LICENSE CHANGELOG.md release-please-config.json .github custom

    # Avoid merging upstream default.yaml with the user's default.custom.yaml.
    if [ -f default.yaml ]; then
      mv default.yaml wanxiang_suggested_default.yaml
    fi

    runHook postInstall
  '';

  meta = {
    description = "Feature-rich pinyin schema for Rime";
    homepage = "https://github.com/amzxyz/rime_wanxiang";
    license = lib.licenses.gpl3Plus;
    platforms = lib.platforms.all;
  };
}
