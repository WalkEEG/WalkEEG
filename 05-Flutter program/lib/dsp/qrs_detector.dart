import 'dart:math' as math;

import 'butterworth_second_order.dart';

/// Simplified Pan-Tompkins QRS detector.
///
/// Pipeline (per sample):
///   band-pass 5-15 Hz (2nd-order Butterworth HP 5 Hz + LP 15 Hz)
///   -> first difference -> square -> moving-window integral (150 ms)
///   -> adaptive threshold + 200 ms refractory period
///
/// The adaptive threshold tracks a decaying estimate of the detection-signal
/// peak (Pan-Tompkins SPKI/THRESHOLD scheme, simplified to a single peak
/// tracker with slow decay). It self-adjusts to signal amplitude, so it
/// works on raw ADC counts or filtered ECG alike.
class QrsDetector {
  QrsDetector({required int sampleRate, int maxRrHistory = 64}) {
    _sampleRate = sampleRate;
    _hp = ButterworthSecondOrder.highPass(sampleRate: sampleRate, cutoffHz: 5);
    _lp = ButterworthSecondOrder.lowPass(sampleRate: sampleRate, cutoffHz: 15);
    _integralLen = (0.15 * sampleRate).round();
    _refractory = (0.2 * sampleRate).round();
    _maxRr = maxRrHistory;
    _buf = List<double>.filled(_integralLen, 0);
  }

  late final int _sampleRate;
  late final ButterworthSecondOrder _hp;
  late final ButterworthSecondOrder _lp;
  late final int _integralLen;
  late final int _refractory;
  late final int _maxRr;

  late final List<double> _buf;
  int _bufHead = 0;
  double _bufSum = 0;

  double _prev = 0;
  int _samplesSinceBeat = 0;
  int _sampleCount = 0;
  int _sincePeakUpdate = 0;
  double _signalPeak = 0;
  double _windowMax = 0;
  double _threshold = 0;
  bool _initialized = false;
  int? _lastBeatSample;

  /// Samples to skip after start/reset so the band-pass settle transient
  /// (large for a step-like baseline jump) can't poison the peak estimate.
  static const int _settleSamples = 500;

  /// RR intervals in ms, most recent first.
  final List<double> _rrMs = [];

  int get beatCount => _rrMs.length;
  double? get lastRrMs => _rrMs.isEmpty ? null : _rrMs.first;

  /// Heart rate in bpm from the median of recent RR intervals.
  int? get bpm {
    if (_rrMs.isEmpty) return null;
    final recent = _rrMs.take(math.min(8, _rrMs.length)).toList()..sort();
    return (60000 / recent[recent.length ~/ 2]).round();
  }

  /// SDNN (ms): standard deviation of RR intervals (recent window).
  double? get sdnnMs {
    if (_rrMs.length < 2) return null;
    final n = math.min(30, _rrMs.length);
    final rr = _rrMs.take(n).toList();
    final mean = rr.reduce((a, b) => a + b) / n;
    final variance =
        rr.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) / n;
    return math.sqrt(variance);
  }

  /// RMSSD (ms): root mean square of successive RR differences.
  double? get rmssdMs {
    if (_rrMs.length < 2) return null;
    final n = math.min(30, _rrMs.length);
    final rr = _rrMs.take(n).toList();
    var sum = 0.0;
    for (var i = 1; i < rr.length; i++) {
      final d = rr[i] - rr[i - 1];
      sum += d * d;
    }
    return math.sqrt(sum / (rr.length - 1));
  }

  void reset() {
    _hp.reset();
    _lp.reset();
    _buf.fillRange(0, _buf.length, 0);
    _bufHead = 0;
    _bufSum = 0;
    _prev = 0;
    _samplesSinceBeat = 0;
    _sampleCount = 0;
    _signalPeak = 0;
    _windowMax = 0;
    _threshold = 0;
    _initialized = false;
    _lastBeatSample = null;
    _rrMs.clear();
  }

  /// Processes one raw sample; returns true when a QRS beat is detected.
  bool process(double x) {
    _sampleCount++;
    _sincePeakUpdate++;

    // Let the band-pass filters settle before learning the signal scale.
    if (_sampleCount <= _settleSamples) {
      // Still run the filters so their state converges.
      final band = _lp.process(_hp.process(x));
      _prev = band;
      return false;
    }

    final band = _lp.process(_hp.process(x));
    final diff = band - _prev;
    _prev = band;
    final sq = diff * diff;

    // Moving-window integral (ring buffer + running sum), 150 ms window.
    _bufSum += sq - _buf[_bufHead];
    _buf[_bufHead] = sq;
    _bufHead = (_bufHead + 1) % _integralLen;
    final integ = _bufSum;

    if (integ > _windowMax) _windowMax = integ;
    _samplesSinceBeat++;

    if (!_initialized) {
      // Learn the signal scale over the first ~2 s.
      if (_sincePeakUpdate >= 2 * _sampleRate) {
        _initialized = true;
        _signalPeak = _windowMax;
        _windowMax = 0;
        _sincePeakUpdate = 0;
        _threshold = 0.4 * _signalPeak;
      }
      return false;
    }

    if (_samplesSinceBeat > _refractory && integ > _threshold) {
      _samplesSinceBeat = 0;
      _signalPeak = 0.125 * integ + 0.875 * _signalPeak;
      _threshold = 0.4 * _signalPeak;
      _recordBeat();
      return true;
    }

    // Every 2 s, adapt the peak estimate to the recent window maximum so the
    // threshold follows amplitude changes (and decays when signal vanishes).
    if (_sincePeakUpdate >= 2 * _sampleRate) {
      _sincePeakUpdate = 0;
      _signalPeak = 0.5 * _signalPeak + 0.5 * _windowMax;
      _windowMax = 0;
      _threshold = 0.4 * _signalPeak;
    }
    return false;
  }

  void _recordBeat() {
    if (_lastBeatSample != null) {
      final rrSamples = _sampleCount - _lastBeatSample!;
      if (rrSamples > 0) {
        final rrMs = rrSamples * 1000.0 / _sampleRate;
        if (rrMs > 200 && rrMs < 2000) {
          _rrMs.insert(0, rrMs);
          if (_rrMs.length > _maxRr) _rrMs.removeLast();
        }
      }
    }
    _lastBeatSample = _sampleCount;
  }
}
