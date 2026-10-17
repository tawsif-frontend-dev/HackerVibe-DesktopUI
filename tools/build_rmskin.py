#!/usr/bin/env python3
"""Build a double-click-installable HackerSuite.rmskin (default settings, no name prompts)."""
import argparse
import os, zipfile
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--output", default=os.path.join(ROOT, "HackerSuite.rmskin"))
out = os.path.abspath(parser.parse_args().output)
ini = """[rmskin]
Name=Hacker Desktop Suite
Author=Tawsif
Version=3.0.0
LoadType=Skin
Load=HackerSuite\\Clock\\Clock.ini
MinimumRainmeter=4.4.0
MinimumWindows=10.0
"""
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
    z.writestr("RMSKIN.ini", ini)
    z.write(os.path.join(ROOT, "LICENSE"), "LICENSE.txt")
    base = os.path.join(ROOT, "Skins")
    excluded_dirs = {".git", "__pycache__", ".pytest_cache"}
    for d, dirs, files in os.walk(base):
        dirs[:] = sorted(name for name in dirs if name not in excluded_dirs)
        for f in sorted(files):
            if f.startswith(".") or f.endswith((".pyc", ".tmp", ".bak")) or ".backup." in f:
                continue
            p = os.path.join(d, f)
            z.write(p, os.path.relpath(p, ROOT).replace(os.sep, "/"))
print("built", out, os.path.getsize(out) // 1024, "KB")
