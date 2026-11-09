# Hacker Suite colour picker
# Called by the Terminal palette swatches:
#   powershell -File PickColor.ps1 -Role Accent -Current "120,200,255,255"
#   powershell -File PickColor.ps1 -Role Accent -Reset
# Writes the chosen colour to @Resources\Themes\Custom.inc and reloads all skins.
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Accent', 'Hover', 'Dim', 'Faint', 'Secondary', 'Warn', 'Crit', 'TextLight', 'BG', 'BarBG')]
    [string]$Role,
    [string]$Current = '',
    [string]$IniPath = '',
    [string]$Color = '',
    [switch]$Reset,
    [switch]$NoRefresh
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

if (-not $IniPath) {
    $IniPath = Join-Path (Split-Path $PSScriptRoot -Parent) 'Themes\Custom.inc'
}
$dir = Split-Path $IniPath -Parent
if (-not (Test-Path -LiteralPath $dir)) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
}

# ---- read what is already there so we only touch this one role ---------
$lines = @()
if (Test-Path -LiteralPath $IniPath) {
    $lines = @(Get-Content -LiteralPath $IniPath)
}
if (-not ($lines -match '^\s*\[Variables\]')) {
    $lines = @('[Variables]') + $lines
}

function Test-RoleLine([string]$line, [string]$role) {
    return $line -match ('^\s*' + [regex]::Escape($role) + '\s*=')
}

$lines = @($lines | Where-Object { -not (Test-RoleLine $_ $Role) })

# ---- reset: just drop the override -------------------------------------
if ($Reset) {
    if ($Role -in @('Accent', 'TextLight')) {
        $lines = @($lines | Where-Object { -not (Test-RoleLine $_ ($Role + 'RGB')) })
    }
    Set-Content -LiteralPath $IniPath -Value $lines -Encoding ASCII
    Write-Host "Reset $Role to the theme colour."
} else {
    # ---- parse a colour string (R,G,B or R,G,B,A) ------------------------
    function ConvertTo-Rgb([string]$text) {
        $parts = @($text -split '[,;]' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })
        if ($parts.Count -lt 3) { return $null }
        $r = 0; $g = 0; $b = 0
        if (-not ([int]::TryParse($parts[0], [ref]$r) -and
                  [int]::TryParse($parts[1], [ref]$g) -and
                  [int]::TryParse($parts[2], [ref]$b))) { return $null }
        return @(
            [Math]::Min(255, [Math]::Max(0, $r)),
            [Math]::Min(255, [Math]::Max(0, $g)),
            [Math]::Min(255, [Math]::Max(0, $b))
        )
    }

    # Keep the current alpha unless the new colour supplies its own.
    $alpha = 255
    $currentParts = @($Current -split '[,;]' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })
    if ($currentParts.Count -ge 4) {
        $a = 255
        if ([int]::TryParse($currentParts[3], [ref]$a)) { $alpha = [Math]::Min(255, [Math]::Max(0, $a)) }
    }

    $rgb = $null
    if ($Color) {
        $rgb = ConvertTo-Rgb $Color
        if (-not $rgb) { Write-Error "Invalid -Color value: $Color"; exit 1 }
        $newParts = @($Color -split '[,;]' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })
        if ($newParts.Count -ge 4) {
            $a = 255
            if ([int]::TryParse($newParts[3], [ref]$a)) { $alpha = [Math]::Min(255, [Math]::Max(0, $a)) }
        }
    } else {
        $rgb = ConvertTo-Rgb $Current

        # ---- colour dialog, owned by a tiny topmost form so it comes forward
        $owner = New-Object System.Windows.Forms.Form
        $owner.Text = 'Hacker Suite'
        $owner.FormBorderStyle = 'None'
        $owner.ShowInTaskbar = $false
        $owner.StartPosition = 'Manual'
        $owner.Location = New-Object System.Drawing.Point(-3000, -3000)
        $owner.Size = New-Object System.Drawing.Size(1, 1)
        $owner.TopMost = $true
        $owner.Show()

        $dlg = New-Object System.Windows.Forms.ColorDialog
        $dlg.AllowFullOpen = $true
        $dlg.FullOpen = $true
        $dlg.AnyColor = $true
        $dlg.SolidColorOnly = $false
        $dlg.ShowHelp = $false
        if ($rgb) {
            $dlg.Color = [System.Drawing.Color]::FromArgb($rgb[0], $rgb[1], $rgb[2])
        }

        $answer = $dlg.ShowDialog($owner)
        $owner.Close()
        $owner.Dispose()
        if ($answer -ne [System.Windows.Forms.DialogResult]::OK) {
            exit 0
        }
        $c = $dlg.Color
        $rgb = @($c.R, $c.G, $c.B)
    }

    $value = '{0},{1},{2},{3}' -f $rgb[0], $rgb[1], $rgb[2], $alpha
    $lines += ('{0}={1}' -f $Role, $value)
    if ($Role -in @('Accent', 'TextLight')) {
        # RGB-only form for shapes that append their own alpha (Calendar).
        $rgbKey = $Role + 'RGB'
        $lines = @($lines | Where-Object { -not (Test-RoleLine $_ $rgbKey) })
        $lines += ('{0}={1},{2},{3}' -f $rgbKey, $rgb[0], $rgb[1], $rgb[2])
    }
    Set-Content -LiteralPath $IniPath -Value $lines -Encoding ASCII
    Write-Host "Set $Role=$value"
}

# ---- make every skin pick the change up right away ---------------------
if (-not $NoRefresh) {
    $rm = Get-Process -Name Rainmeter -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($rm -and $rm.Path) {
        Start-Process -FilePath $rm.Path -ArgumentList '!RefreshApp' -WindowStyle Hidden
    }
}
