#!/usr/bin/env python3
"""Create placeholder directories referenced in build.properties bin.includes."""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SKIP = {"META-INF/", ".", "plugin.properties", "plugin_fr.properties", "plugin.xml"}


def parse_includes(text: str) -> list[str]:
    m = re.search(r"^bin\.includes\s*=\s*(.+)", text, re.M | re.S)
    if not m:
        return []
    raw = m.group(1)
    parts: list[str] = []
    for line in raw.splitlines():
        line = line.strip()
        if line.endswith("\\"):
            line = line[:-1].strip()
        line = line.strip(",").strip()
        if line:
            parts.append(line)
    return parts


def main() -> None:
    created: list[Path] = []
    for bp in ROOT.rglob("build.properties"):
        if "target" in bp.parts:
            continue
        for entry in parse_includes(bp.read_text()):
            if entry in SKIP or "=" in entry or entry.startswith("source.."):
                continue
            path = bp.parent / entry
            if entry.endswith("/"):
                if not path.exists():
                    path.mkdir(parents=True, exist_ok=True)
                    (path / ".gitkeep").touch()
                    created.append(path.relative_to(ROOT))
    print(f"Created {len(created)} directories")
    for p in created:
        print(f"  {p}")


if __name__ == "__main__":
    main()
