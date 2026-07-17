# personal-packages

Personal Nix packages shared by the NewSunH NixOS configurations.

## Packages

- `apple-emoji-ttf`: Apple Color Emoji Linux TTF from upstream releases
- `naiveproxy-bin`: upstream x86_64 Linux release binary
- `ariang`: AriaNg web interface with a desktop launcher
- `rime-wanxiang-schema`: Wanxiang Rime schema and dictionaries
- `rime-wanxiang-gram`: Wanxiang LMDG LTS language model

Blender is intentionally out of scope because it is maintained separately.

## Use as a flake input

```nix
inputs.personal-packages.url = "github:NewSunH/personal-packages";
```

Consume the package outputs directly to retain this flake's locked `nixpkgs`
revision and maximize binary-cache hits:

```nix
inputs.personal-packages.packages.x86_64-linux.naiveproxy-bin
inputs.personal-packages.packages.x86_64-linux.ariang
inputs.personal-packages.packages.x86_64-linux.rime-wanxiang-schema
inputs.personal-packages.packages.x86_64-linux.rime-wanxiang-gram
inputs.personal-packages.packages.x86_64-linux.apple-emoji-ttf
```

The default overlay remains available for consumers that intentionally want to
build the packages against their own `nixpkgs` revision.

## Binary cache

Build outputs are published to `https://newsunh.cachix.org`. The flake advertises
the substituter and its public key through `nixConfig`; the same settings should
be added to the root NixOS flake when this repository is consumed as an input.

`apple-emoji-ttf` is intentionally excluded from the public cache. The upstream
project states that Apple owns the emoji assets and that they are not covered by
the repository's MIT license, so consumers fetch the TTF directly from its
GitHub release.

## Update sources

Run every updater:

```console
./scripts/update
```

Or update selected sources:

```console
./scripts/update apple-emoji naiveproxy ariang rime-gram rime-schema
```

The scheduled GitHub workflow checks weekly. When it finds a change, it validates
the flake, builds and caches all packages, and opens an update pull request. A
manual workflow run always rebuilds the package set, which can be used to refill
the cache.
