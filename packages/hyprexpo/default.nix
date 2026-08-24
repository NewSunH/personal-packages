{
  lib,
  fetchFromGitHub,
  hyprlandPlugins,
  meson,
  ninja,
}:

let
  source = builtins.fromJSON (builtins.readFile ./source.json);
in
hyprlandPlugins.mkHyprlandPlugin {
  pluginName = "hyprexpo";
  inherit (source) version;

  src = fetchFromGitHub {
    owner = "sandwichfarm";
    repo = "hyprexpo";
    inherit (source) rev hash;
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
