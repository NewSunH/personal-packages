{
  lib,
  fetchFromGitHub,
  hyprlandPlugins,
  meson,
  ninja,
}:
hyprlandPlugins.mkHyprlandPlugin {
  pluginName = "hyprexpo";
  version = "0.56.1+3";

  src = fetchFromGitHub {
    owner = "sandwichfarm";
    repo = "hyprexpo";
    rev = "v0.56.1+3";
    hash = "sha256-lI52XGlHMAXhn8ztpRkzefFy5ZnTIsQgAlTEVYTXseA=";
  };

  nativeBuildInputs = [
    meson
    ninja
  ];

  meta = {
    homepage = "https://github.com/sandwichfarm/hyprexpo";
    description = "Enhanced Hyprland workspace overview plugin (hyprexpo fork)";
    license = lib.licenses.bsd3;
    platforms = lib.platforms.linux;
  };
}
