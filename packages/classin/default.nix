{
  lib,
  stdenvNoCC,
  stdenv,
  fetchurl,
  dpkg,
  autoPatchelfHook,
  makeWrapper,
  alsa-lib,
  e2fsprogs,
  expat,
  fontconfig,
  freetype,
  fribidi,
  gmp,
  libdrm,
  libgbm,
  libglvnd,
  libgpg-error,
  libice,
  libsm,
  libx11,
  libxcb,
  util-linux,
  xkeyboard-config,
  zlib,
}:

let
  source = builtins.fromJSON (builtins.readFile ./source.json);
in
stdenvNoCC.mkDerivation {
  pname = "classin";
  inherit (source) version;

  src = fetchurl {
    inherit (source) url hash;
  };

  nativeBuildInputs = [
    dpkg
    autoPatchelfHook
    makeWrapper
  ];
  buildInputs = [
    alsa-lib
    e2fsprogs
    expat
    fontconfig
    freetype
    fribidi
    gmp
    libdrm
    libgbm
    libglvnd
    libgpg-error
    libice
    libsm
    libx11
    libxcb
    stdenv.cc.cc.lib
    util-linux
    zlib
  ];

  dontConfigure = true;
  dontBuild = true;
  dontStrip = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/libexec" "$out/bin"
    cp -a opt/apps/classin "$out/libexec/classin"
    cp -a usr/share "$out/share"
    substituteInPlace "$out/share/applications/classin.desktop" \
      --replace-fail /opt/apps/classin/ClassIn "$out/bin/classin"

    # Use the bundled Qt plugins; desktop-session Qt plugins have another ABI.
    # Upstream ships only the XCB platform plugin, so use XWayland on Wayland.
    makeWrapper "$out/libexec/classin/ClassIn" "$out/bin/classin" \
      --prefix LD_LIBRARY_PATH : "$out/libexec/classin/lib" \
      --set QT_PLUGIN_PATH "$out/libexec/classin/plugins" \
      --set QT_QPA_PLATFORM_PLUGIN_PATH "$out/libexec/classin/plugins/platforms" \
      --set QT_QPA_PLATFORM xcb \
      --set QT_STYLE_OVERRIDE Fusion \
      --set XKB_CONFIG_ROOT "${xkeyboard-config}/share/X11/xkb"

    runHook postInstall
  '';

  meta = {
    description = "ClassIn online classroom client";
    homepage = "https://www.classin.com/";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "classin";
    platforms = [ "x86_64-linux" ];
  };
}
