# EMG Channel Requirements (Draft)

> Applies to: WalkEEG App + nRF52840 firmware
> Status: **To be developed** (planned start: week 1 of 2026-11)
> Updated: 2026-10-31

## 1. Background and Goals

The current system uses ECG/EEG channels (CH0 = AD8232 → SAADC, 500 Hz).
The goal is to **add one surface EMG acquisition channel**, used for:

- **Contraction intensity** of a single muscle (RMS envelope)
- **Muscle fatigue** (downward shift of the median frequency, MDF)
- Later synchronization with BalanxEMS stimulation (EMG-EMS closed loop)

## 2. Conclusion: Enough Channels, No New Hardware Channel Required

- An on-board **ADS1293 (3 channels, CH0–2)** already exists (v3.0 baseboard)
- **Repurpose one channel** (CH1 recommended) for EMG and keep the rest for ECG/EEG
- No new ADC channel is needed, and there is **no need to change the 8-channel BLE frame format**

## 3. Hard Requirements

| Item | Requirement | Current | Gap |
|---|---|---|---|
| Sample rate | **≥ 1 kHz, 2 kHz recommended** | 500 Hz | ❌ must increase |
| Signal bandwidth | **20–500 Hz (-3 dB)** | AD8232 ≈ 0.5–40 Hz | ❌ front end must be changed |
| Resolution | ≥ 12-bit (24-bit recommended) | 12-bit ≈ 8 µV/LSB | ⚠️ too low |
| Input range | At least ±5 mV (surface EMG) | — | to be confirmed |
| Electrodes | Differential bipolar + reference | — | requires mechanical support |
| Coexistence with EMS | **Hardware blanking** during stimulation + software interpolation | None | ❌ to be designed |

### 3.1 Key Uncertainties
- **The ADS1293 is an ECG AFE**: at the current 533 sps the BW is ≈ 105 Hz; the maximum ODR is **6400 sps** (BW scales with ODR), but the **PGA analog bandwidth** must be confirmed from the datasheet to see whether it covers 500 Hz
- If it does not → alternative: **INA333 / AD8237-class instrumentation amp + nRF SAADC @ 2 kHz**

## 4. Functional Requirements

1. Add an **EMG data source**: acquired in parallel with CH0, occupying BLE frame CH1
2. Add an **EMG page** in the App:
   - Live waveform (bandpass 20–500 Hz)
   - **RMS envelope** (100 ms window)
   - **MDF (median frequency)** (sliding-window spectrum)
   - Contraction / relaxation state detection
3. Data export: CSV fields `time,emg_raw,emg_rms,emg_mdf`
4. Relay: EMG uses a dedicated channel and is not mixed with CH0 filtered data

## 5. Acceptance Criteria

1. At rest (muscle relaxed), RMS noise < 5 µV with no obvious 50 Hz interference
2. At maximal voluntary contraction (MVC), RMS increases ≥ 10× with no waveform clipping
3. During a sustained 30 s isometric contraction, MDF drops ≥ 10% (fatigue is measurable)
4. At 2 kHz sampling, BLE packet loss < 1% (8ch × 2 kHz ≈ 32 kB/s)
5. When superimposed on EMS stimulation: recovery within 5 ms after blanking, with no sustained saturation

## 6. Action Items for Next Week (2026-11 W1)

- [ ] Check the ADS1293 datasheet to confirm whether PGA bandwidth / noise meet 20–500 Hz
- [ ] Firmware: switch the ADS1293 ODR to 2 kHz (or trial-run at 6400 first) and verify BLE throughput
- [ ] Wiring: CH1 differential input + reference electrode, first acquisition on the biceps
- [ ] App: EMG page (waveform + RMS + MDF)
- [ ] Evaluate a hardware approach for EMS blanking (analog switch + timing)

## 7. Known Limitations

- Single-channel EMG cannot support muscle-synergy / multi-muscle analysis (requires ≥2 channels)
- Surface EMG is strongly affected by fat thickness, electrode placement, and skin impedance → an individual baseline is mandatory
- Non-medical use: must not be used for diagnostic/therapeutic claims

## 8. Related Documents

- `docs/eeg-alpha-beta-ratio.md` —— EEG β/α ratio requirements
- `docs/ads1293/README.md` —— ADS1293 interface and registers
