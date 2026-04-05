#!/usr/bin/env python3
"""Validate frZone's rig-tuned profile against the committed live-rig mirror."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_MIRROR = REPO_ROOT / "atlas" / "live-rig.default.json"
DEFAULT_SIBLING = REPO_ROOT.parent / "live-rig" / "interop" / "exports" / "live-rig.default.json"
DEFAULT_PROFILE = REPO_ROOT / "interop" / "frzone.rig.json"

EXPECTED_ANALYSIS_IDS = [
    "analysis.low_band",
    "analysis.mid_band",
    "analysis.upper_mid_band",
    "analysis.high_band",
]
EXPECTED_BINDINGS = [
    ("analysis.low_band", 0, 20, "/analysis/low_band"),
    ("analysis.mid_band", 2, 22, "/analysis/mid_band"),
    ("analysis.upper_mid_band", 3, 23, "/analysis/upper_mid_band"),
    ("analysis.high_band", 4, 24, "/analysis/high_band"),
]


def load_json(path: Path) -> Any:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise SystemExit(f"Missing file: {path}") from exc
    except json.JSONDecodeError as exc:
        raise SystemExit(f"Invalid JSON in {path}: {exc}") from exc


def get_repo_registry_entry(snapshot: dict[str, Any], repo_id: str) -> dict[str, Any] | None:
    for entry in snapshot.get("repoRegistry", []):
        if isinstance(entry, dict) and entry.get("id") == repo_id:
            return entry
    return None


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate frZone's rig-tuned alignment against the committed live-rig snapshot mirror.")
    parser.add_argument("--mirror", type=Path, default=DEFAULT_MIRROR, help="Path to the committed local live-rig snapshot mirror.")
    parser.add_argument("--profile", type=Path, default=DEFAULT_PROFILE, help="Path to frZone's rig-tuned profile.")
    parser.add_argument("--sibling", type=Path, default=DEFAULT_SIBLING, help="Optional sibling live-rig snapshot for drift checks.")
    args = parser.parse_args()

    snapshot = load_json(args.mirror)
    profile = load_json(args.profile)
    sibling = load_json(args.sibling) if args.sibling.exists() else None

    errors: list[str] = []
    checks: list[str] = []

    if sibling is not None and snapshot != sibling:
        errors.append(f"{args.mirror}: committed mirror differs from sibling {args.sibling}")
    elif sibling is not None:
        checks.append(f"{args.mirror}: committed mirror matches sibling authority snapshot")

    analysis_catalog = snapshot.get("semanticCatalog", {}).get("analysis", [])
    analysis_ids = [entry.get("id") for entry in analysis_catalog if isinstance(entry, dict)]
    if analysis_ids != EXPECTED_ANALYSIS_IDS:
        errors.append(f"{args.mirror}: semanticCatalog.analysis is {analysis_ids!r}, expected {EXPECTED_ANALYSIS_IDS!r}")
    else:
        checks.append(f"{args.mirror}: semantic analysis catalog matches canonical live-rig IDs")

    frzone_entry = get_repo_registry_entry(snapshot, "frZone")
    if frzone_entry is None:
        errors.append(f"{args.mirror}: missing repoRegistry entry for 'frZone'")
    else:
        if frzone_entry.get("role") != "analysis":
            errors.append(f"{args.mirror}: frZone role is {frzone_entry.get('role')!r}, expected 'analysis'")
        else:
            checks.append(f"{args.mirror}: frZone is registered as the analysis repo")

    if profile.get("profile") != "frzone":
        errors.append(f"{args.profile}: profile is {profile.get('profile')!r}, expected 'frzone'")
    if profile.get("authorityMirror") != "atlas/live-rig.default.json":
        errors.append(f"{args.profile}: authorityMirror is {profile.get('authorityMirror')!r}, expected 'atlas/live-rig.default.json'")

    runtime = profile.get("runtime", {})
    midi_runtime = runtime.get("midi", {})
    osc_runtime = runtime.get("osc", {})
    if runtime.get("rigTunedMode") is not True:
        errors.append(f"{args.profile}: runtime.rigTunedMode must be true")
    if midi_runtime.get("channel") != 15:
        errors.append(f"{args.profile}: runtime.midi.channel is {midi_runtime.get('channel')!r}, expected 15")
    if midi_runtime.get("sendNotes") is not False:
        errors.append(f"{args.profile}: runtime.midi.sendNotes must be false")
    if midi_runtime.get("sendCCs") is not True:
        errors.append(f"{args.profile}: runtime.midi.sendCCs must be true")
    if osc_runtime.get("host") != "127.0.0.1":
        errors.append(f"{args.profile}: runtime.osc.host is {osc_runtime.get('host')!r}, expected '127.0.0.1'")
    if osc_runtime.get("outPort") != 8000:
        errors.append(f"{args.profile}: runtime.osc.outPort is {osc_runtime.get('outPort')!r}, expected 8000")
    if osc_runtime.get("inPort") != 8001:
        errors.append(f"{args.profile}: runtime.osc.inPort is {osc_runtime.get('inPort')!r}, expected 8001")

    lane = profile.get("analysisLane", {})
    semantic_bands = lane.get("semanticBands", [])
    if len(semantic_bands) != len(EXPECTED_BINDINGS):
        errors.append(f"{args.profile}: analysisLane.semanticBands has {len(semantic_bands)} entries, expected {len(EXPECTED_BINDINGS)}")
    else:
        for entry, expected in zip(semantic_bands, EXPECTED_BINDINGS):
            semantic_id, source_index, cc, osc_address = expected
            scope = f"{args.profile}:{semantic_id}"
            if entry.get("semanticId") != semantic_id:
                errors.append(f"{scope}: semanticId is {entry.get('semanticId')!r}, expected {semantic_id!r}")
            if entry.get("sourceBandIndex") != source_index:
                errors.append(f"{scope}: sourceBandIndex is {entry.get('sourceBandIndex')!r}, expected {source_index}")
            if entry.get("cc") != cc:
                errors.append(f"{scope}: cc is {entry.get('cc')!r}, expected {cc}")
            if entry.get("oscAddress") != osc_address:
                errors.append(f"{scope}: oscAddress is {entry.get('oscAddress')!r}, expected {osc_address!r}")

    noncanonical = lane.get("nonCanonicalBands", [])
    if len(noncanonical) != 1 or noncanonical[0].get("sourceBandIndex") != 1:
        errors.append(f"{args.profile}: nonCanonicalBands must describe raw band index 1 as the local-only support band")

    if errors:
        print("FAIL")
        for error in errors:
            print(f"  ERROR: {error}")
        return 1

    print("PASS")
    for check in checks:
        print(f"  OK: {check}")
    print(f"  OK: {args.profile}: rig profile pins Ch 15 plus canonical analysis bindings 20/22/23/24")
    return 0


if __name__ == "__main__":
    sys.exit(main())
