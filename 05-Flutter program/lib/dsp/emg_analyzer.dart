import 'dart:math' as math;

import 'package:flutter/foundation.dart';

class EmgSnapshot {
  final double envelope;
  final double activation;
  final double rms;
  final bool artifact;
  final DateTime at;

  const EmgSnapshot({
    required this.envelope,
    required this.activation,
    required this.rms,
    required this.artifact,
    required this.at,
  });
}

/// Simple EMG envelope: 20 Hz high-pass, 450 Hz low-pass, rectify, 5 Hz envelope.
class EmgAnalyzer extends ChangeNotifier {
  EmgAnalyzer({this.sampleRate = 2000}) {
    _coeff();
  }

  int sampleRate;
  double _aHp = 0, _aLp = 0, _aEnv = 0;

  double _prevX = 0;
  double _hp = 0;
  double _lp = 0;
  double _env = 0;
  double _peak = 1;

  double _rmsAcc = 0;
  int _rmsN = 0;
  int _notifyCounter = 0;

  EmgSnapshot? latest;
  final List<EmgSnapshot> history = <EmgSnapshot>[];

  void _coeff() {
    _aHp = math.exp(-2 * math.pi * 20 / sampleRate);
    _aLp = math.exp(-2 * math.pi * 450 / sampleRate);
    _aEnv = math.exp(-2 * math.pi * 5 / sampleRate);
  }

  void setSampleRate(int hz) {
    sampleRate = hz;
    _coeff();
    clear();
  }

  void addSamples(List<int> samples, int n) {
    for (var i = 0; i < n && i < samples.length; i++) {
      final x = samples[i].toDouble();
      // 20 Hz high-pass
      _hp = _aHp * (_hp + x - _prevX);
      _prevX = x;
      // 450 Hz low-pass
      _lp = (1 - _aLp) * _hp + _aLp * _lp;
      // rectify + 5 Hz envelope
      final rect = _lp.abs();
      _env = (1 - _aEnv) * rect + _aEnv * _env;

      _rmsAcc += rect * rect;
      _rmsN++;
      if (rect > _peak) {
        _peak = rect;
      } else {
        _peak *= 0.9995;
      }
      _notifyCounter++;
    }

    final every = (sampleRate / 20).round(); // ~50 ms
    if (_notifyCounter < every) return;
    _notifyCounter = 0;

    final rms = _rmsN == 0 ? 0.0 : math.sqrt(_rmsAcc / _rmsN);
    _rmsAcc = 0;
    _rmsN = 0;
    final act = _peak <= 0 ? 0.0 : (_env / _peak).clamp(0.0, 1.0);
    latest = EmgSnapshot(
      envelope: _env,
      activation: act,
      rms: rms,
      artifact: _peak > 3000,
      at: DateTime.now(),
    );
    history.add(latest!);
    if (history.length > 1200) history.removeAt(0);
    notifyListeners();
  }

  void clear() {
    _prevX = 0;
    _hp = 0;
    _lp = 0;
    _env = 0;
    _peak = 1;
    _rmsAcc = 0;
    _rmsN = 0;
    _notifyCounter = 0;
    latest = null;
    history.clear();
    notifyListeners();
  }
}
