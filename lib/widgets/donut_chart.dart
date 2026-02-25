import 'dart:math';
import 'package:flutter/material.dart';

class DonutSlice {
  final double value;
  final Color color;
  final String label;
  const DonutSlice({required this.value, required this.color, required this.label});
}

class DonutChart extends StatelessWidget {
  final List<DonutSlice> slices;
  final double thickness;
  final String? centerText;

  const DonutChart({
    super.key,
    required this.slices,
    this.thickness = 18,
    this.centerText,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final size = min(box.maxWidth, 220.0);
      return Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(size),
            painter: _DonutPainter(slices: slices, thickness: thickness, bgColor: Theme.of(context).colorScheme.surfaceVariant),
          ),
          if (centerText != null)
            Text(
              centerText!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
        ],
      );
    });
  }
}

class _DonutPainter extends CustomPainter {
  final List<DonutSlice> slices;
  final double thickness;
  final Color bgColor;
  _DonutPainter({required this.slices, required this.thickness, required this.bgColor});

  @override
  void paint(Canvas canvas, Size size) {
    final total = slices.fold<double>(0, (s, e) => s + e.value);
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.butt;

    // background ring
    stroke.color = bgColor;
    canvas.drawArc(rect.deflate(thickness / 2), -pi / 2, 2 * pi, false, stroke);

    if (total <= 0) return;

    double start = -pi / 2;
    for (final s in slices) {
      if (s.value <= 0) continue;
      final sweep = (s.value / total) * 2 * pi;
      stroke.color = s.color;
      canvas.drawArc(rect.deflate(thickness / 2), start, sweep, false, stroke);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) {
    return old.slices != slices || old.thickness != thickness || old.bgColor != bgColor;
    }
}
