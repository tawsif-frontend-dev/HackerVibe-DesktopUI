<#
  HackerVibe uninstaller.
  Deactivates the widgets and removes the installed HackerSuite folder.

    powershell -ExecutionPolicy Bypass -File .\uninstall.ps1
    ... -Yes        no confirmation prompt
    ... -KeepFiles  keep the folder (only unload the widgets)
    ... -SkinRoot   custom Rainmeter skin root
#>
[CmdletBinding()]
param(
    [switch]$Yes,
    [switch]$KeepFiles,
    [string]$SkinRoot
)
$ErrorActionPreference = 'Stop'

$root = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'Rainmeter\Skins'
$rainmeterIni = Join-Path $env:APPDATA 'Rainmeter\Rainmeter.ini'
if (Test-Path -LiteralPath $rainmeterIni) {
    $line = Select-String -LiteralPath $rainmeterIni -Pattern '^SkinPath=(.+)$' | Select-Object -First 1
    if ($line) { $root = $line.Matches[0].Groups[1].Value.Trim() }
}
if ($SkinRoot) { $root = $SkinRoot }

$target = Join-Path $root 'HackerSuite'
if (-not (Test-Path -LiteralPath $target)) {
    Write-Host "HackerSuite is not installed at $target"
    exit 0
}

$rm = @(
    "$env:ProgramFiles\Rainmeter\Rainmeter.exe",
    "${env:ProgramFiles(x86)}\Rainmeter\Rainmeter.exe",
    "$env:LOCALAPPDATA\Programs\Rainmeter\Rainmeter.exe"
) | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1

$widgets = @('Clock', 'Calendar', 'Weather', 'SystemStatus', 'Network', 'Terminal', 'Quote', 'Shortcuts', 'ThemeCycler')
if ($rm -and (Get-Process Rainmeter -ErrorAction SilentlyContinue)) {
    foreach ($w in $widgets) { & $rm '!DeactivateConfig' "HackerSuite\$w" 2>$null | Out-Null }
    Start-Sleep -Milliseconds 600
}

if (-not $Yes) {
    $action = if ($KeepFiles) { 'Unload the widgets and keep the folder?' } else { "Delete $target ?" }
    $answer = Read-Host "$action [y/N]"
    if ($answer -notmatch '^(y|yes)$') { Write-Host 'Nothing was changed.'; exit 0 }
}

if ($KeepFiles) {
    Write-Host 'Widgets unloaded. Files kept at:' $target -ForegroundColor Green
} else {
    Remove-Item -LiteralPath $target -Recurse -Force
    Write-Host 'Widgets unloaded and HackerSuite files removed.' -ForegroundColor Green
    Write-Host 'Your desktop wallpaper was not changed. Bundled fonts were left installed.'
}
exit 0
