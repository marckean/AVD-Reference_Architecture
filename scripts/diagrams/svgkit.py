"""Small SVG drawing helpers for the AVD reference architecture diagrams.

The module intentionally uses the Python standard library only. It embeds official
Microsoft service icons unmodified, except for per-instance id prefixes so repeated
gradients and clip paths do not collide inside one SVG.
"""

from __future__ import annotations

from dataclasses import dataclass
from html import escape
from pathlib import Path
import re
from typing import Sequence


HERE = Path(__file__).resolve().parent
ICONS = HERE / "icons"
OUT = HERE.parent.parent / "docs" / "assets" / "images"

FONT = "'Segoe UI', 'Segoe UI Variable', system-ui, -apple-system, 'Helvetica Neue', Arial, sans-serif"

PALETTES = {
    "light": {
        "background": "#ffffff",
        "panel_ms": ("#eef4fb", "#c6dbf0"),
        "panel_sub": ("#f4f6f9", "#d3dbe4"),
        "panel_alt": ("#f8fbff", "#d8e5f3"),
        "card": ("#ffffff", "#cfd8e2"),
        "card_alt": ("#f9fbfd", "#d7e0ea"),
        "vnet": "#6f93bf",
        "title": "#0b2a4a",
        "text": "#3f4f60",
        "muted": "#68788a",
        "panel_title": "#0f548c",
        "line": "#0f6cbd",
        "line_soft": "#7faed8",
        "badge": "#0f6cbd",
        "badge_text": "#ffffff",
        "divider": "#dbe3ec",
        "fixed": "#8a4f00",
        "fixed_fill": "#fff4df",
        "requires": "#0f6cbd",
        "recommended": "#6f93bf",
        "danger": "#b42318",
        "success": "#107c10",
    },
    "dark": {
        "background": "#101826",
        "panel_ms": ("#132a45", "#2a4b70"),
        "panel_sub": ("#161f2c", "#2c3a4c"),
        "panel_alt": ("#121c2a", "#33465c"),
        "card": ("#1b2636", "#33465c"),
        "card_alt": ("#152232", "#314359"),
        "vnet": "#5d82ad",
        "title": "#e9eff6",
        "text": "#aab8c7",
        "muted": "#8ea0b4",
        "panel_title": "#7dbbf3",
        "line": "#4aa3f0",
        "line_soft": "#6d8fb5",
        "badge": "#4aa3f0",
        "badge_text": "#0b1724",
        "divider": "#2f4054",
        "fixed": "#f7c56b",
        "fixed_fill": "#3a2b12",
        "requires": "#4aa3f0",
        "recommended": "#7b93b2",
        "danger": "#ff8a7a",
        "success": "#7ee787",
    },
}


def scrub(s: str) -> str:
    """Replace long dash characters to satisfy the repository house style."""
    return s.translate(str.maketrans({"\u2014": "-", "\u2013": "-", "\u2012": "-", "\u2015": "-"}))


def approx_text_width(text: str, size: float = 12.0, weight: int = 400) -> float:
    """Approximate Segoe UI text width closely enough for card wrapping."""
    width = 0.0
    wide = set("MW@#%&QDGOB")
    narrow = set(".,:;!|'ijlI[]() ")
    for ch in text:
        if ch in narrow:
            width += 0.34
        elif ch in wide:
            width += 0.78
        elif ch.isupper():
            width += 0.60
        else:
            width += 0.49
    if weight >= 600:
        width *= 1.06
    return width * size


def wrap_text(text: str, max_width: float, size: float = 12.0, weight: int = 400) -> list[str]:
    words = scrub(text).split()
    lines: list[str] = []
    current: list[str] = []
    for word in words:
        trial = " ".join(current + [word])
        if current and approx_text_width(trial, size, weight) > max_width:
            lines.append(" ".join(current))
            current = [word]
        else:
            current.append(word)
    if current:
        lines.append(" ".join(current))
    return lines


@dataclass(frozen=True)
class Theme:
    mode: str
    colours: dict[str, object]

    @property
    def p(self) -> dict[str, object]:
        return self.colours


@dataclass
class Box:
    kind: str
    name: str
    x: float
    y: float
    w: float
    h: float
    parent: str | None = None

    @property
    def left(self) -> float:
        return self.x

    @property
    def right(self) -> float:
        return self.x + self.w

    @property
    def top(self) -> float:
        return self.y

    @property
    def bottom(self) -> float:
        return self.y + self.h

    def contains(self, other: "Box", pad: float = 0.0) -> bool:
        return (
            other.left >= self.left + pad
            and other.right <= self.right - pad
            and other.top >= self.top + pad
            and other.bottom <= self.bottom - pad
        )

    def overlaps(self, other: "Box", pad: float = 0.0) -> bool:
        return not (
            self.right <= other.left + pad
            or other.right <= self.left + pad
            or self.bottom <= other.top + pad
            or other.bottom <= self.top + pad
        )


@dataclass
class ArrowShape:
    points: list[tuple[float, float]]
    source: str | None
    target: str | None
    label: str


class Svg:
    def __init__(self, width: int, height: int, mode: str, title: str, desc: str):
        self.width = width
        self.height = height
        self.view_y = 0.0
        self.theme = Theme(mode, PALETTES[mode])
        self.p = self.theme.p
        self.title = scrub(title)
        self.desc = scrub(desc)
        self.parts: list[str] = []
        self._icon_counter = 0
        self._marker_ids = set()
        self.boxes: list[Box] = []
        self.text_boxes: list[Box] = []
        self.icon_boxes: list[Box] = []
        self.badge_boxes: list[Box] = []
        self.fixed_boxes: list[Box] = []
        self.arrows: list[ArrowShape] = []
        self._current_panel: str | None = None
        self._name_counter = 0
        self.lint_messages: list[str] = []

    def _name(self, prefix: str, label: str | None = None) -> str:
        self._name_counter += 1
        base = re.sub(r"[^a-z0-9]+", "-", (label or prefix).lower()).strip("-")[:36]
        return f"{prefix}-{self._name_counter}-{base or prefix}"

    def _record(self, box: Box) -> Box:
        self.boxes.append(box)
        return box

    def box_by_name(self, name: str | None) -> Box | None:
        if name is None:
            return None
        for box in self.boxes:
            if box.name == name:
                return box
        return None

    def add(self, s: str) -> None:
        self.parts.append(scrub(s))

    def rect(
        self,
        x: float,
        y: float,
        w: float,
        h: float,
        fill: str,
        stroke: str,
        rx: float = 10,
        dash: str | None = None,
        width: float = 1.2,
        opacity: float | None = None,
    ) -> None:
        d = f' stroke-dasharray="{dash}"' if dash else ""
        op = f' opacity="{opacity}"' if opacity is not None else ""
        self.add(
            f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{rx}" fill="{fill}" '
            f'stroke="{stroke}" stroke-width="{width}"{d}{op}/>'
        )

    def circle(self, cx: float, cy: float, r: float, fill: str, stroke: str | None = None, width: float = 1.0) -> None:
        s = f' stroke="{stroke}" stroke-width="{width}"' if stroke else ""
        self.add(f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="{fill}"{s}/>')

    def line(self, x1: float, y1: float, x2: float, y2: float, colour: str | None = None, dash: str | None = None, width: float = 1.4) -> None:
        d = f' stroke-dasharray="{dash}"' if dash else ""
        self.add(f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="{colour or self.p["line"]}" stroke-width="{width}"{d}/>')

    def text(
        self,
        x: float,
        y: float,
        text: str,
        size: float = 12,
        weight: int = 400,
        colour: str | None = None,
        anchor: str = "start",
        style: str = "",
    ) -> None:
        self.add(
            f'<text x="{x}" y="{y}" font-size="{size}" font-weight="{weight}" '
            f'fill="{colour or self.p["text"]}" text-anchor="{anchor}"{style}>{escape(scrub(text))}</text>'
        )

    def wrapped_text(
        self,
        x: float,
        y: float,
        text: str | Sequence[str],
        max_width: float,
        size: float = 12,
        weight: int = 400,
        colour: str | None = None,
        line_height: float | None = None,
        max_lines: int | None = None,
        anchor: str = "start",
    ) -> float:
        if isinstance(text, str):
            lines = wrap_text(text, max_width, size, weight)
        else:
            lines = []
            for item in text:
                lines.extend(wrap_text(item, max_width, size, weight))
        if max_lines is not None and len(lines) > max_lines:
            raise ValueError(f"Text does not fit: {text!r} wraps to {len(lines)} lines but max is {max_lines}")
        lh = line_height or size * 1.35
        for i, line in enumerate(lines):
            self.text(x, y + i * lh, line, size=size, weight=weight, colour=colour, anchor=anchor)
            width = approx_text_width(line, size, weight)
            tx = x - width / 2 if anchor == "middle" else x
            self.text_boxes.append(Box("text", f"text-{len(self.text_boxes)+1}", tx, y + i * lh - size, width, size * 1.2))
        return y + max(0, len(lines) - 1) * lh

    def icon(self, name: str, x: float, y: float, size: float) -> None:
        path = ICONS / f"{name}.svg"
        if not path.exists():
            self.neutral_icon(x, y, size, name)
            return
        src = path.read_text(encoding="utf-8")
        m = re.search(r"<svg[^>]*>", src, flags=re.S)
        root = m.group(0) if m else "<svg viewBox='0 0 18 18'>"
        viewbox = re.search(r'viewBox="([^"]+)"', root)
        vb = viewbox.group(1) if viewbox else "0 0 18 18"
        inner = re.sub(r"^.*?<svg[^>]*>", "", src, flags=re.S)
        inner = re.sub(r"</svg>\s*$", "", inner.strip())
        self._icon_counter += 1
        prefix = f"i{self._icon_counter}-"
        inner = re.sub(r'\bid="([^"]+)"', lambda m: f'id="{prefix}{m.group(1)}"', inner)
        inner = re.sub(r"url\(#([^)]+)\)", lambda m: f"url(#{prefix}{m.group(1)})", inner)
        inner = re.sub(r'(xlink:href|href)="#([^"]+)"', lambda m: f'{m.group(1)}="#{prefix}{m.group(2)}"', inner)
        self.add(f'<svg x="{x}" y="{y}" width="{size}" height="{size}" viewBox="{vb}">{inner}</svg>')
        self.icon_boxes.append(Box("icon", f"icon-{len(self.icon_boxes)+1}-{name}", x, y, size, size))

    def neutral_icon(self, x: float, y: float, size: float, label: str = "") -> None:
        self.rect(x, y, size, size, "none", str(self.p["line_soft"]), rx=6, width=1.4)
        self.line(x + size * 0.25, y + size * 0.5, x + size * 0.75, y + size * 0.5, colour=str(self.p["line_soft"]))
        if label:
            self.text(x + size / 2, y + size * 0.62, label[:2].upper(), size=size * 0.24, weight=700, colour=str(self.p["line_soft"]), anchor="middle")
        self.icon_boxes.append(Box("icon", f"icon-{len(self.icon_boxes)+1}-{label}", x, y, size, size))

    def panel(self, x: float, y: float, w: float, h: float, title: str, kind: str = "panel_sub", dashed: bool = False) -> str:
        fill, stroke = self.p[kind]
        self.rect(x, y, w, h, str(fill), str(stroke), rx=12, dash="7 5" if dashed else None)
        self.text(x + 16, y + 24, title, size=12.5, weight=700, colour=str(self.p["panel_title"]))
        self.text_boxes.append(Box("panel-title", f"panel-title-{len(self.text_boxes)+1}", x + 16, y + 24 - 12.5, approx_text_width(title, 12.5, 700), 15))
        name = self._name("panel", title)
        self._record(Box("panel", name, x, y, w, h))
        self._current_panel = name
        return name

    def card(
        self,
        x: float,
        y: float,
        w: float,
        h: float,
        icon: str | None,
        title: str,
        body: str | Sequence[str],
        number: int | None = None,
        fixed: bool = False,
        kind: str = "card",
        title_size: float = 13.5,
        body_size: float = 12,
        parent: str | None = None,
    ) -> str:
        fill, stroke = self.p[kind]
        extra_stroke = str(self.p["fixed"]) if fixed else str(stroke)
        self.rect(x, y, w, h, str(fill), extra_stroke, rx=8, width=1.2 if not fixed else 2)
        name = self._name("card", title)
        self._record(Box("card", name, x, y, w, h, parent))
        if number is not None:
            self.badge(x + 17, y + 18, str(number), r=10, size=11, role="card")
        if fixed:
            self.fixed_marker(x + w - 58, y + h - 26)
        tx = x + 14
        if icon:
            icon_x = x + 44 if number is not None else x + 14
            self.icon(icon, icon_x, y + 17, 34)
            tx = icon_x + 46
        if number is not None and not icon:
            tx += 17
        title_width = w - (tx - x) - 14
        title_lines = wrap_text(title, title_width, title_size, 700)
        self.wrapped_text(tx, y + 31, title, max_width=title_width, size=title_size, weight=700, colour=str(self.p["title"]), max_lines=2)
        top = y + 54 if len(title_lines) == 1 else y + 64
        body_x = tx
        body_width = w - (body_x - x) - 14
        max_body_lines = max(1, int((h - (top - y) - 4) / (body_size * 1.25)))
        self.wrapped_text(body_x, top, body, max_width=body_width, size=body_size, colour=str(self.p["text"]), line_height=body_size * 1.25, max_lines=max_body_lines)
        return name

    def badge(self, cx: float, cy: float, label: str, r: float = 11, size: float = 12.5, role: str = "flow") -> None:
        self.circle(cx, cy, r, str(self.p["badge"]))
        self.text(cx, cy + size * 0.36, label, size=size, weight=700, colour=str(self.p["badge_text"]), anchor="middle")
        self.badge_boxes.append(Box(f"{role}-badge", f"badge-{len(self.badge_boxes)+1}", cx - r, cy - r, r * 2, r * 2))

    def fixed_marker(self, x: float, y: float) -> None:
        self.rect(x, y, 44, 18, str(self.p["fixed_fill"]), str(self.p["fixed"]), rx=9, width=1)
        self.add(f'<path d="M{x+9},{y+9} h-2 v6 h8 v-6 h-2 v-3 a2,2 0 0 0 -4,0 z" fill="none" stroke="{self.p["fixed"]}" stroke-width="1"/>')
        self.text(x + 29, y + 13, "fixed", size=9, weight=700, colour=str(self.p["fixed"]), anchor="middle")
        self.fixed_boxes.append(Box("fixed-marker", f"fixed-{len(self.fixed_boxes)+1}", x, y, 44, 18))

    def marker(self, marker_id: str, colour: str) -> str:
        if marker_id not in self._marker_ids:
            self._marker_ids.add(marker_id)
        return marker_id

    def path(self, d: str, colour: str | None = None, width: float = 1.7, dash: str | None = None, head: bool = True) -> None:
        colour = colour or str(self.p["line"])
        marker_id = "arrow-dashed" if dash else "arrow"
        marker = f' marker-end="url(#{marker_id})"' if head else ""
        d_attr = f' stroke-dasharray="{dash}"' if dash else ""
        self.add(f'<path d="{d}" fill="none" stroke="{colour}" stroke-width="{width}" stroke-linejoin="round" stroke-linecap="round"{d_attr}{marker}/>')

    def arrow(
        self,
        points: Sequence[tuple[float, float]],
        dashed: bool = False,
        colour: str | None = None,
        width: float = 1.7,
        head: bool = True,
        source: str | None = None,
        target: str | None = None,
        label: str = "",
    ) -> None:
        if not points:
            return
        d = f"M{points[0][0]},{points[0][1]}"
        for x, y in points[1:]:
            d += f" L{x},{y}"
        self.path(d, colour=colour, width=width, dash="6 5" if dashed else None, head=head)
        self.arrows.append(ArrowShape(list(points), source, target, label))

    def label(self, x: float, y: float, text: str, width: float = 120, size: float = 11, fill_key: str = "card") -> None:
        lines = wrap_text(text, width - 16, size, 600)
        h = 10 + len(lines) * size * 1.25
        fill, stroke = self.p[fill_key]
        self.rect(x, y, width, h, str(fill), str(stroke), rx=8, width=1)
        self.boxes.append(Box("label", self._name("label", text), x, y, width, h))
        self.wrapped_text(x + 8, y + 15, text, width - 16, size=size, weight=600, colour=str(self.p["title"]))

    def legend(self, x: float, y: float, items: Sequence[tuple[str, str]]) -> None:
        w = 260
        h = 20 + len(items) * 24
        fill, stroke = self.p["card_alt"]
        self.rect(x, y, w, h, str(fill), str(stroke), rx=8, width=1)
        self.boxes.append(Box("legend", self._name("legend", "legend"), x, y, w, h))
        self.text(x + 12, y + 20, "Legend", size=12, weight=700, colour=str(self.p["title"]))
        for i, (kind, text) in enumerate(items):
            yy = y + 42 + i * 24
            if kind == "solid":
                self.line(x + 14, yy - 4, x + 54, yy - 4, colour=str(self.p["requires"]), width=1.8)
            elif kind == "dashed":
                self.line(x + 14, yy - 4, x + 54, yy - 4, colour=str(self.p["recommended"]), dash="6 5", width=1.8)
            elif kind == "fixed":
                self.fixed_marker(x + 12, yy - 17)
            self.text(x + 64, yy, text, size=11.5, colour=str(self.p["text"]))

    def edge_point(self, name: str, side: str, offset: float = 0.5) -> tuple[float, float]:
        box = self.box_by_name(name)
        if box is None:
            raise ValueError(f"Unknown box {name}")
        if side == "left":
            return (box.left, box.top + box.h * offset)
        if side == "right":
            return (box.right, box.top + box.h * offset)
        if side == "top":
            return (box.left + box.w * offset, box.top)
        if side == "bottom":
            return (box.left + box.w * offset, box.bottom)
        raise ValueError(f"Unknown side {side}")

    def h_arrow(self, source: str, target: str, dashed: bool = False, colour: str | None = None, y: float | None = None, label: str = "") -> None:
        a = self.box_by_name(source)
        b = self.box_by_name(target)
        if a is None or b is None:
            raise ValueError("Unknown source or target")
        if a.right <= b.left:
            start = (a.right, a.top + a.h / 2)
            end = (b.left, b.top + b.h / 2)
        elif b.right <= a.left:
            start = (a.left, a.top + a.h / 2)
            end = (b.right, b.top + b.h / 2)
        else:
            start = (a.left + a.w / 2, a.bottom)
            end = (b.left + b.w / 2, b.top)
        if y is None:
            self.arrow([start, end], dashed=dashed, colour=colour, source=source, target=target, label=label)
        else:
            self.arrow([start, (start[0], y), (end[0], y), end], dashed=dashed, colour=colour, source=source, target=target, label=label)

    def header_defs(self) -> str:
        line = self.p["line"]
        rec = self.p["recommended"]
        return (
            "<defs>"
            f'<marker id="arrow" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse"><path d="M0,0 L10,5 L0,10 z" fill="{line}"/></marker>'
            f'<marker id="arrow-dashed" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse"><path d="M0,0 L10,5 L0,10 z" fill="{rec}"/></marker>'
            "</defs>"
        )

    def render(self) -> str:
        head = (
            f'<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" '
            f'viewBox="0 {self.view_y:g} {self.width} {self.height}" width="{self.width}" height="{self.height}" '
            f'font-family="{FONT}" role="img" aria-labelledby="t d">'
            f'<title id="t">{escape(self.title)}</title>'
            f'<desc id="d">{escape(self.desc)}</desc>'
            f'{self.header_defs()}'
        )
        return head + "".join(self.parts) + "</svg>\n"

    def fit_to_content(self, margin: float = 35) -> None:
        all_boxes = self.boxes + self.text_boxes + self.icon_boxes + self.badge_boxes + self.fixed_boxes
        bottoms = [box.bottom for box in all_boxes]
        tops = [box.top for box in all_boxes]
        if bottoms and tops:
            self.view_y = min(0.0, min(tops) - margin) if min(tops) < margin else max(0.0, min(tops) - margin)
            self.height = int(max(bottoms) - self.view_y + margin)

    def lint(self, diagram_name: str) -> list[str]:
        errors: list[str] = []
        cards = [b for b in self.boxes if b.kind == "card"]
        panels = [b for b in self.boxes if b.kind == "panel"]
        for i, a in enumerate(cards):
            for b in cards[i + 1 :]:
                if a.overlaps(b, pad=0.5):
                    errors.append(f"{diagram_name}: cards overlap: {a.name} and {b.name}")
        for card in cards:
            if card.parent:
                panel = self.box_by_name(card.parent)
                if panel and not panel.contains(card, pad=0):
                    errors.append(f"{diagram_name}: card {card.name} is not fully inside panel {panel.name}")
        for badge in self.badge_boxes:
            if badge.kind == "card-badge":
                others = self.icon_boxes + self.text_boxes
            else:
                others = self.text_boxes + self.icon_boxes
            for other in others:
                if badge.overlaps(other, pad=-1):
                    errors.append(f"{diagram_name}: badge overlaps {other.kind}: {badge.name}")
        for fixed in self.fixed_boxes:
            for other in self.text_boxes + self.icon_boxes:
                if fixed.overlaps(other, pad=-1):
                    errors.append(f"{diagram_name}: fixed marker overlaps {other.kind}: {fixed.name}")
        for obstacle in [b for b in self.boxes if b.kind in {"label", "legend"}]:
            for panel in panels:
                if obstacle.overlaps(panel) and not panel.contains(obstacle):
                    errors.append(f"{diagram_name}: {obstacle.kind} {obstacle.name} crosses panel {panel.name}")
            for title in [b for b in self.text_boxes if b.kind == "panel-title"]:
                if obstacle.overlaps(title, pad=-1):
                    errors.append(f"{diagram_name}: {obstacle.kind} {obstacle.name} overlaps panel title {title.name}")
        for arrow in self.arrows:
            if len(arrow.points) < 2:
                continue
            start = arrow.points[0]
            end = arrow.points[-1]
            for point, role, endpoint_name in [(start, "source", arrow.source), (end, "target", arrow.target)]:
                if endpoint_name is None:
                    continue
                box = self.box_by_name(endpoint_name)
                if box is None:
                    errors.append(f"{diagram_name}: arrow {arrow.label} has unknown {role} {endpoint_name}")
                    continue
                if not _point_on_edge(point, box):
                    errors.append(f"{diagram_name}: arrow {arrow.label or endpoint_name} {role} endpoint is not on edge of {endpoint_name}: {point}")
            for p1, p2 in zip(arrow.points, arrow.points[1:]):
                if p1[0] != p2[0] and p1[1] != p2[1]:
                    errors.append(f"{diagram_name}: arrow {arrow.label} has non-orthogonal segment {p1}->{p2}")
                    continue
                obstacles = cards + [b for b in self.boxes if b.kind in {"label", "legend"}] + [b for b in self.text_boxes if b.kind == "panel-title"]
                for card in obstacles:
                    if card.name in {arrow.source, arrow.target}:
                        continue
                    if _segment_intersects_box(p1, p2, card):
                        errors.append(f"{diagram_name}: arrow {arrow.label} crosses card {card.name}")
                for endpoint_name in {arrow.source, arrow.target}:
                    box = self.box_by_name(endpoint_name)
                    if box and _segment_intersects_box(p1, p2, box):
                        errors.append(f"{diagram_name}: arrow {arrow.label} passes through connected card {box.name}")
        return errors


def _point_on_edge(point: tuple[float, float], box: Box, tol: float = 1.0) -> bool:
    x, y = point
    on_vertical = (abs(x - box.left) <= tol or abs(x - box.right) <= tol) and box.top - tol <= y <= box.bottom + tol
    on_horizontal = (abs(y - box.top) <= tol or abs(y - box.bottom) <= tol) and box.left - tol <= x <= box.right + tol
    return on_vertical or on_horizontal


def _segment_intersects_box(p1: tuple[float, float], p2: tuple[float, float], box: Box, tol: float = 0.1) -> bool:
    x1, y1 = p1
    x2, y2 = p2
    if y1 == y2:
        y = y1
        if box.top + tol < y < box.bottom - tol:
            lo, hi = sorted((x1, x2))
            return max(lo, box.left + tol) < min(hi, box.right - tol)
    if x1 == x2:
        x = x1
        if box.left + tol < x < box.right - tol:
            lo, hi = sorted((y1, y2))
            return max(lo, box.top + tol) < min(hi, box.bottom - tol)
    return False


def write_svg(name: str, width: int, height: int, draw) -> list[Path]:
    OUT.mkdir(parents=True, exist_ok=True)
    paths = []
    for mode in ("light", "dark"):
        svg = draw(mode)
        path = OUT / f"{name}-{mode}.svg"
        text = svg.render()
        path.write_text(scrub(text), encoding="utf-8", newline="\n")
        paths.append(path)
    return paths
