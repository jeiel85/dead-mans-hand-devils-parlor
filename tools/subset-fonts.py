#!/usr/bin/env python3
"""Subset the bundled fonts to the characters the game can actually draw.

The Godot client renders only its own strings: everything in i18n.gd plus the
digits and symbols the code formats numbers with. Shipping the full KS X 1001
set costs about 2.7 MB in the .pck for glyphs that never appear.

The serif face is subset to that exact set. The sans face keeps the full KS X
1001 range on purpose: it renders the seed input, which is free-form text a
player can type in Korean, and a missing glyph there would be a visible box.

Run after changing strings, then re-run the Godot tests: _test_font_coverage()
in godot/test/test_runner.gd fails if a string needs a glyph that was dropped.

    python tools/subset-fonts.py --source <dir with the full TTFs>

Without --source it re-subsets the fonts already in godot/assets/fonts (safe:
subsetting a subset is idempotent for characters that survive).
"""
from __future__ import annotations

import argparse
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
FONT_DIR = ROOT / "godot" / "assets" / "fonts"
I18N = ROOT / "godot" / "scripts" / "core" / "i18n.gd"

# Symbols and letters that reach draw_string from code rather than from a string
# table (number formats, rank letters, the language toggle, the brand line).
EXTRA = (
    "0123456789/×·%-+.,:()'\"?!→ "
    "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    "abcdefghijklmnopqrstuvwxyz"
)

STRING_LITERAL = re.compile(r'"((?:[^"\\]|\\.)*)"')


def wanted_chars() -> set[str]:
    """Every character in i18n.gd's string literals, plus EXTRA."""
    text = I18N.read_text(encoding="utf-8")
    chars: set[str] = set(EXTRA)
    for match in STRING_LITERAL.finditer(text):
        chars.update(match.group(1))
    # Drop control characters and the escape backslashes the regex kept.
    return {c for c in chars if ord(c) >= 0x20}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=pathlib.Path, default=FONT_DIR,
                        help="directory holding the full-size TTFs")
    args = parser.parse_args()

    try:
        from fontTools import subset
    except ImportError:
        print("fontTools is required: python -m pip install fonttools", file=sys.stderr)
        return 1

    chars = wanted_chars()
    unicodes = sorted(ord(c) for c in chars)
    print(f"glyph set: {len(unicodes)} characters "
          f"({sum(1 for u in unicodes if 0xAC00 <= u <= 0xD7A3)} hangul syllables)")

    # Only the serif face is narrowed; see the module docstring for why sans is not.
    name = "NanumMyeongjo-Bold.ttf"
    src = args.source / name
    dst = FONT_DIR / name
    if not src.exists():
        print(f"missing source font: {src}", file=sys.stderr)
        return 1

    before = src.stat().st_size
    options = subset.Options()
    options.layout_features = ["*"]
    options.name_IDs = ["*"]
    options.notdef_outline = True
    options.recalc_bounds = True
    font = subset.load_font(str(src), options)
    subsetter = subset.Subsetter(options=options)
    subsetter.populate(unicodes=unicodes)
    subsetter.subset(font)
    tmp = dst.with_suffix(".ttf.tmp")
    subset.save_font(font, str(tmp), options)
    font.close()
    tmp.replace(dst)
    after = dst.stat().st_size
    print(f"{name}: {before:,} -> {after:,} bytes "
          f"({100 * (before - after) / before:.0f}% smaller)")
    print("now run: godot --headless --path godot res://test/test_runner.tscn")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
