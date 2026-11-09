<#
  HackerVibe - Fresh PC cache cleaner

  One click clears the junk Windows keeps around:
    %TEMP%  (user temp)      Windows\Temp
    Windows\Prefetch          thumbnails
    CrashDumps / Minidump     Recycle Bin
  and then flushes the DNS cache.

  Safety rules:
    * files that are in use are skipped, never forced
    * anything inside a "qoder" folder in %TEMP% is left alone
      (it holds live tool output that may still be in use)
    * Windows\Temp and Prefetch need admin, so the script re-launches
      itself once behind a UAC prompt

  Switches:
    -DryRun     show what would be removed, delete nothing
    -NoElevate  do not ask for admin (user-level caches only)
    -NoPrompt   do not wait for Enter at the end
#>
param(
    [switch]$DryRun,
    [switch]$NoElevate,
    [switch]$NoPrompt
)

$ErrorActionPreference = 'SilentlyContinue'
$ProgressPreference = 'SilentlyContinue'

function Test-Admin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    (New-Object Security.Principal.WindowsPrincipal $identity).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not $DryRun -and -not $NoElevate -and -not (Test-Admin)) {
    Write-Host 'Windows will ask for permission once (UAC)...' -ForegroundColor Yellow
    $argumentList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"{0}"' -f $PSCommandPath))
    if ($NoPrompt) { $argumentList += '-NoPrompt' }
    try {
        Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList $argumentList -Wait
        exit
    } catch {
        Write-Host 'Admin was not granted - cleaning user caches only.' -ForegroundColor Yellow
    }
}

function Get-FreeBytes {
    try {
        $disk = Get-CimInstance Win32_LogicalDisk -Filter ("DeviceID='{0}'" -f $env:SystemDrive)
        if ($disk -and $disk.FreeSpace) { return [int64]$disk.FreeSpace }
    } catch { }
    return [int64](Get-PSDrive -Name ([string]$env:SystemDrive).Substring(0, 1)).Free
}

$isAdmin = Test-Admin
$freeBefore = Get-FreeBytes
$script:removedBytes = 0
$script:removedFiles = 0
$script:skippedFiles = 0
$script:groups = New-Object System.Collections.ArrayList

function Clear-CacheFolder {
    param(
        [string]$Path,
        [string]$Label,
        [string[]]$Patterns = @('*'),
        [string]$ExcludePattern,
        [switch]$PruneEmpty
    )

    if (-not (Test-Path -LiteralPath $Path)) { return }

    $startBytes = $script:removedBytes
    $deleted = 0
    $skipped = 0

    $files = Get-ChildItem -LiteralPath $Path -Force -File -Recurse -ErrorAction SilentlyContinue
    foreach ($file in $files) {
        $excluded = $false
        if ($ExcludePattern -and ($file.FullName -match $ExcludePattern)) { $excluded = $true }
        $targeted = $false
        foreach ($pattern in $Patterns) { if ($file.Name -like $pattern) { $targeted = $true; break } }
        if ($excluded -or -not $targeted) { continue }

        if ($DryRun) {
            $script:removedBytes += $file.Length
            $deleted++
            continue
        }
        try {
            Remove-Item -LiteralPath $file.FullName -Force -ErrorAction Stop
            $script:removedBytes += $file.Length
            $deleted++
        } catch {
            $skipped++
        }
    }

    if ($PruneEmpty -and -not $DryRun) {
        Get-ChildItem -LiteralPath $Path -Force -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            if ($ExcludePattern -and ($_.FullName -match $ExcludePattern)) { return }
            $left = Get-ChildItem -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue
            if (-not $left) { Remove-Item -LiteralPath $_.FullName -Force -Recurse -ErrorAction SilentlyContinue }
        }
    }

    $script:removedFiles += $deleted
    $script:skippedFiles += $skipped
    [void]$script:groups.Add([pscustomobject]@{
        Label   = $Label
        Files   = $deleted
        Bytes   = $script:removedBytes - $startBytes
        Skipped = $skipped
    })
}

function Get-RecycleBinBytes {
    $bytes = 0
    try {
        $shell = New-Object -ComObject Shell.Application
        $bin = $shell.Namespace(10)
        foreach ($item in $bin.Items()) {
            try { $bytes += [int64]$item.ExtendedProperty('Size') } catch { }
        }
    } catch { }
    return $bytes
}

Write-Host ''
Write-Host '  Fresh PC - cache cleaner' -ForegroundColor Cyan
$adminText = 'no'; if ($isAdmin) { $adminText = 'yes' }
$dryText = 'no'; if ($DryRun) { $dryText = 'yes' }
Write-Host ('  admin: {0}    dry run: {1}' -f $adminText, $dryText) -ForegroundColor DarkGray
Write-Host ''

Clear-CacheFolder -Path $env:TEMP -Label 'Your temp folder' -ExcludePattern '\\qoder' -PruneEmpty
Clear-CacheFolder -Path 'C:\Windows\Temp' -Label 'Windows temp' -PruneEmpty
Clear-CacheFolder -Path 'C:\Windows\Prefetch' -Label 'Prefetch' -Patterns @('*.pf')
Clear-CacheFolder -Path (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Explorer') -Label 'Thumbnails' -Patterns @('thumbcache_*.db')
Clear-CacheFolder -Path (Join-Path $env:LOCALAPPDATA 'CrashDumps') -Label 'Crash dumps' -PruneEmpty
Clear-CacheFolder -Path 'C:\Windows\Minidump' -Label 'Memory dumps' -Patterns @('*.dmp')

# ---- Recycle Bin ---------------------------------------------------------
$binBytes = Get-RecycleBinBytes
$startBytes = $script:removedBytes
if ($DryRun) {
    $script:removedBytes += $binBytes
} else {
    try {
        Clear-RecycleBin -DriveLetter ([string]$env:SystemDrive).Substring(0, 1) -Force -ErrorAction Stop
        $script:removedBytes += $binBytes
    } catch { }
}
[void]$script:groups.Add([pscustomobject]@{
    Label = 'Recycle Bin'; Files = $null; Bytes = $script:removedBytes - $startBytes; Skipped = 0
})

# ---- DNS -----------------------------------------------------------------
if (-not $DryRun) { & ipconfig /flushdns | Out-Null }

# ---- Report --------------------------------------------------------------
foreach ($group in $script:groups) {
    $mb = [math]::Round($group.Bytes / 1MB, 1)
    $line = '  {0,-18} {1,8} MB' -f $group.Label, $mb
    if ($group.Skipped -gt 0) { $line += ('   ({0} in use, kept)' -f $group.Skipped) }
    Write-Host $line -ForegroundColor Gray
}

$freed = [math]::Round($script:removedBytes / 1MB, 1)
$freeAfter = Get-FreeBytes
Write-Host ''
if ($DryRun) {
    Write-Host ('  Would free about {0} MB - nothing was deleted.' -f $freed) -ForegroundColor Yellow
} else {
    Write-Host ('  Freed {0} MB in {1} files.' -f $freed, $script:removedFiles) -ForegroundColor Green
    Write-Host ('  Free space: {0} GB -> {1} GB' -f [math]::Round($freeBefore / 1GB, 2), [math]::Round($freeAfter / 1GB, 2)) -ForegroundColor Green
    if (-not $isAdmin) { Write-Host '  Tip: run as admin to also clear Windows temp and Prefetch.' -ForegroundColor DarkGray }
}
Write-Host ''

$logFolder = Join-Path $env:LOCALAPPDATA 'HackerSuite'
New-Item -ItemType Directory -Force -Path $logFolder | Out-Null
$logLine = '{0}  admin={1} dryrun={2}  freed={3} MB  files={4}  skipped={5}' -f `
    (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $isAdmin, $DryRun, $freed, $script:removedFiles, $script:skippedFiles
Add-Content -LiteralPath (Join-Path $logFolder 'clean-cache.log') -Value $logLine

if (-not $NoPrompt) { [void](Read-Host 'Press Enter to close') }
