#requires -Version 7.0
[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$Source,
  [string]$Filter = ''
)

$ErrorActionPreference = 'Stop'
$sourceRoot = (Resolve-Path -LiteralPath $Source).Path
$revision = & git -C $sourceRoot rev-parse HEAD
if ($LASTEXITCODE -ne 0) { throw 'Source must be an existing Git checkout.' }
$files = @(& git -C $sourceRoot ls-files)
if ($LASTEXITCODE -ne 0) { throw 'Could not list tracked source files.' }
$settingsPath = Join-Path $sourceRoot 'settings.gradle.kts'
$settings = Get-Content -LiteralPath $settingsPath -Raw
$modules = @([regex]::Matches($settings, 'include\("(:[^"\s]+)"\)') | ForEach-Object { $_.Groups[1].Value })
$ui = @($files | Where-Object { $_ -match '/(ui|design|app/shell|app/startup)/.*\.kt$' })
$selected = @($ui | Where-Object { -not $Filter -or $_.Contains($Filter, [StringComparison]::OrdinalIgnoreCase) })
[ordered]@{
  source = $sourceRoot
  revision = "$revision"
  observedUtc = [DateTimeOffset]::UtcNow.ToString('o')
  modules = $modules
  trackedFiles = $files.Count
  uiSourceFiles = $ui.Count
  filter = $Filter
  files = $selected
  note = 'Read-only source inventory, not a page count or proof of UI parity. Inspect callers, defaults, resources and modal states before implementation.'
} | ConvertTo-Json -Depth 4
