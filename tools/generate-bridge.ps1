[CmdletBinding()]
param([switch]$Check)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$baseline = Get-Content (Join-Path $repositoryRoot 'toolchains.json') -Raw | ConvertFrom-Json
$generator = Get-Command flutter_rust_bridge_codegen -ErrorAction SilentlyContinue
$generatorPath = if ($generator) { $generator.Source } else {
  "D:\01_Environment\Tools\FlutterRustBridge\$($baseline.flutterRustBridge.version)\bin\flutter_rust_bridge_codegen.exe"
}
if (-not (Test-Path -LiteralPath $generatorPath)) { throw 'Install the pinned flutter_rust_bridge_codegen. See docs/development/m1-foundation.md.' }
$version = & $generatorPath --version
if ($LASTEXITCODE -ne 0 -or $version -notmatch ([regex]::Escape($baseline.flutterRustBridge.version) + '$')) { throw "Unexpected bridge generator: $version" }
$generated = @((Join-Path $repositoryRoot 'crates/kiyori_ffi/src/frb_generated.rs'))
$generated += Get-ChildItem (Join-Path $repositoryRoot 'packages/kiyori_bridge/lib/src/generated') -File | ForEach-Object FullName
$before = @{}
if ($Check) {
  foreach ($path in $generated) { $before[$path] = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash }
}
Push-Location $repositoryRoot
try {
  & $generatorPath generate --config-file packages/kiyori_bridge/flutter_rust_bridge.yaml
  if ($LASTEXITCODE -ne 0) { throw 'Bridge generation failed.' }
  # FRB invokes rustfmt outside Cargo's edition context; finish with workspace formatting.
  & cargo fmt --all
  if ($LASTEXITCODE -ne 0) { throw 'Workspace Rust formatting failed.' }
  if ($Check) {
    foreach ($path in $generated) {
      if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne $before[$path]) { throw "Generated bridge changed: $path. Review and regenerate before accepting the check." }
    }
  }
} finally { Pop-Location }
