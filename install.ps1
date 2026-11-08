<#
  HackerVibe 4 - Windows installer / personaliser (Rainmeter 4.4+)

  Easiest:  double-click install.bat
  Manual:   powershell -ExecutionPolicy Bypass -File .\install.ps1

  The installer is safe to run again: your settings, quotes and custom
  files in the installed skin are kept. Use -ResetLayout to snap the
  widgets back to the recommended desktop arrangement.

  Non-interactive:
    powershell -ExecutionPolicy Bypass -File .\install.ps1 -Yes `
      -Name "HACKER" -City "Dhaka" -Units metric -Theme Green
#>
[CmdletBinding()]
param(
    [string]$Name,
    [string]$City,
    [ValidateSet('metric', 'imperial')][string]$Units,
    [ValidateSet('Green', 'Blue', 'Red', 'Purple')][string]$Theme,
    [string]$WebsiteLabel,
    [string]$WebsiteUrl,
    [string]$EventName,
    [int]$EventDay = 0,
    [int]$EventMonth = 0,
    [switch]$Yes,
    [switch]$NoStart,
    [switch]$NoWallpaper,
    [switch]$NoFonts,
    [switch]$ResetLayout,
    [switch]$SkipDeps,
    [string]$SkinRoot
)

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$VERSION = '4.0.0'
$WIDGETS = @('Clock', 'Calendar', 'Weather', 'SystemStatus', 'Network', 'Terminal', 'Quote', 'Shortcuts', 'ThemeCycler')
$interactive = (-not $Yes) -and (-not [Console]::IsInputRedirected)

function Write-Head($text) {
    Write-Host ''
    Write-Host "  $text" -ForegroundColor Cyan
    Write-Host ('  ' + ('-' * $text.Length)) -ForegroundColor DarkCyan
}
function Write-Step($number, $total, $text) {
    Write-Host ''
    Write-Host "[$number/$total] " -ForegroundColor DarkGray -NoNewline
    Write-Host $text -ForegroundColor White
}
function Write-Ok($text)   { Write-Host "  ok  " -ForegroundColor Green -NoNewline; Write-Host $text }
function Write-Warn($text) { Write-Host "  !   " -ForegroundColor Yellow -NoNewline; Write-Host $text }
function Write-Info($text) { Write-Host "  .   " -ForegroundColor DarkGray -NoNewline; Write-Host $text }

function Ask($question, $default) {
    if (-not $interactive) { return $default }
    $answer = Read-Host "  $question [$default]"
    if ([string]::IsNullOrWhiteSpace($answer)) { return $default }
    return $answer.Trim()
}
function Ask-Yes($question, $default = $true) {
    if (-not $interactive) { return $default }
    $hint = if ($default) { 'Y/n' } else { 'y/N' }
    $answer = Read-Host "  $question [$hint]"
    if ([string]::IsNullOrWhiteSpace($answer)) { return $default }
    return $answer.Trim().ToLower().StartsWith('y')
}

function Get-Setting($file, $key, $default) {
    if (-not (Test-Path -LiteralPath $file)) { return $default }
    $match = Select-String -LiteralPath $file -Pattern "^\s*$([regex]::Escape($key))=(.*)$" |
             Select-Object -First 1
    if ($match) { return $match.Matches[0].Groups[1].Value.Trim() }
    return $default
}
function Set-Setting($file, $key, $value) {
    $value = ([string]$value) -replace '[\r\n]', ' '
    $pattern = "^\s*$([regex]::Escape($key))="
    $lines = New-Object 'System.Collections.Generic.List[string]'
    $found = $false
    foreach ($line in [IO.File]::ReadAllLines($file)) {
        if ($line -match $pattern) {
            if (-not $found) { $lines.Add("$key=$value"); $found = $true }
        } else {
            $lines.Add($line)
        }
    }
    if (-not $found) { $lines.Add("$key=$value") }
    [IO.File]::WriteAllLines($file, $lines.ToArray(), (New-Object Text.UTF8Encoding($true)))
}

function Get-Geocode($query) {
    if ([string]::IsNullOrWhiteSpace($query)) { return $null }
    try {
        $url = 'https://geocoding-api.open-meteo.com/v1/search?name=' + [uri]::EscapeDataString($query) + '&count=1&language=en&format=json'
        $result = Invoke-RestMethod -Uri $url -TimeoutSec 15 -UseBasicParsing
        if ($result.results -and @($result.results).Count -gt 0) {
            $place = $result.results[0]
            $label = $place.name
            if ($place.admin1 -and $place.admin1 -ne $place.name) { $label = "$($place.name), $($place.admin1)" }
            if ($place.country) { $label = "$label, $($place.country)" }
            return @{ Lat = [string]$place.latitude; Lon = [string]$place.longitude; Label = $label }
        }
    } catch {
        Write-Warn "City lookup failed: $($_.Exception.Message)"
    }
    return $null
}

function Get-Profile {
    $osKey = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
    $osName = $osKey.ProductName
    if ([int]$osKey.CurrentBuildNumber -ge 22000) { $osName = 'Windows 11' }
    $osVersion = $osKey.DisplayVersion
    if (-not $osVersion) { $osVersion = $osKey.ReleaseId }
    $cpu = (Get-ItemProperty 'HKLM:\HARDWARE\DESCRIPTION\System\CentralProcessor\0').ProcessorNameString
    if ($cpu) { $cpu = ($cpu -replace '\s+', ' ').Trim() }
    $gpu = $null
    try {
        $gpu = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0000' -ErrorAction Stop).DriverDesc
    } catch {}
    if (-not $gpu) {
        try { $gpu = (Get-CimInstance Win32_VideoController | Select-Object -First 1).Name } catch {}
    }
    if (-not $gpu) { $gpu = 'not detected' }
    $ram = 0
    try { $ram = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 1) } catch {}
    $screen = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    return [pscustomobject]@{
        Computer = $env:COMPUTERNAME
        User = $env:USERNAME
        OS = "$osName $osVersion".Trim()
        CPU = $cpu
        GPU = $gpu
        RAM = $ram
        Width = $screen.Width
        Height = $screen.Height
    }
}

function Find-Rainmeter {
    $candidates = @(
        "$env:ProgramFiles\Rainmeter\Rainmeter.exe",
        "${env:ProgramFiles(x86)}\Rainmeter\Rainmeter.exe",
        "$env:LOCALAPPDATA\Programs\Rainmeter\Rainmeter.exe"
    )
    foreach ($path in $candidates) {
        if (Test-Path -LiteralPath $path) { return $path }
    }
    try {
        $appPath = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\Rainmeter.exe' -ErrorAction Stop).'(default)'
        if ($appPath -and (Test-Path -LiteralPath $appPath)) { return $appPath }
    } catch {}
    return $null
}

function Install-Rainmeter {
    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if ($winget -and -not $SkipDeps) {
        if (Ask-Yes 'Rainmeter is required. Install it now with winget?' $true) {
            Write-Info 'Running: winget install Rainmeter.Rainmeter'
            & winget install --id Rainmeter.Rainmeter -e --silent --disable-interactivity --accept-package-agreements --accept-source-agreements
            Start-Sleep -Seconds 2
            return (Find-Rainmeter)
        }
    }
    Write-Host ''
    Write-Warn 'Rainmeter is not installed.'
    Write-Host '     Download it from https://www.rainmeter.net and run this installer again.' -ForegroundColor Yellow
    if (-not $SkipDeps) { Start-Process 'https://www.rainmeter.net/download/' }
    return $null
}

function Find-Editor {
    $paths = @(
        "$env:LOCALAPPDATA\Programs\Microsoft VS Code\Code.exe",
        "$env:ProgramFiles\Microsoft VS Code\Code.exe",
        "${env:ProgramFiles(x86)}\Microsoft VS Code\Code.exe"
    )
    foreach ($path in $paths) {
        if (Test-Path -LiteralPath $path) { return @{ Label = 'VS Code'; Cmd = $path } }
    }
    return @{ Label = 'Notepad'; Cmd = "$env:WINDIR\notepad.exe" }
}

function Get-DownloadsPath {
    try { return (New-Object -ComObject Shell.Application).NameSpace('shell:Downloads').Self.Path }
    catch { return (Join-Path $env:USERPROFILE 'Downloads') }
}

function Clean-Name($value, $fallback) {
    $clean = ($value -replace '[^A-Za-z0-9 ._-]', '').Trim()
    if ($clean.Length -gt 14) { $clean = $clean.Substring(0, 14).Trim() }
    if ([string]::IsNullOrWhiteSpace($clean)) { $clean = $fallback }
    return $clean
}

function Install-Fonts($target) {
    $fontDir = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
    New-Item -ItemType Directory -Force -Path $fontDir | Out-Null
    $reg = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
    $count = 0
    Get-ChildItem (Join-Path $target '@Resources\Fonts') -Filter *.ttf -ErrorAction SilentlyContinue | ForEach-Object {
        $dest = Join-Path $fontDir $_.Name
        Copy-Item -LiteralPath $_.FullName -Destination $dest -Force
        New-ItemProperty -Path $reg -Name "$($_.BaseName) (TrueType)" -Value $dest -PropertyType String -Force | Out-Null
        $count++
    }
    return $count
}

function Render-Wallpapers($target, $name) {
    $accent = @{ Blue = '153,213,255'; Green = '168,255,206'; Red = '255,146,146'; Purple = '206,168,255' }
    $wpDir = Join-Path $target '@Resources\Wallpaper'
    $text = $name.ToUpper()
    if ($text.Length -gt 14) { $text = $text.Substring(0, 14) }
    $made = 0
    foreach ($theme in $accent.Keys) {
        $base = Join-Path $wpDir "Base\Hacker_Wallpaper_${theme}_1920x1080.png"
        if (-not (Test-Path -LiteralPath $base)) { continue }
        $c = $accent[$theme].Split(',') | ForEach-Object { [int]$_ }
        $bmp = New-Object Drawing.Bitmap $base
        $g = [Drawing.Graphics]::FromImage($bmp)
        $g.TextRenderingHint = 'AntiAliasGridFit'
        $g.SmoothingMode = 'AntiAlias'
        $fmt = [Drawing.StringFormat]::GenericTypographic
        $size = 105
        do {
            $font = New-Object Drawing.Font('Consolas', $size, [Drawing.FontStyle]::Bold, [Drawing.GraphicsUnit]::Pixel)
            $sz = $g.MeasureString($text, $font, 2000, $fmt)
            $size -= 4
        } while ($sz.Width -gt 440 -and $size -gt 28)
        $x = 958 - $sz.Width / 2
        $y = 742 - $sz.Height / 2
        $glow = New-Object Drawing.SolidBrush ([Drawing.Color]::FromArgb(16, $c[0], $c[1], $c[2]))
        foreach ($dx in -8, -5, -2, 0, 2, 5, 8) {
            foreach ($dy in -8, -5, -2, 0, 2, 5, 8) {
                $g.DrawString($text, $font, $glow, $x + $dx, $y + $dy, $fmt)
            }
        }
        $brush = New-Object Drawing.SolidBrush ([Drawing.Color]::FromArgb(255, $c[0], $c[1], $c[2]))
        $g.DrawString($text, $font, $brush, $x, $y, $fmt)
        $g.Dispose()
        $bmp.Save((Join-Path $wpDir "Hacker_Wallpaper_${theme}_1920x1080.png"), [Drawing.Imaging.ImageFormat]::Png)
        $bmp.Dispose()
        $made++
    }
    return $made
}

function Set-DesktopWallpaper($path) {
    if (-not ('HackerVibeNative' -as [type])) {
        Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class HackerVibeNative {
    [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
}
'@
    }
    [HackerVibeNative]::SystemParametersInfo(20, 0, $path, 3) | Out-Null
}

function Move-Widget($rmExe, $config, $x, $y) {
    & $rmExe '!Move' "$x" "$y" "HackerSuite\$config" | Out-Null
    Start-Sleep -Milliseconds 90
}

function Set-Layout($rmExe, $pc) {
    $w = $pc.Width
    $h = $pc.Height
    $left = 0
    $systemY = 301
    $clockX = [Math]::Max(420, [int]($w / 2) - 122)
    $shortX = [Math]::Max(420, [int]($w / 2) - 133)
    $centerX = [Math]::Max(420, [int]($w / 2) - 200)
    $rightX = $w - 301
    $calendarX = $w - 312
    $calendarY = [Math]::Max(440, $h - 312)
    $themeY = $calendarY - 18
    $weatherY = 140
    $networkY = 470

    Move-Widget $rmExe 'Terminal'     $left      0
    Move-Widget $rmExe 'SystemStatus' $left      $systemY
    Move-Widget $rmExe 'Clock'        $clockX    10
    Move-Widget $rmExe 'Shortcuts'    $shortX    165
    Move-Widget $rmExe 'Network'      $centerX   $networkY
    Move-Widget $rmExe 'Quote'        $rightX    0
    Move-Widget $rmExe 'Weather'      $calendarX $weatherY
    Move-Widget $rmExe 'ThemeCycler'  ($calendarX + 48) $themeY
    Move-Widget $rmExe 'Calendar'     $calendarX $calendarY
}

# =====================================================================
Write-Host ''
Write-Host '  HACKERVIBE 4  ' -ForegroundColor Black -BackgroundColor Cyan -NoNewline
Write-Host '  desktop suite for Rainmeter' -ForegroundColor Cyan
Write-Host "  installer $VERSION" -ForegroundColor DarkGray

$source = Join-Path $PSScriptRoot 'Skins\HackerSuite'
if (-not (Test-Path -LiteralPath $source)) {
    throw "Can't find Skins\HackerSuite next to install.ps1. Run the installer from the repository folder."
}

# ---- 1. Rainmeter ---------------------------------------------------
Write-Step 1 7 'Looking for Rainmeter'
$rmExe = Find-Rainmeter
if (-not $rmExe) { $rmExe = Install-Rainmeter }
if (-not $rmExe) { throw 'Rainmeter is required. Install it, then run install.bat again.' }
$rmVersion = (Get-Item -LiteralPath $rmExe).VersionInfo.ProductVersion
Write-Ok "Rainmeter $rmVersion"

$skinsRoot = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'Rainmeter\Skins'
$rainmeterIni = Join-Path $env:APPDATA 'Rainmeter\Rainmeter.ini'
if (Test-Path -LiteralPath $rainmeterIni) {
    $skinLine = Select-String -LiteralPath $rainmeterIni -Pattern '^SkinPath=(.+)$' | Select-Object -First 1
    if ($skinLine) { $skinsRoot = $skinLine.Matches[0].Groups[1].Value.Trim() }
}
if ($SkinRoot) { $skinsRoot = $SkinRoot; Write-Info "Using custom skin root: $skinsRoot" }
$target = Join-Path $skinsRoot 'HackerSuite'
$settings = Join-Path $target '@Resources\Settings.inc'
$versionFile = Join-Path $target '@Resources\version.txt'
$installedVersion = if (Test-Path -LiteralPath $versionFile) { (Get-Content -LiteralPath $versionFile -Raw).Trim() } else { '0' }
$freshInstall = -not (Test-Path -LiteralPath $settings)
$needsLayout = $freshInstall -or $ResetLayout -or ($installedVersion -ne $VERSION)
Write-Info "Target: $target"

# ---- 2. System profile ----------------------------------------------
Write-Step 2 7 'Reading this PC'
$pc = Get-Profile
Write-Host ''
Write-Host '  SYSTEM PROFILE' -ForegroundColor Cyan
Write-Host ("  user      {0}@{1}" -f $pc.User, $pc.Computer)
Write-Host ("  os        {0}" -f $pc.OS)
Write-Host ("  cpu       {0}" -f $pc.CPU)
Write-Host ("  gpu       {0}" -f $pc.GPU)
Write-Host ("  memory    {0} GB" -f $pc.RAM)
Write-Host ("  screen    {0}x{1}" -f $pc.Width, $pc.Height)
Write-Host ("  skin path {0}" -f $skinsRoot)

$editor = Find-Editor
$downloads = Get-DownloadsPath
Write-Host ("  editor    {0}" -f $editor.Label)
Write-Host ("  downloads {0}" -f $downloads)

# ---- 3. Questions ----------------------------------------------------
Write-Step 3 7 'Personalise it'
$existingName = Get-Setting $settings 'UserName' $env:USERNAME
$existingCity = Get-Setting $settings 'LocationName' 'London, UK'
$existingLat = Get-Setting $settings 'Lat' '51.5074'
$existingLon = Get-Setting $settings 'Lon' '-0.1278'
$existingUnits = Get-Setting $settings 'WeatherUnits' 'metric'
$existingTheme = Get-Setting (Join-Path $target '@Resources\Themes\Theme.inc') 'ThemeName' 'Green'
$existingEvent = Get-Setting $settings 'EventName' 'New Year'
$existingEventDay = [int](Get-Setting $settings 'EventDay' '1')
$existingEventMonth = [int](Get-Setting $settings 'EventMonth' '1')

if (-not $Name) { $Name = Ask 'Your name on the wallpaper (max 14, A-Z 0-9)' $existingName }
$Name = Clean-Name $Name 'HACKER'

if (-not $City) { $City = Ask 'Your city for local weather' $existingCity }
if (-not $Units) { $Units = Ask 'Units (metric or imperial)' $existingUnits }
$Units = $Units.ToLower()
if ($Units -notin @('metric', 'imperial')) { $Units = 'metric' }

if (-not $Theme) { $Theme = Ask 'Theme (Green, Blue, Red or Purple)' $existingTheme }
$Theme = (Get-Culture).TextInfo.ToTitleCase($Theme.ToLower())
if ($Theme -notin @('Green', 'Blue', 'Red', 'Purple')) {
    Write-Warn "Unknown theme '$Theme' - using Green."
    $Theme = 'Green'
}

if (-not $WebsiteLabel) { $WebsiteLabel = Ask 'Label for your website shortcut' 'Website' }
$WebsiteLabel = ($WebsiteLabel -replace '[|\r\n]', ' ').Trim()
if (-not $WebsiteLabel) { $WebsiteLabel = 'Website' }
if (-not $WebsiteUrl) { $WebsiteUrl = Ask 'Your website / GitHub URL' 'https://github.com' }
if ($WebsiteUrl -notmatch '^[a-z]+://') { $WebsiteUrl = "https://$WebsiteUrl" }
if ($WebsiteUrl -notmatch '^https?://[^\s/]+') { throw "That website URL doesn't look valid: $WebsiteUrl" }

if (-not $EventName) { $EventName = Ask 'Calendar countdown event name' $existingEvent }
if ($EventDay -le 0) { $EventDay = [int](Ask 'Event day (1-31)' $existingEventDay) }
if ($EventMonth -le 0) { $EventMonth = [int](Ask 'Event month (1-12)' $existingEventMonth) }
$EventDay = [Math]::Min(31, [Math]::Max(1, $EventDay))
$EventMonth = [Math]::Min(12, [Math]::Max(1, $EventMonth))

$geocode = $null
if ($City -and $City -ne $existingCity) {
    Write-Info "Looking up $City..."
    $geocode = Get-Geocode $City
    if ($geocode) { Write-Ok "$($geocode.Label)  ($($geocode.Lat), $($geocode.Lon))" }
}
if (-not $geocode) {
    $geocode = @{ Label = $existingCity; Lat = $existingLat; Lon = $existingLon }
}

$unitParams = ''
$tempUnit = 'C'
$windUnit = 'km/h'
if ($Units -eq 'imperial') {
    $unitParams = '&temperature_unit=fahrenheit&wind_speed_unit=mph'
    $tempUnit = 'F'
    $windUnit = 'mph'
}

Write-Host ''
Write-Host '  READY TO INSTALL' -ForegroundColor Cyan
Write-Host ("  name      {0}" -f $Name.ToUpper())
Write-Host ("  weather   {0}  [{1}]" -f $geocode.Label, $Units)
Write-Host ("  theme     {0}" -f $Theme)
Write-Host ("  event     {0}  ({1}/{2})" -f $EventName, $EventDay, $EventMonth)
Write-Host ("  website   {0}  ->  {1}" -f $WebsiteLabel, $WebsiteUrl)
Write-Host ("  layout    {0}" -f $(if ($needsLayout) { 'recommended arrangement' } else { 'keep my current positions' }))
if (-not (Ask-Yes 'Install / update now?' $true)) { Write-Host '  Cancelled.'; exit 0 }

# ---- 4. Files --------------------------------------------------------
Write-Step 4 7 'Installing files'
New-Item -ItemType Directory -Force -Path $target | Out-Null
$quotes = Join-Path $target '@Resources\Quotes.txt'
$hadSettings = Test-Path -LiteralPath $settings
$hadQuotes = Test-Path -LiteralPath $quotes

if ($hadSettings) {
    $backup = "$settings.backup.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    Copy-Item -LiteralPath $settings -Destination $backup
    Write-Info "Settings backed up to $(Split-Path -Leaf $backup)"
    Get-ChildItem (Split-Path -Parent $settings) -Filter 'Settings.inc.backup.*' |
        Sort-Object LastWriteTime -Descending |
        Select-Object -Skip 3 |
        Remove-Item -Force -ErrorAction SilentlyContinue
}

& robocopy $source $target /E /XF Settings.inc Quotes.txt /NFL /NDL /NJH /NJS /NP | Out-Null
if ($LASTEXITCODE -ge 8) { throw "Skin copy failed (robocopy exit code $LASTEXITCODE)." }
if (-not $hadSettings) { Copy-Item -LiteralPath (Join-Path $source '@Resources\Settings.inc') -Destination $settings }
if (-not $hadQuotes) { Copy-Item -LiteralPath (Join-Path $source '@Resources\Quotes.txt') -Destination $quotes }
Write-Ok 'Skin files installed (settings and quotes kept)'

# ---- 5. Settings -----------------------------------------------------
Write-Step 5 7 'Connecting your details'
Set-Setting $settings 'UserName' $Name
Set-Setting $settings 'ThemeCycleMinutes' (Get-Setting $settings 'ThemeCycleMinutes' '30')
Set-Setting $settings 'EventName' $EventName
Set-Setting $settings 'EventDay' $EventDay
Set-Setting $settings 'EventMonth' $EventMonth
Set-Setting $settings 'Lat' $geocode.Lat
Set-Setting $settings 'Lon' $geocode.Lon
Set-Setting $settings 'LocationName' $geocode.Label
Set-Setting $settings 'WeatherUnits' $Units
Set-Setting $settings 'WeatherUnitParams' $unitParams
Set-Setting $settings 'TempUnit' $tempUnit
Set-Setting $settings 'WindUnit' $windUnit
Set-Setting $settings 'VSCodePath' $editor.Cmd
Set-Setting $settings 'VSCodeLabel' $editor.Label
Set-Setting $settings 'DownloadsPath' $downloads
Set-Setting $settings 'PortfolioLabel' $WebsiteLabel
Set-Setting $settings 'PortfolioURL' $WebsiteUrl

$themeSource = Join-Path $target "@Resources\Themes\Theme-$Theme.inc"
if (Test-Path -LiteralPath $themeSource) {
    Copy-Item -LiteralPath $themeSource -Destination (Join-Path $target '@Resources\Themes\Theme.inc') -Force
}
Write-Ok "Details saved - weather for $($geocode.Label), theme $Theme"

# ---- 6. Fonts + wallpaper -------------------------------------------
Write-Step 6 7 'Fonts and wallpaper'
if ($NoFonts) {
    Write-Info 'Font install skipped (-NoFonts)'
} else {
    $fontCount = Install-Fonts $target
    Write-Ok "$fontCount fonts installed for your user"
}
$wpCount = Render-Wallpapers $target $Name
Write-Ok "$wpCount personalised wallpapers rendered"
if (-not $NoWallpaper -and (Get-Setting $settings 'ThemeWallpaper' '1') -ne '0') {
    $wallpaper = Join-Path $target "@Resources\Wallpaper\Hacker_Wallpaper_${Theme}_1920x1080.png"
    if (Test-Path -LiteralPath $wallpaper) {
        try { Set-DesktopWallpaper $wallpaper; Write-Ok 'Desktop wallpaper updated' }
        catch { Write-Warn "Could not set the wallpaper: $($_.Exception.Message)" }
    }
}

# ---- 7. Rainmeter ----------------------------------------------------
Write-Step 7 7 'Starting the widgets'
if ($NoStart) {
    Write-Warn 'Skipped (-NoStart). Load HackerSuite from Rainmeter when you are ready.'
} else {
    if (-not (Get-Process Rainmeter -ErrorAction SilentlyContinue)) {
        Start-Process -FilePath $rmExe
        Start-Sleep -Seconds 4
    } else {
        & $rmExe '!RefreshApp' | Out-Null
        Start-Sleep -Seconds 1
    }
    foreach ($widget in $WIDGETS) {
        & $rmExe '!ActivateConfig' "HackerSuite\$widget" "$widget.ini" | Out-Null
    }
    Start-Sleep -Milliseconds 800
    if ($needsLayout) {
        Set-Layout $rmExe $pc
        Write-Ok 'Recommended layout applied'
    } else {
        Write-Info 'Kept your current widget positions'
    }
    & $rmExe '!RefreshApp' | Out-Null
    Write-Ok 'All 9 widgets are loaded'
}

Set-Content -LiteralPath $versionFile -Value $VERSION -Encoding ASCII

Write-Host ''
Write-Host '  INSTALL COMPLETE' -ForegroundColor Black -BackgroundColor Green
Write-Host ''
Write-Host '  Next:' -ForegroundColor Cyan
Write-Host '    - Click a colour on the HACKERVIBE strip to switch theme.'
Write-Host '    - Click the clock for 12h/24h; click a quote for a new one.'
Write-Host '    - Right-click any widget: Edit settings / Refresh all / Theme.'
Write-Host '    - Run doctor.bat if a widget looks wrong or stays empty.'
Write-Host ("    - Installed in: {0}" -f $target)
Write-Host ''
