# =====================================================================
#  HackerVibe - doctor
#  Checks the installed suite and reports anything that looks broken.
#  Run:  double-click doctor.bat   or   powershell -File .\doctor.ps1
# =====================================================================
[CmdletBinding()]
param([string]$SkinRoot)

$ErrorActionPreference = 'Stop'
$fail = 0
$warn = 0

function Pass($msg) { Write-Host "  [ok]   $msg" -ForegroundColor Green }
function Warn($msg) { Write-Host "  [warn] $msg" -ForegroundColor Yellow; $script:warn++ }
function Fail($msg) { Write-Host "  [fail] $msg" -ForegroundColor Red; $script:fail++ }

Write-Host ''
Write-Host '  HACKERVIBE DOCTOR' -ForegroundColor Black -BackgroundColor Cyan
Write-Host '  -----------------' -ForegroundColor DarkCyan

# ---- Rainmeter ------------------------------------------------------
$rm = @(
    "$env:ProgramFiles\Rainmeter\Rainmeter.exe",
    "${env:ProgramFiles(x86)}\Rainmeter\Rainmeter.exe"
) | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $rm) {
    $appPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\App Paths\Rainmeter.exe'
    if (Test-Path $appPath) { $rm = (Get-ItemProperty $appPath).'(default)' }
}
if ($rm) {
    Pass "Rainmeter found: $rm"
    if (Get-Process Rainmeter -ErrorAction SilentlyContinue) { Pass 'Rainmeter is running' }
    else { Warn 'Rainmeter is not running - widgets cannot be shown' }
} else {
    Fail 'Rainmeter is not installed - run install.bat again'
}

# ---- Skin folder ----------------------------------------------------
$root = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'Rainmeter\Skins'
$rainmeterIni = Join-Path $env:APPDATA 'Rainmeter\Rainmeter.ini'
if (Test-Path -LiteralPath $rainmeterIni) {
    $line = Select-String -LiteralPath $rainmeterIni -Pattern '^SkinPath=(.+)$' | Select-Object -First 1
    if ($line) { $root = $line.Matches[0].Groups[1].Value.Trim() }
}
if ($SkinRoot) { $root = $SkinRoot }
$target = Join-Path $root 'HackerSuite'
if (Test-Path -LiteralPath (Join-Path $target 'Clock\Clock.ini')) {
    Pass "Skin folder: $target"
} else {
    Fail "HackerSuite is not installed in $root - run install.bat"
}

if (Test-Path -LiteralPath $target) {
    $widgets = @('Clock', 'Calendar', 'Weather', 'SystemStatus', 'Network', 'Terminal', 'Quote', 'Shortcuts', 'ThemeCycler')
    $missing = @()
    foreach ($w in $widgets) {
        if (-not (Test-Path -LiteralPath (Join-Path $target "$w\$w.ini"))) { $missing += $w }
    }
    if ($missing.Count -eq 0) { Pass 'All 9 widget files are present' }
    else { Fail "Missing widget files: $($missing -join ', ')" }

    $includes = @(
        '@Resources\Settings.inc',
        '@Resources\Common.inc',
        '@Resources\Themes\Theme.inc',
        '@Resources\Variables.inc',
        '@Resources\Language\Language.inc',
        '@Resources\Quotes.txt'
    )
    $missing = @($includes | Where-Object { -not (Test-Path -LiteralPath (Join-Path $target $_)) })
    if ($missing.Count -eq 0) { Pass 'Settings, theme, language and quote files are present' }
    else { Fail "Missing include files: $($missing -join ', ')" }

    $settings = Join-Path $target '@Resources\Settings.inc'
    if (Test-Path -LiteralPath $settings) {
        $text = Get-Content -LiteralPath $settings -Raw
        foreach ($pair in @(@('UserName', 'Your name is empty'), @('Lat', 'Weather latitude is empty'), @('Lon', 'Weather longitude is empty'))) {
            if ($text -notmatch "(?m)^$($pair[0])=(?!\s*$).+") { Warn "$($pair[1]) - run install.bat again or edit Settings.inc" }
        }
        if ($text -match '(?m)^UserName=') { Pass 'Settings.inc exists and is readable' }
    }
}

# ---- Fonts ----------------------------------------------------------
$fontDir = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
$fonts = @('Orbitron.ttf', 'JetBrainsMono-Regular.ttf', 'JetBrainsMono-Bold.ttf', 'Open Sans Light.ttf')
$missing = @($fonts | Where-Object { -not (Test-Path -LiteralPath (Join-Path $fontDir $_)) })
if ($missing.Count -eq 0) { Pass 'Bundled fonts are installed for this user' }
else { Warn "Fonts not installed: $($missing -join ', ') - run install.bat (it installs them per-user)" }

# ---- Wallpaper ------------------------------------------------------
$themeFile = Join-Path $target '@Resources\Themes\Theme.inc'
if (Test-Path -LiteralPath $themeFile) {
    $themeLine = Select-String -LiteralPath $themeFile -Pattern '^ThemeName=(.+)$' | Select-Object -First 1
    $theme = if ($themeLine) { $themeLine.Matches[0].Groups[1].Value.Trim() } else { 'Green' }
    Pass "Active theme: $theme"
    $wall = Join-Path $target "@Resources\Wallpaper\Hacker_Wallpaper_${theme}_1920x1080.png"
    if (Test-Path -LiteralPath $wall) { Pass "Wallpaper for $theme is present" }
    else { Warn "Wallpaper for $theme is missing - run install.bat to render it" }
}

# ---- Network / weather ----------------------------------------------
try {
    $null = Invoke-RestMethod -Uri 'https://api.open-meteo.com/v1/forecast?latitude=23.71&longitude=90.41&current=temperature_2m' -TimeoutSec 12
    Pass 'Open-Meteo weather API is reachable'
} catch {
    Warn 'Open-Meteo is not reachable - check your internet/proxy; weather may stay empty'
}

Write-Host ''
if ($fail -gt 0) {
    Write-Host "  Result: $fail problem(s), $warn warning(s)." -ForegroundColor Red
    Write-Host '  Re-run install.bat to repair files; your settings are kept.'
    exit 1
}
Write-Host "  Result: healthy ($warn warning(s))." -ForegroundColor Green
Write-Host '  If a widget looks empty, right-click it > Refresh.'
exit 0
