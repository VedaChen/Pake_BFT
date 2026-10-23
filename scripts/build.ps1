<#
  百分兔 本地打包脚本（交互式，不需要任何参数）

  在 PowerShell 里运行：
      .\scripts\build.ps1

  依赖（只需装一次）：
    - Node.js 20.9+ 与 pnpm 10
    - Rust（winget install --id Rustlang.Rustup -e）
    - Visual Studio Build Tools（"使用 C++ 的桌面开发"工作负载）

  产物：仓库根目录下的 output\ 文件夹
#>

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
Push-Location $repoRoot

$environments = [ordered]@{
    '1' = @{
        Label      = '生产环境'
        Url        = 'https://sc.baifentu.net/web_app/#/'
        Name       = '百分兔'
        SafeDomain = 'sc.baifentu.net'
    }
    '2' = @{
        Label      = '测试环境'
        Url        = 'https://tiku.baifentu.net/web_app/#/'
        Name       = '百分兔测试'
        SafeDomain = 'tiku.baifentu.net'
    }
}

$architectures = [ordered]@{
    '1' = @{ Label = 'x64（普通电脑）';       List = @('x64') }
    '2' = @{ Label = 'arm64（ARM 设备）';     List = @('arm64') }
    '3' = @{ Label = '两个都要（x64+arm64）'; List = @('x64', 'arm64') }
}

function Write-Title {
    Write-Host ''
    Write-Host '==================================================' -ForegroundColor DarkCyan
    Write-Host '            百分兔  打包工具' -ForegroundColor Cyan
    Write-Host '==================================================' -ForegroundColor DarkCyan
    Write-Host ''
}

function Pause-Menu {
    Write-Host ''
    $null = Read-Host '按回车返回主菜单'
}

function Test-Prerequisites {
    $missing = @()
    foreach ($command in @('node', 'pnpm')) {
        if (-not (Get-Command $command -ErrorAction SilentlyContinue)) { $missing += $command }
    }
    if (-not (Get-Command rustc -ErrorAction SilentlyContinue)) { $missing += 'rust' }
    if ($missing.Count -eq 0) { return $true }

    Write-Host ''
    Write-Host '缺少依赖：' -ForegroundColor Red
    foreach ($item in $missing) {
        if ($item -eq 'node') { Write-Host '  - Node.js 20.9+ : https://nodejs.org/' -ForegroundColor Yellow }
        if ($item -eq 'pnpm') { Write-Host '  - pnpm 10       : npm i -g pnpm@10.26.2' -ForegroundColor Yellow }
        if ($item -eq 'rust') { Write-Host '  - Rust          : winget install --id Rustlang.Rustup -e  （装完重开终端）' -ForegroundColor Yellow }
    }
    return $false
}

function Get-Environment {
    while ($true) {
        Write-Title
        Write-Host '  请选择要打包的环境：' -ForegroundColor White
        Write-Host ''
        foreach ($key in $environments.Keys) {
            $item = $environments[$key]
            Write-Host ('   {0}. {1}  ({2})' -f $key, $item.Label, $item.Url)
        }
        Write-Host '   0. 退出'
        Write-Host ''
        $choice = Read-Host '输入序号'

        if ($choice -eq '0') { return $null }
        if ($environments.Contains($choice)) { return $environments[$choice] }

        Write-Host '输入无效，请重新选择。' -ForegroundColor Red
        Start-Sleep -Milliseconds 700
    }
}

function Get-Architecture {
    param($Environment)

    while ($true) {
        Write-Title
        Write-Host ('  环境：{0}' -f $Environment.Label) -ForegroundColor White
        Write-Host ''
        Write-Host '  请选择目标架构：' -ForegroundColor White
        Write-Host ''
        foreach ($key in $architectures.Keys) {
            Write-Host ('   {0}. {1}' -f $key, $architectures[$key].Label)
        }
        Write-Host '   0. 返回环境选择'
        Write-Host ''
        $choice = Read-Host '输入序号'

        if ($choice -eq '0') { return $null }
        if ($architectures.Contains($choice)) { return $architectures[$choice] }

        Write-Host '输入无效，请重新选择。' -ForegroundColor Red
        Start-Sleep -Milliseconds 700
    }
}

function Invoke-Build {
    param($Environment, $Architecture)

    Write-Title
    Write-Host ('  环境：{0}' -f $Environment.Label) -ForegroundColor White
    Write-Host ('  架构：{0}' -f $Architecture.Label) -ForegroundColor White
    Write-Host ''

    $versionInput = Read-Host '  版本号（直接回车 = 1.0.0）'
    $appVersion = '1.0.0'
    if (-not [string]::IsNullOrWhiteSpace($versionInput)) { $appVersion = $versionInput.Trim() }

    $width = '1200'
    $height = '780'

    Write-Host ''
    Write-Host ('  将生成：{0}' -f $Environment.Name) -ForegroundColor DarkCyan
    Write-Host ('    地址     : {0}' -f $Environment.Url)
    Write-Host ('    域锁定   : {0}' -f $Environment.SafeDomain)
    Write-Host ('    版本/窗口 : {0} / {1}x{2}' -f $appVersion, $width, $height)
    Write-Host ''

    $confirm = Read-Host '  开始打包？[Y/n]'
    if ($confirm -eq 'n' -or $confirm -eq 'N') { return }

    if (-not (Test-Prerequisites)) {
        Pause-Menu
        return
    }

    $iconPath = Join-Path $repoRoot 'assets\bft-icon.ico'
    if (-not (Test-Path -LiteralPath $iconPath)) {
        Write-Host ('找不到图标：{0}' -f $iconPath) -ForegroundColor Red
        Pause-Menu
        return
    }

    $nodeModules = Join-Path $repoRoot 'node_modules'
    if (-not (Test-Path -LiteralPath $nodeModules)) {
        Write-Host ''
        Write-Host '==> 首次运行，安装依赖（pnpm install）' -ForegroundColor Green
        pnpm install
        if ($LASTEXITCODE -ne 0) {
            Write-Host 'pnpm install 失败。' -ForegroundColor Red
            Pause-Menu
            return
        }
    }

    Write-Host ''
    Write-Host '==> 编译打包工具（pnpm run cli:build）' -ForegroundColor Green
    pnpm run cli:build
    if ($LASTEXITCODE -ne 0) {
        Write-Host 'pnpm run cli:build 失败。' -ForegroundColor Red
        Pause-Menu
        return
    }

    $outputDir = Join-Path $repoRoot 'output'
    New-Item -ItemType Directory -Force -Path $outputDir | Out-Null

    $built = @()
    foreach ($oneArch in $Architecture.List) {
        Write-Host ''
        Write-Host ('==> 打包 {0}（{1}）' -f $Environment.Name, $oneArch) -ForegroundColor Green

        if ($oneArch -eq 'arm64') {
            $null = & rustup target add aarch64-pc-windows-msvc 2>&1
        }

        $pakeArgs = @(
            $Environment.Url,
            '--name', $Environment.Name,
            '--icon', $iconPath,
            '--width', $width,
            '--height', $height,
            '--safe-domain', $Environment.SafeDomain,
            '--installer-language', 'zh-CN',
            '--targets', $oneArch,
            '--app-version', $appVersion
        )
        Write-Host ('    node dist/cli.js {0}' -f ($pakeArgs -join ' ')) -ForegroundColor DarkGray

        & node dist/cli.js @pakeArgs
        $pakeExit = $LASTEXITCODE

        # CLI 会把安装包复制到仓库根目录。Windows arm64 上它查找的是
        # "..._aarch64_..." 而 Tauri 实际写 "..._arm64_..."，所以从产物目录兜底。
        $rootMsi = Join-Path $repoRoot ($Environment.Name + '.msi')
        if (-not (Test-Path -LiteralPath $rootMsi)) {
            $candidate = Get-ChildItem -Path (Join-Path $repoRoot 'src-tauri\target') `
                -Recurse -Filter *.msi -ErrorAction SilentlyContinue |
                Sort-Object LastWriteTime -Descending |
                Select-Object -First 1
            if ($candidate) {
                Copy-Item -LiteralPath $candidate.FullName -Destination $rootMsi -Force
                Write-Host ('    已从产物目录取回：{0}' -f $candidate.FullName) -ForegroundColor DarkYellow
            }
        }

        if (-not (Test-Path -LiteralPath $rootMsi)) {
            Write-Host ('打包 {0} 失败（pake 退出码 {1}）。' -f $oneArch, $pakeExit) -ForegroundColor Red
            continue
        }
        if ($pakeExit -ne 0) {
            Write-Warning ('pake 退出码 {0}，但已取回安装包。' -f $pakeExit)
        }

        $finalPath = Join-Path $outputDir ('{0}-{1}.msi' -f $Environment.Name, $oneArch)
        Move-Item -LiteralPath $rootMsi -Destination $finalPath -Force
        $sizeMb = [math]::Round((Get-Item -LiteralPath $finalPath).Length / 1MB, 2)
        $built += New-Object psobject -Property ([ordered]@{
            '架构'     = $oneArch
            '大小(MB)' = $sizeMb
            '文件'     = $finalPath
        })
    }

    Write-Host ''
    if ($built.Count -gt 0) {
        Write-Host '打包完成：' -ForegroundColor Green
        $built | Format-Table -AutoSize
        Write-Host ('输出目录：{0}' -f $outputDir) -ForegroundColor Green
    }
    else {
        Write-Host '没有生成任何安装包，请查看上面的报错。' -ForegroundColor Red
    }
    Pause-Menu
}

try {
    while ($true) {
        $selectedEnvironment = Get-Environment
        if ($null -eq $selectedEnvironment) { break }

        $selectedArchitecture = Get-Architecture -Environment $selectedEnvironment
        if ($null -eq $selectedArchitecture) { continue }

        Invoke-Build -Environment $selectedEnvironment -Architecture $selectedArchitecture
    }
    Write-Host ''
    Write-Host '已退出。' -ForegroundColor DarkGray
}
finally {
    Pop-Location
}
