#!/usr/bin/env python3
"""Refresh frZone's committed live-rig authority mirror."""

from __future__ import annotations

import argparse
import filecmp
import shutil
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_LOCAL_MIRROR = REPO_ROOT / "atlas" / "live-rig.default.json"
DEFAULT_SIBLING_SNAPSHOT = REPO_ROOT.parent / "live-rig" / "interop" / "exports" / "live-rig.default.json"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Refresh or check frZone's committed live-rig authority mirror.")
    parser.add_argument("--mirror", type=Path, default=DEFAULT_LOCAL_MIRROR, help="Path to the committed local mirror.")
    parser.add_argument("--sibling", type=Path, default=DEFAULT_SIBLING_SNAPSHOT, help="Path to the sibling live-rig exported snapshot.")
    parser.add_argument("--check", action="store_true", help="Check whether the local mirror matches the sibling snapshot.")
    return parser.parse_args()


def ensure_exists(path: Path) -> None:
    if not path.exists():
        raise SystemExit(f"Missing file: {path}")


def main() -> int:
    args = parse_args()
    ensure_exists(args.sibling)

    if args.check:
      ensure_exists(args.mirror)
      if filecmp.cmp(args.mirror, args.sibling, shallow=False):
          print(f"PASS: {args.mirror} matches {args.sibling}")
          return 0
      print(f"FAIL: {args.mirror} differs from {args.sibling}")
      return 1

    args.mirror.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(args.sibling, args.mirror)
    print(f"Updated {args.mirror} from {args.sibling}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
