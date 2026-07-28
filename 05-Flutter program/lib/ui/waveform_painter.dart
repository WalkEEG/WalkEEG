import 'dart:math' as math;

import 'package:flutter/material.dart';

class WaveformPainter extends CustomPainter {
  WaveformPainter({
    required this.series,
    required this.colors,
    this.yMin = 0,
    this.yMax = 32767,
  });

  final List<List<int>> series;
  final List<Color> colors;
  final double yMin;
  final double yMax;

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

    // X baseline
    canvas.drawLine(
      Offset(plot.left, plot.bottom),
      Offset(plot.right, plot.bottom),
      axis,
    );

    for (var s = 0; s < series.length; s++) {
      final samples = series[s];
      if (samples.length < 2) continue;

      final paint = Paint()
        ..color = colors[s % colors.length]
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke
        ..isAntiAlias = true;

      final path = Path();
      final n = samples.length;
      final dx = plot.width / (n - 1);

      for (var i = 0; i < n; i++) {
        final v = samples[i].toDouble().clamp(yMin, yMax);
        final x = plot.left + i * dx;
        final y = plot.bottom - ((v - yMin) / range) * plot.height;
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
