#!/usr/bin/env python3
"""Figure 5 helper: bin trigger logs into rate + chatter plots.

Reads CSV logs emitted by the Processing sketch (one row per trigger, optional
MARK rows), bins trigger rates, flags chatter (re-triggers inside cooldown), and
estimates recovery time from each MARK to the next trigger. Intentionally tiny
and monochrome so you can email it to a student, drop it into a VM, or run it on
CI without worrying about GUI backends.
"""

from __future__ import annotations

import argparse
import csv
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path
from typing import Callable, Dict, Iterable, List, Mapping, Tuple, TypeVar

import matplotlib

# Headless-friendly so you can run this on CI or a lab machine without a GUI.
matplotlib.use("Agg")
import matplotlib.pyplot as plt


@dataclass
class TriggerEvent:
    t_ms: float
    condition: str
    mode: str
    band: int
    f_lo: float
    f_hi: float
    energyN: float
    threshold: float
    hysteresis: float
    cooldown_ms: float


@dataclass
class Marker:
    t_ms: float
    label: str


class TriggerLog:
    """In-memory view of a CSV log (events + markers)."""

    def __init__(self, path: Path, events: List[TriggerEvent], markers: List[Marker]):
        self.path = path
        self.events = sorted(events, key=lambda e: e.t_ms)
        self.markers = sorted(markers, key=lambda m: m.t_ms)

    @property
    def conditions(self) -> Iterable[str]:
        return {e.condition for e in self.events}


def read_log(path: Path) -> TriggerLog:
    events: List[TriggerEvent] = []
    markers: List[Marker] = []

    with path.open(newline="") as f:
        reader = csv.reader(f)
        for row in reader:
            if not row:
                continue
            if row[0].strip().lower() == "t_ms":
                # Header row, skip.
                continue
            if len(row) >= 2 and row[1].strip().upper() == "MARK":
                label = row[2].strip() if len(row) > 2 else "mark"
                markers.append(Marker(float(row[0]), label))
                continue
            if len(row) < 10:
                # Not enough columns; skip quietly instead of crashing mid-workshop.
                continue
            try:
                events.append(
                    TriggerEvent(
                        t_ms=float(row[0]),
                        condition=row[1].strip(),
                        mode=row[2].strip(),
                        band=int(row[3]),
                        f_lo=float(row[4]),
                        f_hi=float(row[5]),
                        energyN=float(row[6]),
                        threshold=float(row[7]),
                        hysteresis=float(row[8]),
                        cooldown_ms=float(row[9]),
                    )
                )
            except ValueError:
                # Keep rolling if a line is malformed.
                continue

    return TriggerLog(path, events, markers)


def bin_rates(events: List[TriggerEvent], bin_ms: int) -> Tuple[List[float], List[float]]:
    if not events:
        return [], []

    max_time = max(e.t_ms for e in events)
    bin_count = int(max_time // bin_ms) + 1
    counts = [0 for _ in range(bin_count)]

    for e in events:
        idx = int(e.t_ms // bin_ms)
        counts[idx] += 1

    bin_width_sec = bin_ms / 1000.0
    centers = [((i + 0.5) * bin_width_sec) for i in range(bin_count)]
    rates = [c / bin_width_sec for c in counts]
    return centers, rates


KeyT = TypeVar("KeyT")


def compute_chatter(events: List[TriggerEvent], key_fn: Callable[[TriggerEvent], KeyT]) -> Dict[KeyT, Tuple[int, int]]:
    """Return chatter and total counts grouped by key_fn.

    The cooldown check always happens per (condition, band) pair so cross-band
    triggers cannot falsely flag chatter even when grouping keys coarser.
    """

    chatter: Dict[KeyT, int] = defaultdict(int)
    totals: Dict[KeyT, int] = defaultdict(int)
    last_seen: Dict[Tuple[str, int], float] = {}

    for e in sorted(events, key=lambda ev: ev.t_ms):
        cooldown_key = (e.condition, e.band)
        key = key_fn(e)
        last = last_seen.get(cooldown_key)
        if last is not None and (e.t_ms - last) < e.cooldown_ms:
            chatter[key] += 1
        totals[key] += 1
        last_seen[cooldown_key] = e.t_ms

    return {k: (chatter[k], totals[k]) for k in totals.keys()}


def compute_recovery(
    markers: List[Marker], events: List[TriggerEvent], key_fn: Callable[[TriggerEvent], KeyT]
) -> Dict[KeyT, List[float]]:
    """Return recovery times (seconds) from MARK to next event, grouped by key_fn."""
    if not markers or not events:
        return {}

    recovery: Dict[KeyT, List[float]] = defaultdict(list)
    events_by_key: Dict[KeyT, List[TriggerEvent]] = defaultdict(list)
    for e in sorted(events, key=lambda ev: ev.t_ms):
        events_by_key[key_fn(e)].append(e)

    for m in markers:
        for key, key_events in events_by_key.items():
            next_event = next((e for e in key_events if e.t_ms >= m.t_ms), None)
            if next_event is None:
                continue
            recovery[key].append((next_event.t_ms - m.t_ms) / 1000.0)

    return recovery


def _format_key(key: object) -> str:
    if isinstance(key, tuple):
        cond, band = key
        return f"{cond} (band {band})"
    return str(key)


def plot_rates(events_by_key: Mapping[KeyT, List[TriggerEvent]], bin_ms: int, out_path: Path) -> None:
    fig, ax = plt.subplots(figsize=(9, 4.5))
    styles = ["-", "--", "-.", ":"]
    markers = ["o", "s", "^", "D", "v"]

    for idx, (key, events) in enumerate(sorted(events_by_key.items(), key=lambda kv: _format_key(kv[0]))):
        xs, ys = bin_rates(events, bin_ms)
        if not xs:
            continue
        style = styles[idx % len(styles)]
        marker = markers[idx % len(markers)]
        ax.plot(xs, ys, linestyle=style, marker=marker, linewidth=1.5, color="black", label=_format_key(key))

    ax.set_title("Trigger rate over time (binned)")
    ax.set_xlabel("Time (s)")
    ax.set_ylabel(f"Triggers per {bin_ms/1000:.2f}s bin")
    ax.grid(True, linestyle=":", color="#555", alpha=0.5)
    ax.legend()
    fig.tight_layout()
    fig.savefig(out_path)
    plt.close(fig)


def plot_chatter_and_recovery(
    chatter: Mapping[KeyT, Tuple[int, int]], recovery: Mapping[KeyT, List[float]], out_path: Path
) -> None:
    fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(8, 6), sharex=True)

    conds = sorted({*chatter.keys(), *recovery.keys()}, key=_format_key)
    labels = [_format_key(c) for c in conds]
    ratios = [chatter.get(c, (0, 0))[0] / chatter.get(c, (0, 1e-9))[1] for c in conds]
    ax1.bar(labels, ratios, color="black", alpha=0.7)
    ax1.set_ylabel("Chatter ratio")
    ax1.set_title("Chatter (re-triggers inside cooldown)")
    ax1.grid(True, axis="y", linestyle=":", color="#555", alpha=0.5)

    if recovery:
        data = [recovery.get(c, []) for c in conds]
        ax2.boxplot(data, labels=labels, patch_artist=False, whis=[5, 95])
        ax2.set_ylabel("Recovery time (s from MARK)")
        ax2.set_title("Recovery from MARK to next trigger")
        ax2.grid(True, axis="y", linestyle=":", color="#555", alpha=0.5)
    else:
        ax2.text(0.5, 0.5, "No MARK rows found", ha="center", va="center")
        ax2.axis("off")

    plt.xticks(rotation=20)
    fig.tight_layout()
    fig.savefig(out_path)
    plt.close(fig)


def main() -> None:
    parser = argparse.ArgumentParser(description="Bin trigger logs into Figure 5 plots.")
    parser.add_argument("logs", nargs="+", type=Path, help="CSV logs (t_ms,...)")
    parser.add_argument("--bin-ms", type=int, default=1000, help="Bin width in milliseconds (default: 1000)")
    parser.add_argument(
        "--outdir", type=Path, default=Path("."), help="Where to stash fig5_rates.png and fig5_chatter.png"
    )
    args = parser.parse_args()

    all_events: Dict[str, List[TriggerEvent]] = defaultdict(list)
    all_events_by_band: Dict[Tuple[str, int], List[TriggerEvent]] = defaultdict(list)
    combined_chatter: Dict[str, Tuple[int, int]] = defaultdict(lambda: (0, 0))
    combined_chatter_by_band: Dict[Tuple[str, int], Tuple[int, int]] = defaultdict(lambda: (0, 0))
    combined_recovery: Dict[str, List[float]] = defaultdict(list)
    combined_recovery_by_band: Dict[Tuple[str, int], List[float]] = defaultdict(list)

    for log_path in args.logs:
        log = read_log(log_path)
        for cond in log.conditions:
            cond_events = [e for e in log.events if e.condition == cond]
            all_events[cond].extend(cond_events)
            for e in cond_events:
                all_events_by_band[(cond, e.band)].append(e)

        per_log_chatter = compute_chatter(log.events, key_fn=lambda e: e.condition)
        for cond, (chat, total) in per_log_chatter.items():
            agg_chat, agg_total = combined_chatter[cond]
            combined_chatter[cond] = (agg_chat + chat, agg_total + total)

        per_log_chatter_band = compute_chatter(log.events, key_fn=lambda e: (e.condition, e.band))
        for key, (chat, total) in per_log_chatter_band.items():
            agg_chat, agg_total = combined_chatter_by_band[key]
            combined_chatter_by_band[key] = (agg_chat + chat, agg_total + total)

        per_log_recovery = compute_recovery(log.markers, log.events, key_fn=lambda e: e.condition)
        for cond, times in per_log_recovery.items():
            combined_recovery[cond].extend(times)

        per_log_recovery_band = compute_recovery(log.markers, log.events, key_fn=lambda e: (e.condition, e.band))
        for key, times in per_log_recovery_band.items():
            combined_recovery_by_band[key].extend(times)

    args.outdir.mkdir(parents=True, exist_ok=True)
    plot_rates(all_events, args.bin_ms, args.outdir / "fig5_rates.png")
    plot_rates(all_events_by_band, args.bin_ms, args.outdir / "fig5_rates_by_band.png")
    plot_chatter_and_recovery(combined_chatter, combined_recovery, args.outdir / "fig5_chatter.png")
    plot_chatter_and_recovery(
        combined_chatter_by_band, combined_recovery_by_band, args.outdir / "fig5_chatter_by_band.png"
    )

    # Keep the CLI noisy so workshop participants know where files landed.
    print(
        "Wrote fig5_rates(.png/by_band) and fig5_chatter(.png/_by_band) to"
        f" {args.outdir.resolve()}"
    )


if __name__ == "__main__":
    main()
