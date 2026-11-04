# Mobile App

Flutter application for **iOS and Android**. Connects to the nRF52840 over BLE, renders live waveforms, and can relay raw frames to a local server.

---

## Requirements

| | |
|---|---|
| Flutter | 3.16+ (Dart 3.3+) |
| iOS | Bluetooth permission — `NSBluetoothAlwaysUsageDescription` in `Info.plist` |
| Android | `BLUETOOTH_SCAN`, `BLUETOOTH_CONNECT`, `ACCESS_FINE_LOCATION` in `AndroidManifest.xml` |
| Tier | BLE peripheral must advertise NUS; device name `WalkEEG` |

---

## Running

```bash
cd "05-Flutter program"

＃ 1. Cloud config — copy the template, then fill in your AWS values
cp lib/config/app_config.example.dart lib/config/app_config.dart

＃ 2. Dependencies
flutter pub get

＃ 3. Run
flutter run
```

> `app_config.dart` is **git-ignored** — it holds your Cognito pool IDs and API endpoint. The template `app_config.example.dart` ships with placeholders.

### China / slow pub

```bash
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
export PUB_HOSTED_URL=https://pub.flutter-io.cn
```

---

## Using it

1. **Scan** — tap the Bluetooth icon. The app looks for a device advertising NUS.
2. **Connect** — tap `WalkEEG`. The status line shows `frames / seq / drops / loss%`.
3. **Watch the trace** — CH0 renders immediately. Up to four channels can be overlaid, offset by `ch × 2000` so they don't overlap.
4. **Filter mode** — switch between raw, QRS and HRV views. QRS mode detects R-peaks and computes heart rate; HRV mode adds SDNN and RMSSD.

The status line is the fastest health check:

```
frames=1543  seq=1542  drops=0  loss=0.00%  N=30
```

- `drops > 0` with a rising `loss%` → the link is saturated or the phone is throttling
- `N` is the sample count per frame — shorter frames mean a smaller negotiated MTU

---

## Relay to a local server

The app can forward every received frame to a WebSocket server, so a browser on the same network shows the same signal live.

**Server side:**

```bash
cd 08-realtime
npm install
node server.js          # listens on 0.0.0.0:8787
```

**App side:** tap the relay button (the Wi-Fi icon with a slash when disconnected), then enter:

| Field | Value |
|---|---|
| Host / IP | your computer's LAN address, e.g. `192.168.10.106` |
| Port | `8787` |

Status changes from `disconnected` to `connected`. The browser page at `http://<mac-ip>:8787` starts updating.

> The relay runs over plain WebSocket on your LAN — no cloud, no disk persistence. Frames are written to a 10-second ring buffer so a newly opened browser tab gets the last 2 s immediately.

---

## Project layout

```
05-Flutter program/
├── lib/
│   ├── main.dart              UI, BLE state, waveform painter
│   ├── ble/                   scan, connect, NUS notify handling
│   ├── protocol/packet_parser.dart   frame parsing, seq/loss tracking
│   ├── relay/relay_service.dart      WebSocket relay
│   ├── auth/                  Cognito sign-in
│   ├── storage/s3_uploader.dart      presigned PUT upload
│   └── config/app_config.dart        (git-ignored)
└── test/                      parser + loss-detection unit tests
```

---

## Testing without hardware

```bash
flutter test
```

The parser tests cover frame parsing, sequence wraparound and drop detection, and require no radio.

For an end-to-end check without a phone:

```bash
cd 08-realtime && node simulate.js
```

That injects a synthetic 500 Hz source at the server, so you can verify the browser dashboard independently of the app.

---

## Known issues

**The relay button is hard to find on narrow screens.** The app bar holds six controls (account, sign-out, Y-range dropdown, relay, scan, disconnect). On a phone in portrait the rightmost ones get clipped. Workaround: use a tablet, or rotate to landscape. A layout fix is tracked in the issue list.

**Changing the relay host requires reopening the dialog.** The default `192.168.1.100` is a placeholder — always check the Host field before connecting.
