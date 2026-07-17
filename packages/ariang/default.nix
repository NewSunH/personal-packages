{
  lib,
  stdenvNoCC,
  fetchzip,
  copyDesktopItems,
  imagemagick,
  makeWrapper,
  makeDesktopItem,
  xdg-utils,
}:

let
  source = builtins.fromJSON (builtins.readFile ./source.json);
in
stdenvNoCC.mkDerivation {
  pname = "ariang";
  inherit (source) version;

  src = fetchzip {
    inherit (source) url hash;
    stripRoot = false;
  };

  nativeBuildInputs = [
    copyDesktopItems
    imagemagick
    makeWrapper
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/ariang
    cp -R . $out/share/ariang/

    for size in 16 24 36 48 72; do
      mkdir -p $out/share/icons/hicolor/''${size}x''${size}/apps
      magick $out/share/ariang/tileicon.png -resize ''${size}x''${size} \
        $out/share/icons/hicolor/''${size}x''${size}/apps/ariang.png
    done

    mkdir -p $out/bin
    makeWrapper ${xdg-utils}/bin/xdg-open $out/bin/ariang \
      --add-flags "file://$out/share/ariang/index.html"

    runHook postInstall
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "ariang";
      desktopName = "AriaNg";
      genericName = "Aria2 Web Frontend";
      comment = "Modern web frontend making aria2 easier to use";
      exec = "ariang";
      icon = "ariang";
      terminal = false;
      type = "Application";
      categories = [
        "Network"
        "WebBrowser"
      ];
    })
  ];

  meta = {
    description = "Modern web frontend making aria2 easier to use";
    homepage = "https://ariang.mayswind.net/";
    license = lib.licenses.mit;
    mainProgram = "ariang";
    platforms = lib.platforms.unix;
  };
}
