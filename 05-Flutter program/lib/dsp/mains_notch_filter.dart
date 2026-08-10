import 'dart:math' as math;

/// Single-frequency mains (power-line) notch filter.
///
/// RBJ audio-EQ biquad notch, [stages] cascaded sections (transposed direct
/// form II) for extra depth. This is the industry-standard way to remove
/// 50/60 Hz line hum from ECG: ONE narrow, deep notch — not a harmonic bank —
/// because mains harmonics are handled by the analog front end, and wide
/// notches damage QRS high-frequency content.
///
/// Defaults (Q=20, 2 stages) at 2000 Hz:
///   50 Hz            -> >80 dB attenuation (numerically ~0)
///   49.5/50.5 Hz     -> ~ -17 dB (handles slight mains drift)
///   49/51 Hz         -> ~ -8 dB
///   ECG passband     -> 0 dB (untouched)
class MainsNotchFilter {
  MainsNotchFilter({
    required int sampleRate,
    double freq = 50.0,
    double q = 20.0,
    int stages = 2,
  }) {
    _sections = List.generate(
      stages,
      (_) => _BiquadNotchSection(sampleRate: sampleRate, freq: freq, q: q),
    );
  }

  late final List<_BiquadNotchSection> _sections;

  double process(double x) {
    for (final s in _sections) {
      x = s.process(x);
    }
    return x;
  }

  void reset() {
    for (final s in _sections) {
      s.reset();
    }
  }
}

/// One biquad notch section (RBJ, transposed direct form II):
///
///   y[n] = b0*x[n] + z1[n]
///   z1   = b1*x[n] - a1*y[n] + z2
///   z2   = b2*x[n] - a2*y[n]
class _BiquadNotchSection {
  _BiquadNotchSection({
    required int sampleRate,
    required double freq,
    required double q,
  }) {
    final w0 = 2 * math.pi * freq / sampleRate;
    final alpha = math.sin(w0) / (2 * q);
    final cosW0 = math.cos(w0);
    final a0 = 1 + alpha;

    _b0 = 1 / a0;
    _b1 = (-2 * cosW0) / a0;
    _b2 = 1 / a0;
    _a1 = (-2 * cosW0) / a0;
    _a2 = (1 - alpha) / a0;
  }

  late final double _b0, _b1, _b2, _a1, _a2;
  double _z1 = 0, _z2 = 0;

  double process(double x) {
    final y = _b0 * x + _z1;
    _z1 = _b1 * x - _a1 * y + _z2;
    _z2 = _b2 * x - _a2 * y;
    return y;
  }

  void reset() {
    _z1 = 0;
    _z2 = 0;
  }
}
