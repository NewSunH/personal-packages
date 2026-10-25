{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.dsh;
  inherit (lib) mkOption types;
  yaml = pkgs.formats.yaml { };
  fileSource = types.either types.path types.str;
  configType = types.submodule {
    options = {
      mode = mkOption {
        type = types.enum [
          "linked"
          "seed"
        ];
        default = "linked";
        description = "Link configuration continuously, or seed a writable file only when absent.";
      };
      source = mkOption {
        type = types.nullOr fileSource;
        default = null;
        description = "YAML file. An absolute string links a live file outside the store; a Nix path is copied into the store.";
      };
      settings = mkOption {
        type = types.nullOr (types.listOf yaml.type);
        default = null;
        description = "Native Cordis patch entries. Mutually exclusive with source; use source for !!js expressions.";
      };
    };
  };
  profileType = types.submodule {
    options = {
      bundles = mkOption {
        type = types.nullOr (types.listOf types.str);
        default = null;
        description = "Ordered bundle names. Null leaves the application-owned profile manifest alone.";
      };
      plugins = mkOption {
        type = types.listOf types.package;
        default = [ ];
        description = "Nix plugin packages exposing dshPlugin.name and dshPlugin.path passthru attributes.";
      };
      config = mkOption {
        type = configType;
        default = { };
      };
    };
  };
  sourceFor =
    name: value:
    if value.source != null then
      if builtins.isString value.source then
        config.lib.file.mkOutOfStoreSymlink value.source
      else
        value.source
    else
      yaml.generate "dsh-${name}.patch.yml" value.settings;
  hasConfig = value: value.source != null || value.settings != null;
  profiles =
    cfg.profiles
    // lib.optionalAttrs (hasConfig cfg.desktop.config) {
      desktop = {
        bundles = null;
        plugins = [ ];
        config = cfg.desktop.config;
      };
    };
  configEntries =
    lib.optional (hasConfig cfg.homeConfig) {
      name = "home";
      target = "${cfg.homeDirectory}/cordis.patch.yml";
      value = cfg.homeConfig;
    }
    ++ lib.mapAttrsToList (name: profile: {
      inherit name;
      target = "${cfg.homeDirectory}/profiles/${name}/cordis.patch.yml";
      value = profile.config;
    }) (lib.filterAttrs (_: profile: hasConfig profile.config) profiles);
  managedProfiles = lib.filterAttrs (
    _: profile: profile.bundles != null || profile.plugins != [ ]
  ) cfg.profiles;
  seeds = map (entry: {
    target = entry.target;
    source = toString (sourceFor entry.name entry.value);
  }) (builtins.filter (entry: entry.value.mode == "seed") configEntries);
  manifestFor =
    name: profile:
    pkgs.writeText "dsh-profile-${name}.json" (
      builtins.toJSON {
        name = "dsh-profile-${name}";
        private = true;
        dependencies = builtins.listToAttrs (
          map (plugin: {
            name = plugin.dshPlugin.name;
            value = "file:${plugin.dshPlugin.path}";
          }) profile.plugins
        );
        dsh.profile.bundles = profile.bundles;
      }
    );
  wrapper =
    package: executable:
    let
      commands = if executable == "dsh" then package.dshCommands or [ executable ] else [ executable ];
    in
    pkgs.symlinkJoin {
      name = "${executable}-home-manager";
      paths = [ package ];
      nativeBuildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        for command in ${lib.escapeShellArgs commands}; do
        wrapProgram "$out/bin/$command" \
          --set DSH_HOME ${lib.escapeShellArg cfg.homeDirectory} \
          ${
            lib.optionalString (
              executable == "dsh-desktop"
            ) "--set DSH_DESKTOP_TITLEBAR ${cfg.desktop.titlebar}"
          } \
          --set DSH_NIX_PATH_PREFIX ${lib.escapeShellArg (lib.makeBinPath cfg.extraPackages)} \
          ${lib.optionalString (
            cfg.extraPackages != [ ]
          ) "--prefix PATH : ${lib.makeBinPath cfg.extraPackages}"}
        done
      '';
      meta.mainProgram = executable;
    };
in
{
  options.programs.dsh = {
    enable = lib.mkEnableOption "DeepSeek Harness";
    package = lib.mkPackageOption pkgs "deepseek-harness" { };
    homeDirectory = mkOption {
      type = types.str;
      default = "${config.home.homeDirectory}/.dsh";
      description = "Writable Harness home; sessions, credentials and memory remain application-owned.";
    };
    extraPackages = mkOption {
      type = types.listOf types.package;
      default = [ ];
      description = "Tools exposed to DSH and agent subprocesses, without adding them to every application's PATH.";
    };
    homeConfig = mkOption {
      type = configType;
      default = { };
    };
    profiles = mkOption {
      type = types.attrsOf profileType;
      default = { };
      description = "Optional profile configuration. Undeclared profiles remain application-managed.";
    };
    skills = mkOption {
      type = types.nullOr fileSource;
      default = null;
      description = "Optional skills directory; absolute strings link the live checkout.";
    };
    desktop = {
      enable = lib.mkEnableOption "the DeepSeek Harness desktop application";
      package = lib.mkPackageOption pkgs "deepseek-harness-desktop" { };
      titlebar = mkOption {
        type = types.enum [
          "integrated"
          "native"
        ];
        default = "integrated";
        description = "Use the shared caption/menu or native Linux window decorations.";
      };
      config = mkOption {
        type = configType;
        default = { };
      };
    };
  };
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = lib.hasPrefix "/" cfg.homeDirectory;
        message = "programs.dsh.homeDirectory must be absolute.";
      }
      {
        assertion = !(cfg.profiles ? desktop);
        message = "Use programs.dsh.desktop.config for the Electron-owned desktop profile.";
      }
      {
        assertion = builtins.all (name: builtins.match "[A-Za-z0-9][A-Za-z0-9._-]*" name != null) (
          builtins.attrNames cfg.profiles
        );
        message = "DSH profile names must contain only letters, numbers, dots, underscores and hyphens, starting with a letter or number.";
      }
    ]
    ++ lib.concatMap (entry: [
      {
        assertion = entry.value.source == null || entry.value.settings == null;
        message = "DSH ${entry.name}: config.source and config.settings are mutually exclusive.";
      }
      {
        assertion = !builtins.isString entry.value.source || lib.hasPrefix "/" entry.value.source;
        message = "DSH ${entry.name}: live source strings must be absolute paths.";
      }
    ]) configEntries
    ++ lib.concatLists (
      lib.mapAttrsToList (name: profile: [
        {
          assertion = builtins.match "[A-Za-z0-9][A-Za-z0-9._-]*" name != null;
          message = "Invalid DSH profile name: ${name}";
        }
        {
          assertion = profile.bundles != null;
          message = "DSH ${name}: declare bundles when installing Nix-managed plugins.";
        }
        {
          assertion = builtins.all (
            plugin: plugin ? dshPlugin && plugin.dshPlugin ? name && plugin.dshPlugin ? path
          ) profile.plugins;
          message = "DSH ${name}: each plugin must expose dshPlugin.name and dshPlugin.path.";
        }
        {
          assertion =
            let
              names = map (plugin: plugin.dshPlugin.name) profile.plugins;
            in
            builtins.length names == builtins.length (lib.unique names);
          message = "DSH ${name}: duplicate plugin names.";
        }
      ]) managedProfiles
    );
    home.packages = [
      (wrapper cfg.package "dsh")
    ]
    ++ lib.optional cfg.desktop.enable (wrapper cfg.desktop.package "dsh-desktop");
    home.file =
      lib.listToAttrs (
        map (entry: {
          name = entry.target;
          value.source = sourceFor entry.name entry.value;
        }) (builtins.filter (entry: entry.value.mode == "linked") configEntries)
      )
      // lib.optionalAttrs (cfg.skills != null) {
        "${cfg.homeDirectory}/skills".source =
          if builtins.isString cfg.skills then config.lib.file.mkOutOfStoreSymlink cfg.skills else cfg.skills;
      }
      // lib.concatMapAttrs (name: profile: {
        "${cfg.homeDirectory}/profiles/${name}/package.json".source = manifestFor name profile;
        "${cfg.homeDirectory}/profiles/${name}/node_modules".source = pkgs.linkFarm "dsh-${name}-plugins" (
          map (plugin: {
            name = plugin.dshPlugin.name;
            path = plugin.dshPlugin.path;
          }) profile.plugins
        );
      }) managedProfiles;
    home.activation.dshSeedConfiguration = lib.mkIf (seeds != [ ]) (
      lib.hm.dag.entryAfter [ "linkGeneration" ] ''
        run ${pkgs.python3}/bin/python3 ${./seed-config.py} ${pkgs.writeText "dsh-seeds.json" (builtins.toJSON seeds)}
      ''
    );
    xdg.desktopEntries.deepseek-harness = lib.mkIf cfg.desktop.enable {
      name = "DeepSeek Harness";
      exec = "${wrapper cfg.desktop.package "dsh-desktop"}/bin/dsh-desktop %u";
      icon = "deepseek-harness";
      categories = [ "Development" ];
      mimeType = [ "x-scheme-handler/dsh" ];
      terminal = false;
    };
  };
}
