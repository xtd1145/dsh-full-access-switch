# DSH Full Access 一次性开关 - 卸载脚本
# 用法: powershell -NoProfile -ExecutionPolicy Bypass -File .\uninstall.ps1 [-PackageRoot <dir>] [-SettingsPath <path>]
param(
  [string]$PackageRoot = '',
  [string]$SettingsPath = ''
)
$ErrorActionPreference = 'Stop'


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

$targets = @(
  '@deepseek-ai/dsh-client-ui-permission-presets/lib/client.js',
  '@deepseek-ai/dsh-client-ui-conversation/lib/client.js'
)
foreach ($t in $targets) {
  $idx = $t.IndexOf('/')
  $rest = $t.Substring($idx + 1)
  $idx2 = $rest.IndexOf('/')
  $pkg = $t.Substring(0, $idx) + '/' + $rest.Substring(0, $idx2)
  $rel = $rest.Substring($idx2 + 1)
  $dirs = Find-PackageDirs $pkg
  foreach ($dir in $dirs) {
    $target = Join-Path $dir $rel
    if (-not (Test-Path $target)) { continue }
    $baks = @(Get-ChildItem "$target.bak-*" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending)
    if ($baks.Count -eq 0) {
      Write-Host "无备份可恢复（也许未安装过补丁）: $target"
      continue
    }
    $latest = $baks[0].FullName
    Copy-Item $latest $target -Force
    Write-Host "RESTORED: $target <- $latest"
  }
}

# --- settings.yaml: 移除 permission.defaultPreset ---
if (Test-Path $SettingsPath) {
  $content = [System.IO.File]::ReadAllText($SettingsPath)
  $lines = New-Object System.Collections.Generic.List[string]
  $content -split "`n" | ForEach-Object { $lines.Add($_) }
  # 删除 defaultPreset 行（缩进的 key）
  $removed = $false
  for ($i = $lines.Count - 1; $i -ge 0; $i--) {
    if ($lines[$i] -match '^\s*defaultPreset\s*:') { $lines.RemoveAt($i); $removed = $true }
  }
  if ($removed) {
    # 若 permission 节只剩注释/空行，连同注释一起删除整个节
    $secIdx = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
      if ($lines[$i] -match '^permission:') { $secIdx = $i; break }
    }
    if ($secIdx -ge 0) {
      $hasContent = $false
      for ($j = $secIdx + 1; $j -lt $lines.Count; $j++) {
        if ($lines[$j] -match '^\S') { break }
        if ($lines[$j] -match '^\s*\S' -and $lines[$j] -notmatch '^\s*#') { $hasContent = $true; break }
      }
      if (-not $hasContent) {
        $end = $secIdx + 1
        while ($end -lt $lines.Count -and $lines[$end] -notmatch '^\S') { $end++ }
        $lines.RemoveRange($secIdx, $end - $secIdx)
        if ($secIdx -gt 0 -and $lines[$secIdx - 1].Trim() -eq '') { $lines.RemoveAt($secIdx - 1) }
        if ($secIdx -lt $lines.Count -and $lines[$secIdx].Trim() -eq '') { $lines.RemoveAt($secIdx) }
      }
    }
    $out = $lines -join "`n"
    [System.IO.File]::WriteAllText($SettingsPath, $out, (New-Object System.Text.UTF8Encoding($false)))
    Write-Host "SETTINGS: 已从 $SettingsPath 移除 permission.defaultPreset"
  } else {
    Write-Host 'settings.yaml 中没有 defaultPreset，无需处理'
  }
} else {
  Write-Host '未找到 settings.yaml，跳过'
}

Write-Host ''
Write-Host '完成。刷新浏览器页面后，新会话将恢复 DSH 默认权限（workspace-write + ask）。'
