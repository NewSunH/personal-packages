{
  description = "Personal Nix packages used by NewSunH's NixOS configurations";

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
            overlays = [ overlay ];
          };
        in
        {
          inherit (pkgs)
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
