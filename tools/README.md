# Tools: trigger logging + Figure 5

This folder is the lab bench for the tiny CSV logger and the even tinier Figure 5 generator. It is written like a scratchpad so students (or future you) can see the intent, not just the commands.

## How to log triggers
1. Run the Processing sketch as usual.
2. Press **`e`** to start the CSV logger. A filename appears in the HUD; files land in `processing/FreqZoneTriggers/data/logs/`.
3. Press **`r`** to drop a `MARK` row whenever you change conditions (mute, bypass, etc.). Those rows drive the recovery-time math.
4. Press **`e`** again to close the log when you are done. The file is already headered for the analysis script.

Columns: `t_ms, condition, mode, band, f_lo, f_hi, energyN, threshold, hysteresis, cooldown_ms` and optional `MARK` rows (`t_ms, MARK, label`). One row per trigger keeps the files tiny and easy to email around.

## How to make the figures
1. Pull your logs into this repo (or point to them directly). Install deps once with `python -m pip install matplotlib`.
2. Run: `python tools/analyze_triggers.py --outdir tools/out your/log.csv [more_logs.csv]`
3. Open `fig5_rates.png` and `fig5_chatter.png` from the chosen outdir.

`fig5_rates` gives you a trigger-rate time series (binned, monochrome, publication-ready). `fig5_chatter` stacks chatter ratios over cooldown alongside recovery times from each `MARK` to the next trigger. Tweak `--bin-ms` if you want faster/slower temporal resolution.
