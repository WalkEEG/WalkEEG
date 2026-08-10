import 'package:flutter_test/flutter_test.dart';

import 'package:mobile_walkeeg/ui/waveform_painter.dart';

void main() {
  test('acStats: mean and span of a small-AC signal', () {
    // Baseline 32768 with a small ±300 fluctuation (like filtered ECG).
    final samples = <int>[];
    for (var i = 0; i < 1000; i++) {
      samples.add(32768 + (i % 2 == 0 ? -300 : 300));
    }
    final (mean, span) = acStats(samples);
    expect(mean, closeTo(32768, 0.5));
    expect(span, 600);
  });

  test('acStats: empty input is safe', () {
    final (mean, span) = acStats(<int>[]);
    expect(mean, 0);
    expect(span, 1);
  });

  test('acStats: flat signal has unit span (no division by zero)', () {
    final (_, span) = acStats(List.filled(100, 20000));
    expect(span, 1);
  });

  test('acStats: single sample', () {
    final (mean, span) = acStats(<int>[12345]);
    expect(mean, 12345);
    expect(span, 1);
  });
}
