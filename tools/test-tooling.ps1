#requires -Version 7.0
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'bridge-output.ps1')
$fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ('kiyori-bridge-check-' + [guid]::NewGuid().ToString('N'))
$fixtureRoot = [IO.Path]::GetFullPath($fixtureRoot)
$utf8 = [Text.UTF8Encoding]::new($false)
function Write-Fixture([string]$Relative, [string]$Content) {
  $path = Join-Path $fixtureRoot $Relative
  [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($path))
  [IO.File]::WriteAllText($path, $Content, $utf8)
}
function Expect-Change($Before, [string]$Kind) {
  try { Assert-BridgeOutputUnchanged $Before (Get-BridgeOutputSnapshot $fixtureRoot) }
  catch {
    if ($_.Exception.Message.Contains($Kind + ':')) { return }
    throw
  }
  throw "Failed to detect $Kind generated output."
}
try {
  Write-Fixture 'crates/kiyori_ffi/src/frb_generated.rs' 'rust'
  Write-Fixture 'packages/kiyori_bridge/lib/src/generated/api.dart' 'dart'
  $before = Get-BridgeOutputSnapshot $fixtureRoot
  Assert-BridgeOutputUnchanged $before (Get-BridgeOutputSnapshot $fixtureRoot)
  Write-Fixture 'packages/kiyori_bridge/lib/src/generated/nested/new.dart' 'new'
  Expect-Change $before 'added'
  $before = Get-BridgeOutputSnapshot $fixtureRoot
  Write-Fixture 'packages/kiyori_bridge/lib/src/generated/nested/new.dart' 'modified'
  Expect-Change $before 'modified'
  $before = Get-BridgeOutputSnapshot $fixtureRoot
  Remove-Item -LiteralPath (Join-Path $fixtureRoot 'packages/kiyori_bridge/lib/src/generated/api.dart')
  Expect-Change $before 'removed'
  Write-Host 'PASS: 4 bridge inventory cases (unchanged, nested addition, modification, removal).'
} finally {
  # 仅删除本次创建、已经解析且位于 OS 临时目录内的随机夹具。
  $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
  if (-not $fixtureRoot.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase) -or
      [IO.Path]::GetFileName($fixtureRoot) -notmatch '^kiyori-bridge-check-[0-9a-f]{32}$') {
    throw 'Unsafe tooling fixture cleanup target.'
  }
  if (Test-Path -LiteralPath $fixtureRoot) { Remove-Item -LiteralPath $fixtureRoot -Recurse -Force }
}
