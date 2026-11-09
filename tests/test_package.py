import subprocess
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


class PackageTests(unittest.TestCase):
    def test_builder_includes_skin_resources_and_licenses(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            package = Path(temporary_directory) / "HackerSuite.rmskin"
            subprocess.run(
                [sys.executable, str(ROOT / "tools" / "build_rmskin.py"), "--output", str(package)],
                cwd=ROOT,
                check=True,
                capture_output=True,
                text=True,
            )
            with zipfile.ZipFile(package) as archive:
                names = set(archive.namelist())

        required = {
            "RMSKIN.ini",
            "LICENSE.txt",
            "Skins/HackerSuite/Clock/Clock.ini",
            "Skins/HackerSuite/@Resources/Settings.inc",
            "Skins/HackerSuite/@Resources/Fonts/OFL-JetBrainsMono.txt",
            "Skins/HackerSuite/@Resources/Fonts/LICENSE-Apache-2.0.txt",
            "Skins/HackerSuite/@Resources/Fonts/FONT-NOTICES.txt",
            "Skins/HackerSuite/@Resources/Wallpaper/Base/Hacker_Wallpaper_Green_1920x1080.png",
        }
        self.assertTrue(required.issubset(names), f"Missing package entries: {required - names}")
        self.assertFalse(any(".backup." in name or "/__pycache__/" in name for name in names))

    def test_skins_contain_no_personal_names(self):
        skins = ROOT / "Skins"
        offenders = []
        for path in skins.rglob("*"):
            if path.suffix.lower() not in {".ini", ".inc", ".txt", ".lua"}:
                continue
            text = path.read_text(encoding="utf-8", errors="ignore")
            if "tawsif" in text.lower():
                offenders.append(str(path.relative_to(ROOT)))
        self.assertEqual(offenders, [], f"Personal names found in: {offenders}")

    def test_generic_settings_and_required_widgets(self):
        settings = (ROOT / "Skins/HackerSuite/@Resources/Settings.inc").read_text(encoding="utf-8")
        self.assertIn("UserName=Hacker", settings)
        self.assertIn("WeatherAuto=0", settings)
        self.assertIn("VSCodePath=", settings)
        self.assertIn("PortfolioURL=", settings)
        for widget in ("Clock", "Calendar", "Weather", "SystemStatus", "Network", "Terminal", "Quote", "Shortcuts", "ThemeCycler"):
            self.assertTrue((ROOT / f"Skins/HackerSuite/{widget}/{widget}.ini").is_file(), widget)

    def test_widgets_are_clickable_and_colours_are_customisable(self):
        skins = ROOT / "Skins/HackerSuite"
        self.assertTrue((skins / "@Resources/Themes/Custom.inc").is_file())
        self.assertTrue((skins / "@Resources/Scripts/PickColor.ps1").is_file())
        actions = (skins / "@Resources/Scripts/Actions.lua").read_text(encoding="utf-8")
        for function in ("ToggleUnits", "Copy", "ClearCustom"):
            self.assertIn(f"function {function}", actions)

        terminal = (skins / "Terminal/Terminal.ini").read_text(encoding="utf-8")
        for role in ("Accent", "Hover", "Dim", "Faint", "Secondary", "Warn", "Crit", "TextLight"):
            self.assertIn(f"[Sw{role}]", terminal)
            self.assertIn(f'-Role "{role}"', terminal)
        self.assertIn("PickColor.ps1", terminal)
        self.assertIn("ToolTipText", terminal)

        for widget in ("Clock", "Weather", "SystemStatus", "Network", "Terminal", "Quote", "Shortcuts", "ThemeCycler"):
            ini = (skins / f"{widget}/{widget}.ini").read_text(encoding="utf-8")
            self.assertIn("Themes\\Custom.inc", ini, widget)
            self.assertIn("LeftMouseUpAction", ini, widget)


if __name__ == "__main__":
    unittest.main()
