#requires -Version 7.0
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$baseline = Get-Content -LiteralPath (Join-Path $repositoryRoot 'toolchains.json') -Raw | ConvertFrom-Json
Push-Location $repositoryRoot
try {
  $flutterJson = & flutter --version --machine
  if ($LASTEXITCODE -ne 0) { throw 'Flutter version query failed.' }
  $flutter = ($flutterJson -join "`n") | ConvertFrom-Json
  if ($flutter.frameworkVersion -ne $baseline.flutter.version -or
      $flutter.dartSdkVersion -ne $baseline.flutter.dartVersion -or
      $flutter.channel -ne 'stable') {
    throw "Expected stable Flutter $($baseline.flutter.version) / Dart $($baseline.flutter.dartVersion). Activate the pinned SDK."
  }
  $rust = & rustc --version
  if ($LASTEXITCODE -ne 0 -or $rust -notmatch ('^rustc ' + [regex]::Escape($baseline.rust.version) + ' ')) {
    throw "Expected Rust $($baseline.rust.version); found $rust"
  }
  Write-Host "PASS: Flutter $($flutter.frameworkVersion), bundled Dart $($flutter.dartSdkVersion), $rust"
} finally { Pop-Location }
