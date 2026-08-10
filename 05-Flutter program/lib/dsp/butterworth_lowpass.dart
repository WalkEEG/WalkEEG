/// 4th-order Butterworth low-pass filter (fc = 100 Hz @ 2 kHz).
///
/// This is the standard "band-limit" stage used in ECG processing
/// (AAMI EC57 / bedside-monitor practice): it smooths broadband noise
/// (muscle artifact, switching noise) above the ECG band while preserving
/// waveform morphology below ~90 Hz. Combined with a single 50 Hz notch it
/// replaces ad-hoc harmonic notches that would otherwise blunt QRS peaks.
///
/// Coefficients computed via bilinear transform of the analog prototype
/// (fc=100 Hz, fs=2000 Hz, prewarped), 2 cascaded biquad sections:
///   section 1: b=[0.0190368316, 0.0380736632, 0.0190368316] a=[1, -1.4796742169, 0.5558215433]
///   section 2: b=[0.0218838520, 0.0437677039, 0.0218838520] a=[1, -1.7009643319, 0.7884997398]
/// Response: 5/30/50 Hz = 0 dB, 100 Hz = -3 dB, 150 Hz = -14.6 dB,
/// 200 Hz = -25 dB, 400 Hz = -53 dB.
class ButterworthLowPass {
  ButterworthLowPass();

  // b0, b1, b2, a1, a2 per section (a0 normalized to 1).
  static const List<List<double>> _coeffs = [
    [0.0190368316, 0.0380736632, 0.0190368316, -1.4796742169, 0.5558215433],
    [0.0218838520, 0.0437677039, 0.0218838520, -1.7009643319, 0.7884997398],
  ];

  final List<_State> _states = [
    _State(),
    _State(),
  ];

  double process(double x) {
    for (var i = 0; i < _coeffs.length; i++) {
      final c = _coeffs[i];
      final s = _states[i];
      final y = c[0] * x + s.z1;
      s.z1 = c[1] * x - c[3] * y + s.z2;
      s.z2 = c[2] * x - c[4] * y;
      x = y;
    }
    return x;
  }

  void reset() {
    for (final s in _states) {
      s.z1 = 0;
      s.z2 = 0;
    }
  }
}

class _State {
  double z1 = 0;
  double z2 = 0;
}
