# WalkEEG Signal Algorithms

Platform-neutral signal statistics. **No third-party dependencies — Python
standard library only.**

## What this is

A set of statistical functions you can call directly: take a sample array, get
structured metrics back. No network, no cloud services, no file system.

The semantics live in [`docs/algorithms/`](../docs/algorithms) — that is the
**contract**, this is the **implementation**. They must agree; when they do not,
the specification wins and the implementation gets fixed.

## Why it is a separate directory

Algorithms and deployment are different concerns. `07-backend/` is one specific
AWS deployment (SAM template, Cognito, S3, Lambda permissions) — if you are not on
AWS, that whole directory is irrelevant to you. But the algorithms themselves —
band power, beta/alpha ratio, RMS, envelope, MDF — have nothing to do with which
server runs them.

At the repository root the meaning is immediate: **want the algorithms? take this
one directory. Want a deployment reference? look at `07-backend/`.**

## Design constraints

| Constraint | Reason |
|---|---|
| **Standard library only** | Runs where pip is unavailable; works in Lambda, scripts and notebooks alike |
| **Pure functions** | No global state, no implicit I/O — input determines output, unit-testable |
| **Explicit units** | Input must be µV, stated in signatures and docstrings; raw LSB is rejected |
| **Fail loudly** | Mismatched sample rate or missing metadata raises, never guesses a default |

## Usage

```python
import sys
sys.path.insert(0, "algorithms/python")

from walkeeg_stats import band_powers, beta_alpha_ratio

# Input: single-channel voltage in µV, 500 Hz sample rate
powers = band_powers(samples, sample_rate=500)
print(powers)          # {'theta': ..., 'alpha': ..., 'beta': ...}

ratio = beta_alpha_ratio(powers)
print(ratio)
```

## Layout

```
algorithms/
├── README.md               this file
├── python/
│   ├── walkeeg_stats.py    implementation (stdlib only)
│   └── conformance_test.py self-check against reference vectors
└── fixtures/
    ├── synthetic_alpha.csv  10 Hz synthetic, validates alpha
    ├── synthetic_emg.csv    synthetic broadband, validates RMS
    └── expected.json        expected outputs for the above
```

## Current status

**Framework stage.** Interfaces, data contracts and error handling are settled;
algorithm bodies raise `NotImplementedError` until called.

The reason for the ordering: fixing the interface and acceptance method first
avoids rewriting the contract mid-implementation. Once `fixtures/` exists and the
reference vectors are pinned down, each body gets an unambiguous pass criterion.

| Module | Status |
|---|---|
| Data validation `_validate` | ✅ Implemented |
| `band_powers` | ⬜ Pending |
| `beta_alpha_ratio` | ✅ Implemented |
| `rms` | ⬜ Pending |
| `envelope` | ⬜ Pending |
| `median_frequency` | ⬜ Pending |
| Reference vectors | ⬜ Pending |

## Related documents

- [`docs/algorithms/data-format.md`](../docs/algorithms/data-format.md) — data format and units
- [`docs/algorithms/eeg-pipeline.md`](../docs/algorithms/eeg-pipeline.md) — EEG pipeline
- [`docs/algorithms/emg-pipeline.md`](../docs/algorithms/emg-pipeline.md) — EMG pipeline
- [`docs/algorithms/conformance.md`](../docs/algorithms/conformance.md) — conformance criteria
