@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0doctor.ps1"
set "exitCode=%ERRORLEVEL%"
echo.
pause
exit /b %exitCode%
