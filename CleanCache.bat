@echo off
title Fresh PC - cache cleaner
rem Double-click this file to clear Windows junk in one go.
rem Add -DryRun to preview, -NoElevate to skip the UAC prompt.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\CleanCache.ps1" %*
if errorlevel 1 pause
