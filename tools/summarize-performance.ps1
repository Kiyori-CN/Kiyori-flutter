#requires -Version 7.0
[CmdletBinding()]
param(
  [string]$Report = (Join-Path $PSScriptRoot '../apps/kiyori/build/integration_response_data.json'),
  [ValidateRange(1, 1000)][double]$RefreshRate
)

$ErrorActionPreference = 'Stop'
$data = Get-Content -LiteralPath $Report -Raw | ConvertFrom-Json
$hz = if ($PSBoundParameters.ContainsKey('RefreshRate')) { $RefreshRate } else { [double]$data.environment.refresh_rate_hz }
if ($hz -le 0 -or -not [double]::IsFinite($hz)) { throw 'Missing or invalid display refresh rate; supply -RefreshRate.' }
$budgetUs = 1000000 / $hz
$rows = foreach ($phase in 'first_swipes', 'warm_swipes') {
  $frames = $data.$phase
  foreach ($stage in 'build', 'rasterizer') {
    # Flutter FrameTimingSummarizer 的原始数组单位为微秒，不能直接当毫秒。
    $values = @($frames."frame_${stage}_times")
    if ($values.Count -eq 0 -or $values.Count -ne $frames.frame_count) { throw "Missing/incomplete $phase $stage timings." }
    foreach ($value in $values) {
      if ($null -eq $value -or $value -is [string] -or [double]$value -lt 0 -or -not [double]::IsFinite([double]$value)) {
        throw "Invalid timing in $phase $stage."
      }
    }
    $sorted = @($values | Sort-Object)
    $over = @($values | Where-Object { $_ -gt $budgetUs }).Count
    [pscustomobject]@{
      Phase = $phase
      Stage = $stage
      Frames = $values.Count
      RefreshHz = $hz
      BudgetMs = [math]::Round($budgetUs / 1000, 3)
      P50Ms = $sorted[[math]::Ceiling($values.Count * .50) - 1] / 1000
      P90Ms = $sorted[[math]::Ceiling($values.Count * .90) - 1] / 1000
      P99Ms = $sorted[[math]::Ceiling($values.Count * .99) - 1] / 1000
      WorstMs = $sorted[-1] / 1000
      OverBudget = $over
      OverBudgetPercent = [math]::Round(100 * $over / $values.Count, 3)
    }
  }
}
$rows | ConvertTo-Json
