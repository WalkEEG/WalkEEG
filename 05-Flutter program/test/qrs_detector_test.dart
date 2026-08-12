import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:mobile_walkeeg/dsp/qrs_detector.dart';

/// Synthesizes [seconds] of ECG-like signal: Gaussian QRS spikes at [bpm]
/// on a 32768 baseline, plus optional 50 Hz mains hum.
List<double> synthEcg({
  required int seconds,
  required int bpm,
  double qrsAmp = 3000,
  double humAmp = 400,
  double baseline = 32768,
}) {
  const fs = 2000;
  final n = seconds * fs;
  final rr = 60 * fs / bpm; // samples per beat
  final out = List<double>.filled(n, baseline);
  for (var i = 0; i < n; i++) {
    final tInBeat = i % rr;
    // Narrow Gaussian pulse ~ 12 ms wide.
    final gauss =
        qrsAmp * math.exp(-math.pow((tInBeat - 12) / 8, 2).toDouble());
    final hum = humAmp * math.sin(2 * math.pi * 50 * i / fs);
    out[i] = baseline + gauss + hum;
  }
  return out;
}

void main() {
  const fs = 2000;

  test('detects all beats at 60 bpm with 50Hz hum', () {
    final detector = QrsDetector(sampleRate: fs);
    final x = synthEcg(seconds: 12, bpm: 60); // 12 beats in 12 s
    var beats = 0;
    for (final v in x) {
      if (detector.process(v)) beats++;
    }
    // Allow the first ~2 s for the adaptive threshold to learn.
    expect(beats, greaterThanOrEqualTo(9),
        reason: 'detected $beats beats, expected ~10 (12 minus learning)');
    expect(beats, lessThanOrEqualTo(13), reason: 'no excessive false beats');
    expect(detector.bpm, inInclusiveRange(55, 65));
  });

  test('tracks 90 bpm', () {
    final detector = QrsDetector(sampleRate: fs);
    final x = synthEcg(seconds: 12, bpm: 90);
    var beats = 0;
    for (final v in x) {
      if (detector.process(v)) beats++;
    }
    expect(beats, greaterThanOrEqualTo(15),
        reason: 'detected $beats, expected ~16');
    expect(detector.bpm, inInclusiveRange(85, 95));
  });

  test('rejects flat noise (no false positives)', () {
    final detector = QrsDetector(sampleRate: fs);
    final x = List<double>.filled(8 * fs, 32768); // pure baseline
    var beats = 0;
    for (final v in x) {
      if (detector.process(v)) beats++;
    }
    expect(beats, 0, reason: 'flat signal must not trigger');
  });

  test('SDNN/RMSSD computed from RR intervals', () {
    // Irregular rhythm: alternate 0.8s and 1.0s RR per BEAT.
    final x = <double>[];
    var beat = 0;
    final fsD = fs.toDouble();
    while (x.length < 20 * fs) {
      final rr = beat % 2 == 0 ? 0.8 : 1.0;
      beat++;
      final n = (rr * fsD).round();
      for (var i = 0; i < n; i++) {
        x.add(32768 + (i == 10 ? 3000 : 0));
      }
    }
    final detector2 = QrsDetector(sampleRate: fs);
    for (final v in x) {
      detector2.process(v);
    }
    expect(detector2.sdnnMs, isNotNull);
    expect(detector2.rmssdMs, isNotNull);
    expect(detector2.sdnnMs!, greaterThan(20)); // clear variability present
  });
}
