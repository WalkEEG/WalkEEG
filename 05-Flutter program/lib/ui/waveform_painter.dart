import 'dart:math' as math;

import 'package:flutter/material.dart';

class WaveformPainter extends CustomPainter {
  WaveformPainter({
    required this.series,
    required this.colors,
    this.yMin = 0,
    this.yMax = 32767,
    this.acMode = false,
    this.beatFracs = const [],
  });

  final List<List<int>> series;
  final List<Color> colors;
  final double yMin;
  final double yMax;

  /// AC-coupled autoscale display (monitor style): each channel is centered
  /// on its own mean and scaled so its peak-to-peak span fills the plot.
  final bool acMode;

  /// QRS beat positions as fractions of the visible window (0..1), drawn as
  /// vertical tick markers at the top of the plot.
  final List<double> beatFracs;

  static const double _axisPadLeft = 44;
  static const double _axisPadBottom = 4;
  static const double _axisPadTop = 4;

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = const Color(0xFF0E1A1F);
    canvas.drawRect(Offset.zero & size, bg);

    final plot = Rect.fromLTRB(
      _axisPadLeft,
      _axisPadTop,
      size.width,
      size.height - _axisPadBottom,
    );
    if (plot.width <= 0 || plot.height <= 0) return;

    final range = (yMax - yMin).abs().clamp(1.0, double.infinity);
    final axis = Paint()
      ..color = const Color(0xAAFFFFFF)
      ..strokeWidth = 1.2;
    final grid = Paint()
      ..color = const Color(0x28FFFFFF)
      ..strokeWidth = 1;
    final tick = Paint()
      ..color = const Color(0xAAFFFFFF)
      ..strokeWidth = 1.2;

    // Y axis line
    canvas.drawLine(
      Offset(plot.left, plot.top),
      Offset(plot.left, plot.bottom),
      axis,
    );

    final tp = TextPainter(textDirection: TextDirection.ltr);
    const tickCount = 4;
    for (var i = 0; i <= tickCount; i++) {
      final t = i / tickCount;
      final value = yMax - (yMax - yMin) * t;
      final y = plot.top + plot.height * t;

      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), grid);
      canvas.drawLine(Offset(plot.left - 5, y), Offset(plot.left, y), tick);

      if (acMode) {
        // Numeric scale is meaningless when each channel autoscales.
        continue;
      }

      tp.text = TextSpan(
        text: value.round().toString(),
        style: const TextStyle(
          color: Color(0xCCFFFFFF),
          fontSize: 10,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      );
      tp.layout(minWidth: 0, maxWidth: _axisPadLeft - 8);
      final labelY = (y - tp.height / 2).clamp(0.0, size.height - tp.height);
      tp.paint(canvas, Offset(_axisPadLeft - 8 - tp.width, labelY));
    }

    if (acMode) {
      tp.text = const TextSpan(
        text: 'AC',
        style: TextStyle(
          color: Color(0xCCFFFFFF),
          fontSize: 10,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      );
      tp.layout(minWidth: 0, maxWidth: _axisPadLeft - 8);
      tp.paint(canvas, Offset(_axisPadLeft - 8 - tp.width, 0));
    }

    // X baseline
    canvas.drawLine(
      Offset(plot.left, plot.bottom),
      Offset(plot.right, plot.bottom),
      axis,
    );

    // Vertical grid: 10 divisions (oscilloscope style)
    for (var i = 0; i <= 10; i++) {
      final x = plot.left + plot.width * i / 10;
      canvas.drawLine(Offset(x, plot.top), Offset(x, plot.bottom), grid);
    }

    // QRS beat markers (vertical ticks at the top edge).
    final beatPaint = Paint()
      ..color = const Color(0xFFFF6B6B)
      ..strokeWidth = 2;
    for (final f in beatFracs) {
      final x = plot.left + f * plot.width;
      canvas.drawLine(
        Offset(x, plot.top),
        Offset(x, plot.top + 10),
        beatPaint,
      );
    }

    for (var s = 0; s < series.length; s++) {
      final samples = series[s];
      if (samples.length < 2) continue;

      final paint = Paint()
        ..color = colors[s % colors.length]
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke
        ..isAntiAlias = true;

      // AC-coupled autoscale: center on mean, span fills 90% of plot height.
      final double mean;
      final double span;
      if (acMode) {
        final stats = acStats(samples);
        mean = stats.$1;
        span = stats.$2;
      } else {
        mean = yMin;
        span = range;
      }
      final centerY = plot.top + plot.height / 2;
      final amp = acMode ? plot.height * 0.9 : plot.height;

      final path = Path();
      final n = samples.length;
      final dx = plot.width / (n - 1);

      for (var i = 0; i < n; i++) {
        final v = samples[i].toDouble().clamp(yMin, yMax);
        final x = plot.left + i * dx;
        final y = acMode
            ? centerY - ((v - mean) / span) * amp / 2
            : plot.bottom - ((v - yMin) / range) * plot.height;
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant WaveformPainter oldDelegate) => true;
}

/// Downsample for drawing so UI stays smooth at 2 kHz.
List<int> downsample(List<int> src, int maxPoints) {
  if (src.length <= maxPoints) return List<int>.from(src);
  final out = <int>[];
  final step = src.length / maxPoints;
  for (var i = 0; i < maxPoints; i++) {
    final idx = math.min(src.length - 1, (i * step).floor());
    out.add(src[idx]);
  }
  return out;
}

/// AC-coupled autoscale stats for a sample set: (mean, peak-to-peak span).
/// Span is floored at 1 so division never explodes.
(double, double) acStats(List<int> samples) {
  if (samples.isEmpty) return (0, 1);
  var sum = 0;
  var mn = samples.first;
  var mx = samples.first;
  for (final v in samples) {
    sum += v;
    if (v < mn) mn = v;
    if (v > mx) mx = v;
  }
  final span = math.max(mx - mn, 1).toDouble();
  return (sum / samples.length, span);
}
