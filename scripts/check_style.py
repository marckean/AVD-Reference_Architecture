"""House style checks for the repository.

Fails the build if any text file contains an em dash, en dash, figure dash or horizontal bar.
The repository uses plain hyphens only. Third-party icon files are skipped.
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
EXTENSIONS = {
    ".md", ".yml", ".yaml", ".json", ".bicep", ".bicepparam", ".ps1", ".psm1", ".psd1",
    ".py", ".js", ".css", ".html", ".svg", ".xml", ".csv", ".txt",
}
SKIP_DIRS = {".git", "site", "node_modules", "__pycache__", ".cache", ".venv", "venv"}
SKIP_PATHS = {ROOT / "scripts" / "diagrams" / "icons"}


def candidate_files():
    for path in ROOT.rglob("*"):
        if not path.is_file() or path.suffix.lower() not in EXTENSIONS:
            continue
        if any(part in SKIP_DIRS for part in path.relative_to(ROOT).parts):
            continue
        if any(skip in path.parents for skip in SKIP_PATHS):
            continue
        yield path


problems = []
checked = 0
for path in sorted(candidate_files()):
    checked += 1
    try:
        text = path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        text = path.read_text(encoding="utf-8-sig", errors="replace")
    for number, line in enumerate(text.splitlines(), start=1):
        for char, name in BANNED.items():
            if char in line:
                problems.append(f"{path.relative_to(ROOT)}:{number}: {name} found - use a plain hyphen")

if problems:
    print("\n".join(problems))
    sys.exit(1)

print(f"House style check passed: no em or en dashes in {checked} files.")
