import 'package:flutter/material.dart';

class OutlierVisualizationWidget extends StatelessWidget {
  final List<List<double>> originalCoordinates;
  final List<List<double>> filteredCoordinates;
  final List<bool> adjustedPoints;
  // State-based statistics
  final int totalPoints;
  final int totalOutliersDetected;
  final int currentOutliers;
  final double outlierPercentage;
  final bool showVisualization;

  const OutlierVisualizationWidget({
    super.key,
    required this.originalCoordinates,
    required this.filteredCoordinates,
    required this.adjustedPoints,
    this.totalPoints = 0,
    this.totalOutliersDetected = 0,
    this.currentOutliers = 0,
    this.outlierPercentage = 0.0,
    this.showVisualization = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!showVisualization || originalCoordinates.isEmpty) {
      return const SizedBox.shrink();
    }

    // Calculate percentage for current frame
    final currentPercentage =
        originalCoordinates.isNotEmpty
            ? (currentOutliers / originalCoordinates.length * 100)
                .toStringAsFixed(1)
            : '0.0';

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(179), // 0.7 opacity
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Outlier Detection (MAD)',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Current: $currentOutliers points ($currentPercentage%)',
            style: TextStyle(
              color: Colors.grey[300],
              fontSize: 12,
              decoration: TextDecoration.none,
            ),
          ),
          Text(
            'Total: $totalOutliersDetected of $totalPoints (${outlierPercentage.toStringAsFixed(1)}%)',
            style: TextStyle(
              color: Colors.grey[300],
              fontSize: 12,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 12),
          // Mini data visualization
          SizedBox(
            height: 100,
            child: CustomPaint(
              painter: CoordinatesPainter(
                originalCoordinates: originalCoordinates,
                filteredCoordinates: filteredCoordinates,
                adjustedPoints: adjustedPoints,
              ),
              size: Size.infinite,
            ),
          ),
          const SizedBox(height: 8),
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem(Colors.grey.withOpacity(0.7), 'Original'),
              const SizedBox(width: 16),
              _buildLegendItem(Colors.red, 'Outlier'),
              const SizedBox(width: 16),
              _buildLegendItem(Colors.green, 'Adjusted'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[300],
            fontSize: 12,
            decoration: TextDecoration.none,
          ),
        ),
      ],
    );
  }
}

class CoordinatesPainter extends CustomPainter {
  final List<List<double>> originalCoordinates;
  final List<List<double>> filteredCoordinates;
  final List<bool> adjustedPoints;

  CoordinatesPainter({
    required this.originalCoordinates,
    required this.filteredCoordinates,
    required this.adjustedPoints,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw background grid
    final gridPaint =
        Paint()
          ..color = Colors.grey.withOpacity(0.2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.5;

    // Draw horizontal grid lines
    for (int i = 0; i <= 4; i++) {
      final y = i * size.height / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Draw vertical grid lines
    for (int i = 0; i <= 4; i++) {
      final x = i * size.width / 4;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    // Draw connection lines between original and adjusted points
    if (adjustedPoints.isNotEmpty) {
      final linePaint =
          Paint()
            ..color = Colors.yellow.withOpacity(0.4)
            ..strokeWidth = 1.0;

      for (
        int i = 0;
        i < originalCoordinates.length && i < filteredCoordinates.length;
        i++
      ) {
        if (i < adjustedPoints.length && adjustedPoints[i]) {
          final originalX = originalCoordinates[i][0] * size.width;
          final originalY = originalCoordinates[i][1] * size.height;
          final filteredX = filteredCoordinates[i][0] * size.width;
          final filteredY = filteredCoordinates[i][1] * size.height;

          canvas.drawLine(
            Offset(originalX, originalY),
            Offset(filteredX, filteredY),
            linePaint,
          );
        }
      }
    }

    // Draw original points (gray)
    final originalPointPaint =
        Paint()
          ..color = Colors.grey.withOpacity(0.7)
          ..strokeWidth = 2.0;

    // Draw filtered points (green) and original outlier points (red)
    final outlierPointPaint =
        Paint()
          ..color = Colors.red
          ..strokeWidth = 2.0;

    final adjustedPointPaint =
        Paint()
          ..color = Colors.green
          ..strokeWidth = 2.0;

    // Draw all points
    for (int i = 0; i < originalCoordinates.length; i++) {
      final x = originalCoordinates[i][0] * size.width;
      final y = originalCoordinates[i][1] * size.height;

      bool isAdjusted = i < adjustedPoints.length && adjustedPoints[i];

      // Draw the original point
      if (isAdjusted) {
        // Draw the original outlier point in red
        canvas.drawCircle(Offset(x, y), 2, outlierPointPaint);
      } else {
        // Draw normal point in gray
        canvas.drawCircle(Offset(x, y), 2, originalPointPaint);
      }
    }

    // Draw adjusted points on top
    for (int i = 0; i < filteredCoordinates.length; i++) {
      if (i < adjustedPoints.length && adjustedPoints[i]) {
        final x = filteredCoordinates[i][0] * size.width;
        final y = filteredCoordinates[i][1] * size.height;
        canvas.drawCircle(Offset(x, y), 2, adjustedPointPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
