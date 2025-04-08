import 'package:flutter/material.dart';

class ModelResultsWidget extends StatelessWidget {
  final bool modelAvailable;
  final bool modelLoaded;
  final String currentActivity;
  final double confidenceScore;

  const ModelResultsWidget({
    super.key,
    required this.modelAvailable,
    required this.modelLoaded,
    required this.currentActivity,
    required this.confidenceScore,
  });

  @override
  Widget build(BuildContext context) {
    if (!modelAvailable) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(
          179,
        ), // 0.7 opacity converted to alpha value
        borderRadius: BorderRadius.circular(8),
      ),
      child:
          modelLoaded
              ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Activity Prediction',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    currentActivity,
                    style: TextStyle(
                      color:
                          confidenceScore > 0.7
                              ? Colors.green[300]
                              : Colors.yellow[300],
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Linear progress bar for confidence
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: confidenceScore,
                      backgroundColor: Colors.grey[700],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        confidenceScore > 0.7
                            ? Colors.green[300]!
                            : Colors.yellow[300]!,
                      ),
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Confidence: ${(confidenceScore * 100).toStringAsFixed(1)}%',
                    style: TextStyle(
                      color: Colors.grey[300],
                      fontSize: 14,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              )
              : const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(width: 16),
                  Flexible(
                    child: Text(
                      'Loading model...',
                      style: TextStyle(
                        color: Colors.white,
                        decoration: TextDecoration.none,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
    );
  }
}
