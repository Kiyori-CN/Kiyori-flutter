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
  # format/test 直接调用 PATH 上的 dart，不能只相信 Flutter 报告的随附版本。
  $dart = & dart --version 2>&1
  if ($LASTEXITCODE -ne 0 -or "$dart" -notmatch ('^Dart SDK version: ' + [regex]::Escape($baseline.flutter.dartVersion) + ' ')) {
    throw "Expected Dart $($baseline.flutter.dartVersion) on PATH; found $dart"
  }
  Write-Host "PASS: Flutter $($flutter.frameworkVersion), bundled and PATH Dart $($flutter.dartSdkVersion), $rust"
} finally { Pop-Location }
