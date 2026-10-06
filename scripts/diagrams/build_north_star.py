"""Build the North Star architecture diagram in light and dark variants."""

from build_all import north_star
from svgkit import OUT, write_svg


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    for path in write_svg("north-star-architecture", 1000, 548, north_star):
        print(f"wrote {path.relative_to(OUT.parent.parent)} ({path.stat().st_size:,} bytes)")
