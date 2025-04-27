import 'package:flutter/material.dart';

class FrequencyBarChartWidget extends StatelessWidget {
  final double dominantFrequency;
  final double maxAmplitude;
  final List<double> frequencies;
  final List<double> amplitudes;
  final bool isVisible;

  const FrequencyBarChartWidget({
    super.key,
    required this.dominantFrequency,
    required this.maxAmplitude,
    required this.frequencies,
    required this.amplitudes,
    required this.isVisible,
  });

  @override
  Widget build(BuildContext context) {
    if (!isVisible || dominantFrequency <= 0) {
      return const SizedBox.shrink();
    }

    // Calculate steps per minute based on Hz
    final double stepsPerMinute = dominantFrequency * 60;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(179), // 0.7 opacity
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Walking Frequency:',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.none,
                ),
              ),
              Text(
                '${dominantFrequency.toStringAsFixed(2)} Hz',
                style: const TextStyle(
                  color: Colors.orange,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                '${stepsPerMinute.toStringAsFixed(0)} steps/min',
                style: const TextStyle(
                  color: Colors.cyan,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Frequency meter visual representation
          Container(
            height: 24,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                // Dynamic width based on dominant frequency
                // Assuming walking frequency is typically 0-3 Hz
                Container(
                  width:
                      (dominantFrequency / 3.0).clamp(0.0, 1.0) *
                      (MediaQuery.of(context).size.width - 72),
                  height: 24,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.green, Colors.yellow, Colors.orange],
                      stops: const [0.3, 0.7, 1.0],
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          // Scale labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                '0 Hz',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 10,
                  decoration: TextDecoration.none,
                ),
              ),
              Text(
                '1 Hz',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 10,
                  decoration: TextDecoration.none,
                ),
              ),
              Text(
                '2 Hz',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 10,
                  decoration: TextDecoration.none,
                ),
              ),
              Text(
                '3+ Hz',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 10,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Mini frequency spectrum visualization if we have amplitude data
          if (amplitudes.isNotEmpty && amplitudes.length > 5)
            Container(
              height: 60,
              width: double.infinity,
              padding: const EdgeInsets.only(top: 5),
              child: CustomPaint(
                painter: FrequencySpectrumPainter(
                  frequencies: frequencies,
                  amplitudes: amplitudes,
                  dominantFrequency: dominantFrequency,
                ),
                size: Size(MediaQuery.of(context).size.width - 72, 60),
              ),
            ),
          const SizedBox(height: 8),
          Text(
            'Typical walking: 1.5-2.5 Hz (90-150 steps/min)',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 12,
              fontStyle: FontStyle.italic,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }
}

class FrequencySpectrumPainter extends CustomPainter {
  final List<double> frequencies;
  final List<double> amplitudes;
  final double dominantFrequency;

  FrequencySpectrumPainter({
    required this.frequencies,
    required this.amplitudes,
    required this.dominantFrequency,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (frequencies.isEmpty || amplitudes.isEmpty) return;

    const int maxFreqDisplay = 5; // Only show spectrum up to 5 Hz

    // Find the maximum amplitude for normalization
    final double maxAmp = amplitudes.reduce((a, b) => a > b ? a : b);

    // Find index of max frequency to display
    int maxIndex = 0;
    for (int i = 0; i < frequencies.length; i++) {
      if (frequencies[i] > maxFreqDisplay) {
        maxIndex = i;
        break;
      }
    }

    if (maxIndex == 0 && frequencies.isNotEmpty) {
      maxIndex = frequencies.length - 1;
    }

    // Prepare paints
    final Paint linePaint =
        Paint()
          ..color = Colors.blue[300]!
          ..strokeWidth = 2.0
          ..style = PaintingStyle.stroke;

    final Paint dominantPaint =
        Paint()
          ..color = Colors.orange
          ..strokeWidth = 3.0
          ..style = PaintingStyle.stroke;

    final Paint fillPaint =
        Paint()
          ..color = Colors.blue.withOpacity(0.2)
          ..style = PaintingStyle.fill;

    // Calculate points for the spectrum
    final List<Offset> points = [];
    final Path fillPath = Path();

    // Add first point at origin
    points.add(Offset(0, size.height));
    fillPath.moveTo(0, size.height);

    // Calculate width per frequency bin
    final double widthPerBin = size.width / maxFreqDisplay;

    for (int i = 0; i < maxIndex; i++) {
      if (i < frequencies.length && i < amplitudes.length) {
        final double x = frequencies[i] * widthPerBin;

        // Normalize amplitude to fit in the height, invert because y grows downward
        final double normalizedAmp = amplitudes[i] / maxAmp;
        final double y = size.height - (normalizedAmp * size.height);

        points.add(Offset(x, y));
        fillPath.lineTo(x, y);
      }
    }

    // Complete the fill path
    fillPath.lineTo(points.last.dx, size.height);
    fillPath.close();

    // Draw the fill
    canvas.drawPath(fillPath, fillPaint);

    // Draw the line connecting all points
    for (int i = 0; i < points.length - 1; i++) {
      canvas.drawLine(points[i], points[i + 1], linePaint);
    }

    // Draw a vertical line at the dominant frequency
    if (dominantFrequency > 0 && dominantFrequency <= maxFreqDisplay) {
      final double x = dominantFrequency * widthPerBin;
      canvas.drawLine(Offset(x, size.height), Offset(x, 0), dominantPaint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
