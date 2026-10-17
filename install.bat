@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1"
set "exitCode=%ERRORLEVEL%"
if not "%exitCode%"=="0" echo Installation failed with exit code %exitCode%.
pause
exit /b %exitCode%
