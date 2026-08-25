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
  pluginName = "scrolloverview";
  inherit (source) version;

  src = fetchFromGitHub {
    owner = "yayuuu";
    repo = "hyprland-scroll-overview";
    inherit (source) rev hash;
  };

  # main 分支对应发行版 Hyprland（hyprpm 的 commit_pins 面向正式版），
  # new-release 分支跟踪 Hyprland git master（0.57-dev 头文件布局），
  # 与 nixpkgs 的发行版 hyprland 不匹配，故此处固定 main。
  nativeBuildInputs = [
    meson
    ninja
  ];

  # 仓库同时带 CMakeLists.txt 和 meson.build；上游 flake 明确禁掉 CMake 走
  # Makefile，这里按 hyprexpo 的方式强制走 meson 构建。
  dontUseCmakeConfigure = true;

  # 供 scripts/generate-plugin-version.sh 读取（hyprctl plugin list 显示版本）。
  SCROLLOVERVIEW_BUILD_VERSION = source.version;

  meta = {
    homepage = "https://github.com/yayuuu/hyprland-scroll-overview";
    description = "Scroll overview plugin, just like niri (based on hyprexpo scroll-overview branch)";
    license = lib.licenses.bsd3;
    platforms = lib.platforms.linux;
  };
}
