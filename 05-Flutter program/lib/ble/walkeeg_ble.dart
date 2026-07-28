import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../protocol/packet_parser.dart';

const String kDeviceName = 'WalkEEG';
const String kNusServiceUuid = '6e400001-b5a3-f393-e0a9-e50e24dcca9e';
const String kNusTxUuid = '6e400003-b5a3-f393-e0a9-e50e24dcca9e';
const String kNusRxUuid = '6e400002-b5a3-f393-e0a9-e50e24dcca9e';

enum BleLinkState { idle, scanning, connecting, connected, streaming, error }

class WalkEegBleController {
  WalkEegBleController({WalkEegPacketParser? parser})
      : parser = parser ?? WalkEegPacketParser();

  final WalkEegPacketParser parser;

  final _stateCtrl = StreamController<BleLinkState>.broadcast();
  final _statusCtrl = StreamController<String>.broadcast();
  final _tickCtrl = StreamController<void>.broadcast();

  Stream<BleLinkState> get stateStream => _stateCtrl.stream;
  Stream<String> get statusStream => _statusCtrl.stream;
  Stream<void> get tickStream => _tickCtrl.stream;

  BleLinkState state = BleLinkState.idle;
  BluetoothDevice? device;
  StreamSubscription<List<int>>? _notifySub;
  StreamSubscription<BluetoothConnectionState>? _connSub;
  String statusText = 'Idle';

  Future<void> ensurePermissions() async {
    if (await Permission.bluetoothScan.isDenied) {
      await Permission.bluetoothScan.request();
    }
    if (await Permission.bluetoothConnect.isDenied) {
      await Permission.bluetoothConnect.request();
    }
    if (await Permission.locationWhenInUse.isDenied) {
      await Permission.locationWhenInUse.request();
    }
  }

  void _setState(BleLinkState s, [String? msg]) {
    state = s;
    if (msg != null) {
      statusText = msg;
      _statusCtrl.add(msg);
    }
    _stateCtrl.add(s);
  }

  Future<void> startScanAndConnect() async {
    await ensurePermissions();
    parser.reset();
    _setState(BleLinkState.scanning, 'Scanning for $kDeviceName…');

    // Drop a stale link left from before re-flash / reset.
    try {
      await device?.disconnect();
    } catch (_) {}
    device = null;
    await _notifySub?.cancel();
    _notifySub = null;

    await FlutterBluePlus.stopScan();

    BluetoothDevice? found;
    final sub = FlutterBluePlus.scanResults.listen((results) {
      for (final r in results) {
        final name = r.advertisementData.advName.isNotEmpty
            ? r.advertisementData.advName
            : r.device.platformName;
        if (name.trim() == kDeviceName) {
          found = r.device;
        }
      }
    });

    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 12));
      await FlutterBluePlus.isScanning
          .where((scanning) => scanning == false)
          .first
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      // Fall through and report not found if still empty.
    } catch (e) {
      await FlutterBluePlus.stopScan();
      await sub.cancel();
      _setState(BleLinkState.error, 'Scan failed: $e');
      return;
    } finally {
      await FlutterBluePlus.stopScan();
      await sub.cancel();
    }

    if (found == null) {
      _setState(
        BleLinkState.error,
        'Device $kDeviceName not found — check board power & advertising',
      );
      return;
    }

    await connect(found!);
  }

  Future<void> connect(BluetoothDevice d) async {
    device = d;
    _setState(BleLinkState.connecting, 'Connecting…');

    _connSub?.cancel();
    _connSub = d.connectionState.listen((s) {
      if (s == BluetoothConnectionState.disconnected) {
        _notifySub?.cancel();
        _notifySub = null;
        _setState(BleLinkState.idle, 'Disconnected');
      }
    });

    try {
      await d.connect(timeout: const Duration(seconds: 10));
      await d.requestMtu(512);

      _setState(BleLinkState.connected, 'Discovering services…');
      final services = await d.discoverServices();

      BluetoothCharacteristic? tx;
      for (final s in services) {
        if (s.uuid.str128.toLowerCase() != kNusServiceUuid) continue;
        for (final c in s.characteristics) {
          if (c.uuid.str128.toLowerCase() == kNusTxUuid) {
            tx = c;
          }
        }
      }

      if (tx == null) {
        _setState(BleLinkState.error, 'NUS TX characteristic not found');
        return;
      }

      await tx.setNotifyValue(true);
      _notifySub?.cancel();
      _notifySub = tx.onValueReceived.listen((value) {
        parser.feed(Uint8List.fromList(value));
        _tickCtrl.add(null);
      });

      _setState(BleLinkState.streaming, 'Streaming');
    } catch (e) {
      _setState(BleLinkState.error, 'Connect failed: $e');
    }
  }

  Future<void> disconnect() async {
    await _notifySub?.cancel();
    _notifySub = null;
    await _connSub?.cancel();
    _connSub = null;
    final d = device;
    device = null;
    if (d != null) {
      try {
        await d.disconnect();
      } catch (_) {}
    }
    _setState(BleLinkState.idle, 'Stopped');
  }

  Future<void> dispose() async {
    await disconnect();
    await _stateCtrl.close();
    await _statusCtrl.close();
    await _tickCtrl.close();
  }
}
