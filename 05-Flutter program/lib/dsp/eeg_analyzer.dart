import 'dart:math' as math;

import 'package:flutter/foundation.dart';

class EegSnapshot {
  final double theta;
  final double alpha;
  final double beta;
  final double ratio;
  final bool artifact;
  final DateTime at;

  const EegSnapshot({
    required this.theta,
    required this.alpha,
    required this.beta,
    required this.ratio,
    required this.artifact,
    required this.at,
  });
}

/// Alpha/beta band power from CH0. 500 Hz, 2 s window, 50% overlap.
/// Goertzel only; no FFT dependency.
class EegAnalyzer extends ChangeNotifier {
  EegAnalyzer({
    this.sampleRate = 500,
    this.windowSeconds = 2,
    this.hopSeconds = 1,
  });

  final int sampleRate;
  final double windowSeconds;
  final double hopSeconds;

  static const int thetaLo = 4, thetaHi = 7;
  static const int alphaLo = 8, alphaHi = 12;
  static const int betaLo = 13, betaHi = 30;

  final List<double> _buf = <double>[];
  int _sinceCompute = 0;
  double _thetaEma = 0;
  double _alphaEma = 0;
  double _betaEma = 0;

  EegSnapshot? latest;
  final List<EegSnapshot> history = <EegSnapshot>[];

  void addSamples(List<int> samples, int n) {
    for (var i = 0; i < n && i < samples.length; i++) {
      _buf.add(samples[i].toDouble());
    }
    final maxBuf = (sampleRate * (windowSeconds + 1)).round();
    if (_buf.length > maxBuf) {
      _buf.removeRange(0, _buf.length - maxBuf);
    }

    _sinceCompute += n;
    final win = (sampleRate * windowSeconds).round();
    final hop = (sampleRate * hopSeconds).round();
    if (_sinceCompute < hop || _buf.length < win) return;

    _sinceCompute = 0;
    final raw = _buf.sublist(_buf.length - win);
    _compute(raw);
  }

  void _compute(List<double> raw) {
    final n = raw.length;
    var sum = 0.0;
    var mn = raw.first;
    var mx = raw.first;
    for (final v in raw) {
      sum += v;
      if (v < mn) mn = v;
      if (v > mx) mx = v;
    }
    final mean = sum / n;
    final x = List<double>.filled(n, 0);
    for (var i = 0; i < n; i++) {
      final w = 0.5 - 0.5 * math.cos(2 * math.pi * i / (n - 1));
      x[i] = (raw[i] - mean) * w;
    }

    double band(int lo, int hi) {
      var p = 0.0;
      for (var f = lo; f <= hi; f++) {
        p += _goertzel(x, f.toDouble());
      }
      return p;
    }

    final theta = band(thetaLo, thetaHi);
    final alpha = band(alphaLo, alphaHi);
    final beta = band(betaLo, betaHi);

    // 12-bit AD8232: about 8 uV/LSB. Large p2p = movement/EMG.
    final artifact = (mx - mn) > 400;
    if (!artifact) {
      _thetaEma = _thetaEma == 0 ? theta : 0.8 * _thetaEma + 0.2 * theta;
      _alphaEma = _alphaEma == 0 ? alpha : 0.8 * _alphaEma + 0.2 * alpha;
      _betaEma = _betaEma == 0 ? beta : 0.8 * _betaEma + 0.2 * beta;
    }
    final ratio = _alphaEma > 0 ? _betaEma / _alphaEma : 0.0;

    latest = EegSnapshot(
      theta: _thetaEma,
      alpha: _alphaEma,
      beta: _betaEma,
      ratio: ratio,
      artifact: artifact,
      at: DateTime.now(),
    );
    history.add(latest!);
    if (history.length > 1200) history.removeAt(0);
    notifyListeners();
  }

  double _goertzel(List<double> x, double freq) {
    final n = x.length;
    final k = (n * freq / sampleRate).round();
    final w = 2 * math.pi * k / n;
    final c = 2 * math.cos(w);
    var s0 = 0.0, s1 = 0.0, s2 = 0.0;
    for (final v in x) {
      s0 = v + c * s1 - s2;
      s2 = s1;
      s1 = s0;
    }
    final p = s1 * s1 + s2 * s2 - c * s1 * s2;
    return p / (n * n);
  }

  void clear() {
    _buf.clear();
    _sinceCompute = 0;
    _thetaEma = 0;
    _alphaEma = 0;
    _betaEma = 0;
    latest = null;
    history.clear();
    notifyListeners();
  }
}
