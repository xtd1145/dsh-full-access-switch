# DSH Full Access 一次性开关 - 安装脚本
# 用法: powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 [-PackageRoot <dir>] [-SettingsPath <path>]
param(
  [string]$PackageRoot = '',
  [string]$SettingsPath = ''
)
$ErrorActionPreference = 'Stop'


$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$patchFile = Join-Path $scriptDir 'patches.json'
if (-not (Test-Path $patchFile)) { throw "找不到 $patchFile - 请把 install.ps1 与 patches.json 放在同一目录" }
$table = Get-Content -Raw -Encoding UTF8 $patchFile | ConvertFrom-Json

if ($SettingsPath -eq '') { $SettingsPath = Join-Path $env:USERPROFILE '.dsh\settings.yaml' }

function Find-PackageDirs([string]$pkgSpec) {
  $bare = $pkgSpec -replace '^@[^/]+/', ''
  $dirs = @()
  if ($PackageRoot -ne '' -and (Test-Path (Join-Path $PackageRoot $bare))) { $dirs += Join-Path $PackageRoot $bare }
  $profileRoot = Join-Path $env:USERPROFILE '.dsh\profiles'
  $cand = Join-Path $profileRoot "node_modules\@deepseek-ai\$bare"
  if (Test-Path $cand) { $dirs += $cand }
  $npxRoot = Join-Path $env:LOCALAPPDATA 'npm-cache\_npx'
  if (Test-Path $npxRoot) {
    Get-ChildItem $npxRoot -Directory -ErrorAction SilentlyContinue | ForEach-Object {
      $c = Join-Path $_.FullName "node_modules\@deepseek-ai\$bare"
      if (Test-Path $c) { $dirs += $c }
    }
  }
  return $dirs | Select-Object -Unique
}

function Apply-FilePatches([string]$target, [array]$patches, [string]$marker) {
  $text = [System.IO.File]::ReadAllText($target)
  if ($text.Contains($marker)) {
    Write-Host "已打过补丁，跳过: $target"
    return $true
  }
  foreach ($p in $patches) {
    $count = ([regex]::Matches($text, [regex]::Escape($p.old))).Count
    if ($count -ne 1) {
      Write-Host "FAIL: $target 中锚点 '$($p.name)' 出现 $count 次（预期 1 次）- 可能版本不匹配，未做任何修改"
      return $false
    }
  }
  $stamp = Get-Date -Format 'yyyyMMddHHmmss'
  $bak = "$target.bak-$stamp"
  Copy-Item $target $bak -Force
  foreach ($p in $patches) { $text = $text.Replace($p.old, $p.new) }
  [System.IO.File]::WriteAllText($target, $text, (New-Object System.Text.UTF8Encoding($false)))
  Write-Host "PATCHED: $target (备份: $bak)"
  return $true
}

$ok = $true
foreach ($file in $table.files) {
  $dirs = Find-PackageDirs $file.package
  if ($dirs.Count -eq 0) {
    Write-Host "WARN: 未找到包 $($file.package)（跳过；可用 -PackageRoot 手动指定安装位置）"
    continue
  }
  foreach ($dir in $dirs) {
    $target = Join-Path $dir $file.client
    if (-not (Test-Path $target)) { Write-Host "WARN: 缺少 $target"; continue }
    $r = Apply-FilePatches $target @($file.patches) $file.marker
    if (-not $r) { $ok = $false }
  }
}

# --- settings.yaml: permission.defaultPreset ---
$section = $table.settings.section
$key = $table.settings.key
$value = $table.settings.value
$content = ''
if (Test-Path $SettingsPath) { $content = [System.IO.File]::ReadAllText($SettingsPath) }
if ($content -match '(?m)^\s*defaultPreset\s*:') {
  Write-Host 'settings.yaml 已含 defaultPreset，跳过'
} else {
  $lines = New-Object System.Collections.Generic.List[string]
  if ($content -ne '') { $content -split "`n" | ForEach-Object { $lines.Add($_) } }
  $secIdx = -1
  for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match "^$section`:") { $secIdx = $i; break }
  }
  if ($secIdx -ge 0) {
    $lines.Insert($secIdx + 1, "  $key`: $value")
  } else {
    if ($lines.Count -gt 0 -and $lines[$lines.Count - 1] -ne '') { $lines.Add('') }
    $lines.Add("$section`:")
    $lines.Add("  $key`: $value")
  }
  $out = $lines -join "`n"
  [System.IO.File]::WriteAllText($SettingsPath, $out, (New-Object System.Text.UTF8Encoding($false)))
  Write-Host "SETTINGS: $SettingsPath 已写入 $section.$key = $value"
}

if ($ok) {
  Write-Host ''
  Write-Host '完成。请刷新浏览器页面（F5）加载新的前端代码。'
} else {
  Write-Host ''
  Write-Host '部分补丁未应用（见上方 FAIL）。请检查 DSH 版本（预期 0.1.1-rc.2）。'
}
