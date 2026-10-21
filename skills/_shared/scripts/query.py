#!/usr/bin/env python3
"""Read-only lookups that SKILL.md steps used to do with inline `python3 -c "..."`.

Inline `python3 -c "...(...)"` cannot be expressed by an exact/prefix tool allow-list
(parentheses and `*` are refused there), so each one became a subcommand here.
Every subcommand prints exactly what the inline line it replaces printed: the
values feed `--ar`, `--max-bytes` and the sidecar's `--provider` / `--model`, and
test-query.sh compares the old and new stdout byte for byte.

  slot   --platform P --archetype A [--field aspect|max_bytes [--first]]
         no --field: the whole slot as JSON (ensure_ascii=False)
  cost   --provider P --model M          prints the estimate, `None` when unknown
  limits [--provider P --model M]        prints max_images_per_run [and the estimate]
  json   --key K                         reads JSON from stdin
  json   --file F --key K
  json   --arg JSON (--key K | --results-id NN --keys k1,k2)
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import asset_lib as a  # noqa: E402


class QueryError(Exception):
    pass


def cmd_slot(args) -> None:
    slot = a.archetype_slot(a.load_platform(args.platform), args.archetype)
    if args.field is None:
        if args.first:
            raise QueryError("--first needs --field")
        print(json.dumps(slot, ensure_ascii=False))
        return
    if slot is None:
        raise QueryError(f"{args.platform} / {args.archetype} is unsupported; it has no {args.field}")
    value = slot[args.field]
    if args.first and isinstance(value, list):
        value = value[0]
    print(value)


def cmd_cost(args) -> None:
    print(a.estimate_cost(args.provider, args.model))


def cmd_limits(args) -> None:
    # Imported here: md2publish-diagram vendors query.py without config.py.
    import config

    limit = config.load_config()["max_images_per_run"]
    if args.provider is None and args.model is None:
        print(limit)
        return
    if args.provider is None or args.model is None:
        raise QueryError("--provider and --model go together")
    print(limit, a.estimate_cost(args.provider, args.model))


def cmd_json(args) -> None:
    sources = [s for s in (args.file, args.arg) if s is not None]
    if len(sources) > 1:
        raise QueryError("give at most one of --file / --arg (none means stdin)")
    if args.file is not None:
        with open(args.file) as fh:
            data = json.load(fh)
    elif args.arg is not None:
        data = json.loads(args.arg)
    else:
        data = json.load(sys.stdin)

    if args.results_id is not None:
        if args.keys is None or args.key is not None:
            raise QueryError("--results-id needs --keys (and no --key)")
        match = [r for r in data["results"] if str(r["id"]) == args.results_id]
        if not match:
            raise QueryError(f"no results entry with id {args.results_id!r}")
        print(*(match[0][k] for k in args.keys.split(",")))
        return
    if args.key is None or args.keys is not None:
        raise QueryError("give --key (or --results-id with --keys)")
    print(data[args.key])


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)

    s = sub.add_parser("slot")
    s.add_argument("--platform", required=True)
    s.add_argument("--archetype", required=True)
    s.add_argument("--field", choices=["aspect", "max_bytes"])
    s.add_argument("--first", action="store_true", help="a list value prints its first item")
    s.set_defaults(fn=cmd_slot)

    s = sub.add_parser("cost")
    s.add_argument("--provider", required=True)
    s.add_argument("--model", required=True)
    s.set_defaults(fn=cmd_cost)

    s = sub.add_parser("limits")
    s.add_argument("--provider")
    s.add_argument("--model")
    s.set_defaults(fn=cmd_limits)

    s = sub.add_parser("json")
    s.add_argument("--file")
    s.add_argument("--arg")
    s.add_argument("--key")
    s.add_argument("--results-id")
    s.add_argument("--keys")
    s.set_defaults(fn=cmd_json)

    args = ap.parse_args()
    try:
        args.fn(args)
    except (QueryError, a.AssetError) as e:
        print(str(e), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
