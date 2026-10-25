{ pkgs, home-manager }:
let
  dummy = pkgs.writeShellScriptBin "dsh" "exit 0";
  desktop = pkgs.writeShellScriptBin "dsh-desktop" "exit 0";
  pluginPackage = pkgs.runCommand "dsh-module-fixture" { } ''
    mkdir -p "$out/lib/node_modules/dsh-module-fixture"
    cd "$out/lib/node_modules/dsh-module-fixture"
    echo '{"name":"dsh-module-fixture","version":"1.0.0","type":"module","main":"index.js","dsh":{"bundle":{"patch":"./cordis.patch.yml"}}}' > package.json
    echo 'export const name = "fixture"; export function apply() {}' > index.js
    printf '%s\n' '- insert:' '    - id: fixture' '      name: ./index.js' > cordis.patch.yml
  '';
  plugin = pluginPackage // {
    dshPlugin = {
      name = "dsh-module-fixture";
      path = "${pluginPackage}/lib/node_modules/dsh-module-fixture";
    };
  };
  home = home-manager.lib.homeManagerConfiguration {
    inherit pkgs;
    modules = [
      ./dsh.nix
      {
        home.username = "dsh-test";
        home.homeDirectory = "/tmp/dsh-module-test";
        home.stateVersion = "25.11";
        programs.dsh = {
          enable = true;
          package = dummy;
          desktop = {
            enable = true;
            package = desktop;
            config = {
              mode = "seed";
              settings = [ ];
            };
          };
          homeConfig.settings = [
            {
              id = "locale";
              config.preference = "zh";
            }
          ];
          profiles.web = {
            plugins = [ plugin ];
            bundles = [
              "@deepseek-ai/dsh-base"
              "@deepseek-ai/dsh-web-app"
              "dsh-module-fixture"
            ];
            config.source = toString ./fixtures/live.patch.yml;
          };
          profiles.editable.config = {
            mode = "seed";
            settings = [ ];
          };
        };
      }
    ];
  };
in
{
  activation = home.activationPackage;
  files = builtins.attrNames home.config.home.file;
  assertions = map (entry: entry.message) (
    builtins.filter (entry: !entry.assertion) home.config.assertions
  );
  profileSource = home.config.home.file."/tmp/dsh-module-test/.dsh/profiles/web/package.json".source;
  seeds = home.config.home.activation.dshSeedConfiguration.data;
}
