{
  description = "Personal Nix packages used by NewSunH's NixOS configurations";

  nixConfig = {
    extra-substituters = [ "https://newsunh.cachix.org" ];
    extra-trusted-public-keys = [
      "newsunh.cachix.org-1:voaLAjHu01ASoWbhCgCFDMvr6fPVF//Hw0hRa6jaoRM="
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    rime-wanxiang-src = {
      url = "github:amzxyz/rime-wanxiang";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      rime-wanxiang-src,
      ...
    }:
    let
      supportedSystems = [ "x86_64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;

      overlay = final: _prev: {
        akizip = final.callPackage ./packages/akizip { };
        apple-emoji-ttf = final.callPackage ./packages/apple-emoji-ttf { };
        classin = final.callPackage ./packages/classin { };
        doq = final.callPackage ./packages/doq { };
        dsh = final.callPackage ./packages/dsh { };
        deepseek-harness = final.callPackage ./packages/deepseek-harness/package.nix { };
        deepseek-harness-desktop = final.callPackage ./packages/deepseek-harness/desktop.nix { };
        naiveproxy-bin = final.callPackage ./packages/naiveproxy-bin { };
        ariang = final.callPackage ./packages/ariang { };
        uosc-danmaku = final.callPackage ./packages/uosc-danmaku { };
        rime-wanxiang-schema = final.callPackage ./packages/rime-wanxiang-schema {
          inherit rime-wanxiang-src;
        };
        rime-wanxiang-gram = final.callPackage ./packages/rime-wanxiang-gram { };
        hyprexpo = final.callPackage ./packages/hyprexpo { };
        latex-workshop-doq = final.callPackage ./packages/latex-workshop-doq { };
        scrolloverview = final.callPackage ./packages/scrolloverview { };
      };
    in
    {
      overlays.default = overlay;
      lib.mkDshPlugin =
        {
          name,
          package,
          modulePath ? "${package}/lib/node_modules/${name}",
        }:
        package
        // {
          dshPlugin = {
            inherit name;
            path = modulePath;
          };
        };

      homeManagerModules.dsh = import ./packages/dsh/home-manager.nix { inherit self; };
      homeManagerModules.deepseek-harness = { lib, pkgs, ... }: {
        imports = [ ./modules/home-manager/dsh.nix ];
        programs.dsh.package =
          lib.mkDefault
            self.packages.${pkgs.stdenv.hostPlatform.system}.deepseek-harness;
        programs.dsh.desktop.package =
          lib.mkDefault
            self.packages.${pkgs.stdenv.hostPlatform.system}.deepseek-harness-desktop;
      };

      packages = forAllSystems (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfreePredicate =
              package:
              builtins.elem (package.pname or "") [
                "7zz"
                "apple-emoji-ttf"
                "classin"
                "dsh"
                "uasm"
              ];
            overlays = [ overlay ];
          };
        in
        {
          inherit (pkgs)
            akizip
            apple-emoji-ttf
            ariang
            classin
            doq
            dsh
            deepseek-harness
            deepseek-harness-desktop
            hyprexpo
            latex-workshop-doq
            naiveproxy-bin
            rime-wanxiang-gram
            rime-wanxiang-schema
            scrolloverview
            uosc-danmaku
            ;

          default = pkgs.naiveproxy-bin;
        }
      );

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt);
    };
}
