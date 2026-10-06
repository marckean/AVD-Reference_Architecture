"""House style checks for the documentation.

Fails the build if any Markdown or YAML file contains an em dash or en dash.
The site uses plain hyphens only.
"""

import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
BANNED = {
    "\u2014": "em dash",
    "\u2013": "en dash",
    "\u2012": "figure dash",
    "\u2015": "horizontal bar",
}

files = list(ROOT.joinpath("docs").rglob("*.md"))
files += list(ROOT.joinpath("includes").rglob("*.md"))
files += [ROOT / "mkdocs.yml", ROOT / "README.md"]

problems = []
for path in files:
    if not path.exists():
        continue
    for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        for char, name in BANNED.items():
            if char in line:
                problems.append(f"{path.relative_to(ROOT)}:{number}: {name} found - use a plain hyphen")

if problems:
    print("\n".join(problems))
    sys.exit(1)

print("House style check passed: no em or en dashes.")
