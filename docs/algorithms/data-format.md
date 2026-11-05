# Data Format Specification

> Defines the data format across the whole chain: **device → app → storage →
> offline analysis**.
> Any new implementation (new language, new platform, new server) must parse and
> write according to this document, or the numbers are not comparable.

## 1. Units and dimensions

Easiest to overlook, most expensive to get wrong.

| Quantity | Unit | Notes |
|---|---|---|
| Amplitude | **µV** (microvolts) | Specification layer uses µV throughout. Code may use LSB or raw counts internally, but conversion is mandatory at module boundaries |
| Time | **seconds (s)** | CSV time column counts from the start of recording |
| Frequency | **Hz** | Sample rates and band edges |
| Power | **µV²** | Band energy; do not call it "power" if you never squared it |

**Conversion requires knowing the LSB size.** Current platform:

| Front end | Resolution | LSB | Notes |
|---|---|---|---|
| AD8232 @ 12-bit SAADC | 12 bit | ≈ **8 µV/LSB** | Depends on reference voltage and gain; must be calibrated by measurement |
| ADS1293 | 24 bit | See datasheet | Depends on configured gain |

> **Hard requirement:** any algorithm that emits µV must also record its
> `lsb_uv` conversion factor. Without it the data cannot be compared across
> devices and is effectively unusable.

## 2. BLE binary frame (device → app)

Raw frame over NUS:

```
Offset  Len  Field        Description
  0      1   magic        0xA5
  1      1   version      0x01
  2      2   seq          u16 little-endian, frame counter, wraps at 0xFFFF
  4      1   n            samples per channel in this frame
  5      1   (reserved)   alignment
  6   n×16   payload      8 channels × n samples × u16 LE, interleaved by sample
```

- **Frame length** = `6 + n × 8 × 2` bytes
- **Channel count** is fixed at **8**
- **Sample values** are **unsigned integers**; the bit width depends on the
  acquisition mode (8/10/12/14/16 bit), i.e. 0..2^N−1
- **Interleave order**: all 8 channels of sample 0, then sample 1, and so on

```
payload[0..15]   = channels 0..7 of sample 0
payload[16..31]  = channels 0..7 of sample 1
...
```

**Drop detection:** `seq` must be the previous value + 1 (modulo 65536 wrap).
The size of the jump equals the number of lost frames.

**Reference implementation:** `05-Flutter program/lib/protocol/packet_parser.dart`

> Note: that file's header comment references `docs/WALKEEG_PACKET.md`, which
> does not exist. This document is its canonical replacement.

## 3. Channel assignment (current firmware)

| Channel | Purpose | Notes |
|---|---|---|
| CH0 | AD8232 primary front end | ECG / EEG, 500 Hz |
| CH1 | ADS1293 channel 0 | EMG or spare EEG |
| CH2 | ADS1293 channel 1 | Spare |
| CH3–CH7 | Reserved | Zero-filled or unconnected |

> Channel assignment is an **implicit contract** between firmware and app. Any
> change must be applied in the same commit to: firmware `stream.c`, app
> `packet_parser.dart`, this section, and the CSV column headers.

## 4. CSV storage format (app → S3 / local)

### 4.1 Raw recording

```csv
time,ch0,ch1,ch2,ch3,ch4,ch5,ch6,ch7
0.000,2048,2047,2049,2048,2048,2048,2048,2048
0.002,2049,2048,2050,2048,2048,2048,2048,2048
```

- `time`: seconds since recording start, 3 decimal places
- `chN`: **raw counts**, unfiltered
- Units are not encoded in column names; section 1 applies

### 4.2 Derived metrics (companion file)

Algorithm outputs go into a separate file, never mixed into the raw waveform:

```csv
time,theta,alpha,beta,ratio,artifact
0.0,12.4,48.2,31.0,0.64,0
1.0,11.8,50.1,29.6,0.59,0
```

- `artifact`: 0 = normal, 1 = window flagged as artifact (values not trustworthy)
- Band energy in **µV²**; `ratio` is dimensionless

## 5. Metadata (must travel with the data)

A separate file or S3 object tags, containing at least:

| Field | Type | Required | Notes |
|---|---|---|---|
| `sample_rate` | number | ✅ | Hz; may differ per channel, use an object |
| `lsb_uv` | number | ✅ | Microvolts per LSB, per channel |
| `started_at` | ISO 8601 | ✅ | With timezone |
| `duration_s` | number | ✅ | Recording length |
| `channels` | object | ✅ | Channel → purpose, e.g. `{"0":"ecg","1":"emg"}` |
| `firmware` | string | ✅ | Firmware version, for tracing algorithm mismatches |
| `frontend` | string | Recommended | `ad8232` / `ads1293` |

**Data without `sample_rate` and `lsb_uv` is incomplete by definition.**
Downstream algorithms must refuse it rather than guessing a default.

## 6. Relation to current implementations

| Current state | Action |
|---|---|
| `07-backend/README.md` `POST /signals` body already carries `channels`, `sampleRate`, `duration` | Keep; add `lsb_uv` |
| App CSV export has no unit metadata | Add the metadata file per section 5 |
| Relay `/ingest` binary protocol (magic `0x57`) | Differs from the BLE frame; see `08-realtime/server.js`. Unify if cross-platform interop is needed |

> The relay protocol is currently
> `W | ver | seq u16 | t_ms u64 | n u8 | ch[8][n] u16`, differing from the BLE
> frame in its **timestamp** and **header length**. To get one parser for every
> platform, build it on section 2 rather than inventing a third format.
