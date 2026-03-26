import 'dart:ui';
import 'package:flutter/material.dart';

class ScanOverlay extends StatelessWidget {
  const ScanOverlay({super.key});
  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _ScanPainter(),
      ),
    );
  }
}

class _ScanPainter extends CustomPainter {
  final _paint = Paint()
    ..color = const Color(0xFF58A6FF)
    ..strokeWidth = 5
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  @override
  void paint(Canvas canvas, Size size) {
    final inset = 24.0;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(inset, inset + 99, size.width - inset * 2, size.height - inset * 2 - 225),
      const Radius.circular(24),
    );

    // corners
    final corner = 46.0;
    // top-left
    canvas.drawPath(_cornerPath(rect.left, rect.top, true, true, corner), _paint);
    // top-right
    canvas.drawPath(_cornerPath(rect.right, rect.top, false, true, corner), _paint);
    // bottom-left
    canvas.drawPath(_cornerPath(rect.left, rect.bottom, true, false, corner), _paint);
    // bottom-right
    canvas.drawPath(_cornerPath(rect.right, rect.bottom, false, false, corner), _paint);

    // // horizontal guide line (middle)
    // final midY = rect.top + rect.height * .42;
    // canvas.drawLine(Offset(rect.left + 20, midY), Offset(rect.right - 20, midY),
    //     _paint..strokeWidth = 4);
  }

  Path _cornerPath(double x, double y, bool left, bool top, double len) {
    final p = Path();
    final dx = left ? 1 : -1;
    final dy = top ? 1 : -1;
    p.moveTo(x, y + 24 * dy);
    p.quadraticBezierTo(x, y, x + 24 * dx, y);
    p.moveTo(x + len * dx, y);
    p.lineTo(x + 24 * dx, y);
    p.moveTo(x, y + len * dy);
    p.lineTo(x, y + 24 * dy);
    return p;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
