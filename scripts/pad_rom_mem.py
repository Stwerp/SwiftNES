#!/usr/bin/env python3
"""pad_rom_mem.py

Normalizes a Yosys/Verilog $readmemh init file for a small ROM.

- Accepts hex tokens (whitespace-separated), optionally one per line.
- Ignores blank lines and lines starting with '#' or '//'.
- Validates values fit within the given nibble width.
- Pads with zeros up to the requested depth.

Default is tailored for SwiftNES: 1024 x 4-bit.
"""

from __future__ import annotations

import argparse
from pathlib import Path
import sys


def _parse_tokens(text: str, width_bits: int, src: Path) -> list[int]:
    max_val = (1 << width_bits) - 1
    tokens: list[int] = []

    for raw in text.splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or line.startswith("//"):
            continue
        for tok in line.split():
            try:
                val = int(tok, 16)
            except ValueError as e:
                raise SystemExit(
                    f"Invalid hex token in {src}: {tok!r} (line: {raw!r})"
                ) from e
            if not (0 <= val <= max_val):
                raise SystemExit(
                    f"Token out of range for {width_bits}-bit ROM in {src}: {tok!r}"
                )
            tokens.append(val)

    return tokens


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Pad/validate a ROM .mem file")
    parser.add_argument("--in", dest="input", required=True, help="Input .mem path")
    parser.add_argument("--out", dest="output", required=True, help="Output .mem path")
    parser.add_argument("--depth", type=int, default=1024, help="Number of words")
    parser.add_argument("--width", type=int, default=4, help="Word width in bits")
    parser.add_argument(
        "--pad",
        choices=["zero"],
        default="zero",
        help="Padding policy if input is short",
    )

    args = parser.parse_args(argv)

    src = Path(args.input)
    dst = Path(args.output)

    if args.depth <= 0:
        raise SystemExit("depth must be > 0")
    if args.width <= 0:
        raise SystemExit("width must be > 0")

    tokens = _parse_tokens(src.read_text(encoding="utf-8"), args.width, src)

    if len(tokens) > args.depth:
        raise SystemExit(
            f"ROM init has {len(tokens)} entries, exceeds depth {args.depth}: {src}"
        )
    if len(tokens) < args.depth:
        missing = args.depth - len(tokens)
        print(
            f"WARN: ROM init short ({len(tokens)}/{args.depth}); padding {missing} zeros",
            file=sys.stderr,
        )
        tokens.extend([0] * missing)

    dst.parent.mkdir(parents=True, exist_ok=True)

    # Use lowercase hex, one token per line (matches existing file style).
    dst.write_text("\n".join(format(v, "x") for v in tokens) + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
