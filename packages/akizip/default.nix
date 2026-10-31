{
  lib,
  fetchFromGitHub,
  python3Packages,
  meson,
  ninja,
  pkg-config,
  gettext,
  desktop-file-utils,
  gobject-introspection,
  wrapGAppsHook4,
  glib,
  gtk4,
  libadwaita,
  _7zz-rar,
}:
python3Packages.buildPythonApplication (finalAttrs: {
  pname = "akizip";
  version = "0.4.4";
  pyproject = false;

  src = fetchFromGitHub {
    owner = "AkiZip";
    repo = "AkiZip";
    tag = finalAttrs.version;
    hash = "sha256-LzLzbCVoN4SRFaxALlod8K5iYLiCx9iJ6BJnlN7tum0=";
  };

  nativeBuildInputs = [
    meson
    ninja
    pkg-config
    gettext
    desktop-file-utils
    gobject-introspection
    wrapGAppsHook4
  ];
  buildInputs = [
    glib
    gtk4
    libadwaita
  ];
  dependencies = [ python3Packages.pygobject3 ];

  patches = [ ./interaction-fixes.patch ];
  postPatch = ''
    substituteInPlace src/plugins/sevenzip.py \
      --replace-fail /app/bin/7zz ${lib.getExe _7zz-rar}
    substituteInPlace data/top.akizip.akizip.desktop.in \
      --replace-fail 'Exec=akizip' "Exec=$out/bin/akizip" \
      --replace-fail 'Icon=top.akizip.akizip' \
        "Icon=$out/share/icons/hicolor/scalable/apps/top.akizip.akizip.svg"
  '';

  doCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    meson test --print-errorlogs
    ${python3Packages.python.interpreter} ${./test-interactions.py} "$out"
    runHook postInstallCheck
  '';
  dontWrapGApps = true;
  preFixup = ''
    makeWrapperArgs+=("''${gappsWrapperArgs[@]}")
  '';

  meta = {
    description = "GTK4 archive manager using the 7-Zip command-line engine";
    homepage = "https://github.com/AkiZip/AkiZip";
    license = lib.licenses.gpl3Plus;
    platforms = lib.platforms.linux;
    mainProgram = "akizip";
  };
})
