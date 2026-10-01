[CmdletBinding()]
param([string]$EnvironmentRoot = 'D:\01_Environment')

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$baseline = Get-Content -LiteralPath (Join-Path $repositoryRoot 'toolchains.json') -Raw | ConvertFrom-Json
$policyModule = Join-Path $EnvironmentRoot 'Maintenance\EnvPolicy.psm1'
if (-not (Test-Path -LiteralPath $policyModule -PathType Leaf)) {
  throw 'Managed environment policy is unavailable. See docs/development/toolchains.md for manual setup.'
}
Import-Module $policyModule -Force
$policy = Import-EnvPolicy -Root $EnvironmentRoot
Set-ProcessEnvFromPolicy -Policy $policy

# Only this shell selects the project SDK; persisted user policy remains the authority for shared state.
$selectedFlutterRoot = Join-Path $EnvironmentRoot "Toolchains\Flutter\$($baseline.flutter.version)\flutter"
$selectedJavaRoot = Join-Path $EnvironmentRoot "Toolchains\Java\jdk-$($baseline.android.jdk)"
foreach ($required in @((Join-Path $selectedFlutterRoot 'bin\flutter.bat'), (Join-Path $selectedJavaRoot 'bin\java.exe'))) {
  if (-not (Test-Path -LiteralPath $required -PathType Leaf)) { throw "Missing pinned tool: $required" }
}
$env:FLUTTER_ROOT = $selectedFlutterRoot
$env:JAVA_HOME = $selectedJavaRoot
$env:Path = Join-EnvPathList -Entries (@((Join-Path $selectedFlutterRoot 'bin'), (Join-Path $selectedJavaRoot 'bin')) + ($env:Path -split ';'))
Write-Host "Kiyori environment active for this shell: Flutter $($baseline.flutter.version), Rust $($baseline.rust.version) via rust-toolchain.toml."
