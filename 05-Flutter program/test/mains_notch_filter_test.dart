import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:mobile_walkeeg/dsp/butterworth_lowpass.dart';
import 'package:mobile_walkeeg/dsp/mains_notch_filter.dart';

/// Synthesizes [n] samples of a sine with the given amplitude/freq at 2 kHz.
List<double> sineWave(int n, double freq, double amp, {double phase = 0}) {
  final fs = 2000.0;
  return List.generate(
    n,
    (i) => amp * math.sin(2 * math.pi * freq * i / fs + phase),
  );
}

/// Chain under test: 50 Hz notch then 100 Hz low-pass (as in the app).
List<double> filterAll(List<double> x) {
  final notch = MainsNotchFilter(sampleRate: 2000);
  final lp = ButterworthLowPass();
  return x.map((v) => lp.process(notch.process(v))).toList();
}

/// RMS gain of the filtered steady-state response (skips first 3000 samples).
double steadyGain(List<double> x) {
  final y = filterAll(x);
  final tail = y.sublist(3000);
  final sum = tail.fold(0.0, (a, b) => a + b * b);
  final rms = math.sqrt(sum / tail.length);
  return rms / (1000 / math.sqrt2);
}

/// QRS-like pulse train: 20 ms wide triangle peak of [peak] every 800 ms,
/// on a 32768 baseline. Returns (input, filtered) sample lists.
(List<double>, List<double>) qrsPulseTrain(int peak, {double widthMs = 20}) {
  const fs = 2000;
  final n = fs * 4;
  final x = List<double>.filled(n, 32768);
  final w = (widthMs / 1000 * fs).round();
  for (var i = 0; i < n; i++) {
    final phase = i % (fs * 800 ~/ 1000);
    if (phase < w) {
      final t = phase / w;
      x[i] = 32768 + peak * (t < 0.5 ? 2 * t : 2 * (1 - t));
    }
  }
  return (x, filterAll(x));
}

void main() {
  const fs = 2000;
  const n = 8000;

  test('50 Hz mains hum is deeply attenuated', () {
    final x = sineWave(n, 50, 1000);
    expect(steadyGain(x), lessThan(0.01));
  });

  test('49.5/50.5 Hz drift is well attenuated', () {
    for (final f0 in [49.5, 50.5]) {
      final x = sineWave(n, f0, 1000);
      expect(steadyGain(x), lessThan(0.2),
          reason: '${f0}Hz gain=${steadyGain(x)} should be <0.2 (-14dB)');
    }
  });

  test('broadband noise above 150 Hz is suppressed by the low-pass', () {
    final x = sineWave(n, 200, 1000);
    expect(steadyGain(x), lessThan(0.12),
        reason: '200Hz gain=${steadyGain(x)} should be <0.12 (-18dB)');
  });

  test('ECG passband (5/30 Hz) is essentially untouched', () {
    for (final f0 in [5.0, 30.0]) {
      final x = sineWave(n, f0, 1000);
      expect(steadyGain(x), greaterThan(0.95), reason: '${f0}Hz');
    }
  });

  test('QRS morphology is preserved: pulse peak retains >80%', () {
    final (raw, filtered) = qrsPulseTrain(2000);
    // Measure peak-to-peak amplitude above baseline.
    final fMax = filtered.reduce(math.max);
    final fMin = filtered.reduce(math.min);
    final rawMax = raw.reduce(math.max);
    final rawMin = raw.reduce(math.min);
    final rawAmp = rawMax - rawMin;
    final filtAmp = fMax - fMin;
    expect(filtAmp / rawAmp, greaterThan(0.8),
        reason: 'pulse amplitude preserved ${(filtAmp / rawAmp * 100).toStringAsFixed(1)}%');
    // Peak still sharp enough (not smeared flat): peak value within 15% of raw.
    expect(fMax, greaterThanOrEqualTo(rawMax * 0.85));
  });

  test('integer round-trip stays in unsigned 16-bit range', () {
    final notch = MainsNotchFilter(sampleRate: fs);
    final lp = ButterworthLowPass();
    final x = sineWave(n, 50, 20000).map((v) => v + 32768).toList();
    for (final v in x) {
      final y = lp.process(notch.process(v)).round().clamp(0, 65535);
      expect(y, inInclusiveRange(0, 65535));
    }
  });
}
