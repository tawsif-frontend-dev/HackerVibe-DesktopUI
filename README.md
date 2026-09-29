# Hacker Vibe Desktop Suite UI

A cyberpunk-themed [Rainmeter](https://www.rainmeter.net) desktop suite — clock,
calendar, weather, system status, network monitor, terminal-style stats,
quote rotator, and app shortcuts — with 4 switchable color themes
(Green / Blue / Red / Purple) and an auto-cycler that syncs the wallpaper
and every widget together.

![theme preview](docs/preview.png)

## Install (Windows, one command)

1. Install [Rainmeter](https://www.rainmeter.net) if you don't have it
   (or `winget install Rainmeter.Rainmeter`).
2. Download this repo (`Code > Download ZIP`, or `git clone`).
3. Double-click **`install.bat`**.

The installer asks a few quick questions — your name (shown on the wallpaper
and terminal widget), your website/GitHub link, and a countdown event — then
copies everything into your Rainmeter skins folder, generates your
personalized wallpapers, installs the bundled fonts, and loads every widget.
Nothing is hard-coded to any specific person's machine or username; every
path is either auto-detected or asked at install time.

Run `install.bat` again any time to change your name or links.

### Prefer to do it by hand?
See [`Skins/HackerSuite/README.txt`](Skins/HackerSuite/README.txt) for the
manual install / manual theme-switching steps, and how to add your own
quotes.

## What's inside

| Widget | What it shows |
|---|---|
| Clock | Time, date, motto, year/week progress |
| Calendar | Full month view + countdown to an event you set |
| Weather | Live conditions via [Open-Meteo](https://open-meteo.com) (no API key) |
| System Status | CPU / RAM / disk usage with warning colors |
| Network | Ping + up/down speed |
| Terminal | `neofetch`-style OS/CPU/GPU/uptime readout |
| Quote | Rotating quotes from `Quotes.txt` (add your own) |
| Shortcuts | Launch VS Code, your site, your downloads folder |
| ThemeCycler | Rotates all of the above through the 4 themes on a timer |

Right-click any widget for a theme switcher, "Edit settings", and "Refresh
all". Everything configurable lives in one file:
`Skins/HackerSuite/@Resources/Settings.inc`.

## Rebuilding wallpapers yourself

```
pip install pillow
python tools/make_wallpapers.py "YOUR NAME"
```

This reads the nameless base art in `@Resources/Wallpaper/Base/` and renders
your name onto all 4 theme colors. `install.ps1` does this automatically
during setup.

## License

MIT — see [LICENSE](LICENSE). Bundled fonts keep their own OFL license.
