{ self }:
{ lib, pkgs, ... }:
let
  packages = self.packages.${pkgs.stdenv.hostPlatform.system};
in
{
  imports = [ ../../modules/home-manager/dsh.nix ];
  programs.dsh = {
    package = lib.mkDefault packages.dsh;
    desktop.package = lib.mkDefault packages.deepseek-harness-desktop;
    profiles = lib.mapAttrs (name: bundles: {
      bundles = lib.mkDefault bundles;
      plugins = lib.mkDefault packages.dsh.profilePlugins.${name};
    }) packages.dsh.profileBundles;
  };
}
