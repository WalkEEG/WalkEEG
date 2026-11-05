# WalkEEG

**An open-source wearable biosignal platform for EEG, ECG and EMG.**

Schematics, firmware, mobile app, cloud backend — and a 500 Hz live browser dashboard.
Built for BCI research, education, and anyone curious about the electrical activity inside their body.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Website](https://img.shields.io/badge/website-walkeeg.com-6366f1)](https://www.walkeeg.com)
[![Firmware: Zephyr](https://img.shields.io/badge/firmware-Zephyr%20%2F%20NCS-06b6d4)](02-firmware)
[![App: Flutter](https://img.shields.io/badge/app-Flutter-45b7d1)](05-Flutter%20program)

---

## What is this?

WalkEEG captures electrophysiological signals from the body, streams them wirelessly, and makes them visible in real time — on a phone, in a browser, or in a desktop oscilloscope.

| Signal | Source | Amplitude | Bandwidth |
|---|---|---|---|
| **EEG** — Electroencephalography | Cortical neurons firing together | 10 – 100 µV | 0.5 – 100 Hz |
| **ECG** — Electrocardiography | The electrical sequence pacing each heartbeat | 0.5 – 5 mV | 0.05 – 150 Hz |
| **EMG** — Electromyography | Motor units contracting a muscle | 10 – 1000 µV | 20 – 500 Hz |

These span **four orders of magnitude** in amplitude. A front end that handles all three rates its noise against the weakest (EEG) while keeping enough headroom for the strongest (EMG) — which is what an **80–120 dB CMRR** analog front end delivers.

---

## What's in the box

```
walkeeg/
├── 01-hardware/     KiCad schematics — analog front end, power, connectors
├── 02-firmware/     nRF52840 firmware (Zephyr / Nordic Connect SDK)
├── 03-PC program/   Desktop oscilloscope (LabVIEW, EN + Chinese)
├── 04-MATLAB program/ Analysis scripts (legacy, optional)
├── 05-Flutter program/ iOS + Android app
├── 06-website/      www.walkeeg.com (static, S3 + CloudFront)
├── 07-backend/      AWS SAM — one deployment example, not the platform
├── 08-realtime/     500 Hz WebSocket relay + live browser dashboard
├── algorithms/      Platform-neutral signal statistics (stdlib Python)
└── docs/            Design notes and interface specs
     └── algorithms/ Algorithm contracts + conformance tests
```

| Component | Stack | Status |
|---|---|---|
| **Hardware** | KiCad 10 · AD8232 + ADS1293 | v3.0 |
| **Firmware** | nRF52840 · Zephyr · BLE 5.0 (2M PHY, DLE, MTU 498) | working |
| **Mobile app** | Flutter 3.16+ · Dart 3.3+ | iOS + Android |
| **PC software** | LabVIEW | released |
| **Backend** | AWS SAM · Node 20 | deployed |
| **Live dashboard** | Node · WebSocket · vanilla JS | working |

---

## Quick start

### Firmware

The firmware targets the **nRF52840** and builds with Nordic Connect SDK. A complete, verified toolchain lives at `/opt/nordic/ncs/v2.5.99-dev1` on macOS — but any recent NCS works.

```bash
# 1. Source the NCS environment (adjust paths to your install)
export ZEPHYR_BASE=/path/to/ncs/zephyr
export ZEPHYR_TOOLCHAIN_VARIANT=zephyr
export ZEPHYR_SDK_INSTALL_DIR=/path/to/ncs/toolchains/*/opt/zephyr-sdk

# 2. Build from inside the NCS west workspace — not from the app dir
west build -b nrf52840dk/nrf52840 -d /tmp/build-walkeeg 02-firmware

# 3. Flash (Nordic boards)
nrfutil device recover   --serial-number <SN>
nrfutil device program   --serial-number <SN> --firmware /tmp/build-walkeeg/zephyr/zephyr.hex
nrfutil device reset     --serial-number <SN>
```

> **Building with J-Link instead?** Older J-Link firmware (e.g. V9) can fail to program the nRF52840 — erase succeeds, writes silently don't stick. Use `nrfutil` instead.

**Startup diagnostics.** The firmware blinks the run LED N times to report how far it got:

| Blinks | Meaning |
|---|---|
| 1 | `bt_enable()` OK |
| 2 | NUS service initialised |
| 3 | Analog front end initialised |
| 4 | BLE advertising started |
| 8 | `bt_le_adv_start()` failed |

### Mobile app

```bash
cd "05-Flutter program"
cp lib/config/app_config.example.dart lib/config/app_config.dart  # then fill in your AWS values
flutter pub get
flutter run
```

Requires Bluetooth permissions. On iOS, add `NSBluetoothAlwaysUsageDescription` to `Info.plist`.

### Live dashboard

```bash
cd 08-realtime
npm install
node server.js          # http://0.0.0.0:8787
node simulate.js        # optional: synthetic 500 Hz source
```

Open `http://<your-lan-ip>:8787`. The phone relays frames over WebSocket to `/ingest`; browsers subscribe at `/live`.

---

## How it works

```
    AD8232                  nRF52840                 Phone / PC
 ┌──────────┐   analog   ┌────────────┐    BLE    ┌────────────┐
 │ Electrodes│ ────────▶ │  SAADC     │ ────────▶ │  Flutter   │
 │  + AFE    │  10-1000µV│  + NUS GATT│  2 Mbps   │  app       │
 └──────────┘            └────────────┘           └─────┬──────┘
                                                        │ WebSocket
                                                        ▼
                                              ┌──────────────────┐
                                              │ 08-realtime      │
                                              │ browser dashboard│
                                              └──────────────────┘
```

1. **Acquire** — electrodes pick up microvolt-level potentials; the AFE amplifies and filters them.
2. **Transmit** — the nRF52840 digitises at 500 Hz – 4 kHz and streams over BLE 5.0 using Nordic UART Service, with 2M PHY, data-length extension (251-byte payloads) and a 498-byte MTU.
3. **Visualise** — the Flutter app renders live waveforms with QRS detection and HRV metrics.
4. **Store** — sessions upload to S3 via Cognito-authenticated direct PUT; metadata lands in DynamoDB.
5. **Share** — the app can relay raw frames to a local WebSocket server, so any browser on the network sees the same signal live.

### BLE packet format

```
magic 'W' (0x57) | version (1) | seq (u16 LE) | t_ms (u64 LE) | n (u8) | ch[8][n] (u16 LE)
└──────────────────────────── 13-byte header ─────────────────────────────┘
```

8 channels, 500 Hz, `n = 50` samples per batch → ~10 frames per second.

---

## Repository map

| Path | What you'll find |
|---|---|
| [`01-hardware/`](01-hardware) | KiCad 10 project, AD8232 / ADS1293 front ends, connector pinouts |
| [`02-firmware/`](02-firmware) | Zephyr application, board overlays, Kconfig switches |
| [`05-Flutter program/`](05-Flutter%20program) | Cross-platform app, BLE link, relay service |
| [`06-website/`](06-website) | Static site source, deployed to S3 + CloudFront |
| [`07-backend/`](07-backend) | AWS SAM deployment example (optional if you're not on AWS) |
| [`08-realtime/`](08-realtime) | WebSocket relay and browser charting |
| [`algorithms/`](algorithms) | Reusable signal statistics — stdlib Python, no cloud SDK |
| [`docs/`](docs) | Interface specs, migration notes, hardware revisions |
| [`docs/algorithms/`](docs/algorithms) | Platform-neutral signal processing contracts |

---

## Contributing

Issues and pull requests are welcome. Before opening a PR:

1. Keep the firmware buildable against current NCS — note the NCS version you tested with.
2. For hardware changes, attach the updated schematic PDF alongside the KiCad files.
3. For protocol changes, update `docs/` in the same commit.

## Where does algorithm code belong?

Signal processing is specified once in [`docs/algorithms/`](docs/algorithms) and
implemented once in [`algorithms/`](algorithms). That pair is the only place the
math should exist.

- **Real-time** algorithms run next to the data (app DSP, relay) — latency
  forbids a network round trip. They reimplement the contract for performance,
  and must match it.
- **Offline / batch** algorithms belong in `algorithms/`. `07-backend/` is just
  one way to run them, on one cloud. Swap it for cron, a Kubernetes job, or a
  laptop script without touching the math.
- Every implementation must satisfy
  [`docs/algorithms/conformance.md`](docs/algorithms/conformance.md) against the
  same fixtures.

Run the contract tests at any time:

```bash
python3 algorithms/python/conformance_test.py
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for details (coming soon).

---

## License

MIT — see [LICENSE](LICENSE).

Copyright (c) 2026 the WalkEEG team · [www.walkeeg.com](https://www.walkeeg.com)
