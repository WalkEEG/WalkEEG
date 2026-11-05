# Beta/Alpha Ratio (β/α): Requirements and Rationale

> Applies to: WalkEEG App (`05-Flutter program`)
> Updated: 2026-10-31
> Implementation: `lib/dsp/eeg_analyzer.dart`, `lib/ui/eeg_page.dart`

## 1. Requirements

### 1.1 Function
Compute the **β/α ratio** of the single-channel (CH0) EEG **in real time** inside the App and display it on the EEG page; also output the power of the three bands **θ / α / β** so the ratio's origin can be explained.

### 1.2 Algorithm Parameters (current implementation)
| Item | Value |
|---|---|
| Sample rate | 500 Hz (matches the BLE frame) |
| Analysis window | 2 s (1000 samples), hop 1 s, 50% overlap |
| Window function | Hann |
| Spectrum | Per-bin Goertzel (1 Hz resolution, no FFT dependency) |
| Bands | θ 4–7 Hz / α 8–12 Hz / β 13–30 Hz |
| Smoothing | EMA per band (0.8 / 0.2) |
| Ratio | `β_EMA / α_EMA` (when α > 0) |
| Artifact gate | p2p > 400 LSB within the window (≈3.2 mV @ 8 µV/LSB) → **EMA is not updated for that window**, flagged as `artifact` |

### 1.3 Output
- **EEG page**: live α/β bars + β/α value + α trend curve (one point per 1 s) + "α baseline" (eyes-closed calibration)
- **CSV export**: `time,theta,alpha,beta,ratio,artifact`
- **Relay (`/ingest`)**: CH0 = waveform after the current filter mode; CH7 = raw CH0

### 1.4 Acceptance Criteria
1. **Eyes closed → eyes open**: α power drops markedly (alpha blocking) and β/α rises;
2. **Eyes open → eyes closed**: α recovers and β/α falls;
3. Artifact segments (blinks / jaw clenching / movement) are excluded from the EMA and marked `artifact=1` in the CSV;
4. For the same subject and posture, three consecutive eyes-closed baselines show < 30% variation in α power;
5. No sustained drift of the ratio over 5 minutes (other than genuine state changes).

## 2. Rationale (why this ratio is needed)

### 2.1 Physiological Meaning
- **α waves (8–12 Hz)**: predominantly occipital, strongest during **eyes-closed relaxation**; suppressed on eyes-open / arousal (alpha blocking).
- **β waves (13–30 Hz)**: predominantly frontal/central, associated with **arousal, focus, cognitive load, and tension**.
- The **β/α ratio** is therefore a low-dimensional, interpretable index of "**central arousal**":
  - Ratio ↑ → more alert / tense / higher cognitive load
  - Ratio ↓ → more relaxed
- Compared with the absolute power of a single band, **the ratio cancels common-mode changes** such as electrode impedance, individual differences, and overall gain, making long-term trends more stable.

### 2.2 Product Value (BalanxEMS / WalkEEG)
1. **Pre-training relaxation guidance**: take a 30 s eyes-closed baseline; if the ratio is high, prompt the user to relax before training;
2. **In-training state monitoring**: observe in real time whether the user is over-tense (which affects movement quality and subjective experience);
3. **Post-training recovery assessment**: compare the ratio before and after training → produce a "central fatigue / recovery" score;
4. **Neurofeedback**: use the ratio as the feedback variable for relaxation training;
5. **Data asset**: long-term CSV / cloud records that support individual baselines and trend analysis.

### 2.3 Known Limitations (must be reflected in product messaging)
- **Single channel**: no localization, multi-lead, or ERP capability; electrodes must be placed on the **occipital region (O1/O2 with mastoid reference)** to obtain reliable α.
- **The AD8232 is 12-bit (≈8 µV/LSB)**: α amplitudes of 10–50 µV correspond to only 1–6 LSB, which is coarse; **switching to the ADS1293 (24-bit)** is recommended before using this as a formal product metric.
- **Artifacts**: blinks / jaw clenching / head movement cannot be removed by EOG regression on a single channel and can only be discarded at the whole-window level, which limits the effective data rate.
- **Non-medical**: must not be used for diagnosis, treatment, or any medical claim; it is for training and state reference only.

## 3. References
- Implementation: `05-Flutter program/lib/dsp/eeg_analyzer.dart`
- Page: `05-Flutter program/lib/ui/eeg_page.dart`
- Acquisition: `05-Flutter program/lib/protocol/packet_parser.dart` (500 Hz, 8-channel frames)
