[CmdletBinding()]
param([switch]$Check)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'bridge-output.ps1')
$baseline = Get-Content (Join-Path $repositoryRoot 'toolchains.json') -Raw | ConvertFrom-Json
$generator = Get-Command flutter_rust_bridge_codegen -ErrorAction SilentlyContinue
$generatorPath = if ($generator) { $generator.Source } else {
  "D:\01_Environment\Tools\FlutterRustBridge\$($baseline.flutterRustBridge.version)\bin\flutter_rust_bridge_codegen.exe"
}
if (-not (Test-Path -LiteralPath $generatorPath)) { throw 'Install the pinned flutter_rust_bridge_codegen. See docs/development/m1-foundation.md.' }
$version = & $generatorPath --version
if ($LASTEXITCODE -ne 0 -or $version -notmatch ([regex]::Escape($baseline.flutterRustBridge.version) + '$')) { throw "Unexpected bridge generator: $version" }
if ($Check) { $before = Get-BridgeOutputSnapshot $repositoryRoot }
Push-Location $repositoryRoot
try {
  & $generatorPath generate --config-file packages/kiyori_bridge/flutter_rust_bridge.yaml
  if ($LASTEXITCODE -ne 0) { throw 'Bridge generation failed.' }
  # 只格式化生成输出，避免检查模式顺带改写人工维护的 Rust 源码。
  & rustfmt --edition $baseline.rust.edition (Join-Path $repositoryRoot 'crates/kiyori_ffi/src/frb_generated.rs')
  if ($LASTEXITCODE -ne 0) { throw 'Generated Rust formatting failed.' }
  if ($Check) {
    Assert-BridgeOutputUnchanged $before (Get-BridgeOutputSnapshot $repositoryRoot)
    Write-Host "PASS: $($before.Count) generated bridge files unchanged."
  }
} finally { Pop-Location }
