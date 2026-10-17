<div align="center">

# HackerVibe Desktop UI

**A cyberpunk-themed Rainmeter desktop suite for Windows.**
Clock · Calendar · Weather · System Monitor · Network · Terminal Stats · Quotes · Shortcuts

[![Rainmeter](https://img.shields.io/badge/Rainmeter-4.4%2B-0aa8d2?logo=rainmeter&logoColor=white)](https://www.rainmeter.net)
[![Platform](https://img.shields.io/badge/platform-Windows%2010%2F11-informational)](#requirements)
[![License: MIT](https://img.shields.io/badge/license-MIT-green)](LICENSE)
[![Fonts: OFL](https://img.shields.io/badge/fonts-OFL--1.1-orange)](Skins/HackerSuite/@Resources/Fonts)

![Desktop preview — all 4 themes](docs/preview.png)
*Green · Blue · Red · Purple — same layout, live-swapped colors and wallpaper.*

</div>

---

## Overview

HackerVibe Desktop UI is a full desktop widget suite built on Rainmeter.
It ships with **4 switchable color themes** — Green, Blue, Red, Purple —
that recolor every widget *and* swap the desktop wallpaper in sync, either
manually with one click or automatically on a timer.

The installer asks for per-user details, generates personalized wallpapers,
and configures shortcuts for the current machine. Settings live in the
installed skin folder; the source tree contains generic defaults.

## Features

| Widget | Description |
|---|---|
| **Clock** | Time, date, a rotating motto, and year/week progress |
| **Calendar** | Full month view with a countdown to an event you set |
| **Weather** | Live conditions via [Open-Meteo](https://open-meteo.com) — free, no API key |
| **System Status** | CPU / RAM / disk usage with color-coded warning thresholds |
| **Network** | Ping latency and live upload/download speed |
| **Terminal** | `neofetch`-style OS / CPU / GPU / uptime readout |
| **Quote** | Rotates quotes from an editable text file |
| **Shortcuts** | One-click launchers for your editor, site, and downloads folder |
| **ThemeCycler** | Rotates wallpaper + all widgets through the 4 themes on a timer |

## Requirements

- Windows 10 or 11
- [Rainmeter](https://www.rainmeter.net) 4.4+ (`winget install Rainmeter.Rainmeter`)

## Installation

```bash
git clone https://github.com/tawsif-frontend-dev/HackerVibe-DesktopUI.git
cd HackerVibe-DesktopUI
install.bat
```

Or download the ZIP (`Code → Download ZIP`) and double-click `install.bat`.

The installer will:

1. Locate your Rainmeter install and skins folder automatically
2. Ask for your name, portfolio/GitHub link, and a countdown event
3. Copy the skin into Rainmeter's configured skin path (usually `Documents\Rainmeter\Skins`)
4. Render your personalized wallpaper in all 4 theme colors
5. Install the bundled fonts for your user account
6. Load every widget in Rainmeter

Run `install.bat` again to update installer-managed values. Existing settings
are backed up before those values are updated; custom settings, quotes, and
other files in the installed skin are retained. If installation is interrupted,
rerun `install.bat`; use the timestamped settings backup in the installed
`@Resources` folder to recover previous values if needed.

<details>
<summary><strong>Prefer a manual install?</strong></summary>

See [`Skins/HackerSuite/README.txt`](Skins/HackerSuite/README.txt) for
step-by-step manual installation, manual theme switching, and how to add
your own quotes.
</details>

## Configuration

Everything lives in one file:
[`Skins/HackerSuite/@Resources/Settings.inc`](Skins/HackerSuite/@Resources/Settings.inc).
After installation, edit the installed skin's `@Resources/Settings.inc` (right-click
any widget → **Edit settings**), then
**Refresh all** to apply it. Theme switching never touches this file.

## Safe Removal

Run `powershell -ExecutionPolicy Bypass -File .\uninstall.ps1` from the
repository folder. After confirmation, the script deactivates the suite and
moves the complete installed skin to a timestamped archive outside Rainmeter's
active skin folder. Review that archive before deleting it; it includes settings,
quotes, and any other custom files. Installed fonts are left in place because
they may be shared with other applications.

## Switching Themes

Right-click any widget → **Theme → Green / Blue / Red / Purple**. This
instantly recolors every widget and updates the wallpaper together.

To cycle automatically, load `ThemeCycler.ini` from Rainmeter's manage
window — it rotates through all 4 themes on a timer you set in
`Settings.inc` (`ThemeCycleMinutes`).

## Privacy

Weather uses Open-Meteo. By default, the configured coordinates are sent to Open-Meteo and IP-based location detection is disabled. To enable automatic location, set `WeatherAuto=1` in `Settings.inc`; this contacts `ip-api.com` over HTTP and exposes your public IP address to that service. The network widget also pings the configured host (`PingHost`, default `1.1.1.1`).

## Rebuilding Wallpapers

The wallpapers ship pre-rendered with a placeholder name. To regenerate
them with your own (this also happens automatically during install):

```bash
pip install pillow
python tools/make_wallpapers.py "YOUR NAME"
```

This reads the nameless base art in `@Resources/Wallpaper/Base/` and
renders your name onto all 4 theme colors.

## Project Structure

```
HackerVibe-DesktopUI/
├── install.bat / install.ps1     # One-click Windows installer
├── tools/
│   ├── make_wallpapers.py        # Wallpaper text renderer
│   └── build_rmskin.py           # Packages a .rmskin installer
└── Skins/HackerSuite/
    ├── Clock/ Calendar/ Weather/ ...   # One .ini per widget
    └── @Resources/
        ├── Settings.inc           # All user-facing config
        ├── Themes/ Variables*.inc # Color themes
        ├── Wallpaper/             # Generated + base art
        ├── Fonts/                 # Bundled, open-licensed fonts
        └── Scripts/               # Lua: theme engine, quote rotator
```

## Contributing

Issues and pull requests are welcome — new themes, widgets, or bug fixes
all fit. Please keep any new config generic (no hard-coded personal paths
or names); route user-specific values through `Settings.inc` instead.

## License

Project code is licensed under [MIT](LICENSE). Bundled JetBrains Mono and
Orbitron font license texts are included in `Skins/HackerSuite/@Resources/Fonts/`.
The legacy Open Sans Light v1.10 and Roboto v2.137 font files are distributed
under Apache-2.0 based on their embedded versions and historical Google Fonts
license metadata. Their license and version/source notes are included in the
same `Fonts/` directory.

---

<div align="center">
If this saved you some setup time, a ⭐ on the repo helps others find it.
</div>
