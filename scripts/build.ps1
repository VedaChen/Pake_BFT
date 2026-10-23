<#
.SYNOPSIS
  Builds the "百分兔" Windows installers (production or test, x64 and/or arm64).

.DESCRIPTION
  Wraps the Pake CLI in this repository: installs dependencies if needed, builds
  dist/cli.js, then runs one build per architecture and collects the resulting
  MSI files into the git-ignored output\ folder.

  Requirements (one time):
    - Node.js 20.9+ and pnpm 10
    - Rust via rustup (winget install --id Rustlang.Rustup -e)
    - Visual Studio Build Tools with the "Desktop development with C++" workload

.PARAMETER Environment
  prod = https://sc.baifentu.net/web_app/#/
  test = https://tiku.baifentu.net/web_app/#/

.PARAMETER Arch
  x64 (default), arm64, or both. arm64 cross-compiles from an x64 machine.

.EXAMPLE
  .\scripts\build.ps1

.EXAMPLE
  .\scripts\build.ps1 -Environment test -Arch both -AppVersion 1.1.0

.EXAMPLE
  .\scripts\build.ps1 -Arch arm64 -DryRun   # show the commands only
#>
[CmdletBinding()]
param(
    # Which deployment to package.
    [ValidateSet('prod', 'test')]
    [string]$Environment = 'prod',

    # Target architecture(s).
    [ValidateSet('x64', 'arm64', 'both')]
    [string]$Arch = 'x64',

    # Icon file (.ico / .png). Defaults to assets\bft-icon.ico.
    [string]$Icon = '',

    [string]$AppVersion = '1.0.0',

    [string]$Width = '1200',

    [string]$Height = '780',

    # Skip "pnpm install" (dependencies already present).
    [switch]$SkipInstall,

    # Skip "pnpm run cli:build" (dist/cli.js already up to date).
    [switch]$SkipCliBuild,

    # Print what would run, without building anything.
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
Push-Location $repoRoot
try {
    $targets = @{
        prod = @{
            Url        = 'https://sc.baifentu.net/web_app/#/'
            Name       = '百分兔'
            SafeDomain = 'sc.baifentu.net'
        }
        test = @{
            Url        = 'https://tiku.baifentu.net/web_app/#/'
            Name       = '百分兔测试'
            SafeDomain = 'tiku.baifentu.net'
        }
    }
    $target = $targets[$Environment]

    if ([string]::IsNullOrWhiteSpace($Icon)) {
        $Icon = Join-Path $repoRoot 'assets\bft-icon.ico'
    }
    if (-not (Test-Path -LiteralPath $Icon)) {
        throw "Icon not found: $Icon"
    }
    $Icon = (Resolve-Path -LiteralPath $Icon).Path

    foreach ($command in @('node', 'pnpm')) {
        if (-not (Get-Command $command -ErrorAction SilentlyContinue)) {
            throw "Missing '$command'. Install Node.js 20.9+ and pnpm 10 first."
        }
    }
    if (-not $DryRun -and -not (Get-Command rustc -ErrorAction SilentlyContinue)) {
        throw "Missing Rust. Install it with: winget install --id Rustlang.Rustup -e"
    }

    $archList = @('x64')
    if ($Arch -eq 'arm64' -or $Arch -eq 'both') {
        $archList = @('x64', 'arm64')
    }
    if ($Arch -eq 'arm64') {
        $archList = @('arm64')
    }

    Write-Host ''
    Write-Host ("Environment : {0} ({1})" -f $Environment, $target.Name) -ForegroundColor Cyan
    Write-Host ("URL         : {0}" -f $target.Url) -ForegroundColor Cyan
    Write-Host ("Safe domain : {0}" -f $target.SafeDomain) -ForegroundColor Cyan
    Write-Host ("Arch        : {0}" -f ($archList -join ', ')) -ForegroundColor Cyan
    Write-Host ''

    if ($DryRun) {
        Write-Host 'Dry run: nothing will be built.' -ForegroundColor Yellow
    }
    else {
        if (-not $SkipInstall) {
            Write-Host '==> pnpm install' -ForegroundColor Green
            pnpm install
            if ($LASTEXITCODE -ne 0) { throw 'pnpm install failed' }
        }
        if (-not $SkipCliBuild) {
            Write-Host '==> pnpm run cli:build' -ForegroundColor Green
            pnpm run cli:build
            if ($LASTEXITCODE -ne 0) { throw 'pnpm run cli:build failed' }
        }
    }

    $outputDir = Join-Path $repoRoot 'output'
    if (-not $DryRun) {
        New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
    }

    $built = @()
    foreach ($oneArch in $archList) {
        $pakeArgs = @(
            $target.Url,
            '--name', $target.Name,
            '--icon', $Icon,
            '--width', $Width,
            '--height', $Height,
            '--safe-domain', $target.SafeDomain,
            '--installer-language', 'zh-CN',
            '--targets', $oneArch,
            '--app-version', $AppVersion
        )

        Write-Host ("==> Build {0} ({1})" -f $target.Name, $oneArch) -ForegroundColor Green
        Write-Host ("    node dist/cli.js {0}" -f ($pakeArgs -join ' ')) -ForegroundColor DarkGray

        if ($DryRun) { continue }

        if ($oneArch -eq 'arm64') {
            $null = & rustup target add aarch64-pc-windows-msvc 2>&1
            if ($LASTEXITCODE -ne 0) {
                Write-Warning 'rustup target add aarch64-pc-windows-msvc failed; the arm64 build may not work.'
            }
        }

        & node dist/cli.js @pakeArgs
        $pakeExit = $LASTEXITCODE

        # The CLI copies the installer to the repo root. On Windows arm64 it
        # looks for "..._aarch64_..." while Tauri writes "..._arm64_...", so
        # fall back to the newest MSI left in the bundle folder.
        $rootMsi = Join-Path $repoRoot ($target.Name + '.msi')
        if (-not (Test-Path -LiteralPath $rootMsi)) {
            $candidate = Get-ChildItem -Path (Join-Path $repoRoot 'src-tauri\target') `
                -Recurse -Filter *.msi -ErrorAction SilentlyContinue |
                Sort-Object LastWriteTime -Descending |
                Select-Object -First 1
            if ($candidate) {
                Copy-Item -LiteralPath $candidate.FullName -Destination $rootMsi -Force
                Write-Host ("    recovered {0}" -f $candidate.FullName) -ForegroundColor DarkYellow
            }
        }
        if (-not (Test-Path -LiteralPath $rootMsi)) {
            throw ("No MSI produced for {0} (pake exit code {1})." -f $oneArch, $pakeExit)
        }
        if ($pakeExit -ne 0) {
            Write-Warning ("pake exited with code {0} for {1}, but the MSI was recovered." -f $pakeExit, $oneArch)
        }

        $finalPath = Join-Path $outputDir ('{0}-{1}.msi' -f $target.Name, $oneArch)
        Move-Item -LiteralPath $rootMsi -Destination $finalPath -Force
        $sizeMb = [math]::Round((Get-Item -LiteralPath $finalPath).Length / 1MB, 2)
        $built += New-Object psobject -Property ([ordered]@{
            Arch = $oneArch
            File = $finalPath
            'Size (MB)' = $sizeMb
        })
    }

    if ($built.Count -gt 0) {
        Write-Host ''
        $built | Format-Table -AutoSize
        Write-Host ("Done. Installers are in {0}" -f $outputDir) -ForegroundColor Green
    }
}
finally {
    Pop-Location
}
