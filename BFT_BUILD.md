# 百分兔 桌面端打包说明

把网页 `https://sc.baifentu.net/web_app/#/`（生产）和 `https://tiku.baifentu.net/web_app/#/`（测试）打成 Windows / macOS 桌面应用。

- 代码仓库：`https://github.com/VedaChen/Pake_BFT`（tw93/Pake 的 fork），分支 `main`
- 打包工具：Pake CLI（本仓库 `bin/`，通过 Tauri v2 生成安装包）
- 产物：Windows `.msi`（x64 / arm64）、macOS `.dmg`（arm64 / x64）

---

## 1. 两种打包方式

| 方式 | 入口 | 适用 |
| --- | --- | --- |
| GitHub Actions | `.github/workflows/pake-cli.yaml`（workflow 名：`Build App With Pake CLI`） | 不想装环境、要 mac+win 全平台 |
| 本地 PowerShell | `scripts/build.ps1`（交互菜单） | 只打 Windows，改完立即验证 |

两种方式用的是**同一套 Pake 参数**，产物行为一致。

---

## 2. 关键参数（两套环境）

| 项 | 生产 | 测试 |
| --- | --- | --- |
| URL | `https://sc.baifentu.net/web_app/#/` | `https://tiku.baifentu.net/web_app/#/` |
| name（产品名/安装目录/快捷方式） | `百分兔` | `百分兔测试` |
| safe_domain（域锁定） | `sc.baifentu.net` | `tiku.baifentu.net` |
| 图标 | 仓库内 `assets/bft-icon.ico`（CI 用 raw URL） | 同左 |
| installer_language | `zh-CN`（**必须**，见 §5.1） | `zh-CN` |
| app_version | 每次发版必须递增（**必须**，见 §5.2） | 同左 |
| window_mode | `window`（有最小化/最大化/关闭）/ `fullscreen`（全屏无按钮）/ `frameless`（无标题栏） | 同左 |
| bundle_webview | `true`（内嵌离线 WebView2 ≈140MB / mac 塞占位资源） | `false`（小包） |

两个包的 `identifier` 由 `md5(url + "::" + name)` 生成，URL 不同 → identifier 不同 → 可以同时安装、互不覆盖。

---

## 3. GitHub Actions 打包

### 3.1 触发（网页）

仓库 → Actions → `Build App With Pake CLI` → `Run workflow`，填：

```
platform        : windows-latest   （或 macos-latest / ubuntu-24.04）
url             : https://sc.baifentu.net/web_app/#/
name            : 百分兔
icon            : https://raw.githubusercontent.com/VedaChen/Pake_BFT/main/assets/bft-icon.ico
safe_domain     : sc.baifentu.net
installer_language: zh-CN
window_mode     : fullscreen（或 window / frameless）
bundle_webview  : true（正式）/ false（测试）
app_version     : 1.1.0（每次发版必须在此基础 +1，见 §5.2）
width / height  : 1200 / 780
fullscreen/maximize: false（由 window_mode 控制，保持 false）
```

### 3.2 触发（命令行）

```bash
export GH_TOKEN=<有 repo+workflow 权限的 token>

gh workflow run "Build App With Pake CLI" --repo VedaChen/Pake_BFT \
  -f platform="windows-latest" \
  -f url="https://sc.baifentu.net/web_app/#/" \
  -f name="百分兔" \
  -f icon="https://raw.githubusercontent.com/VedaChen/Pake_BFT/main/assets/bft-icon.ico" \
  -f safe_domain="sc.baifentu.net" \
  -f installer_language="zh-CN" \
  -f window_mode="fullscreen" \
  -f app_version="1.1.0" \
  -f width="1200" -f height="780" \
  -f fullscreen=false -f maximize=false
```

### 3.3 取产物

```bash
gh run list  --repo VedaChen/Pake_BFT --workflow "Build App With Pake CLI" --limit 5
gh run watch <run-id> --repo VedaChen/Pake_BFT
gh run download <run-id> --repo VedaChen/Pake_BFT -D ./out
```

产物名：`<name>-Windows-x64`、`<name>-Windows-arm64`、`<name>-macOS-arm64`、`<name>-macOS-x64`。

### 3.4 三个 job

| job | 条件 | 矩阵 | 说明 |
| --- | --- | --- | --- |
| `build` | `platform == ubuntu-24.04` | — | Linux 原有逻辑（本项目不用） |
| `windows` | `platform == windows-latest` | `arch: x64, arm64` | arm64 由 x64 runner **交叉编译** |
| `macos` | `platform == macos-latest` | `arch: arm64, x64` | 一次 dispatch 出两个 dmg |

Windows 关键步骤与坑（对照 workflow 里的注释）：

1. `rustup target add aarch64-pc-windows-msvc`（仅 arm64，setup-env 只装 x64）
2. `--targets x64|arm64`、`--installer-language zh-CN`
3. `--inject scripts/inject/quit-app.js`（见 §4）
4. 窗口模式：`fullscreen` → `--fullscreen`；`frameless` → `--hide-window-decorations`
5. CLI 把 msi 复制到仓库根目录 → 脚本改名为 `<name>-<arch>.msi`
6. **arm64 兜底**：Pake 按 `_aarch64_` 找 msi，Tauri 实际写 `_arm64_`，会报 `ENOENT`；脚本改为从 `src-tauri/target/**/bundle/msi/*.msi` 取最新的

macOS 关键点：

0. **图标必须 png/icns，不能用 ico**：Pake 在 mac 上用 sharp 把图转 icns，而 sharp 读不了 `.ico`，会静默回退成默认图标（日志：`macOS icon must be .icns type., but you give .ico` / `Icon will remain as default.`）。仓库里有 `assets/bft-icon.png`（从 ico 里抽出的 256px 帧），workflow 会把 `.ico` 自动替换成同名 `.png`
1. `--targets arm64|x64`（原模板没传，只会出 runner 自身架构）
2. `--hide-on-close false`：macOS 默认**关窗只是隐藏**，不加这个网页「退出应用」点了没反应
3. `--inject scripts/inject/quit-app.js`
4. dmg 同样改名 `<name>-<arch>.dmg`，并有产物目录兜底

---

## 4. 网页「退出应用」按钮怎么生效

网页实现（`webpage/src/views/LoginView.vue`，`quitApp`）：

```js
fetch('http://127.0.0.1:19876/quit', { mode: 'no-cors' })  // 旧 Chrome 壳的本地退出服务
window.close()
```

在 Pake（Tauri/WebView2）里这两件事都无效。因此仓库内有注入脚本：

- `scripts/inject/quit-app.js`：在页面脚本之前注入，拦截 `fetch` 到 `127.0.0.1:19876`、重写 `window.close()`，统一调用 `__TAURI__.window.getCurrentWindow().close()`
- 关掉最后一个窗口即退出进程（Windows 默认 `hide_on_close=false`；macOS 由 `--hide-on-close false` 保证）
- 依赖：Pake 会给配置的远程域名自动授予 IPC 权限（`src-tauri/src/app/config.rs` 的 `remote_capability`），能力集里已有 `core:window:allow-close`
- 因此**不需要改网页、也不需要改 Pake 的 Rust 代码**

> 页面以后若改成 `window.__TAURI__` 或派发 `pake:quit` 事件，这个脚本也兼容。

---

## 4.1 安装包体积策略

| 环境 | Windows | macOS | 目的 |
| --- | --- | --- | --- |
| 正式 | `bundle_webview=true` → `webviewInstallMode: offlineInstaller`（Tauri 构建时下载对应架构的离线安装包并内嵌，安装时缺失则自动离线安装）≈140MB | 把一个占位资源 `src-tauri/webview2-runtime.cab` 塞进 `bundle.resources`（macOS 的 WKWebView 是系统组件，没有可装的运行时，纯为撑体积） | 用户不用自己装 WebView2，包体也显得正式 |
| 测试 | `bundle_webview=false` → 不内嵌，约 3.5MB | 不塞资源，约 5MB | 内部分发省流量 |

开关由 `scripts/ci/configure-bundle.mjs` 在打包前改写 `src-tauri/tauri.windows.conf.json` / `tauri.macos.conf.json`，本地脚本在结束后用 `git checkout` 还原。

## 5. 已知坑（都是实际踩过的）

### 5.1 中文应用名必须 `--installer-language zh-CN`

默认 `en-US`（代码页 1252）时，WiX 打包阶段 `light.exe` 直接失败：`failed to bundle project: failed to run light.exe`。换成 `zh-CN`（代码页 936）后正常。

### 5.2 同版本 MSI 不会替换已装的 exe，必须递增版本号

Windows Installer 按文件版本判断是否替换。装过 `1.0.0` 后，再装另一个 `1.0.0`（哪怕内容不同，例如窗口版 → 全屏版）**不会替换 exe**，看起来「装了但没变化」。所以：**每次改配置发版，都要把 `app_version` 加一**（如 1.1.0 → 1.2.0）。

排查方法：控制面板/应用列表里看版本号；版本号没变 = 没替换。想彻底干净就先卸载再装。

> 本地 `scripts/build.ps1` 会自动处理：每次打包把版本号最后一位 +1，记录在 `output\version.txt`（git 忽略）。
> CI 是手动传 `app_version`，需要人工保证递增。

### 5.3 `--maximize` 在 Windows 上会变成极小窗口

Pake 主窗口是「先隐藏创建、页面加载后 show」。Windows 上隐藏态直接最大化会得到空的还原矩形，show 出来是一条很窄的小窗。**不要用 `--maximize`**；需要大窗口就用 `window_mode=fullscreen`，或普通窗口自己点最大化。

### 5.4 arm64 的 msi 复制 bug

见 §3.4 第 6 点。CI 与本地脚本都已兜底，不会失败。

### 5.5 全屏包 vs 普通窗口包容易装错

两种包文件名相同（`百分兔-x64.msi`）。务必按目录/版本号区分，例如 `output/1.1.0-全屏/`。

---

## 6. 本地打包（Windows）

### 6.1 依赖（一次性）

- Node.js 20.9+、pnpm 10
- Rust：`winget install --id Rustlang.Rustup -e`（装完重开终端）
- Visual Studio Build Tools，勾选「使用 C++ 的桌面开发」
- WiX 不用装（Tauri 自带 WixTools）、WebView2 通常系统已有

### 6.2 运行

```powershell
cd <仓库目录>
.\scripts\build.ps1
```

菜单流程：环境（生产/测试）→ 架构（x64 / arm64 / 两个都要）→ 窗口模式（普通 / 全屏 / 无边框）→ 确认。

版本号不再手填：脚本读取 `output\version.txt`（首次缺省 `1.1.0`），把最后一位 +1 作为本次版本，成功出包后写回文件。同一次运行里打多个架构/多个环境共用一个版本号。

脚本自动完成：首次 `pnpm install` → `pnpm run cli:build` → 按架构调 `node dist/cli.js` → arm64 自动加 Rust target → 兜底取回 msi → 汇总到 `output\`。

产物直接放 `output\`，文件名带版本：`output\百分兔-x64-v1.1.2.msi`、`output\百分兔测试-arm64-v1.1.2.msi`。

**每次出新包会自动删掉同产品、同格式的旧版本文件**（例如打出 `百分兔-x64-v1.1.4.msi` 就删掉 `百分兔-x64-v1.1.3.msi`），不用手动清理。

`output\` 已在 `.gitignore` 中忽略，不会进版本库。

脚本是 UTF-8 BOM + CRLF，Windows PowerShell 5.1 下中文不乱码。

---

## 7. 发版检查清单

1. 确认仓库 `main` 已是最新（`git pull`）
2. 提升 `app_version`（必须，见 §5.2；本地脚本自动 +1，CI 需手填）
3. 两套环境各触发一次 workflow（Windows、macOS 各一次）
4. 运行全绿后 `gh run download` 取四个产物
5. 装机验证：
   - 控制面板版本号 = 本次版本
   - 全屏包：无标题栏按钮，网页「退出应用」能退出
   - 窗口包：最小化/最大化/关闭正常
   - 域锁定：不能导航到 `baifentu.net` 之外的站点

---

## 8. 相关文件

| 文件 | 作用 |
| --- | --- |
| `.github/workflows/pake-cli.yaml` | CI 打包（windows/macos 矩阵、参数映射、产物改名与兜底） |
| `scripts/build.ps1` | 本地交互式打包 |
| `scripts/inject/quit-app.js` | 网页「退出应用」→ Tauri 关窗 |
| `assets/bft-icon.ico` | 应用图标（CI 用 raw URL 引用） |
| `bin/` | Pake CLI 源码（一般不需要改） |
| `src-tauri/` | Tauri 壳（一般不需要改） |
