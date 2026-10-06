import unittest
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
from svgkit import Svg


class SvgLintTests(unittest.TestCase):
    def assert_lint_fails(self, svg: Svg, expected: str) -> None:
        errors = svg.lint("fixture")
        self.assertTrue(errors, "expected lint to fail")
        self.assertIn(expected, "\n".join(errors))

    def test_line_through_third_card_fails(self) -> None:
        svg = Svg(400, 200, "light", "test", "test")
        a = svg.card(20, 70, 80, 50, None, "A", "ok")
        b = svg.card(160, 60, 80, 70, None, "B", "ok")
        c = svg.card(300, 70, 80, 50, None, "C", "ok")
        svg.arrow([(100, 95), (300, 95)], source=a, target=c, label="through-b")
        self.assert_lint_fails(svg, "crosses card")

    def test_card_outside_panel_fails(self) -> None:
        svg = Svg(300, 200, "light", "test", "test")
        panel = svg.panel(30, 30, 160, 120, "Panel")
        svg.card(150, 70, 80, 50, None, "Outside", "ok", parent=panel)
        self.assert_lint_fails(svg, "is not fully inside panel")

    def test_legend_crossing_panel_fails(self) -> None:
        svg = Svg(300, 220, "light", "test", "test")
        svg.panel(40, 40, 160, 120, "Panel")
        svg.legend(100, 130, [("solid", "Requires"), ("dashed", "Recommended")])
        self.assert_lint_fails(svg, "crosses panel")

    def test_badge_over_text_fails(self) -> None:
        svg = Svg(300, 200, "light", "test", "test")
        svg.wrapped_text(80, 80, "Important text", 160, size=12, weight=700)
        svg.badge(88, 75, "1")
        self.assert_lint_fails(svg, "badge overlaps")

    def test_fixed_marker_over_text_fails(self) -> None:
        svg = Svg(300, 200, "light", "test", "test")
        svg.wrapped_text(80, 80, "Description text", 160, size=12)
        svg.fixed_marker(82, 70)
        self.assert_lint_fails(svg, "fixed marker overlaps")

    def test_text_exceeding_card_raises(self) -> None:
        svg = Svg(300, 200, "light", "test", "test")
        with self.assertRaises(ValueError):
            svg.card(20, 20, 90, 55, None, "Tiny card", "This text cannot possibly fit inside the card")

    def test_line_through_connected_card_fails(self) -> None:
        svg = Svg(300, 240, "light", "test", "test")
        a = svg.card(90, 70, 100, 70, None, "A", "ok")
        b = svg.card(90, 170, 100, 50, None, "B", "ok")
        svg.arrow([(140, 70), (140, 220)], source=a, target=b, label="through-source")
        self.assert_lint_fails(svg, "passes through connected card")

    def test_clean_fixture_passes(self) -> None:
        svg = Svg(400, 200, "light", "test", "test")
        panel = svg.panel(10, 10, 380, 160, "Panel")
        a = svg.card(40, 60, 100, 55, None, "A", "ok", parent=panel)
        b = svg.card(240, 60, 100, 55, None, "B", "ok", parent=panel)
        svg.arrow([(140, 87.5), (240, 87.5)], source=a, target=b, label="clean")
        self.assertEqual(svg.lint("fixture"), [])


if __name__ == "__main__":
    unittest.main()
