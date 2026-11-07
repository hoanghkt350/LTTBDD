import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The same vector mark is used in the app and to export launcher icons.
class PawPalsLogo extends StatelessWidget {
  const PawPalsLogo({super.key, this.size = 104});

  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Logo PawPals: dấu chân và trái tim',
    image: true,
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: const PawPalsLogoPainter()),
    ),
  );
}

class PawPalsLogoPainter extends CustomPainter {
  const PawPalsLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 128, size.height / 128);
    final background = RRect.fromRectAndRadius(
      const Rect.fromLTWH(0, 0, 128, 128),
      const Radius.circular(36),
    );
    canvas.drawRRect(
      background,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF538D78), AppTheme.darkBackground],
        ).createShader(const Rect.fromLTWH(0, 0, 128, 128)),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(6, 6, 116, 116),
        const Radius.circular(31),
      ),
      Paint()
        ..color = Colors.white.withValues(alpha: .12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    final paw = Paint()..color = const Color(0xFFF5F6E9);
    void toe(double x, double y, double w, double h, double rotation) {
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rotation * math.pi / 180);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: w, height: h),
        paw,
      );
      canvas.restore();
    }

    toe(33, 53, 15, 22, -28);
    toe(52, 36, 16, 24, -9);
    toe(76, 36, 16, 24, 9);
    toe(95, 53, 15, 22, 28);
    final pad = Path()
      ..moveTo(64, 55)
      ..cubicTo(52, 55, 47, 66, 38, 77)
      ..cubicTo(25, 94, 41, 106, 54, 99)
      ..quadraticBezierTo(64, 94, 74, 99)
      ..cubicTo(87, 106, 103, 94, 90, 77)
      ..cubicTo(81, 66, 76, 55, 64, 55)
      ..close();
    canvas.drawPath(pad, paw);
    final heart = Path()
      ..moveTo(64, 89)
      ..cubicTo(61, 86, 51, 79, 51, 73)
      ..cubicTo(51, 65, 60, 63, 64, 70)
      ..cubicTo(68, 63, 77, 65, 77, 73)
      ..cubicTo(77, 79, 67, 86, 64, 89)
      ..close();
    canvas.drawPath(heart, Paint()..color = AppTheme.primary);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant PawPalsLogoPainter oldDelegate) => false;
}
