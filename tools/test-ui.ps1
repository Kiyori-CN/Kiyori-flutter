#requires -Version 7.0
[CmdletBinding()]
param(
  [string[]]$Test = @(),
  [switch]$Capture,
  [string]$Output = 'work/ui-capture',
  [string]$Font
)

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$appRoot = Join-Path $repositoryRoot 'apps/kiyori'
& (Join-Path $PSScriptRoot 'check-toolchains.ps1')
$arguments = @('test', '--reporter', 'expanded')
if ($Test.Count -eq 0 -and $Capture) {
  $Test = Get-ChildItem (Join-Path $appRoot 'test') -Filter '*capture_test.dart' -File | ForEach-Object Name
}
foreach ($item in $Test) {
  $relative = if ($item.StartsWith('test/')) { $item } else { "test/$item" }
  $resolved = [IO.Path]::GetFullPath((Join-Path $appRoot $relative))
  $testRoot = [IO.Path]::GetFullPath((Join-Path $appRoot 'test')) + [IO.Path]::DirectorySeparatorChar
  if (-not $resolved.StartsWith($testRoot, [StringComparison]::OrdinalIgnoreCase) -or
      -not (Test-Path -LiteralPath $resolved -PathType Leaf) -or -not $resolved.EndsWith('_test.dart')) {
    throw "Expected an existing app test: $item"
  }
  $arguments += $relative
}
if ($Capture) {
  $captureRoot = [IO.Path]::GetFullPath((Join-Path $repositoryRoot $Output))
  $arguments += "--dart-define=KIYORI_CAPTURE=$captureRoot"
  if ($Font) {
    $fontPath = (Resolve-Path -LiteralPath $Font -ErrorAction Stop).Path
    $arguments += "--dart-define=KIYORI_CAPTURE_FONT=$fontPath"
  }
}
Push-Location $appRoot
try {
  & flutter @arguments
  if ($LASTEXITCODE -ne 0) { throw 'UI verification failed.' }
} finally { Pop-Location }
