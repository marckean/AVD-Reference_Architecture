"""Build the North Star architecture diagram as two SVGs, one for light mode and one for dark mode.

    python scripts/diagrams/build_north_star.py

Writes docs/assets/images/north-star-architecture-light.svg and -dark.svg. The pages embed
both with Material's #only-light and #only-dark suffixes, so the diagram follows the theme.

Icons come from the official Azure architecture icons and Microsoft Entra architecture icons,
which Microsoft permits in architectural diagrams and documentation. They're embedded unaltered
apart from a per-instance prefix on their internal gradient ids.
"""

import re
from pathlib import Path

HERE = Path(__file__).resolve().parent
ICONS = HERE / "icons"
OUT = HERE.parent.parent / "docs" / "assets" / "images"

W, H = 1000, 548
FONT = "'Segoe UI', 'Segoe UI Variable', system-ui, -apple-system, 'Helvetica Neue', Arial, sans-serif"

PALETTES = {
    "light": {
        "panel_ms": ("#eef4fb", "#c6dbf0"),
        "panel_sub": ("#f4f6f9", "#d3dbe4"),
        "card": ("#ffffff", "#cfd8e2"),
        "vnet": "#6f93bf",
        "title": "#0b2a4a",
        "text": "#3f4f60",
        "panel_title": "#0f548c",
        "line": "#0f6cbd",
        "badge": "#0f6cbd",
        "badge_text": "#ffffff",
        "divider": "#dbe3ec",
    },
    "dark": {
        "panel_ms": ("#132a45", "#2a4b70"),
        "panel_sub": ("#161f2c", "#2c3a4c"),
        "card": ("#1b2636", "#33465c"),
        "vnet": "#5d82ad",
        "title": "#e9eff6",
        "text": "#aab8c7",
        "panel_title": "#7dbbf3",
        "line": "#4aa3f0",
        "badge": "#4aa3f0",
        "badge_text": "#0b1724",
        "divider": "#2f4054",
    },
}


class Svg:
    def __init__(self, palette):
        self.p = palette
        self.parts = []
        self.n = 0

    def add(self, s):
        self.parts.append(s)

    def rect(self, x, y, w, h, fill, stroke, rx=10, dash=None, width=1.2):
        d = f' stroke-dasharray="{dash}"' if dash else ""
        self.add(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{rx}" fill="{fill}" stroke="{stroke}" stroke-width="{width}"{d}/>')

    def text(self, x, y, s, size=12, weight=400, color=None, anchor="start"):
        color = color or self.p["text"]
        s = s.replace("&", "&amp;").replace("<", "&lt;")
        self.add(f'<text x="{x}" y="{y}" font-size="{size}" font-weight="{weight}" fill="{color}" text-anchor="{anchor}">{s}</text>')

    def icon(self, name, x, y, size):
        src = (ICONS / f"{name}.svg").read_text(encoding="utf-8")
        inner = re.sub(r"^.*?<svg[^>]*>", "", src, flags=re.S)
        inner = re.sub(r"</svg>\s*$", "", inner.strip())
        self.n += 1
        prefix = f"i{self.n}-"
        inner = re.sub(r'\bid="([^"]+)"', lambda m: f'id="{prefix}{m.group(1)}"', inner)
        inner = re.sub(r"url\(#([^)]+)\)", lambda m: f"url(#{prefix}{m.group(1)})", inner)
        inner = re.sub(r'(xlink:href|href)="#([^"]+)"', lambda m: f'{m.group(1)}="#{prefix}{m.group(2)}"', inner)
        self.add(f'<svg x="{x}" y="{y}" width="{size}" height="{size}" viewBox="0 0 18 18">{inner}</svg>')

    def arrow(self, d, head=True):
        m = ' marker-end="url(#arrow)"' if head else ""
        self.add(f'<path d="{d}" fill="none" stroke="{self.p["line"]}" stroke-width="1.7" stroke-linejoin="round"{m}/>')

    def badge(self, cx, cy, label):
        self.add(f'<circle cx="{cx}" cy="{cy}" r="11" fill="{self.p["badge"]}"/>')
        self.text(cx, cy + 4.5, label, size=12.5, weight=700, color=self.p["badge_text"], anchor="middle")

    def card(self, x, y, w, h, icon, title, lines, icon_size=38, title_size=14):
        self.rect(x, y, w, h, *self.p["card"], rx=8, width=1)
        self.icon(icon, x + 14, y + 18, icon_size)
        tx = x + 14 + icon_size + 12
        self.text(tx, y + 32, title, size=title_size, weight=600, color=self.p["title"])
        for i, line in enumerate(lines):
            self.text(tx, y + 52 + i * 16, line)


def build(mode):
    p = PALETTES[mode]
    s = Svg(p)

    # Users
    s.icon("users", 52, 192, 52)
    s.text(78, 270, "Users", size=14, weight=600, color=p["title"], anchor="middle")
    s.text(78, 288, "Windows App or", anchor="middle")
    s.text(78, 304, "web browser", anchor="middle")

    # Microsoft-managed services
    s.rect(168, 24, 318, 504, *p["panel_ms"], rx=12)
    s.text(184, 48, "Microsoft-managed services", size=12.5, weight=700, color=p["panel_title"])
    s.card(186, 66, 282, 92, "entra-id", "Microsoft Entra ID", ["Sign-in, Conditional Access", "and single sign-on"])
    s.rect(186, 180, 282, 178, *p["card"], rx=8, width=1)
    s.icon("avd", 200, 198, 38)
    s.text(250, 212, "Azure Virtual Desktop", size=14, weight=600, color=p["title"])
    s.text(250, 232, "Workspace feed, gateway")
    s.text(250, 248, "and broker")
    s.add(f'<line x1="250" y1="266" x2="452" y2="266" stroke="{p["divider"]}" stroke-width="1"/>')
    s.text(250, 288, "Session host configuration,")
    s.text(250, 304, "session host update and")
    s.text(250, 320, "autoscale")
    s.card(186, 380, 282, 92, "intune", "Microsoft Intune", ["Device and user policy from", "the settings catalog"])

    # Your Azure subscription
    s.rect(516, 24, 468, 504, *p["panel_sub"], rx=12)
    s.text(532, 48, "Your Azure subscription", size=12.5, weight=700, color=p["panel_title"])
    s.rect(534, 62, 432, 240, "none", p["vnet"], rx=8, dash="6 4", width=1.3)
    s.icon("vnet", 548, 70, 18)
    s.text(572, 84, "Spoke virtual network", size=12, weight=600, color=p["title"])

    s.rect(552, 98, 236, 188, *p["card"], rx=8, width=1)
    s.icon("host-pools", 566, 112, 36)
    s.text(612, 126, "Pooled host pool", size=14, weight=600, color=p["title"])
    s.text(612, 144, "Windows 11 Enterprise")
    s.text(612, 160, "multi-session")
    for i in range(3):
        s.icon("vm", 605 + i * 48, 176, 34)
    s.text(670, 236, "Microsoft Entra joined session", anchor="middle")
    s.text(670, 252, "hosts on ephemeral OS disks", anchor="middle")

    s.rect(826, 156, 124, 72, *p["card"], rx=8, width=1)
    s.icon("private-endpoint", 873, 164, 30)
    s.text(888, 214, "Private endpoint", size=12, anchor="middle")

    s.card(534, 330, 214, 94, "gallery", "Azure Compute Gallery", ["Image versions built by", "Azure Image Builder"], icon_size=34, title_size=13)
    s.card(770, 330, 196, 94, "files", "Azure Files", ["FSLogix profiles and", "App Attach packages"], icon_size=34, title_size=13)
    s.rect(534, 446, 432, 66, *p["card"], rx=8, width=1)
    s.icon("monitor", 548, 462, 34)
    s.text(594, 476, "Azure Monitor and Log Analytics", size=13, weight=600, color=p["title"])
    s.text(594, 495, "Diagnostics, performance data, AVD Insights and alerts")

    # Flows, numbered to match the list under the diagram
    s.arrow("M110,214 H140 V112 H183")          # 1 sign in
    s.arrow("M110,240 H183")                    # 2 connect
    s.arrow("M550,140 H500 V222 H471")          # 3 reverse connect
    s.arrow("M788,192 H823")                    # 4 profiles and apps, via the private endpoint
    s.arrow("M888,228 V327")
    s.arrow("M468,300 H510 V250 H549")          # 5 create, update, delete
    s.arrow("M640,330 V289")                    # 6 image version
    s.arrow("M468,426 H524 V272 H549")          # 7 policy
    s.arrow("M760,286 V443")                    # 8 logs and metrics
    for cx, cy, n in [(140, 166, 1), (152, 240, 2), (500, 182, 3), (888, 268, 4),
                      (510, 284, 5), (640, 316, 6), (524, 372, 7), (760, 316, 8)]:
        s.badge(cx, cy, str(n))

    head = (
        f'<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" '
        f'viewBox="0 0 {W} {H}" width="{W}" height="{H}" font-family="{FONT}" role="img" '
        f'aria-labelledby="t d">'
        '<title id="t">Azure Virtual Desktop North Star architecture</title>'
        '<desc id="d">Users sign in with Microsoft Entra ID and connect through Azure Virtual Desktop. '
        'A pooled host pool of Microsoft Entra joined session hosts on ephemeral OS disks reverse connects '
        'to the service, is created and updated by session host configuration and autoscale, uses images '
        'from Azure Compute Gallery and policy from Microsoft Intune, reads profiles and App Attach packages '
        'from Azure Files over a private endpoint, and sends telemetry to Azure Monitor.</desc>'
        f'<defs><marker id="arrow" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" '
        f'orient="auto-start-reverse"><path d="M0,0 L10,5 L0,10 z" fill="{p["line"]}"/></marker></defs>'
    )
    return head + "".join(s.parts) + "</svg>\n"


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    for mode in PALETTES:
        path = OUT / f"north-star-architecture-{mode}.svg"
        path.write_text(build(mode), encoding="utf-8", newline="\n")
        print(f"wrote {path.relative_to(HERE.parent.parent)} ({path.stat().st_size:,} bytes)")
