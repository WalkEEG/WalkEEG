# WalkEEG Flutter App

Receives in realtime the 8-channel 16-bit@2kHz test waveform pushed by the nRF52840 (advertised name **WalkEEG**) over NUS Notify, and plots it.

- Requirements traceability and deliverables: [`../docs/WALKEEG_README.md`](../docs/WALKEEG_README.md)
- Protocol: [`../docs/WALKEEG_PACKET.md`](../docs/WALKEEG_PACKET.md)
- Integration testing: [`../docs/WALKEEG_VERIFY.md`](../docs/WALKEEG_VERIFY.md)

## Dependencies

- Flutter 3.16+ (Dart 3.3+)
- Android: BLE permissions are already declared in `AndroidManifest.xml`
- iOS: enable Bluetooth in Xcode and add `NSBluetoothAlwaysUsageDescription` to `Info.plist`

Recommended in mainland China:

```powershell
$env:FLUTTER_STORAGE_BASE_URL="https://storage.flutter-io.cn"
$env:PUB_HOSTED_URL="https://pub.flutter-io.cn"
```

## Running

```bash
cd mobile_walkeeg
flutter pub get
flutter run
```

## Usage

1. Flash the `app_nus` firmware (`build_walkeeg`) that includes the WalkEEG stream
2. Open the app → tap the Bluetooth icon to scan
3. After connecting you should see a ramp waveform; it wraps around about every 32 seconds
4. The top bar can switch up to 4 channels on screen at once (`+ch×2000` offset between channels)
5. Status line: `frames / seq / drops / loss%`, used to confirm packet loss

## Unit tests (no device required)

```bash
flutter test
```

Verifies frame parsing, seq packet-loss detection, and concatenated-packet synchronization.
