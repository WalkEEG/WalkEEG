# EEG / EMG Test Procedure (CJMCU-1293 + nRF52840)

> Applies to: the `nrf52840` branch of `WalkECG_firmware` + CJMCU-1293 module + WalkEEG App.
> Current firmware: 3-lead ECG configuration, 533 sps; `CH0 = IN2−IN1`, `CH1 = IN3−IN1`, `CH2 = IN3−IN2`, `RLD → IN4`.
> Current App: 8-channel int16 frames, default 500 Hz time axis, per-channel independent filtering (raw / 50Hz+LP / bandpass / QRS / HRV).

## 0. Limitations First

| Item | Current state | Impact |
|---|---|---|
| Sample rate | 533 sps (Nyquist 266 Hz) | Sufficient for EEG alpha/beta; EMG only shows low frequency/envelope, high frequencies are lost |
| AFE positioning | ADS1293 is an ECG AFE | Usable for EEG/EMG, but noise and input bias are inferior to a dedicated EEG AFE such as the ADS1299 |
| App time axis | Default 500 Hz | About 6% off from the firmware's 533 Hz, so heart rate/frequency readings will be low |
| EMG bandwidth | Needs 20–450 Hz, 1–2 kSPS | Not configured in the current firmware/App; standard EMG requires firmware + App changes |

## 1. General Preparation

1. **The 3.5 mm plug must be three-conductor TRS**: a two-conductor TS plug shorts pin 2 and pin 3 of P1/P2.
2. **Measure the pinout first**: use the continuity mode of a multimeter to confirm that `L / R / COM` land on pin 1 / 2 / 3 of P1 (i.e., IN1 / IN2 / IN3). Pinouts may differ between vendors.
3. **Electrodes**: Ag/AgCl gel electrodes; wipe the skin with alcohol to remove oil; wait 1–2 minutes after applying; keep impedance below 10 kΩ where possible, and similar on both channels.
4. **Power**: use a battery/power bank, **do not apply electrodes while the charger is plugged in**; a 10 kΩ series resistor + TVS on the inputs is more robust.
5. **Power-on check**: LED3 (P0.15) on the Qingfeng board blinks once per second; the phone can scan `WalkEEG`.
6. After connecting, the App status line should show `Streaming`, with `frames` continuously increasing.

## 2. EEG (2-channel, common reference)

### 2.1 Electrode Placement

| Electrode | Position | Plug into | Net | Role |
|---|---|---|---|---|
| R | Left mastoid A1 | P1-1 | IN1 | Common reference REF |
| L | Left forehead Fp1 (2–3 cm above the eyebrow) | P1-2 | IN2 | CH0 positive input |
| COM(F) | Right forehead Fp2 | P1-3 | IN3 | CH1 positive input |
| Second R wire | Right mastoid A2 or Fpz | P2-1 | IN4 | RLD / bias |
| Spare | Fpz / ground / shielding | P2-2 / P2-3 | IN5 / IN6 | Not used by the current firmware |

Result:

- **CH0 = L − R = Fp1 − A1**
- **CH1 = COM − R = Fp2 − A1**
- CH2 = COM − L = Fp2 − Fp1 (may be ignored)

> Prerequisite: the measured R really lands on IN1. If R lands on IN2/IN3, use whichever electrode lands on IN1 as the reference, or change `FLEX_CH1/2` in the firmware.

### 2.2 App Settings

1. Connect to `WalkEEG`, confirm `frames` is increasing, `drops` is near 0, and MTU is about 495.
2. Display only CH0 and CH1; set the window to **2 s** initially; set the Y axis to **AC auto**.
3. Set all filters to **Raw** initially.

### 2.3 Verification Steps

| Step | Action | Expected |
|---|---|---|
| 1 | Lightly touch the Fp1 electrode with a finger | CH0 shows spikes/fluctuation |
| 2 | Lightly touch the Fp2 electrode with a finger | CH1 responds |
| 3 | Blink | Large slow waves appear on both CH0/CH1 |
| 4 | Clench teeth / turn head | High-frequency muscle noise appears |
| 5 | Close eyes quietly for 10 s | Frontal alpha is weak; it only becomes obvious after moving L/COM to O1/O2 |
| 6 | Set CH0 to `50Hz+LP`, keep CH1 Raw | CH0 becomes smoother, CH1 unchanged (verifies per-channel independence) |
| 7 | Switch CH0 to Bandpass, then back to Raw | CH1 should not jump/reset |
| 8 | Add CH2 with a different filter | CH0/CH1 unaffected |
| 9 | Use "All channels" to set everything, then change CH1 alone | Only CH1 changes, and the status-line summary is correct |

> `QRS` / `HRV` are ECG algorithms and are meaningless on EEG; for EEG prefer `Raw` / `50Hz+LP` / `Bandpass`.

### 2.4 EEG Troubleshooting

| Symptom | Check first |
|---|---|
| frames=0 | NUS TX Notify not enabled in the App; firmware has not started conversion; no DRDY from the ADS1293 |
| Both channels flat | RLD (P2-1) not connected; electrodes not applied well; R/L/COM pinout wrong |
| Large 50 Hz | Poor RLD contact, high electrode impedance, wires too long; connect RLD first, then enable the 50Hz notch |
| Waveform clipping/railing | Large electrode DC offset or gain too high; use fresh electrodes/reapply, adjust firmware only if that fails |
| Only blinks, no EEG | Normal for the forehead; alpha requires placement at O1/O2 |

## 3. EMG (single-channel bipolar)

> At 533 sps the current setup can only verify "is there a signal, and how large is it"; standard surface EMG requires 1–2 kSPS + 20–450 Hz bandpass.

### 3.1 Electrode Placement (biceps brachii example)

| Electrode | Position | Plug into | Net |
|---|---|---|---|
| L | One end of the muscle belly (along the fiber direction) | P1-2 | IN2 |
| R | Other end of the muscle belly, about 2–3 cm from L | P1-1 | IN1 |
| COM(F) | Bony landmark at the elbow, e.g., olecranon/ulna | P1-3 | IN3 |
| Second R wire | Another bony point (wrist/elbow) | P2-1 | IN4 (RLD) |

Result:

- **CH0 = L − R**: differential EMG across the muscle belly — the main channel to watch
- CH1 = COM − R: potential between the reference point and the muscle belly, generally ignore

Key points:

- The two active electrodes should be **along the muscle fiber direction**, not across the muscle;
- Spacing 2–3 cm: too close gives a small signal, too far picks up adjacent muscles;
- Place the reference electrode on a bony landmark, not on the muscle belly.

### 3.2 App Settings

1. Display **CH0** only;
2. Set the window to **100–250 ms** (EMG bursts are fast);
3. Y axis **AC auto**;
4. Filter **Raw** first; once a signal is confirmed, try `50Hz+LP` (note that its 100 Hz low-pass removes EMG high frequencies).

### 3.3 Verification Steps

1. Relax for 5 s and record the baseline;
2. Flex the elbow / clench the fist forcefully for 3 s; CH0 should show a clear high-frequency burst;
3. Relax for 3 s; the burst disappears;
4. Repeat 3 times and compare amplitude and stability;
5. Lightly tap the muscle belly with a finger; short spikes should appear;
6. Compare peak-to-peak amplitude relaxed vs. contracted — typically a 5–20× difference.

### 3.4 EMG Troubleshooting

| Symptom | Check first |
|---|---|
| No change during contraction | Electrodes on tendon/bone; L/R orientation wrong; poor reference/RLD contact |
| Large baseline drift | The ECG 0.5 Hz high-pass is not enough; a 20 Hz high-pass is needed (the current App has no EMG mode) |
| Waveform clipping | Gain/range; electrode offset |
| Obvious 50 Hz | RLD contact, electrode impedance, cable shielding |

### 3.5 What Standard EMG Still Needs

1. **Firmware**: change the ODR to 1–2 kSPS (modify `AFE_RES` / `R1/R2/R3`) and confirm the high-pass cutoff;
2. **App**: add an `EMG` filter mode (20 Hz high-pass + 450 Hz low-pass), default window 200 ms;
3. **Electrodes**: fixed bipolar spacing and reference point; EMG-specific snap electrodes are preferable.

## 4. Quick Checklist

- [ ] Firmware running, LED3 blinking once per second, phone can scan `WalkEEG`
- [ ] App connected, `frames` increasing
- [ ] 3.5 mm plug is three-conductor TRS, pinout measured
- [ ] RLD (P2-1 / IN4) connected to a bony point
- [ ] Touching an electrode produces a response in Raw mode
- [ ] EEG: CH0=Fp1−A1, CH1=Fp2−A1
- [ ] EMG: CH0=bipolar across muscle belly, clear burst during contraction
- [ ] Switching the filter on one channel does not cause other channels to jump

## 5. Related Files

- Module interface and pins: `docs/ads1293/README.md`
- Module schematic: `docs/ads1293/CJMCU-1293.PDF`
- Firmware: `nrf52840` branch of `WalkECG_firmware`
- App: `05-Flutter program`
