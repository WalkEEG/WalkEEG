# Conformance Testing

> Different implementations processing the same file must agree.
> This document defines what "agree" means and how to verify it.

## 1. Why it is needed

If the same data run through the same specification produces different numbers in
Dart, Node and Python, at least one of them violates the specification. Without
reference vectors there is only "looks close enough" — and in cross-platform work
"close enough" is the same as no specification at all.

## 2. Reference dataset

Not yet generated. The specification calls for `docs/algorithms/fixtures/`
containing at least:

| File | Content | Purpose |
|---|---|---|
| `synthetic_alpha.csv` | Synthetic 10 Hz sine, known amplitude, 500 Hz | Absolute correctness of alpha power |
| `synthetic_emg.csv` | Synthetic broadband noise through a known bandpass | EMG envelope and RMS |
| `synthetic_50hz.csv` | Pure 50 Hz sine | Notch and mains rejection |
| `step.csv` | Step signal | Filter transient, overshoot |

**Synthetic beats real recordings here**: the true value is known, so a
discrepancy tells you whether the code is wrong or the signal is simply like
that.

## 3. Agreement criteria

Numeric outputs are compared by **relative error**:

$$
\text{rel\_err} = \frac{|\text{actual} - \text{expected}|}{\max(|\text{expected}|, \epsilon)}
$$

| Output | Tolerance | Rationale |
|---|---|---|
| Band power | ≤ 1 % | Should be nearly identical for the same window and window function |
| RMS | ≤ 0.5 % | Pure arithmetic; FP32/FP64 differences live here |
| Beta/alpha ratio | ≤ 1 % | Error propagates through numerator and denominator |
| MDF | ≤ ±1 frequency bin | Bin discretization |
| Filter output (per sample) | ≤ 1e-6 relative | Identical coefficient sequence should match point by point |

**Exceeding a tolerance means non-conformance.** Locate the cause — coefficient
derivation / window function / unit conversion / accumulation order — rather than
loosening the tolerance.

## 4. Implementation choices that must be declared

Each of these changes the numbers. An implementation **must state its choice in
its own README**, or it is non-conforming:

1. **Accumulation order**: sequential loop vs vectorized sum → different floats
2. **Numeric precision**: FP32 / FP64; fixed-point must state the Q format
3. **Filter initial state**: zero-initialized vs steady-state → affects the first
   samples
4. **Window coherent-gain compensation**: applied / not applied
5. **Band edges**: inclusive or half-open (does `4–7` include 7.0 Hz?)
6. **Artifact windows**: discarded / flagged but retained
7. **Frame drops**: interpolate on `seq` gaps, or leave as-is

## 5. Verification checklist

Tick every item before shipping a new implementation:

- [ ] `synthetic_alpha.csv` reproduces the known alpha power within 1 %
- [ ] `synthetic_emg.csv` reproduces RMS within 0.5 %
- [ ] `synthetic_50hz.csv` gives the expected mains rejection ratio
- [ ] `step.csv` shows no overshoot and no divergence
- [ ] A sample rate that mismatches the data raises an error (does not run silently)
- [ ] Missing `lsb_uv` metadata refuses to emit µV values
- [ ] Artifact windows are visible in the output (`artifact=1`)
- [ ] Every choice in section 4 is declared

## 6. Cross-implementation boundaries

| Upstream | Downstream | Contract |
|---|---|---|
| Firmware `stream.c` | App `packet_parser.dart` | `data-format.md` §2 frame layout |
| App CSV export | `07-backend` batch | `data-format.md` §4 §5 |
| Realtime relay | `08-realtime/server.js` | Relay binary protocol (see data-format §6) |
| Any end | Any end | The reference vectors in this document |

## 7. Current status

| Item | Status |
|---|---|
| Reference dataset | ❌ Not created |
| Dart implementation passing | ⚠️ Nothing to compare against yet |
| Node implementation passing | ❌ Skeleton only |
| Python reference implementation | ⚠️ Interface defined, bodies pending |

> **Recommended order**: create `synthetic_alpha.csv` and `synthetic_emg.csv`
> first, then write the Python reference implementation as the golden standard,
> and finally align Dart / Node to it.
> Doing it backwards (making Python match an existing implementation) would
> freeze that implementation's bugs into the specification.
