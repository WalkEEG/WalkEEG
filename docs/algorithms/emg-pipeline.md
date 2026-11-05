# EMG Processing Specification

> Surface EMG: bandpass → rectify → envelope → RMS / median frequency (MDF).
> Target outputs: **contraction strength** (RMS envelope) and **fatigue**
> (downward MDF shift).

## 1. Pipeline overview

```
Raw counts (LSB)
   │  ① high-pass 20 Hz      ← removes movement artifact and electrode drift
   ▼
   │  ② low-pass 450 Hz      ← removes high-frequency noise, keeps Nyquist margin
   ▼
   │  ③ full-wave rectify |x|
   ▼
   │  ④ envelope low-pass 5 Hz
   ▼
   ├──→ RMS (sliding window)
   ├──→ MDF (sliding-window spectrum)
   └──→ activation = envelope / peak
```

## 2. Current implementation (app-side reference)

`05-Flutter program/lib/dsp/emg_analyzer.dart`

| Item | Value | Implementation |
|---|---|---|
| High-pass cutoff | 20 Hz | First-order IIR, `a = exp(−2π·20/fs)` |
| Low-pass cutoff | 450 Hz | First-order IIR, `a = exp(−2π·450/fs)` |
| Envelope low-pass | 5 Hz | First-order IIR, `a = exp(−2π·5/fs)` |
| Rectification | Full-wave | `abs()` |
| RMS | Sliding window | Running sum of squares, reset each notify cycle |
| Peak tracking | Slow decay | Instant on rising edge, `×0.9995` per sample on falling |
| Activation | `envelope / peak` | Clamped to 0..1 |
| Artifact test | `peak > 3000` | Hard-coded threshold, in LSB |
| Update rate | `fs/20` (≈ 50 ms) | 20 Hz refresh |

**Exact one-pole IIR** (Dart, note the α/$a$ complementary form):

```dart
// high-pass: difference first, then one-pole low-pass
hp  = a_hp * (hp + x - prev_x);  prev_x = x;
// low-pass
lp  = (1 - a_lp) * hp + a_lp * lp;
// envelope
env = (1 - a_env) * |lp| + a_env * env;
```

where `a = exp(−2π·fc/fs)`.

> ⚠️ **A first-order IIR rolls off gently**: the 20 Hz high-pass attenuates only
> about 6 dB at 10 Hz. If downstream analysis needs quantitative results near
> 50 Hz mains, use second-order or higher (see
> `butterworth_second_order.dart` in the app).

## 3. Sample rate: an open problem

| Source | Sample rate |
|---|---|
| `emg_analyzer.dart` default | **2000 Hz** |
| `main.dart` constructor argument | **2000 Hz** |
| `docs/emg-channel-requirement.md` current firmware | **500 Hz** |
| Requirement target | ≥ 1 kHz, 2 kHz recommended |

**These numbers currently contradict each other.** The code derives filter
coefficients as if the rate were 2 kHz. If the data is actually 500 Hz then:

- the 450 Hz low-pass sits **above Nyquist (250 Hz)** — the coefficients are
  meaningless and the filter behaviour is undefined
- the 20 Hz high-pass has a normalized frequency off by a factor of four

**Specification requirement:** coefficients **must** be derived from the actual
sample rate, and that rate **must** come from metadata (see `data-format.md`
section 5), never from a default. Each implementation must:

1. read `sample_rate` from metadata
2. verify `fc_lowpass < sample_rate / 2`
3. **fail** when the check fails — never run silently

## 4. Precise definitions

### 4.1 RMS (contraction strength)

Root mean square of the rectified signal over a window:

$$
\text{RMS} = \sqrt{\frac{1}{N}\sum_{i=1}^{N} x_{rect}[i]^2}
$$

- **Unit**: µV (after conversion via `lsb_uv`)
- **Window**: the specification calls for **100 ms** (matching the requirement
  document); the current implementation resets its accumulator on each notify
  cycle (≈ 50 ms), which is **not a fixed window**. State this explicitly when
  porting.
- **Resting baseline**: must be recorded, otherwise absolute RMS is not
  comparable between people

### 4.2 MDF (median frequency, fatigue indicator)

The frequency at which accumulated power reaches half the total:

$$
\sum_{f=f_{min}}^{\text{MDF}} P(f) = \frac{1}{2}\sum_{f=f_{min}}^{f_{max}} P(f)
$$

- **Physiology**: during fatigue, fast-twitch fibre recruitment drops and
  conduction velocity falls → the spectrum **shifts left** → MDF decreases
- **Acceptance**: MDF drops ≥ 10% over a 30 s sustained contraction
- **Preconditions**: window ≥ 256 samples, Hann window, per-bin power
- **Current state**: **not implemented** (the requirement document lists it as
  pending)

### 4.3 Activation

Normalized envelope, used to judge "is the muscle contracting":

$$
\text{activation} = \frac{\text{envelope}}{\text{peak}}, \quad \text{clamp}(0, 1)
$$

- **Limitation**: `peak` adapts to history, so absolute values are not
  comparable between sessions; only useful for relative judgement within one
  session

## 5. Artifact handling

| Artifact | Symptom | Handling |
|---|---|---|
| Electrode off | Baseline jump, large saturation | Hardware lead-off detection; discard affected windows |
| Movement | Large low-frequency swing | Mitigated by the 20 Hz high-pass |
| 50 Hz mains | Narrow-band spike | Notch filter; the current EMG chain has none — evaluate |
| EMS stimulation crosstalk | Saturation during a pulse | **Hardware blanking**, then interpolation |

**Requirement:** artifacts must appear in the output fields (e.g. `artifact=1`),
and RMS/MDF over those intervals must be flagged unreliable. **They must not
update the baseline or any EMA.**

## 6. How this differs from the EEG chain

Both are biopotentials, but the processing goals differ — **do not reuse the same
filter set**:

| | EMG | EEG |
|---|---|---|
| Target band | 20–450 Hz | 0.5–40 Hz |
| Focus | Amplitude envelope, spectral shift | Band power ratios |
| Sample rate | ≥ 1 kHz | ≈ 500 Hz is enough |
| Artifact handling | Discard whole window | Discard window + EOG regression (multichannel) |

## 7. Acceptance criteria

An implementation must reproduce the following end-to-end:

1. **Resting**: RMS noise < 5 µV, no significant mains residual at 500 Hz
2. **MVC (maximum voluntary contraction)**: RMS ≥ 10× increase, no clipping
3. **Fatigue**: MDF drops ≥ 10% over a 30 s sustained contraction
4. **Rate mismatch**: feeding 500 Hz data into a 2 kHz configuration must raise
   an error, not silently produce output

## 8. Reference implementations

| Language | Location | Status |
|---|---|---|
| Dart | `05-Flutter program/lib/dsp/emg_analyzer.dart` | RMS implemented, MDF not implemented |
| Node | `07-backend/src/handlers/process.js` | Skeleton (TODO) |
| Python | `algorithms/python/walkeeg_stats.py` | Skeleton (interface final, body pending) |
