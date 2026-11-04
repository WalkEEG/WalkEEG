# WalkEEG Documentation

> Open-source wearable biosignal platform for **EEG**, **ECG** and **EMG** —
> 80–120 dB CMRR analog front end, BLE 5.0, Flutter app, 500 Hz live dashboard.

---

## Start here

| If you want to… | Go to |
|---|---|
| Build and flash the firmware | [Firmware → Build](firmware/build.md) |
| Run the phone app | [Mobile App](app.md) |
| Understand the BLE packet format | [Protocol](protocol.md) |
| Deploy the cloud backend | [Backend](backend.md) |
| Get the live browser view working | [Realtime Dashboard](realtime.md) |
| Modify the analog front end | [Hardware](hardware.md) |

---

## Signal chain

```
  Electrodes                                                  Browser
      │                                                          ▲
      ▼                                                          │ WebSocket
 ┌──────────┐   analog    ┌────────────┐   BLE 5.0   ┌──────────┴───┐
 │  AD8232  │ ──────────▶ │  nRF52840  │ ──────────▶ │ Flutter app  │
 │   AFE    │  10–1000 µV │  SAADC+NUS │   2 Mbps    │  iOS/Android │
 └──────────┘             └────────────┘             └──────────────┘
                                                             │
                                                             ▼
                                                    ┌─────────────────┐
                                                    │ S3 data bucket  │
                                                    │ + DynamoDB      │
                                                    └─────────────────┘
```

1. **Acquire** — microvolt potentials amplified and filtered by the analog front end
2. **Transmit** — digitised at 500 Hz – 4 kHz, streamed over BLE with 2M PHY and 498-byte MTU
3. **Visualise** — live waveforms with QRS detection and HRV metrics
4. **Store** — Cognito-authenticated upload to S3, metadata in DynamoDB
5. **Share** — relayed over WebSocket so any browser sees the same signal

---

## Repository layout

| Directory | Contents |
|---|---|
| `01-hardware/` | KiCad 10 schematics — AFE, power, connectors |
| `02-firmware/` | Zephyr application for nRF52840 |
| `03-PC program/` | LabVIEW desktop oscilloscope (EN / 中文) |
| `04-MATLAB program/` | Offline analysis scripts (legacy) |
| `05-Flutter program/` | iOS + Android app |
| `06-website/` | Static site, S3 + CloudFront |
| `07-backend/` | AWS SAM stack |
| `08-realtime/` | WebSocket relay + browser dashboard |

---

## Getting help

- **Issues:** [github.com/WalkEEG/WalkEEG/issues](https://github.com/WalkEEG/WalkEEG/issues)
- **Website:** [www.walkeeg.com](https://www.walkeeg.com)
- **License:** MIT — see [LICENSE](https://github.com/WalkEEG/WalkEEG/blob/master/LICENSE)
