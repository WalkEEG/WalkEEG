# WalkEMG Front End A (AD8232 Filter Modification)

Date: 2026-11-01 · Branch: `WalkEMG`

## Goal
Change the AD8232 from the ECG bandwidth (0.5–16 Hz) to a **shared EEG + EMG bandwidth (about 0.05–500 Hz)** with a sample rate of 2 kSPS (adjustable 500/1000/2000/4000).

## Schematic Components (`01-hardware/history/AD-ND-S1.1.pdf`)

After tracing the PDF netlist, the signal chain is:

| Stage | Component | Original cutoff |
|---|---|---|
| High-pass | **C4 / C6 = 0.33 µF** with R10~R14 = 10 MΩ | ≈ 0.05 Hz (diagnostic ECG setting) |
| Low-pass (2nd-order Sallen-Key) | **C1 = 1.5 nF** (R6/R7 node → OUT feedback), **C3 = 10 nF** (OPAMP+ → REFOUT AC ground), R6 = R7 = 1 MΩ | f₀ ≈ 41 Hz, dominant pole 15.9 Hz |
| (RLD network, not signal filtering) | C2 1 nF + R5 360 kΩ | — |

The original 15.9 Hz low-pass cuts off beta and most of the EMG signal — this is why the change is required.

> 2026-11-02 correction: an earlier version of this section said "C4→15 nF, C3→330 pF". That only suits pure EMG,
> and since C1 was not changed at the same time, the upper limit was still held at ~100 Hz by the second pole of C1/R6/R7.
> We now need **shared EEG + EMG**, so the high-pass must stay low-frequency; what changes is **C1 + C3**.

## Modification (Shared EEG + EMG, 0.05–500 Hz)

| Component | Original | New | Notes |
|---|---|---|---|
| **C1** | 1.5 nF | **100 pF** (C0G/NP0) | 2nd-order low-pass capacitor 1 |
| **C3** | 10 nF | **1 nF** (C0G/NP0) | 2nd-order low-pass capacitor 2 |

- Cutoff frequency: `f₀ = 1 / (2π·√(R6·R7·C1·C3))` = 1/(2π×1 MΩ×√(100 pF×1 nF)) ≈ **503 Hz**.
- **C1 and C3 must be changed together**: change only C3 and the second pole is still set by C1, so the upper limit does not rise; change only C1 and the dominant pole remains at 15.9 Hz.
- **Do not touch the high-pass C4 / C6** (keep 0.33 µF, ≈0.05 Hz): both the EEG 0.5 Hz and the EMG 20 Hz rely on it.
- If only EMG is needed later and motion artifacts must be suppressed, then change C4 to 15 nF (high-pass ≈10.6 Hz) — but this cuts the EEG low frequencies.
- Alternative values: C1 120 pF + C3 820 pF ≈ 507 Hz (closer to the original capacitor ratio of 6.7, so Q is closer to the original design); 100 pF + 1 nF gives a ratio of 10 and slightly more damping, which does not affect envelope detection.
- Use **C0G/NP0, 5%** capacitors; do not use X7R.
- Before assembling the board, confirm with a multimeter: C1 sits between the R6/R7 node and OUT; C3 sits between OPAMP+ (pin 7) and REFOUT (pin 8).

## Firmware
- `stream.h`: default `WALKEEG_DEFAULT_SAMPLE_HZ 2000`; runtime `walkeeg_stream_set_rate()` / `get_rate()`.
- `stream.c`: runtime `sample_hz`, timer period `1e6/sample_hz` µs; supports 500/1000/2000/4000.
- `prj.conf`: `CONFIG_SYS_CLOCK_TICKS_PER_SEC=8000`; 4 kHz = 250 µs = 2 ticks.
- `main.c`: NUS RX command `SET_RATE 2000\n`, returns `OK 2000\n` or `ERR\n`.
- No NVS write currently: defaults to 2000 Hz at power-up, and the App sends the command once after connecting.

## App
- BLE: add an NUS RX write of `sendCommand("SET_RATE 2000\n")`.
- Sample-rate menu: 500 / 1000 / 2000 / 4000; on switching, send the command and rebuild the analyzer.
- `EmgAnalyzer`: 20 Hz high-pass, 450 Hz low-pass, rectification, 5 Hz envelope; outputs envelope / RMS / activation.
- `EmgPage`: envelope bar, activation percentage, sample-rate dropdown, CSV copy.
- EEG analysis still uses raw CH0; the relay sends the current sample-rate configuration.

## Relay / Web Page
- After connecting to `/ingest`, the App sends the text: `{"type":"config","rate":2000}`.
- The server stores `sourceRateHz` and broadcasts it to `/live`; the web timeline is computed as rate × 5 s.
- The binary frame format is unchanged: `magic 0xA5 | ver | seq u16 | n u8 | ch[8][n] u16`; `t_ms` exists only in the relay envelope.

## Limitations
- AD8232 is 12-bit at about 8 µV/LSB: adequate for the EMG envelope, but not for detailed EMG waveforms; for product-grade EMG, switch to the ADS1293/ADS1299.
- At 4 kSPS the SAADC oversampling has already dropped to 2; still, validate the envelope at 2 kSPS first.
- Motion artifacts are large; first test fist clench/relax while sitting still, then move on to walking.
