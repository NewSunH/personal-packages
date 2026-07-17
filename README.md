# personal-packages

Personal Nix packages shared by the NewSunH NixOS configurations.

## Packages

- `naiveproxy-bin`: upstream x86_64 Linux release binary
- `ariang`: AriaNg web interface with a desktop launcher
- `rime-wanxiang-schema`: Wanxiang Rime schema and dictionaries
- `rime-wanxiang-gram`: Wanxiang LMDG LTS language model

Blender is intentionally out of scope because it is maintained separately.

## Use as a flake input

```nix
inputs.personal-packages = {
  url = "github:NewSunH/personal-packages";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

Install the overlay in a NixOS or Home Manager module:

```nix
{
  nixpkgs.overlays = [ inputs.personal-packages.overlays.default ];
}
```

The packages are then available as `pkgs.naiveproxy-bin`, `pkgs.ariang`,
`pkgs.rime-wanxiang-schema`, and `pkgs.rime-wanxiang-gram`.

## Update sources

Run every updater:

```console
./scripts/update
```

Or update selected sources:

```console
./scripts/update naiveproxy ariang rime-gram rime-schema
```

The scheduled GitHub workflow checks weekly. When it finds a change, it validates
the flake, builds all packages, and opens an update pull request.
