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
      nixpkgs,
      rime-wanxiang-src,
      ...
    }:
    let
      supportedSystems = [ "x86_64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;

      overlay = final: _prev: {
        apple-emoji-ttf = final.callPackage ./packages/apple-emoji-ttf { };
        naiveproxy-bin = final.callPackage ./packages/naiveproxy-bin { };
        ariang = final.callPackage ./packages/ariang { };
        rime-wanxiang-schema = final.callPackage ./packages/rime-wanxiang-schema {
          inherit rime-wanxiang-src;
        };
        rime-wanxiang-gram = final.callPackage ./packages/rime-wanxiang-gram { };
      };
    in
    {
      overlays.default = overlay;

      packages = forAllSystems (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfreePredicate = package: (package.pname or "") == "apple-emoji-ttf";
            overlays = [ overlay ];
          };
        in
        {
          inherit (pkgs)
            apple-emoji-ttf
            ariang
            naiveproxy-bin
            rime-wanxiang-gram
            rime-wanxiang-schema
            ;

          default = pkgs.naiveproxy-bin;
        }
      );

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt);
    };
}
