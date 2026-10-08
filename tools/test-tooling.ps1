#requires -Version 7.0
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'bridge-output.ps1')
. (Join-Path $PSScriptRoot 'foundation-content.ps1')
. (Join-Path $PSScriptRoot 'platform-build.ps1')
$routingCases = 0
foreach ($hostName in @('windows', 'macos', 'linux')) {
  foreach ($platformName in @('android', 'windows', 'ios', 'macos', 'linux')) {
    $allowed = $platformName -eq 'android' -or $platformName -eq $hostName -or ($platformName -eq 'ios' -and $hostName -eq 'macos')
    $failed = $false
    try { $actual = @(Get-KiyoriBuildArguments -Platform $platformName -HostPlatform $hostName -Mode profile -NoPub) }
    catch { $failed = $true }
    if ($failed -eq $allowed) { throw "Invalid build host routing: $hostName -> $platformName" }
    if ($allowed) {
      $target = if ($platformName -eq 'android') { 'apk' } else { $platformName }
      $expected = @('build', $target, '--profile')
      if ($platformName -eq 'android') { $expected += @('--target-platform', 'android-arm64') }
      if ($platformName -eq 'ios') { $expected += '--no-codesign' }
      $expected += '--no-pub'
      if (($actual -join '|') -ne ($expected -join '|')) { throw "Invalid build arguments: $hostName -> $platformName" }
    }
    $routingCases++
  }
}
Write-Host "PASS: $routingCases build host/target routing cases."
$contentCases = @(
  @{ Name = 'valid JSON'; Path = 'nested/config.json'; Text = "{`"name`":`"Kiyori`",`"enabled`":true}`n"; Error = '' },
  @{ Name = 'JSON scalar'; Path = 'value.json'; Text = "null`n"; Error = '' },
  @{ Name = 'JSON syntax'; Path = 'nested/config.json'; Text = "{broken}`n"; Error = 'Invalid JSON' },
  @{ Name = 'JSON trailing comma'; Path = 'config.json'; Text = "{`"a`":1,}`n"; Error = 'Invalid JSON' },
  @{ Name = 'JSON comment'; Path = 'config.json'; Text = "{/* comment */}`n"; Error = 'Invalid JSON' },
  @{ Name = 'JSON whitespace'; Path = 'config.json'; Text = " `n"; Error = 'Invalid JSON' },
  @{ Name = 'CRLF'; Path = 'text.txt'; Text = "text`r`n"; Error = 'Expected LF' },
  @{ Name = 'final newline'; Path = 'text.txt'; Text = 'text'; Error = 'Missing final newline' },
  @{ Name = 'BOM'; Path = 'text.txt'; Text = ([char]0xFEFF + "text`n"); Error = 'UTF-8 BOM' },
  @{ Name = 'heading skip'; Path = 'test.md'; Text = "# Title`n`n### Section`n"; Error = 'Skipped heading level' },
  @{ Name = 'multiple H1'; Path = 'test.md'; Text = "# First`n`n# Second`n"; Error = 'Expected one H1' },
  @{ Name = 'tilde fence'; Path = 'test.md'; Text = "# Title`n`n~~~text`n# Example`n~~~`n"; Error = '' },
  @{ Name = 'unclosed fence'; Path = 'test.md'; Text = "# Title`n`n~~~text`nbody`n"; Error = 'Unclosed code fence' },
  @{ Name = 'table mismatch'; Path = 'test.md'; Text = "# Title`n`n| A | B |`n| --- | --- |`n| C |`n"; Error = 'Inconsistent table columns' },
  @{ Name = 'escaped table pipe'; Path = 'test.md'; Text = "# Title`n`n| A | B |`n| --- | --- |`n| C\|D | E |`n"; Error = '' },
  @{ Name = 'fence language'; Path = 'test.md'; Text = "# Title`n`n~~~`nbody`n~~~`n"; Error = 'Missing fence language' },
  @{ Name = 'longer fence'; Path = 'test.md'; Text = ('# Title', '', '````markdown', '```text', '# Example', '```', '````', '') -join "`n"; Error = '' }
)
foreach ($case in $contentCases) {
  $found = @(Get-FoundationContentFailures -Relative $case.Path -Bytes ([Text.Encoding]::UTF8.GetBytes($case.Text)))
  if ($case.Error) {
    if (-not ($found | Where-Object { $_.StartsWith($case.Error + ':') })) { throw "Missing expected failure: $($case.Name)" }
  } elseif ($found.Count -ne 0) { throw "Unexpected failure in $($case.Name): $found" }
}
$invalidUtf8 = @(Get-FoundationContentFailures -Relative 'text.txt' -Bytes ([byte[]]@(0xC3, 0x28, 0x0A)))
if ($invalidUtf8.Count -ne 1 -or $invalidUtf8[0] -notlike 'Invalid UTF-8:*') { throw 'Invalid UTF-8 was accepted.' }
$links = @(Get-FoundationLocalLinks -Content (('# Title', '[local](nested/file%20name.md#section)', '[web](https://example.com)', '[anchor](#here)', '````markdown', '```text', '[example](missing.md)', '```', '````', '[second](other.md)', '') -join "`n"))
if ($links.Count -ne 2 -or $links[0] -ne 'nested/file name.md' -or $links[1] -ne 'other.md') { throw "Wrong local link extraction: $links" }
Write-Host "PASS: $($contentCases.Count + 2) content cases (JSON, encoding, Markdown, tables and links)."
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
