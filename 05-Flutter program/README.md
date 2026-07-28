# WalkEEG Flutter App

实时接收 nRF52840（广播名 **WalkEEG**）经 NUS Notify 推送的 8 通道 16-bit@2kHz 测试波形并绘制。

- 需求对照与交付说明：[`../docs/WALKEEG_README.md`](../docs/WALKEEG_README.md)
- 协议：[`../docs/WALKEEG_PACKET.md`](../docs/WALKEEG_PACKET.md)
- 联调：[`../docs/WALKEEG_VERIFY.md`](../docs/WALKEEG_VERIFY.md)

## 依赖

- Flutter 3.16+（Dart 3.3+）
- Android：BLE 权限已在 `AndroidManifest.xml` 声明
- iOS：需在 Xcode 中开启 Bluetooth，并在 `Info.plist` 加 `NSBluetoothAlwaysUsageDescription`

国内建议：

```powershell
$env:FLUTTER_STORAGE_BASE_URL="https://storage.flutter-io.cn"
$env:PUB_HOSTED_URL="https://pub.flutter-io.cn"
```

## 运行

```bash
cd mobile_walkeeg
flutter pub get
flutter run
```

## 使用

1. 烧录含 WalkEEG 推流的 `app_nus` 固件（`build_walkeeg`）
2. 打开 App → 点蓝牙图标扫描
3. 连接后应看到斜坡波形；约 32 秒回绕
4. 顶部可切换最多 4 路通道同屏（通道间 `+ch×2000` 错开）
5. 状态行：`frames / seq / drops / loss%`，用于确认丢包

## 单测（不需真机）

```bash
flutter test
```

验证帧解析、seq 丢包检测、粘包同步。
