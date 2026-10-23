> **本仓库是「百分兔」桌面端的打包仓库**（基于 [tw93/Pake](https://github.com/tw93/Pake) fork，用 Pake CLI + Tauri 生成 Windows / macOS 安装包）。
> 完整技术细节、参数含义、踩过的坑见 **[BFT_BUILD.md](./BFT_BUILD.md)**。下面是接手同学的快速上手。

---

# 百分兔 桌面端：Fork、打包、下载

## 一、Fork 到自己的账号

1. 打开本仓库页面，右上角 **Fork** → 选择自己的账号 → **Create fork**（保持 `main` 分支即可）
2. 直接用自己的 fork 就能跑打包，**不需要额外配置任何 Secret**（打出来的包不签名、不公证）
3. 如需换图标，替换这两个文件（打包时 CI 通过 raw URL 下载，所以必须提交到仓库）：
   - Windows：`assets/bft-icon.ico`（多尺寸 ico）
   - macOS：`assets/bft-icon.png`（≥256×256，PNG；**macOS 不能用 ico**，Pake 转换会失败并回退成默认图标）
4. 若你的 fork 私有，注意 Actions 在私有仓库有额度限制，且部分 runner（如 `macos-latest`）可能不可用，建议保持公开

## 二、触发打包（一个 Action 出全部安装包）

### 2.1 前置检查（一次性）

**Settings → Actions → General**：

- **Actions permissions**：允许使用 Actions
- **Workflow permissions**：选 **Read and write permissions**

### 2.2 操作步骤

1. 进入 **Actions** 标签页
2. 左侧选 **打包百分兔（正式+测试 · Windows+macOS）**
3. **Run workflow**，只需要填 5 个参数：

| 参数             | 说明                         | 建议                                             |
| ---------------- | ---------------------------- | ------------------------------------------------ |
| `app_version`    | 版本号，**每次必须比上次大** | 例 `1.1.4`                                       |
| `window_mode`    | 窗口模式                     | `fullscreen`（全屏无按钮，网页「退出应用」退出） |
| `platform`       | 打哪些平台                   | `all`                                            |
| `environment`    | 打哪些环境                   | `all`（正式+测试）                               |
| `merge_artifact` | 是否合并成一个压缩包         | `true`                                           |

一次运行会并行产出 **8 个安装包**：正式/测试 × Windows(x64, arm64) × macOS(arm64, x64)。
URL、产品名、域名锁定、图标、WebView2（正式内嵌/测试小包）都已在 workflow 里写死，**不用手填**。

### 2.3 命令行触发（可选）

```bash
export GH_TOKEN=<你的 token，需 repo + workflow 权限>

gh workflow run "打包百分兔（正式+测试 · Windows+macOS）" --repo <你的账号>/Pake_BFT   -f app_version="1.1.4"   -f window_mode="fullscreen"   -f platform="all"   -f environment="all"   -f merge_artifact=true
```

## 三、下载产物

### 3.1 网页下载（推荐，点一次）

运行结束后，页面最下方 **Artifacts** 里只有一个：

```
百分兔-全部安装包-v1.1.4.zip
```

下载解压即可，里面是：

```
百分兔-x64-v1.1.4.msi         正式 Windows x64（内嵌离线 WebView2）
百分兔-arm64-v1.1.4.msi       正式 Windows arm64
百分兔-arm64-v1.1.4.dmg       正式 macOS Apple Silicon
百分兔-x64-v1.1.4.dmg         正式 macOS Intel
百分兔测试-x64-v1.1.4.msi     测试 Windows x64（小包）
百分兔测试-arm64-v1.1.4.msi   测试 Windows arm64
百分兔测试-arm64-v1.1.4.dmg   测试 macOS Apple Silicon
百分兔测试-x64-v1.1.4.dmg     测试 macOS Intel
```

如果想单独下某一个，把 `merge_artifact` 设为 `false`，Artifacts 里就会出现 8 个独立产物（`prod-windows-x64`、`test-macos-arm64` 等）。

### 3.2 Release 直链（推荐给最终用户）

`publish_release=true`（默认）时，构建结束会自动创建 Release，tag 为 `v<版本>`：

```
https://github.com/<账号>/Pake_BFT/releases/tag/v1.1.4
https://github.com/<账号>/Pake_BFT/releases/download/v1.1.4/百分兔-x64-v1.1.4.msi
```

Release 附件的下载**不需要登录 GitHub**，适合直接发给用户；同名文件重复发布会覆盖。

### 3.2 命令行下载

```bash
gh run list  --repo <你的账号>/Pake_BFT --limit 5
gh run watch <run-id> --repo <你的账号>/Pake_BFT
gh run download <run-id> --repo <你的账号>/Pake_BFT -D ./output
```

### 3.3 直链格式

```
https://github.com/<你的账号>/Pake_BFT/actions/runs/<run-id>/artifacts/<artifact-id>
```

`run-id` 在运行页面 URL 里；`artifact-id` 用
`gh api repos/<账号>/Pake_BFT/actions/runs/<run-id>/artifacts` 查。

## 四、本地打包（仅 Windows）

```powershell
# 一次性依赖：Node.js 20.9+ / pnpm 10 / Rust(rustup) / VS Build Tools(使用 C++ 的桌面开发)
cd <仓库目录>
.\scripts\build.ps1
```

菜单选择：环境（生产/测试）→ 架构（x64 / arm64 / 两个都要）→ 窗口模式（普通 / 全屏 / 无边框）→ 确认。

- 版本号自动 +1（记录在 `output\version.txt`）
- 产物输出到 `output\正式\` 或 `output\测试\`，文件名带版本
- 打包成功后自动删除同产品、同格式的旧版本包

## 五、必须知道的几个坑

| 坑                         | 说明                                                                                                        |
| -------------------------- | ----------------------------------------------------------------------------------------------------------- |
| 中文名打包失败             | 必须传 `installer_language=zh-CN`（默认 `en-US` 代码页打不了中文，`light.exe` 报错）                        |
| 装了新包没变化             | 同版本 msi 不会替换已安装的 exe，**每次必须递增 `app_version`**；或先卸载再装                               |
| macOS 图标不生效           | macOS 只认 png/icns，传 `.ico` 会静默回退默认图标；仓库已放 `assets/bft-icon.png`                           |
| arm64 msi 构建报 ENOENT    | Pake 按 `aarch64` 找文件、Tauri 实际写 `arm64`；workflow 已有兜底从 bundle 目录取回                         |
| macOS 打不开提示「已损坏」 | 未签名/未公证，右键 →「打开」，或 `系统设置 → 隐私与安全性 → 仍要打开`                                      |
| 想关掉网页右键菜单         | `scripts/inject/disable-context-menu.js` 已注入；网页「退出应用」由 `scripts/inject/quit-app.js` 桥接到关窗 |

---

以下是上游 Pake 的原始说明：

<div align="center">
  <img src="https://raw.githubusercontent.com/tw93/Pake/23bd253908a9b67be433faca0c84d3f857586d85/assets/logo.png" width="138" />
  <h1>Pake</h1>
  <p><b>Turn any website into a lightweight desktop app with one command. Supports macOS, Windows, and Linux.</b></p>
  <p><a href="https://pake.run">pake.run</a></p>
  <p>English · <a href="README_CN.md">中文</a> · <a href="README_TW.md">繁體</a> · <a href="README_JA.md">日本語</a> · <a href="README_KR.md">한국어</a> · <a href="README_DE.md">Deutsch</a> · <a href="README_FR.md">Français</a></p>
  <a href="https://twitter.com/HiTw93" target="_blank"><img alt="twitter" src="https://img.shields.io/badge/follow-Tw93-red?style=flat-square&logo=Twitter"></a>
  <a href="https://t.me/+9f9gf4ZrFSQ2OWVl" target="_blank"><img alt="telegram" src="https://img.shields.io/badge/chat-telegram-blueviolet?style=flat-square&logo=Telegram"></a>
  <a href="https://github.com/tw93/Pake/releases" target="_blank"><img alt="GitHub downloads" src="https://img.shields.io/github/downloads/tw93/Pake/total.svg?style=flat-square"></a>
  <a href="https://github.com/tw93/Pake/commits" target="_blank"><img alt="GitHub commit" src="https://img.shields.io/github/commit-activity/m/tw93/Pake?style=flat-square"></a>
  <a href="https://github.com/tw93/Pake/issues?q=is%3Aissue+is%3Aclosed" target="_blank"><img alt="GitHub closed issues" src="https://img.shields.io/github/issues-closed/tw93/Pake.svg?style=flat-square"></a>
</div>

## Features

- 🎐 **Lightweight**: Installer is nearly 20 times smaller than Electron packages, typically under 10 MB on disk, a lighter alternative to Nativefier and other Electron wrappers
- 🚀 **Fast**: Built with Rust Tauri, much faster than traditional JS frameworks with lower memory usage
- ⚡ **Easy to use**: One-command packaging via CLI or online building, no complex configuration needed
- 📦 **Feature-rich**: Supports shortcuts, immersive windows, drag & drop, style customization, ad removal

## Getting Started

- **Beginners**: Download ready-made [Popular Packages](#popular-packages) or use [Online Building](docs/github-actions-usage.md) with no environment setup required
- **Developers**: Install [CLI Tool](docs/cli-usage.md) for one-command packaging of any website with customizable icons, window settings, and more
- **Advanced Users**: Clone the project locally for [Custom Development](#development), or check [Advanced Usage](docs/advanced-usage.md) for style customization and feature enhancement
- **Troubleshooting**: Check [FAQ](docs/faq.md) for common issues and solutions

## Popular Packages

<table>
    <tr>
        <td>WeRead
            <a href="https://github.com/tw93/Pake/releases/latest/download/WeRead.dmg">Mac</a>
            <a href="https://github.com/tw93/Pake/releases/latest/download/WeRead_x64.msi">Windows</a>
            <a href="https://github.com/tw93/Pake/releases/latest/download/WeRead_x86_64.deb">Linux</a>
        </td>
        <td>Twitter
            <a href="https://github.com/tw93/Pake/releases/latest/download/Twitter.dmg">Mac</a>
            <a href="https://github.com/tw93/Pake/releases/latest/download/Twitter_x64.msi">Windows</a>
            <a href="https://github.com/tw93/Pake/releases/latest/download/Twitter_x86_64.deb">Linux</a>
        </td>
    </tr>
    <tr>
        <td><img src=https://raw.githubusercontent.com/tw93/static/main/pake/WeRead.jpg width=600/></td>
        <td><img src=https://raw.githubusercontent.com/tw93/static/main/pake/Twitter.jpg width=600/></td>
    </tr>
    <tr>
        <td>Grok
            <a href="https://github.com/tw93/Pake/releases/latest/download/Grok.dmg">Mac</a>
            <a href="https://github.com/tw93/Pake/releases/latest/download/Grok_x64.msi">Windows</a>
            <a href="https://github.com/tw93/Pake/releases/latest/download/Grok_x86_64.deb">Linux</a>
        </td>
        <td>DeepSeek
            <a href="https://github.com/tw93/Pake/releases/latest/download/DeepSeek.dmg">Mac</a>
            <a href="https://github.com/tw93/Pake/releases/latest/download/DeepSeek_x64.msi">Windows</a>
            <a href="https://github.com/tw93/Pake/releases/latest/download/DeepSeek_x86_64.deb">Linux</a>
        </td>
    </tr>
    <tr>
        <td><img src=https://raw.githubusercontent.com/tw93/static/main/pake/Grok.png width=600/></td>
        <td><img src=https://raw.githubusercontent.com/tw93/static/main/pake/DeepSeek.png width=600/></td>
    </tr>
    <tr>
        <td>ChatGPT
            <a href="https://github.com/tw93/Pake/releases/latest/download/ChatGPT.dmg">Mac</a>
            <a href="https://github.com/tw93/Pake/releases/latest/download/ChatGPT_x64.msi">Windows</a>
            <a href="https://github.com/tw93/Pake/releases/latest/download/ChatGPT_x86_64.deb">Linux</a>
        </td>
        <td>Gemini
            <a href="https://github.com/tw93/Pake/releases/latest/download/Gemini.dmg">Mac</a>
            <a href="https://github.com/tw93/Pake/releases/latest/download/Gemini_x64.msi">Windows</a>
            <a href="https://github.com/tw93/Pake/releases/latest/download/Gemini_x86_64.deb">Linux</a>
        </td>
    </tr>
    <tr>
        <td><img src=https://raw.githubusercontent.com/tw93/static/main/pake/ChatGPT.png width=600/></td>
        <td><img src=https://raw.githubusercontent.com/tw93/static/main/pake/Gemini.png width=600/></td>
    </tr>
    <tr>
      <td>YouTube Music
            <a href="https://github.com/tw93/Pake/releases/latest/download/YouTubeMusic.dmg">Mac</a>
            <a href="https://github.com/tw93/Pake/releases/latest/download/YouTubeMusic_x64.msi">Windows</a>
            <a href="https://github.com/tw93/Pake/releases/latest/download/YouTubeMusic_x86_64.deb">Linux</a>
      </td>
      <td>YouTube
            <a href="https://github.com/tw93/Pake/releases/latest/download/YouTube.dmg">Mac</a>
            <a href="https://github.com/tw93/Pake/releases/latest/download/YouTube_x64.msi">Windows</a>
            <a href="https://github.com/tw93/Pake/releases/latest/download/YouTube_x86_64.deb">Linux</a>
      </td>
    </tr>
    <tr>
        <td><img src=https://raw.githubusercontent.com/tw93/static/main/pake/YouTubeMusic.png width=600 /></td>
        <td><img src=https://raw.githubusercontent.com/tw93/static/main/pake/YouTube.jpg width=600 /></td>
    </tr>
    <tr>
        <td>LiZhi
            <a href="https://github.com/tw93/Pake/releases/latest/download/LiZhi.dmg">Mac</a>
            <a href="https://github.com/tw93/Pake/releases/latest/download/LiZhi_x64.msi">Windows</a>
            <a href="https://github.com/tw93/Pake/releases/latest/download/LiZhi_x86_64.deb">Linux</a>
        </td>
        <td>ProgramMusic
            <a href="https://github.com/tw93/Pake/releases/latest/download/ProgramMusic.dmg">Mac</a>
            <a href="https://github.com/tw93/Pake/releases/latest/download/ProgramMusic_x64.msi">Windows</a>
            <a href="https://github.com/tw93/Pake/releases/latest/download/ProgramMusic_x86_64.deb">Linux</a>
        </td>
    </tr>
    <tr>
        <td><img src=https://raw.githubusercontent.com/tw93/static/main/pake/LiZhi.jpg width=600/></td>
        <td><img src=https://raw.githubusercontent.com/tw93/static/main/pake/ProgramMusic.jpg width=600/></td>
    </tr>
    <tr>
        <td>Excalidraw
            <a href="https://github.com/tw93/Pake/releases/latest/download/Excalidraw.dmg">Mac</a>
            <a href="https://github.com/tw93/Pake/releases/latest/download/Excalidraw_x64.msi">Windows</a>
            <a href="https://github.com/tw93/Pake/releases/latest/download/Excalidraw_x86_64.deb">Linux</a>
        </td>
        <td>XiaoHongShu
            <a href="https://github.com/tw93/Pake/releases/latest/download/XiaoHongShu.dmg">Mac</a>
            <a href="https://github.com/tw93/Pake/releases/latest/download/XiaoHongShu_x64.msi">Windows</a>
            <a href="https://github.com/tw93/Pake/releases/latest/download/XiaoHongShu_x86_64.deb">Linux</a>
        </td>
    </tr>
    <tr>
        <td><img src=https://raw.githubusercontent.com/tw93/static/main/pake/Excalidraw.png width=600/></td>
        <td><img src=https://raw.githubusercontent.com/tw93/static/main/pake/XiaoHongShu.png width=600/></td>
    </tr>
    <tr>
        <td>Notion
            <a href="https://github.com/tw93/Pake/releases/latest/download/Notion.dmg">Mac</a>
            <a href="https://github.com/tw93/Pake/releases/latest/download/Notion_x64.msi">Windows</a>
            <a href="https://github.com/tw93/Pake/releases/latest/download/Notion_x86_64.deb">Linux</a>
        </td>
        <td>Flomo
            <a href="https://github.com/tw93/Pake/releases/latest/download/Flomo.dmg">Mac</a>
            <a href="https://github.com/tw93/Pake/releases/latest/download/Flomo_x64.msi">Windows</a>
            <a href="https://github.com/tw93/Pake/releases/latest/download/Flomo_x86_64.deb">Linux</a>
        </td>
    </tr>
    <tr>
        <td><img src=https://raw.githubusercontent.com/tw93/static/main/pake/Notion.png width=600/></td>
        <td><img src=https://raw.githubusercontent.com/tw93/static/main/pake/Flomo.png width=600/></td>
    </tr>
</table>

<details>
<summary>🏂 You can download more applications from <a href="https://github.com/tw93/Pake/releases">Releases</a>. <b>Click here to expand the shortcuts reference!</b></summary>

<br/>

| Mac                                                       | Windows/Linux                                       | Function                            |
| --------------------------------------------------------- | --------------------------------------------------- | ----------------------------------- |
| <kbd>⌘</kbd> + <kbd>[</kbd>                               | <kbd>Ctrl</kbd> + <kbd>[</kbd>                      | Return to the previous page         |
| <kbd>⌘</kbd> + <kbd>]</kbd>                               | <kbd>Ctrl</kbd> + <kbd>]</kbd>                      | Go to the next page                 |
| <kbd>⌘</kbd> + <kbd>↑</kbd>                               | <kbd>Ctrl</kbd> + <kbd>↑</kbd>                      | Auto scroll to top of page          |
| <kbd>⌘</kbd> + <kbd>↓</kbd>                               | <kbd>Ctrl</kbd> + <kbd>↓</kbd>                      | Auto scroll to bottom of page       |
| <kbd>⌘</kbd> + <kbd>R</kbd>                               | <kbd>Ctrl</kbd> + <kbd>R</kbd>                      | Refresh page                        |
| <kbd>⌘</kbd> + <kbd>W</kbd>                               | <kbd>Ctrl</kbd> + <kbd>W</kbd>                      | Hide window, not quit               |
| <kbd>⌘</kbd> + <kbd>-</kbd>                               | <kbd>Ctrl</kbd> + <kbd>-</kbd>                      | Zoom out                            |
| <kbd>⌘</kbd> + <kbd>=</kbd>                               | <kbd>Ctrl</kbd> + <kbd>=</kbd>                      | Zoom in                             |
| <kbd>⌘</kbd> + <kbd>0</kbd>                               | <kbd>Ctrl</kbd> + <kbd>0</kbd>                      | Reset zoom                          |
| <kbd>⌘</kbd> + <kbd>L</kbd>                               | <kbd>Ctrl</kbd> + <kbd>L</kbd>                      | Copy current page URL               |
| <kbd>⌘</kbd> + <kbd>⇧</kbd> + <kbd>⌥</kbd> + <kbd>V</kbd> | <kbd>Ctrl</kbd> + <kbd>Shift</kbd> + <kbd>V</kbd>   | Paste and match style               |
| <kbd>⌘</kbd> + <kbd>⇧</kbd> + <kbd>H</kbd>                | <kbd>Ctrl</kbd> + <kbd>Shift</kbd> + <kbd>H</kbd>   | Go to home page                     |
| <kbd>⌘</kbd> + <kbd>⌥</kbd> + <kbd>I</kbd>                | <kbd>Ctrl</kbd> + <kbd>Shift</kbd> + <kbd>I</kbd>   | Toggle developer tools (debug only) |
| <kbd>⌘</kbd> + <kbd>⇧</kbd> + <kbd>⌫</kbd>                | <kbd>Ctrl</kbd> + <kbd>Shift</kbd> + <kbd>Del</kbd> | Clear cache and restart             |
| <kbd>⌃</kbd> + <kbd>⌘</kbd> + <kbd>F</kbd>                | <kbd>F11</kbd>                                      | Toggle native window fullscreen     |

Double-click the title bar to toggle fullscreen. On Windows and Linux, `--hide-window-decorations` gives a frameless window with a top drag region. On Mac, swipe to go back or forward and drag the title bar to move the window, and the menu bar has navigation, zoom and window controls.

</details>

## Command-Line Packaging

![Pake](https://raw.githubusercontent.com/tw93/static/main/pake/pake1.gif)

```bash
# Install Pake CLI
pnpm install -g pake-cli

# Basic usage, fetches the website icon automatically
pake https://github.com --name GitHub

# Advanced usage, custom options
pake https://weekly.tw93.fun --name Weekly --icon https://cdn.tw93.fun/pake/weekly.icns --width 1200 --height 800 --hide-title-bar
```

The first build sets up the environment and takes a while, later builds are fast. See the [CLI Usage Guide](docs/cli-usage.md) for every option, or try [GitHub Actions Online Building](docs/github-actions-usage.md) if you'd rather skip the command line.

Using Pake from a script or AI agent? Pass `--json` for machine-readable results, describe apps declaratively with `--config app.json` ([schema](schema/pake.schema.json)), and package local build output directly with `pake ./dist --name MyTool`. See [llms.txt](llms.txt) for the full agent contract. The official skill installs like this:

```text
# Claude Code
/plugin marketplace add tw93/Pake
/plugin install pake@pake

# Codex
codex plugin marketplace add tw93/Pake
codex plugin add pake@pake
```

Copy this to your AI agent to get started:

```text
Use Pake (npm i -g pake-cli) to package webpages as desktop apps. Read https://unpkg.com/pake-cli@latest/llms.txt first; always run pake with --json and parse stdout as a single JSON object. Package <url-or-local-dist> into an app named <AppName>.
```

## Development

Requires Rust `>=1.85` and Node `>=22` (recommended LTS; `>=20.9` also works), see the [Tauri documentation](https://v2.tauri.app/start/prerequisites/) for setup. If you are new to this toolchain, the CLI is the easier path.

```bash
# Install dependencies
pnpm i

# Local development [right-click to open debug mode]
pnpm run dev

# Build application
pnpm run build
```

For style customization, feature enhancement, container communication and other advanced features, see [Advanced Usage Documentation](docs/advanced-usage.md).

## Developers

Pake wouldn't be possible without these incredible contributors. ❤️

<a href="https://github.com/tw93/Pake/graphs/contributors">
  <img src="./CONTRIBUTORS.svg?v=2" alt="Contributors" width="1000" />
</a>

## Support

- The most direct way to support me is getting [Mole for Mac](https://mole.fit), my paid Mac cleanup app
- If Pake helped you, give it a star, [share it](https://twitter.com/intent/tweet?url=https://github.com/tw93/Pake&text=Pake%20-%20Turn%20any%20webpage%20into%20a%20desktop%20app%20with%20one%20command.%20Nearly%2020x%20smaller%20than%20Electron%20packages,%20supports%20macOS%20Windows%20Linux), or open an issue or PR, including sites that would make good desktop apps
- I have two cats, TangYuan and Coke, and if Pake makes your life a little easier, feel free to treat them to <a href="https://cats.tw93.fun?name=Pake" target="_blank">canned food 🥩</a>

These lovely people already did 🐱

<a href="https://cats.tw93.fun?name=Pake"><img src="https://cdn.jsdelivr.net/gh/tw93/sponsors@main/assets/sponsors.svg" width="1000" loading="lazy" /></a>

## License

Pake is open source under GPL-3.0, see [LICENSE](./LICENSE) and [Pake Output Exception](./LICENSE-EXCEPTION); apps you build with Pake are entirely yours to use and distribute. If you fork Pake into your own product, to avoid confusion please give it a different name and credit Pake as the source.
