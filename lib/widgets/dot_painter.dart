import 'package:flutter/material.dart';
import 'package:flutter_face_tracking_exercise_app/constants/constants.dart';

class DotPainter extends CustomPainter {
  final Offset offset;

  DotPainter(this.offset);

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = Colors.red
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 10.0;

    canvas.drawCircle(offset, AppConstants.dotRadius, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
