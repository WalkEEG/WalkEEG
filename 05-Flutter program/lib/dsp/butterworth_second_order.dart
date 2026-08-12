import 'dart:math' as math;

/// Generic 2nd-order Butterworth filter (low-pass or high-pass), computed
/// from the analog prototype via bilinear transform with prewarping.
///
/// Used for the ECG baseline-drift high-pass (0.5 Hz) and the Pan-Tompkins
/// QRS band-pass stages (5 Hz high-pass + 15 Hz low-pass) at 2 kHz.
class ButterworthSecondOrder {
  ButterworthSecondOrder.lowPass({
    required int sampleRate,
    required double cutoffHz,
  }) : _hp = false {
    _init(sampleRate, cutoffHz);
  }

  ButterworthSecondOrder.highPass({
    required int sampleRate,
    required double cutoffHz,
  }) : _hp = true {
    _init(sampleRate, cutoffHz);
  }

  final bool _hp;
  late final double _b0, _b1, _b2, _a1, _a2;
  double _z1 = 0, _z2 = 0;

  void _init(int sampleRate, double cutoffHz) {
    final wc = math.tan(math.pi * cutoffHz / sampleRate);
    final sigma = -math.sqrt(2) / 2; // 2nd-order Butterworth pole (re)
    final omega = math.sqrt(2) / 2; // 2nd-order Butterworth pole (im)
    final s2 = sigma * sigma + omega * omega;
    final a0 = 1 - 2 * sigma * wc + s2 * wc * wc;

    if (_hp) {
      _b0 = 1 / a0;
      _b1 = -2 / a0;
      _b2 = 1 / a0;
    } else {
      _b0 = wc * wc / a0;
      _b1 = 2 * wc * wc / a0;
      _b2 = wc * wc / a0;
    }
    _a1 = 2 * (s2 * wc * wc - 1) / a0;
    _a2 = (1 + 2 * sigma * wc + s2 * wc * wc) / a0;
  }

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
