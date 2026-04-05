# frZone Interop

This folder holds the rig-facing contract surface for `frZone`.

- `frzone.rig.json`
  - committed rig-tuned runtime profile
  - pins the canonical analysis lane to the shared `live-rig` vocabulary
  - keeps generic classroom mappings separate from sibling-repo alignment

The authority mirror for this repo lives in `../atlas/live-rig.default.json`.

Refresh it from the sibling authority checkout with:

```bash
python3 tools/sync_live_rig_authority.py
```

Validate the local mirror plus the committed `frZone` rig profile with:

```bash
python3 tools/validate_rig_alignment.py
```
