# 生成检查比较完整路径集合和内容，不能只检查生成前已存在的顶层文件。
function Get-BridgeOutputSnapshot([string]$RepositoryRoot) {
  $snapshot = [System.Collections.Generic.Dictionary[string, string]]::new([StringComparer]::Ordinal)
  $rust = Join-Path $RepositoryRoot 'crates/kiyori_ffi/src/frb_generated.rs'
  $dart = Join-Path $RepositoryRoot 'packages/kiyori_bridge/lib/src/generated'
  $files = @()
  if (Test-Path -LiteralPath $rust -PathType Leaf) { $files += Get-Item -LiteralPath $rust }
  if (Test-Path -LiteralPath $dart -PathType Container) {
    $files += Get-ChildItem -LiteralPath $dart -Recurse -File
  }
  foreach ($file in $files) {
    $relative = [IO.Path]::GetRelativePath($RepositoryRoot, $file.FullName).Replace('\', '/')
    $snapshot.Add($relative, (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash)
  }
  return ,$snapshot
}

function Assert-BridgeOutputUnchanged($Before, $After) {
  $changes = @(
    foreach ($path in $Before.Keys) {
      if (-not $After.ContainsKey($path)) { "removed: $path" }
      elseif ($Before[$path] -cne $After[$path]) { "modified: $path" }
    }
    foreach ($path in $After.Keys) {
      if (-not $Before.ContainsKey($path)) { "added: $path" }
    }
  )
  if ($changes.Count -gt 0) {
    throw "Generated bridge changed:`n$($changes -join "`n")`nReview the generated diff before accepting the check."
  }
}
