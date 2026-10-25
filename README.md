# personal-packages

Personal Nix packages shared by the NewSunH NixOS configurations.

## Packages

- `apple-emoji-ttf`: Apple Color Emoji Linux TTF from upstream releases
- `classin`: ClassIn online classroom client (official x86_64 Linux binary)
- `naiveproxy-bin`: upstream x86_64 Linux release binary
- `ariang`: AriaNg web interface with a desktop launcher
- `doq`: reader mode and color schemes add-on for PDF.js
- `dsh`: personal TUI/Web profiles and plugins on the official-source DeepSeek Harness core
- `deepseek-harness`: official-source DSH CLI and Web, without personal plugin defaults
- `deepseek-harness-desktop`: experimental Linux Electron desktop application
- `uosc-danmaku`: mpv DanDanPlay danmaku extension with uosc integration
- `rime-wanxiang-schema`: Wanxiang Rime schema and dictionaries
- `rime-wanxiang-gram`: Wanxiang LMDG LTS language model
- `hyprexpo`: Hyprland workspace overview plugin (sandwichfarm fork)
- `scrolloverview`: Hyprland scroll overview plugin (yayuuu fork; `main`
  branch tracks release Hyprland, `new-release` tracks Hyprland git master)

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
inputs.personal-packages.packages.x86_64-linux.classin
inputs.personal-packages.packages.x86_64-linux.doq
inputs.personal-packages.packages.x86_64-linux.dsh
inputs.personal-packages.packages.x86_64-linux.deepseek-harness
inputs.personal-packages.packages.x86_64-linux.deepseek-harness-desktop
inputs.personal-packages.packages.x86_64-linux.uosc-danmaku
inputs.personal-packages.packages.x86_64-linux.rime-wanxiang-schema
inputs.personal-packages.packages.x86_64-linux.rime-wanxiang-gram
inputs.personal-packages.packages.x86_64-linux.apple-emoji-ttf
inputs.personal-packages.packages.x86_64-linux.hyprexpo
inputs.personal-packages.packages.x86_64-linux.scrolloverview
```

The default overlay remains available for consumers that intentionally want to
build the packages against their own `nixpkgs` revision.

See [official-source DSH packaging](packages/deepseek-harness/README.md) for the
optional `homeManagerModules.deepseek-harness` module, linked or seeded YAML,
declarative plugin profiles, and Linux desktop limitations. The personal
`dsh` package wraps the same official core, adds pinned TUI/Web profiles, and exports
`profilePlugins`/`profileBundles`. Use `homeManagerModules.dsh` for these defaults
or `homeManagerModules.deepseek-harness` for the generic module. Install one CLI.

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
./scripts/update apple-emoji naiveproxy ariang classin uosc-danmaku rime-gram rime-schema
```

The scheduled GitHub workflow checks daily at 00:00 UTC (08:00 Singapore time).
When it finds a change, it validates the flake, builds packages, caches the
cacheable outputs, and opens an update pull request with auto-merge enabled. A
manual workflow run always rebuilds the package set, which can be used to refill
the cache.

ClassIn updates use the official download configuration's Linux amd64 version
and URL. The updater downloads the package to calculate its SHA-256 hash and
writes `packages/classin/source.json`; CI builds ClassIn before opening an update
PR. ClassIn is built before enabling the public cache upload.

For a ClassIn installation from this local checkout, pull the package updates
and run `nix profile upgrade classin` to upgrade the installed client. The GitHub
workflow updates package definitions; it does not upgrade local user profiles.
