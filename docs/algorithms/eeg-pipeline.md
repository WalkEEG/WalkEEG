# EEG Processing Specification

> Band power and the beta/alpha ratio: turning continuous EEG into a comparable,
> trackable **arousal index**.

## 1. Pipeline overview

```
Raw counts (LSB)
   │  ① convert to µV
   ▼
   │  ② bandpass 0.5–40 Hz     ← remove drift, limit band
   ▼
   │  ③ window (2 s, 50% overlap)
   ▼
   │  ④ Hann window + spectrum
   ▼
   ├──→ theta (4–7 Hz) power
   ├──→ alpha (8–12 Hz) power
   ├──→ beta (13–30 Hz) power
   └──→ beta/alpha ratio
```

## 2. Current implementation (app-side reference)

Authoritative requirement document: `docs/eeg-alpha-beta-ratio.md`
(**requirements and product rationale** live there).
This file defines **algorithm semantics** — what counts as computing it
correctly.

| Item | Value |
|---|---|
| Sample rate | 500 Hz |
| Window | 2 s (1000 samples) |
| Hop | 1 s (50% overlap) |
| Window function | Hann |
| Spectrum | Per-bin Goertzel, 1 Hz resolution |
| Bands | theta 4–7 / alpha 8–12 / beta 13–30 Hz |
| Smoothing | Per-band EMA, coefficients 0.8 / 0.2 |
| Ratio | `beta_EMA / alpha_EMA` (when alpha > 0) |
| Artifact threshold | In-window p2p > 400 LSB (≈ 3.2 mV @ 8 µV/LSB) |

## 3. Why Goertzel instead of FFT

2 s @ 500 Hz = 1000 samples, and only 27 bins are needed (4–30 Hz). Goertzel costs
O(N) per bin, so 27 bins total O(27N) — cheaper than a full O(N log N) FFT, and
it needs **no FFT dependency**.

Trade-off: **resolution is bound to window length**. 1000 samples @ 500 Hz gives
Δf = 0.5 Hz, which differs from the "1 Hz resolution" stated in the requirement
document. Use the actual `fs/N`.

**Cross-platform requirement:** an FFT-based implementation must use the **same
window length, window function and bin edges**, or beta/alpha values are not
comparable.

## 4. Key definitions

### 4.1 Band power

$$
E_{band} = \sum_{f \in band} |X(f)|^2
$$

- **Unit**: µV² (voltage squared, **not** µV)
- **Window gain compensation**: the specification requires **compensating** for
  the Hann coherent gain. Otherwise absolute values differ with window length
- Recommend emitting both µV² and its log10 value, so cross-subject comparisons
  do not span orders of magnitude

### 4.2 Beta/alpha ratio

$$
\text{ratio} = \frac{\beta_{EMA}}{\alpha_{EMA}}
$$

- **Dimensionless**
- **Meaning**: central arousal. Rising → alert/tense; falling → relaxed
- **Why a ratio**: cancels common-mode effects such as electrode impedance,
  individual differences and overall gain

### 4.3 EMA smoothing

```dart
ema = 0.8 * ema_prev + 0.2 * value
```

- Time constant ≈ 5 windows (≈ 5 s), depending on hop size
- **Artifact windows do not update the EMA** (skipped when `artifact=1`)

## 5. Artifact detection

| Criterion | Threshold | Notes |
|---|---|---|
| In-window peak-to-peak | > 400 LSB | ≈ 3.2 mV @ 8 µV/LSB |

**Requirements:**
- Artifact windows **do not update the EMA**, but they **are still emitted**
  (`artifact=1`) so the data stays auditable
- The threshold must be **parameterized** and expressed in µV via `lsb_uv`, not
  hard-coded in LSB. After moving to a 24-bit front end (ADS1293), 400 LSB means
  nothing

## 6. Known limitations

Stated at the specification level; implementations may not paper over them:

1. **Single channel cannot localize**: no multi-lead analysis, no ERP, no source
   localization
2. **Insufficient resolution**: AD8232 is 12-bit, so alpha at 10–50 µV spans only
   1–6 LSB. **Official position: switch to ADS1293 (24-bit) before treating this
   as a production metric**
3. **Artifacts cannot be regressed out**: with one channel there is no EOG
   reference, so blinks can only be discarded window-by-window
4. **Not medical**: must not be used for diagnosis, treatment, or any medical
   claim

## 7. Acceptance criteria

1. **Eyes closed → eyes open**: alpha power drops noticeably (alpha blocking),
   beta/alpha rises
2. **Eyes open → eyes closed**: alpha recovers, beta/alpha falls
3. **Artifacts**: blink/clench/movement windows do not update the EMA and appear
   as `artifact=1` in the CSV
4. **Stability**: same subject, same posture, three consecutive eyes-closed
   baselines, alpha power variation < 30%
5. **Drift**: no sustained ratio drift over 5 minutes (absent genuine state
   change)

## 8. Electrode placement requirement

The beta/alpha ratio is only meaningful **over the occipital region**:

- The alpha rhythm is strongest at O1/O2
- Reference: linked mastoids or Cz
- **Wrong electrode placement means no alpha, and the ratio is noise**

## 9. Reference implementations

| Language | Location | Status |
|---|---|---|
| Dart | `05-Flutter program/lib/dsp/eeg_analyzer.dart` | Implemented |
| Node | `07-backend/src/handlers/process.js` | Skeleton (TODO) |
| Python | `algorithms/python/walkeeg_stats.py` | Skeleton (interface final, body pending) |
