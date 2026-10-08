# 平台与宿主路由集中在纯函数中；错误在查询 SDK 或解析依赖前给出。
function Get-KiyoriBuildArguments {
  param(
    [Parameter(Mandatory)][ValidateSet('android', 'windows', 'ios', 'macos', 'linux')][string]$Platform,
    [ValidateSet('debug', 'profile', 'release')][string]$Mode = 'debug',
    [Parameter(Mandatory)][ValidateSet('windows', 'macos', 'linux')][string]$HostPlatform,
    [switch]$NoPub
  )
  $requiredHost = switch ($Platform) {
    'windows' { 'windows' }
    'ios' { 'macos' }
    'macos' { 'macos' }
    'linux' { 'linux' }
  }
  if ($requiredHost -and $requiredHost -ne $HostPlatform) {
    throw "$Platform builds require a $requiredHost host; current host is $HostPlatform."
  }
  $target = if ($Platform -eq 'android') { 'apk' } else { $Platform }
  $arguments = @('build', $target, "--$Mode")
  if ($Platform -eq 'android') { $arguments += @('--target-platform', 'android-arm64') }
  if ($Platform -eq 'ios') { $arguments += '--no-codesign' }
  if ($NoPub) { $arguments += '--no-pub' }
  return $arguments
}
