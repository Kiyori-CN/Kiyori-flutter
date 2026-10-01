[CmdletBinding()]
param([switch]$WindowsIntegration)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
function Invoke-Checked {
  param([string]$Command, [string[]]$Arguments)
  & $Command @Arguments
  if ($LASTEXITCODE -ne 0) { throw "Failed: $Command $($Arguments -join ' ')" }
}
Push-Location $repositoryRoot
try {
  & (Join-Path $PSScriptRoot 'check-foundation.ps1')
  & (Join-Path $PSScriptRoot 'check-toolchains.ps1')
  Invoke-Checked cargo @('fmt', '--all', '--check')
  Invoke-Checked cargo @('clippy', '--workspace', '--all-targets', '--locked', '--', '-D', 'warnings')
  Invoke-Checked cargo @('test', '--workspace', '--locked')
  Invoke-Checked dart @('format', '--output=none', '--set-exit-if-changed', 'apps/kiyori/lib', 'apps/kiyori/test', 'apps/kiyori/integration_test', 'apps/kiyori/test_driver', 'packages/kiyori_ui/lib', 'packages/kiyori_bridge/lib', 'packages/kiyori_bridge/test', 'packages/kiyori_bridge/hook')
  Invoke-Checked flutter @('analyze')
  Push-Location apps/kiyori
  try { Invoke-Checked flutter @('test', '--reporter', 'expanded') } finally { Pop-Location }
  # Standalone Dart tests use FRB's documented loader override, not the bundle search path.
  Invoke-Checked cargo @('build', '-p', 'kiyori_ffi', '--release', '--locked')
  $previousLibraryPath = $env:FRB_DART_LOAD_EXTERNAL_LIBRARY_NATIVE_LIB_DIR
  $env:FRB_DART_LOAD_EXTERNAL_LIBRARY_NATIVE_LIB_DIR = Join-Path $repositoryRoot 'target/release'
  Push-Location packages/kiyori_bridge
  try { Invoke-Checked dart @('test', '--reporter', 'expanded') }
  finally {
    Pop-Location
    $env:FRB_DART_LOAD_EXTERNAL_LIBRARY_NATIVE_LIB_DIR = $previousLibraryPath
  }
  if ($WindowsIntegration) {
    if (-not $IsWindows) { throw 'Windows engine integration requires a Windows host.' }
    Push-Location apps/kiyori
    try { Invoke-Checked flutter @('test', 'integration_test/runtime_test.dart', '-d', 'windows') }
    finally { Pop-Location }
  }
} finally { Pop-Location }
