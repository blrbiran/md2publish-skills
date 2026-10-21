#!/usr/bin/env python3
"""Print the final cover path recorded in a md2publish-cover sidecar.

Usage: cover_path.py <sidecar.json>

The sidecar's `image` field is the final file name (`.png`, or `.jpg` when it was
compressed); it resolves next to the sidecar. Replaces an inline `python3 -c`
in SKILL.md step 2 with the same output bytes.
"""

import json
import pathlib
import sys


def main() -> int:
    if len(sys.argv) != 2:
        print(__doc__.strip(), file=sys.stderr)
        return 2
    p = pathlib.Path(sys.argv[1])
    print(p.parent / json.load(p.open())["image"])
    return 0


if __name__ == "__main__":
    sys.exit(main())
