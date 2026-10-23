// 按环境开关打包体积相关的配置（CI 与本地脚本共用）。
//
//   node scripts/ci/configure-bundle.mjs windows true    # 正式版：内嵌离线 WebView2
//   node scripts/ci/configure-bundle.mjs windows false   # 测试版：保持小包
//   node scripts/ci/configure-bundle.mjs macos true      # 正式版：塞一个占位资源撑体积
//   node scripts/ci/configure-bundle.mjs macos false
//   node scripts/ci/configure-bundle.mjs restore         # 全部还原成仓库原始内容
//
// 说明：
// - Windows 用 webviewInstallMode=offlineInstaller：Tauri 打包时下载对应架构的
//   WebView2 离线安装包并内嵌，安装时若系统缺失会自动离线安装（约 +140MB）。
// - macOS 的 WKWebView 属于系统组件，没有运行时可装；这里只是把一个占位文件
//   作为 bundle.resources 打进去，纯粹让 dmg 体积变大。

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(scriptDir, '..', '..');
const windowsConf = path.join(repoRoot, 'src-tauri', 'tauri.windows.conf.json');
const macosConf = path.join(repoRoot, 'src-tauri', 'tauri.macos.conf.json');
const BALLAST = 'webview2-runtime.cab';

const readJson = (file) => JSON.parse(fs.readFileSync(file, 'utf8'));
const writeJson = (file, value) =>
  fs.writeFileSync(file, JSON.stringify(value, null, 2) + '\n', 'utf8');

const readFlag = (value) => value === 'true' || value === 'on' || value === '1';

function configureWindows(enabled) {
  const conf = readJson(windowsConf);
  conf.bundle ??= {};
  conf.bundle.windows ??= {};

  if (enabled) {
    conf.bundle.windows.webviewInstallMode = {
      type: 'offlineInstaller',
      silent: true,
    };
  } else {
    delete conf.bundle.windows.webviewInstallMode;
  }

  writeJson(windowsConf, conf);
  console.log(
    `[bundle] windows: webviewInstallMode=${enabled ? 'offlineInstaller' : 'off'}`,
  );
}

function configureMacos(enabled) {
  const conf = readJson(macosConf);
  conf.bundle ??= {};

  const resources = new Set(Array.isArray(conf.bundle.resources) ? conf.bundle.resources : []);
  if (enabled) {
    resources.add(BALLAST);
  } else {
    resources.delete(BALLAST);
  }

  if (resources.size > 0) {
    conf.bundle.resources = [...resources];
  } else {
    delete conf.bundle.resources;
  }

  writeJson(macosConf, conf);
  console.log(`[bundle] macos: ballast=${enabled ? BALLAST : 'off'}`);
}

const [platform, value] = process.argv.slice(2);

switch (platform) {
  case 'windows':
    configureWindows(readFlag(value));
    break;
  case 'macos':
    configureMacos(readFlag(value));
    break;
  case 'restore': {
    // 用 git 还原，避免 JSON 重新序列化带来的格式变化。
    const { execFileSync } = await import('node:child_process');
    try {
      execFileSync('git', ['checkout', '--', windowsConf, macosConf], {
        cwd: repoRoot,
        stdio: 'ignore',
      });
      console.log('[bundle] restored via git');
    } catch {
      console.log('[bundle] restore skipped (not a git checkout)');
    }
    break;
  }
  default:
    console.error(
      'usage: node scripts/ci/configure-bundle.mjs <windows|macos|restore> [true|false]',
    );
    process.exit(1);
}
