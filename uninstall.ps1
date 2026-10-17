<#
  Safely deactivate HackerSuite and move its complete installed folder to an archive.
  Settings, quotes, and any other user edits remain recoverable in that archive.
#>
$ErrorActionPreference = 'Stop'

$skinsRoot = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'Rainmeter\Skins'
$rainmeterIni = Join-Path $env:APPDATA 'Rainmeter\Rainmeter.ini'
if (Test-Path $rainmeterIni) {
    $skinPathSetting = Select-String -Path $rainmeterIni -Pattern '^SkinPath=(.+)$' | Select-Object -First 1
    if ($skinPathSetting) { $skinsRoot = $skinPathSetting.Matches[0].Groups[1].Value.Trim() }
}

$target = Join-Path $skinsRoot 'HackerSuite'
if (-not (Test-Path $target)) {
    Write-Host "HackerSuite was not found at: $target"
    exit 0
}

$archiveName = "HackerSuite-uninstalled-$(Get-Date -Format 'yyyyMMdd-HHmmss-fff')"
$archive = Join-Path (Split-Path $skinsRoot -Parent) $archiveName
$answer = Read-Host "Deactivate HackerSuite and archive its complete folder to '$archive'? [y/N]"
if ($answer -notmatch '^(y|yes)$') {
    Write-Host 'No files were changed.'
    exit 0
}

$rainmeterExe = @("$env:ProgramFiles\Rainmeter\Rainmeter.exe", "${env:ProgramFiles(x86)}\Rainmeter\Rainmeter.exe") |
    Where-Object { Test-Path $_ } | Select-Object -First 1
if ($rainmeterExe -and (Get-Process Rainmeter -ErrorAction SilentlyContinue)) {
    & $rainmeterExe '!DeactivateConfig' 'HackerSuite'
}

Move-Item -LiteralPath $target -Destination $archive
Write-Host "HackerSuite was removed from Rainmeter's active skin path. Files were preserved at: $archive" -ForegroundColor Green
Write-Host 'Bundled fonts were left installed so shared or pre-existing fonts are not removed.'
