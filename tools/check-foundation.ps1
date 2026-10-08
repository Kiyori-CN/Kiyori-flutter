#requires -Version 7.0
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'foundation-content.ps1')
$failures = [System.Collections.Generic.List[string]]::new()
$utf8 = [System.Text.UTF8Encoding]::new($false, $true)
$paths = @('README.md', 'AGENTS.md', 'CONTEXT.md', 'toolchains.json', 'rust-toolchain.toml', '.editorconfig', '.gitattributes', '.gitignore')
$paths += Get-ChildItem -LiteralPath (Join-Path $repositoryRoot 'docs') -Recurse -File | ForEach-Object { [IO.Path]::GetRelativePath($repositoryRoot, $_.FullName) }
$paths += Get-ChildItem -LiteralPath $PSScriptRoot -File | ForEach-Object { [IO.Path]::GetRelativePath($repositoryRoot, $_.FullName) }
# 跟踪文件与未忽略的新文件都参与；不会遍历 build/target 或读取机器私有 JSON。
$jsonPaths = @(git -C $repositoryRoot ls-files --cached --others --exclude-standard -- '*.json')
if ($LASTEXITCODE -ne 0) { throw 'Cannot enumerate repository JSON files.' }
$paths += $jsonPaths
$paths += 'apps/kiyori/README.md'
$paths = @($paths | Sort-Object -Unique)

foreach ($relative in $paths) {
  $path = Join-Path $repositoryRoot $relative
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { $failures.Add("Missing: $relative"); continue }
  $bytes = [IO.File]::ReadAllBytes($path)
  foreach ($failure in (Get-FoundationContentFailures -Relative $relative -Bytes $bytes)) { $failures.Add($failure) }
  try { $content = $utf8.GetString($bytes) } catch { continue }
  if ($relative.EndsWith('.md')) {
    foreach ($target in (Get-FoundationLocalLinks -Content $content)) {
      if (-not (Test-Path -LiteralPath (Join-Path (Split-Path -Parent $path) $target))) { $failures.Add("Broken local link: $relative -> $target") }
    }
  }
  if ($relative.EndsWith('.ps1')) {
    $parseErrors = $null
    $tokens = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$tokens, [ref]$parseErrors)
    foreach ($parseError in $parseErrors) { $failures.Add("PowerShell parse: $relative :: $($parseError.Message)") }
  }
}

# 导航只检查覆盖，不生成第二套目录；新文档必须从唯一文档中心可发现。
$docsRoot = Join-Path $repositoryRoot 'docs'
$catalogTargets = @(Get-FoundationLocalLinks -Content ([IO.File]::ReadAllText((Join-Path $docsRoot 'README.md'))))
$catalogPaths = @($catalogTargets | ForEach-Object { [IO.Path]::GetFullPath((Join-Path $docsRoot $_)) })
foreach ($doc in Get-ChildItem -LiteralPath $docsRoot -Recurse -Filter '*.md' -File) {
  if ($doc.FullName -eq (Join-Path $docsRoot 'README.md')) { continue }
  if ($doc.FullName -notin $catalogPaths) { $failures.Add("Document missing from docs/README.md: $([IO.Path]::GetRelativePath($repositoryRoot, $doc.FullName))") }
}

# 公共 UI 不能反向依赖应用/桥接。检查真实 import/export，不维护文件哈希快照。
foreach ($file in Get-ChildItem (Join-Path $repositoryRoot 'packages/kiyori_ui/lib') -Filter '*.dart' -Recurse -File) {
  $content = Get-Content -LiteralPath $file.FullName -Raw
  foreach ($match in [regex]::Matches($content, '(?m)^\s*(?:import|export)\s+[''"]([^''"]+)[''"]')) {
    $uri = $match.Groups[1].Value
    if ($uri -match '^package:(kiyori|kiyori_bridge)/') {
      $failures.Add("Shared UI imports business/composition: $($file.Name) -> $uri")
    }
  }
}

$baseline = Get-Content -LiteralPath (Join-Path $repositoryRoot 'toolchains.json') -Raw | ConvertFrom-Json
$rustPin = Get-Content -LiteralPath (Join-Path $repositoryRoot 'rust-toolchain.toml') -Raw
if ($rustPin -notmatch ('(?m)^channel = "' + [regex]::Escape($baseline.rust.version) + '"$')) { $failures.Add('Rust version differs between toolchains.json and rust-toolchain.toml') }
$targetMatch = [regex]::Match($rustPin, '(?m)^targets = (\[[^\r\n]+\])$')
if (-not $targetMatch.Success) { $failures.Add('Native Assets requires explicit Rust targets') }
else {
  $targets = @($targetMatch.Groups[1].Value | ConvertFrom-Json)
  if (@(Compare-Object $targets @($baseline.rust.targets)).Count -ne 0) {
    $failures.Add('Rust targets differ between toolchains.json and rust-toolchain.toml')
  }
}
$ffiPin = Get-Content -LiteralPath (Join-Path $repositoryRoot 'crates/kiyori_ffi/rust-toolchain.toml') -Raw
if (($ffiPin -replace '(?m)^#.*\r?\n', '').Trim() -ne $rustPin.Trim()) { $failures.Add('Native Assets crate-local Rust pin differs from the root pin') }

# 只检查真实存在的版本接线；不建立第二份依赖清单或大型架构快照。
function Assert-Setting([string]$Relative, [string]$Pattern, [string]$Description) {
  $content = Get-Content -LiteralPath (Join-Path $repositoryRoot $Relative) -Raw
  if ($content -notmatch $Pattern) { $failures.Add("Version wiring mismatch: $Description ($Relative)") }
}
Assert-Setting 'apps/kiyori/android/settings.gradle.kts' ('id\("com.android.application"\) version "' + [regex]::Escape($baseline.android.agp) + '"') 'AGP'
Assert-Setting 'apps/kiyori/android/gradle/wrapper/gradle-wrapper.properties' ('gradle-' + [regex]::Escape($baseline.android.gradle) + '-bin.zip') 'Gradle'
Assert-Setting 'apps/kiyori/android/gradle/wrapper/gradle-wrapper.properties' ('distributionSha256Sum=' + $baseline.android.gradleDistributionSha256) 'Gradle SHA-256'
foreach ($setting in @(@('ndkVersion', $baseline.android.ndk), @('buildToolsVersion', $baseline.android.buildTools))) {
  Assert-Setting 'apps/kiyori/android/app/build.gradle.kts' ($setting[0] + ' = "' + [regex]::Escape($setting[1]) + '"') $setting[0]
}
foreach ($setting in @(@('compileSdk', $baseline.android.compileSdk), @('targetSdk', $baseline.android.targetSdk), @('minSdk', $baseline.android.minSdkCandidate))) {
  Assert-Setting 'apps/kiyori/android/app/build.gradle.kts' ('(?m)^\s*' + $setting[0] + ' = ' + $setting[1] + '\s*$') $setting[0]
}
Assert-Setting 'Cargo.toml' ('flutter_rust_bridge = "=' + [regex]::Escape($baseline.flutterRustBridge.version) + '"') 'Rust FRB'
Assert-Setting 'packages/kiyori_bridge/pubspec.yaml' ('(?m)^  flutter_rust_bridge: ' + [regex]::Escape($baseline.flutterRustBridge.version) + '$') 'Dart FRB'
Assert-Setting 'packages/kiyori_bridge/pubspec.yaml' ('(?m)^  flutter_rust_bridge_hooks: ' + [regex]::Escape($baseline.flutterRustBridge.hooksVersion) + '$') 'FRB hooks'

# app 负责装配 feature；feature 反向引用 app 会阻碍独立测试和页面复用。
foreach ($file in Get-ChildItem (Join-Path $repositoryRoot 'apps/kiyori/lib/features') -Filter '*.dart' -Recurse -File) {
  $content = Get-Content -LiteralPath $file.FullName -Raw
  foreach ($match in [regex]::Matches($content, '(?m)^\s*(?:import|export)\s+[''"]([^''"]+)[''"]')) {
    $uri = $match.Groups[1].Value
    $referencesApp = $uri.StartsWith('package:kiyori/app/')
    if ($uri.StartsWith('.')) {
      $resolved = [IO.Path]::GetFullPath((Join-Path $file.DirectoryName $uri))
      $appRoot = [IO.Path]::GetFullPath((Join-Path $repositoryRoot 'apps/kiyori/lib/app')) + [IO.Path]::DirectorySeparatorChar
      $referencesApp = $resolved.StartsWith($appRoot, [StringComparison]::OrdinalIgnoreCase)
    }
    if ($referencesApp) { $failures.Add("Feature imports app composition: $($file.Name) -> $uri") }
  }
}
if ($failures.Count -gt 0) { $failures | ForEach-Object { Write-Host "FAIL: $_" }; throw "$($failures.Count) foundation checks failed." }
Write-Host "PASS: $($paths.Count) files; UTF-8/LF, Markdown/tables/local links/catalog, $($jsonPaths.Count) JSON files, PowerShell syntax, toolchain wiring and feature-to-app boundary."
Write-Host 'Scope: foundation structure only; not external URLs, Markdown anchor resolution, architecture correctness or application builds.'
