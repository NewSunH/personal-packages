# DeepSeek Harness: official CLI and Linux desktop packaging

This package builds the official `dsh-v0.2.1-rc.3` source and its pnpm workspace lockfile. The `packages/dsh` personal adapter uses this exact core with separately pinned TUI/Web plugins (TUI 0.17.0 supports rc.3). Packages never migrate credentials, sessions, memory or existing profiles automatically.

```sh
nix build path:.#deepseek-harness -o result-dsh-official
./result-dsh-official/bin/dsh --version
./result-dsh-official/bin/dsh web

nix build path:.#deepseek-harness-desktop -o result-dsh-desktop
./result-dsh-desktop/bin/dsh-desktop
```

Run these commands from `personal-packages`. `path:.` includes the new package files before they are added to Git. The desktop package is experimental: upstream currently publishes desktop releases only for Windows and macOS. This Linux package uses Nixpkgs Electron and Python, not upstream's downloadable installer payload. It does not register a second `dsh` CLI. Updates are managed by Nix; the upstream updater and its menu entry are disabled.

## Package boundaries

- `deepseek-harness`: upstream CLI, built-in profiles and Web resources. The CLI's default selection and plugin commands remain upstream-owned. Node and pnpm are available for application-managed plugin operations.
- `deepseek-harness-desktop`: Electron shell, private Desktop Host, runtime resources and desktop entry. PTY and sharp binaries are rebuilt against Electron headers separately from the ordinary Node runtime. Desktop sharp links against Nixpkgs libvips so it shares Electron's GLib instead of loading the conflicting npm libvips payload.
- `homeManagerModules.deepseek-harness`: optional `programs.dsh` configuration module. Do not combine it with the personal `homeManagerModules.dsh` module: both define `programs.dsh`.
- `workspace.nix`: shared official-source compilation and type checks. `runtime.nix` deploys the production dependencies into separate CLI and desktop outputs, keeping desktop resources out of the CLI runtime reference graph. Building the CLI still compiles the upstream workspace's desktop bundles.

The source and dependency hashes are pinned. Normal builds install dependencies offline. Downstream patches support distribution Node/Electron builds, protect Nix-managed files and plugin profiles, preserve declared tool paths after the Desktop login-shell probe, and use Nix-provided desktop dependencies in place instead of copying them into the user home. They are downstream compatibility changes, not accepted upstream changes.

The desktop uses a private Electron executable with an installed `resources/app` tree, so `app.isPackaged` is true. Its library/data files are shared with Nixpkgs Electron; the Nixpkgs GTK/GIO/sandbox wrapper environment is retained. The upstream integrated caption is shared between Windows and Linux, including its Application/Edit menu, native window controls and draggable strip. `process.platform` remains `linux`. Set `DSH_DESKTOP_TITLEBAR=native` (or `programs.dsh.desktop.titlebar = "native"` in Home Manager) to retain native Linux decorations and a conventional menu bar. macOS-specific behavior and Windows-only installer/tray logic remain platform-specific.

The Linux application icon reuses upstream's rounded Windows artwork, preserving the dark whale and light background. Both SVG and PNG icons are installed for desktop launchers; Electron uses the same rounded PNG.

## Home Manager

```nix
{ config, inputs, pkgs, ... }:
{
  imports = [ inputs.personal-packages.homeManagerModules.deepseek-harness ];
  programs.dsh = {
    enable = true;
    desktop.enable = true;
    extraPackages = [ pkgs.ripgrep pkgs.git ];

    profiles.web = {
      bundles = [ "@deepseek-ai/dsh-base" "@deepseek-ai/dsh-web-app" ];
      config = {
        mode = "linked";
        source = "${config.home.homeDirectory}/nixos/home/dsh/web.patch.yml";
      };
    };

    # Seed once, then allow edits in the application's settings UI.
    desktop.config = {
      mode = "seed";
      source = ./desktop.patch.yml;
    };
    skills = "${config.home.homeDirectory}/nixos/home/dsh/skills";
  };
}
```

The module defaults to `~/.dsh`. Set `homeDirectory` explicitly to test with an isolated home. Packages used without Home Manager honor upstream `DSH_HOME`. Browser caches remain Electron-owned and are not relocated by this setting.

`homeConfig` and each profile's `config` support:

| Option | Behavior |
| --- | --- |
| `source = ./patch.yml` | Source file is copied to the Nix store. |
| `source = "/absolute/checkout/patch.yml"` | Out-of-store link permits live editing without rebuilding. |
| `settings = [ ... ]` | Generate YAML from native Cordis patch entries. Mutually exclusive with `source`. |
| `mode = "linked"` | Home Manager owns the link continuously. Application writeback to the store-backed link is rejected; edit its source instead. |
| `mode = "seed"` | Initialize only if absent; later generations and rollbacks preserve application edits. |

Use standalone YAML for large configurations and `!!js` expressions. The layering remains upstream's: ordered bundles, profile patch, home patch, then CLI `--patch`. HMR reloads edits when the selected profile enables it; otherwise restart the application.

Profiles with `bundles = null` and no Nix plugins retain application-owned manifests and dependencies. An explicit `bundles` list makes Home Manager own that profile's manifest and `node_modules`; manage its dependencies through Nix, not through `dsh plugin` or the UI. Existing unmanaged files are not forcibly overwritten during activation. Use a fresh profile or deliberately migrate it after backup.

The `desktop` profile is Electron-owned. Configure it through `desktop.config`, not `profiles.desktop`. Desktop plugin dependencies remain application-managed in this first implementation.

## Third-party plugins

`profiles.<name>.plugins` accepts packages carrying `dshPlugin.name` and `dshPlugin.path`. `path` must point to an installed Node package directory, including its own external runtime dependency closure; peers supplied by DSH remain runtime-resolved.

```nix
let
  memento = inputs.personal-packages.lib.mkDshPlugin {
    name = "dsh-memento";
    package = myPackages.dsh-memento;
    # Defaults to "${myPackages.dsh-memento}/lib/node_modules/dsh-memento".
  };
in {
  programs.dsh.profiles.work = {
    plugins = [ memento ];
    bundles = [ "@deepseek-ai/dsh-base" "dsh-memento" ];
  };
}
```

This helper annotates an already-built package. It does not fetch npm specifications during activation or bypass DSH's plugin version checks. TUI plugins must be packaged independently and explicitly selected in `bundles`; the official package does not silently install the personal TUI stack.

## Validation

The CLI's install checks run without API credentials and cover version/help, headless configuration, native module loading, a real PTY, and an HTTP response from Web on an ephemeral loopback port. The workspace also runs upstream `build:artifacts`, `build:check`, and focused caption/preload tests.

The module has a focused seed-file check:

```sh
python3 modules/home-manager/test-seed-config.py
```

`test-module.nix` exposes the evaluated Home Manager generation and assertions for linked, seeded, desktop, and external-plugin configuration. `test-module-runtime.py <generation> <dsh-executable>` checks actual plugin composition and rejection of package operations on a managed profile.

The desktop checks sharp's declared libvips version requirement before compiling. Its install check runs `test-sharp.cjs` under the packaged Electron in Node mode, verifies the locally compiled addon and pinned libvips version, and checks that the process loads a single shared GLib from Nixpkgs. It repeatedly probes metadata, decodes and resizes PNG/JPEG/WebP attachments concurrently. Reading metadata is essential: the conflicting prebuilt libvips can encode images successfully but segfault when opening a conversation reads saved attachment metadata.

`node test-desktop.mjs <desktop-package> <xvfb-run-executable> [window-manager-executable]` checks packaged mode, Linux identity, caption/menu IPC, the welcome window, Desktop Host, default workspace creation, and rendered workspace in an isolated home without API credentials. Run it again with `DSH_DESKTOP_TITLEBAR=native` to check the fallback. Pass Openbox as the optional window manager to also exercise maximize/minimize/restore and fullscreen transitions with renderer notifications. It retains package/menu state, text snapshots and a screenshot under `/tmp/dsh-desktop-smoke-*`. CI builds the CLI/desktop packages and checks seeding; graphical qualification is separate. Building resources alone does not establish GUI functionality.

Local validation on x86_64-linux passed for both builds, CLI install checks, Home Manager generation/runtime and seed checks, flake evaluation, and Xvfb desktop smoke tests for integrated/native captions (Electron 44.9.3). With Openbox, maximize/minimize/restore and enter/leave fullscreen also passed. The workspace runs 317 focused desktop and layout regression tests. The desktop smoke test configures a temporary Documents directory; Linux users without an XDG Documents directory can choose a workspace manually. Model requests, audio, office conversions, and a native Wayland session are not qualified by this test.
