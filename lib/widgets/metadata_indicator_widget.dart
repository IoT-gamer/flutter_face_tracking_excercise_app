import 'package:flutter/material.dart';

class MetadataIndicatorWidget extends StatelessWidget {
  final int fps;
  final int queueLength;
  final int maxQueueLength;
  final bool modelLoaded;

  const MetadataIndicatorWidget({
    super.key,
    required this.fps,
    required this.queueLength,
    required this.maxQueueLength,
    required this.modelLoaded,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(179), // Approx 0.7 opacity
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            'FPS: $fps',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              decoration: TextDecoration.none,
            ),
          ),
          Text(
            'Points: $queueLength/$maxQueueLength',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              decoration: TextDecoration.none,
            ),
          ),
          if (modelLoaded)
            const Text(
              'Model: Active',
              style: TextStyle(
                color: Colors.green,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                decoration: TextDecoration.none,
              ),
            ),
        ],
      ),
    );
  }
}
