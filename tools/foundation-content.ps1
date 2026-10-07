#requires -Version 7.0

# 纯内容检查供正式入口与独立夹具复用；不读取目录、不改变工作树。
function Get-FoundationContentFailures {
  param([string]$Relative, [byte[]]$Bytes)

  $failures = [System.Collections.Generic.List[string]]::new()
  $utf8 = [System.Text.UTF8Encoding]::new($false, $true)
  try { $content = $utf8.GetString($Bytes) }
  catch { return "Invalid UTF-8: $Relative" }
  if ($content.StartsWith([char]0xFEFF)) { $failures.Add("UTF-8 BOM: $Relative") }
  if ($content.Contains("`r")) { $failures.Add("Expected LF: $Relative") }
  if (-not $content.EndsWith("`n")) { $failures.Add("Missing final newline: $Relative") }

  if ($Relative.EndsWith('.json', [StringComparison]::OrdinalIgnoreCase)) {
    # ConvertFrom-Json 接受注释等扩展；配置文件声明 JSON 时按标准语法检查。
    $document = $null
    try { $document = [System.Text.Json.JsonDocument]::Parse($content) }
    catch { $failures.Add("Invalid JSON: $Relative") }
    finally { if ($null -ne $document) { $document.Dispose() } }
  }
  if ($Relative.EndsWith('.md', [StringComparison]::OrdinalIgnoreCase)) {
    $fenceCharacter = ''
    $fenceLength = 0
    $headingCount = 0
    $lastLevel = 0
    $tableColumns = 0
    foreach ($line in ($content -split "`n")) {
      # 支持较长外层围栏和 tilde；示例里的三个反引号不能提前关闭四反引号围栏。
      if ($fenceLength -gt 0) {
        if ($line -match ('^ {0,3}' + [regex]::Escape($fenceCharacter) + '{' + $fenceLength + ',}\s*$')) {
          $fenceLength = 0
        }
        continue
      }
      if ($line -match '^ {0,3}(`{3,}|~{3,})(.*)$') {
        $fenceCharacter = $Matches[1].Substring(0, 1)
        $fenceLength = $Matches[1].Length
        if ([string]::IsNullOrWhiteSpace($Matches[2])) { $failures.Add("Missing fence language: $Relative") }
        $tableColumns = 0
        continue
      }
      if ($line -match '^(#{1,6}) ') {
        $level = $Matches[1].Length
        if ($level -eq 1) { $headingCount++ }
        if ($lastLevel -gt 0 -and $level -gt ($lastLevel + 1)) { $failures.Add("Skipped heading level: $Relative :: $line") }
        $lastLevel = $level
      }
      if ($line -match '^\s*\|.*\|\s*$') {
        # 本仓库表格约定两端有管道，单元中的管道必须转义，包括行内代码。
        $columns = [regex]::Matches($line, '(?<!\\)(?:\\\\)*\|').Count - 1
        if ($tableColumns -gt 0 -and $columns -ne $tableColumns) { $failures.Add("Inconsistent table columns: $Relative :: $line") }
        $tableColumns = $columns
      } else { $tableColumns = 0 }
    }
    if ($fenceLength -gt 0) { $failures.Add("Unclosed code fence: $Relative") }
    if ($headingCount -ne 1) { $failures.Add("Expected one H1: $Relative") }
  }
  return $failures.ToArray()
}

function Get-FoundationLocalLinks {
  param([string]$Content)

  $fenceCharacter = ''
  $fenceLength = 0
  foreach ($line in ($Content -split "`n")) {
    if ($fenceLength -gt 0) {
      if ($line -match ('^ {0,3}' + [regex]::Escape($fenceCharacter) + '{' + $fenceLength + ',}\s*$')) { $fenceLength = 0 }
      continue
    }
    if ($line -match '^ {0,3}(`{3,}|~{3,})') {
      $fenceCharacter = $Matches[1].Substring(0, 1)
      $fenceLength = $Matches[1].Length
      continue
    }
    foreach ($link in [regex]::Matches($line, '\[[^\]]*\]\(([^)]+)\)')) {
      $target = $link.Groups[1].Value.Trim('<', '>')
      if ($target -match '^[a-zA-Z][a-zA-Z0-9+.-]*:' -or $target.StartsWith('#')) { continue }
      $target = [Uri]::UnescapeDataString(($target -split '#')[0])
      if ($target) { $target }
    }
  }
}
