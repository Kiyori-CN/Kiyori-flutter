#requires -Version 7.0
[CmdletBinding()]
param(
  [Parameter(Mandatory)][ValidateSet('android', 'windows', 'ios', 'macos', 'linux')][string]$Platform,
  [ValidateSet('debug', 'profile', 'release')][string]$Mode = 'debug',
  [switch]$NoPub
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'platform-build.ps1')
$hostPlatform = if ($IsWindows) { 'windows' } elseif ($IsMacOS) { 'macos' } elseif ($IsLinux) { 'linux' } else { throw 'Unsupported build host.' }
$buildArguments = @(Get-KiyoriBuildArguments -Platform $Platform -Mode $Mode -HostPlatform $hostPlatform -NoPub:$NoPub)
& (Join-Path $PSScriptRoot 'check-toolchains.ps1')
Push-Location (Join-Path $repositoryRoot 'apps/kiyori')
try {
  & flutter @buildArguments
  if ($LASTEXITCODE -ne 0) { throw "$Platform build failed." }
} finally { Pop-Location }
