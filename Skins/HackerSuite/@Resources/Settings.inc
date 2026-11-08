; =====================================================================
;  HACKERVIBE - SETTINGS
;  This is the only file you normally need to edit.
;  Right-click any widget > "Edit settings", save, then "Refresh all".
;  install.ps1 fills in the values below for you.
; =====================================================================
[Variables]

; ---- Who are you? ---------------------------------------------------
; Shown in the Terminal widget and credited on your own quotes.
UserName=Hacker

; ---- Theme ----------------------------------------------------------
; Minutes between automatic theme changes (ThemeCycler widget)
; 0 = keep the current theme and never switch automatically
ThemeCycleMinutes=30
; 1 = also change the desktop wallpaper when the theme changes
ThemeWallpaper=1

; ---- Clock ----------------------------------------------------------
; 0 = 12-hour, 1 = 24-hour (or just click the clock)
Clock24=0
Motto=FOCUS / PLAN / EXECUTE / SUCCEED

; ---- Calendar event countdown (rolls over to next year) -------------
EventName=New Year
EventDay=1
EventMonth=1

; ---- Quote ----------------------------------------------------------
; Minutes between random quotes (click the quote for a new one)
; Add your own quotes in @Resources\Quotes.txt   (use {USER} for your name)
QuoteMinutes=60

; ---- Weather (Open-Meteo, free, no API key) -------------------------
; 1 = detect the city from your IP through ip-api.com (sends your IP)
; 0 = use the Lat / Lon / LocationName below (privacy-friendly default)
WeatherAuto=0
Lat=51.5074
Lon=-0.1278
LocationName=London, UK
; metric = Celsius + km/h, imperial = Fahrenheit + mph
WeatherUnits=metric
WeatherUnitParams=
TempUnit=C
WindUnit=km/h

; ---- System Status alerts (percent) --------------------------------
WarnAt=60
CritAt=85

; ---- Network --------------------------------------------------------
PingHost=1.1.1.1

; ---- Shortcuts ------------------------------------------------------
; install.ps1 detects these automatically. Use full paths, no % variables.
VSCodePath=C:\Program Files\Microsoft VS Code\Code.exe
VSCodeLabel=VS Code
DownloadsPath=C:\Users\Public\Downloads
PortfolioLabel=My Website
PortfolioURL=https://github.com
