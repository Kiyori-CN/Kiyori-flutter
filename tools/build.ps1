[CmdletBinding()]
param(
  [Parameter(Mandatory)][ValidateSet('android', 'windows', 'ios')][string]$Platform,
  [ValidateSet('debug', 'profile', 'release')][string]$Mode = 'debug',
  [switch]$NoPub
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
& (Join-Path $PSScriptRoot 'check-toolchains.ps1')
Push-Location (Join-Path $repositoryRoot 'apps/kiyori')
try {
  $pubArguments = @()
  if ($NoPub) { $pubArguments += '--no-pub' }
  switch ($Platform) {
    'android' { & flutter build apk "--$Mode" --target-platform android-arm64 @pubArguments }
    'windows' { & flutter build windows "--$Mode" @pubArguments }
    'ios' {
      if (-not $IsMacOS) { throw 'iOS builds require a Mac with Xcode. This host cannot validate iOS.' }
      & flutter build ios "--$Mode" --no-codesign @pubArguments
    }
  }
  if ($LASTEXITCODE -ne 0) { throw "$Platform build failed." }
} finally { Pop-Location }
