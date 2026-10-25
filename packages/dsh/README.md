# Personal DSH profiles

`dsh` 是官方源码包 `deepseek-harness` 上的个人启动器和固定插件层，两者共用 0.2.1-rc.3 核心。TUI 固定为声明支持 rc.3 的 0.17.0；Web 保留 better-sidebar、checkpoint-rewind、claude-move 和 usage-billing。通知插件从记录的源码构建。构建和启动不依赖原来的工作目录，也不在启动时联网安装 npm 包。

```sh
nix build path:.#dsh -o result-dsh
./result-dsh/bin/dsh
./result-dsh/bin/dsh-web
./result-dsh/bin/dsh-raw --version
```

默认 `DSH_HOME=~/.dsh`，可显式覆盖。`dsh` 默认 TUI，`dsh web` / `dsh-web` 默认只监听 127.0.0.1:3080，`DSH_WEB_PORT` 可改端口，`dsh-raw` 调用官方 CLI。遥测默认关闭。

## Home Manager

```nix
{ config, inputs, ... }:
{
  imports = [ inputs.personal-packages.homeManagerModules.dsh ];
  programs.dsh = {
    enable = true;
    desktop.enable = true;
    profiles.dsh-tui.config.source = "${config.home.homeDirectory}/nixos/home/dev/agent/dsh/dsh-tui.patch.yml";
    profiles.web.config.source = "${config.home.homeDirectory}/nixos/home/dev/agent/dsh/dsh-web.patch.yml";
    skills = "${config.home.homeDirectory}/nixos/home/dev/agent/dsh/skills";
  };
}
```

此模块复用通用 `programs.dsh` 接口，默认选择个人包及 TUI/Web 插件。`desktop` 使用官方桌面包，与 CLI 共用数据目录。配置接口见 [通用模块说明](../deepseek-harness/README.md)。文档工具可通过 `home.packages` 或 `extraPackages` 自选，不由通用模块强制安装。

`profilePackages`、`profilePlugins`、`profileBundles` 是包的 passthru，可用于组合自己的模块。每个插件提供 `dshPlugin.name/path`，与通用模块接口一致。插件共享官方核心的模块实例，不另装一个旧版本核心。

首次独立使用时，启动器创建 Nix 管理的 manifest/依赖链接，并仅在缺失时初始化可写配置。已由 Home Manager 管理的链接保持由 Home Manager 更新。应用偏好、技能自定义入口不会被启动器覆盖。已有非受管 profile 不自动接管；迁移前备份，只搬运行状态，不搬旧 node_modules。Nix 回退不会回退凭据、会话或记忆。

## Maintenance

插件 manifests 和锁文件在 `source/.runtime/dsh/profiles/`。先检查插件声明的兼容范围，再调整版本，用 pnpm 11 更新锁文件；构建固定的依赖哈希记录在 `deps.json`。官方核心及桌面由 `packages/deepseek-harness` 维护，个人层不下载第二份核心。

`import-source.py` 仅刷新原个人部署的配置、技能及通知插件源码，保留这里独立维护的插件 manifests/锁文件。`source.json` 记录初始导入来源和通知插件版本。快照不包含凭据、会话、账本或 node_modules。

构建检查加载真实 TUI/Web 配置，并测试并发初始化、只读插件、配置保留、中断恢复及旧 profile 保护。插件组合和个人配置尚未声明统一的分发许可证，组合包暂标记 unfree；官方通用包保持自身许可证。
