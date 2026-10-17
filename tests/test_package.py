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
            "Skins/HackerSuite/@Resources/Wallpaper/Base/Hacker_Wallpaper_Green_1920x1080.png",
        }
        self.assertTrue(required.issubset(names), f"Missing package entries: {required - names}")
        self.assertFalse(any(".backup." in name or "/__pycache__/" in name for name in names))


if __name__ == "__main__":
    unittest.main()
