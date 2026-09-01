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

    # Keep a mixed-version deployment usable while librime rebuilds its
    # compiled schema.  Wanxiang 17.9 removed user_predict.lua and changed
    # unicode_conversion.lua to expose P/T submodules.  An already running
    # librime process can still load the previous schema for one session;
    # provide the old entry points until that stale build is replaced.
    if [ ! -e lua/wanxiang/user_predict.lua ]; then
      mkdir -p lua/wanxiang
      cp ${./legacy/user_predict.lua} lua/wanxiang/user_predict.lua
    fi
    if [ -f lua/wanxiang/unicode_conversion.lua ] \
      && grep -qF 'return { P = P, T = T }' lua/wanxiang/unicode_conversion.lua; then
      substituteInPlace lua/wanxiang/unicode_conversion.lua \
        --replace-fail 'return { P = P, T = T }' 'return { P = P, T = T, func = T.func }'
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
