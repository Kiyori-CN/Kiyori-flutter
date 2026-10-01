[CmdletBinding()]
param(
  [Parameter(Mandatory)][ValidateSet('android', 'windows', 'ios')][string]$Platform,
  [ValidateSet('debug', 'profile', 'release')][string]$Mode = 'debug'
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
& (Join-Path $PSScriptRoot 'check-toolchains.ps1')
Push-Location (Join-Path $repositoryRoot 'apps/kiyori')
try {
  switch ($Platform) {
    'android' { & flutter build apk "--$Mode" --target-platform android-arm64 }
    'windows' { & flutter build windows "--$Mode" }
    'ios' {
      if (-not $IsMacOS) { throw 'iOS builds require a Mac with Xcode. This host cannot validate iOS.' }
      & flutter build ios "--$Mode" --no-codesign
    }
  }
  if ($LASTEXITCODE -ne 0) { throw "$Platform build failed." }
} finally { Pop-Location }
