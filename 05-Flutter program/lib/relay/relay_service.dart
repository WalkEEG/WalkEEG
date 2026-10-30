import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Buffers parsed 8-channel frames and relays them to the local Node server.
/// Protocol: magic 'W' | version 1 | seq u16 | t_ms u32 | n u8 | ch[8][n] u16
class RelayService extends ChangeNotifier {
  static const int batchSamples = 50; // 100 ms @ 500 Hz

  final List<List<int>> _buf = List.generate(8, (_) => <int>[]);
  int _count = 0;
  int _seq = 0;
  int _t = 0;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  Timer? _retry;
  bool _want = false;

  String status = 'off';
  String host = '192.168.1.100';
  int port = 8787;
  int sentSamples = 0;

  bool get enabled => _want;
  bool get connected => _channel != null;

  Future<void> connect({String? host, int? port}) async {
    if (host != null && host.isNotEmpty) this.host = host;
    if (port != null) this.port = port;
    _want = true;
    await _close();
    _setStatus('connecting');
    try {
      final ch = WebSocketChannel.connect(
        Uri.parse('ws://${this.host}:${this.port}/ingest'),
      );
      await ch.ready.timeout(const Duration(seconds: 5));
      _channel = ch;
      _sub = ch.stream.listen(
        (_) {},
        onDone: _onDone,
        onError: (_) => _onDone(),
        cancelOnError: true,
      );
      _setStatus('connected');
    } catch (e) {
      _setStatus('error: $e');
      _scheduleRetry();
    }
  }

  Future<void> _close() async {
    _retry?.cancel();
    _retry = null;
    await _sub?.cancel();
    _sub = null;
    try {
      await _channel?.sink.close();
    } catch (_) {}
    _channel = null;
  }

  void _onDone() {
    _channel = null;
    _sub = null;
    if (!_want) return;
    _setStatus('reconnecting');
    _scheduleRetry();
  }

  void _scheduleRetry() {
    if (!_want) return;
    _retry?.cancel();
    _retry = Timer(const Duration(seconds: 2), () {
      if (_want) connect();
    });
  }

  Future<void> disconnect() async {
    _want = false;
    _retry?.cancel();
    _retry = null;
    await _close();
    _setStatus('off');
  }

  /// Called from the BLE packet parser callback. [perCh] is 8 channels of n
  /// unsigned samples each.
  void onFrame(int seq, List<List<int>> perCh, int n) {
    if (!_want || _channel == null) return;
    for (var i = 0; i < n; i++) {
      if (_count == 0) {
        _seq = seq;
        _t = DateTime.now().millisecondsSinceEpoch;
      }
      for (var c = 0; c < 8; c++) {
        _buf[c].add(perCh[c][i]);
      }
      _count++;
      if (_count >= batchSamples) _flush();
    }
  }

  void _flush() {
    final ch = _channel;
    if (ch == null || _count == 0) return;
    final n = _count;
    final bytes = Uint8List(13 + n * 16);
    final bd = ByteData.view(bytes.buffer);
    bytes[0] = 0x57; // 'W'
    bytes[1] = 1;
    bd.setUint16(2, _seq & 0xffff, Endian.little);
    bd.setUint64(4, _t, Endian.little);
    bytes[12] = n;
    var off = 13;
    for (var i = 0; i < n; i++) {
      for (var c = 0; c < 8; c++) {
        bd.setUint16(off, _buf[c][i] & 0xffff, Endian.little);
        off += 2;
      }
    }
    try {
      ch.sink.add(bytes);
      sentSamples += n;
    } catch (_) {
      _onDone();
    }
    for (var c = 0; c < 8; c++) {
      _buf[c].clear();
    }
    _count = 0;
    notifyListeners();
  }

  void _setStatus(String s) {
    status = s;
    notifyListeners();
  }

  @override
  void dispose() {
    _want = false;
    _retry?.cancel();
    _sub?.cancel();
    _channel?.sink.close();
    super.dispose();
  }
}
