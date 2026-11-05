# WalkEEG Signal Processing Specification

> Cross-platform algorithm contract: data formats, algorithm definitions,
> input/output requirements.
> Goal: any implementation (Flutter / Python / Node / MATLAB) that follows these
> documents produces numbers that can be validated against each other.

## Why this directory exists

The same algorithm currently appears in several implementations:

| Location | Language | Content |
|---|---|---|
| `05-Flutter program/lib/dsp/emg_analyzer.dart` | Dart | EMG envelope, RMS, activation |
| `05-Flutter program/lib/dsp/eeg_analyzer.dart` | Dart | EEG theta/alpha/beta, beta/alpha ratio |
| `08-realtime/server.js` | Node | Realtime relay and display |
| `07-backend/src/handlers/process.js` | Node | Batch skeleton (TODO) |
| `03-PC program` / `04-MATLAB program` | C# / MATLAB | Earlier analysis |

The problem is not that the code lives in several places — it is that there is
**no single source of truth**. Parameters drift between implementations, fixes
never travel back, and changing platform means rewriting from scratch.

This directory defines the **contract** only. It does not dictate where code lives:

- **Real-time** algorithms stay on the device (app / local relay). At 500 Hz ×
  8 channels the latency requirement rules out a cloud round trip.
- **Offline** algorithms may run in the `07-backend` Lambda batch, or in a
  desktop script.
- Both sides implement against **the same specification** and are validated
  against the same reference vectors.

## Document index

| Document | Content | Status |
|---|---|---|
| [data-format.md](data-format.md) | CSV / BLE frames / units and dimensions | Final |
| [emg-pipeline.md](emg-pipeline.md) | EMG: bandpass → rectify → envelope → RMS / MDF | Final |
| [eeg-pipeline.md](eeg-pipeline.md) | EEG: theta/alpha/beta band power, beta/alpha ratio | Final |
| [conformance.md](conformance.md) | Reference vectors and cross-implementation tests | Criteria final |

## Three hard rules

1. **One unit system.** Amplitude is **µV** everywhere in this specification
   (input conversion factors are defined separately), time is **seconds**, and
   frequency is **Hz**. Code may work in LSB internally, but any value crossing
   a module boundary must carry its unit.
2. **Algorithms must be reproducible.** Each one states its filter type, order,
   coefficient derivation or reference implementation. "Apply a bandpass filter"
   on its own is not a specification.
3. **Artifacts must be explicit.** An artifact that cannot be removed may only
   be flagged or discarded window-by-window, and it must appear in the output
   fields. Never let it slide silently into the results.

## Relation to existing documents

- Hardware and front-end selection: `06-website/wiki/hardware.md`,
  `docs/ads1293/README.md`
- Requirements and acceptance: `docs/eeg-alpha-beta-ratio.md`,
  `docs/emg-channel-requirement.md`
- Server deployment: `07-backend/README.md`

This directory is the sole authority on **algorithm semantics**. Requirement
documents define *what is wanted*; these documents define *what is computed and
how*.
