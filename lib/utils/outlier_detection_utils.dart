/// Utility class for outlier detection using Median Absolute Deviation (MAD)
class OutlierDetectionUtils {
  /// Detects and replaces outliers from a list of coordinate points using MAD
  ///
  /// [coordinates] is a list of [x,y] coordinate pairs
  /// [threshold] is the number of MADs beyond which a point is considered an outlier
  /// Returns coordinates with outliers replaced by interpolated values
  static List<List<double>> filterOutliersMAD(
    List<List<double>> coordinates, {
    double threshold = 3.0,
  }) {
    if (coordinates.isEmpty || coordinates.length < 4) {
      return coordinates; // Not enough data to meaningfully detect outliers
    }

    try {
      // Extract x and y coordinates into separate lists for analysis
      List<double> xCoords = coordinates.map((point) => point[0]).toList();
      List<double> yCoords = coordinates.map((point) => point[1]).toList();

      // Get outlier flags for each dimension
      List<bool> xOutliers = _detectOutliersMAD(xCoords, threshold: threshold);
      List<bool> yOutliers = _detectOutliersMAD(yCoords, threshold: threshold);

      // Create a copy of the original coordinates
      List<List<double>> processedCoordinates = List.from(coordinates);

      // Replace outliers with interpolated values
      _replaceOutliers(
        processedCoordinates,
        xOutliers,
        0,
      ); // Replace x-coordinate outliers
      _replaceOutliers(
        processedCoordinates,
        yOutliers,
        1,
      ); // Replace y-coordinate outliers

      return processedCoordinates;
    } catch (e) {
      print('Error in filterOutliersMAD: $e');
      // In case of any error, return the original data
      return coordinates;
    }
  }

  /// Replace outliers with interpolated values from neighboring points
  static void _replaceOutliers(
    List<List<double>> coordinates,
    List<bool> outliers,
    int index,
  ) {
    if (coordinates.isEmpty || outliers.isEmpty) return;

    // First pass: simple median replacement for isolated outliers
    double median = _calculateMedian(
      coordinates.map((point) => point[index]).toList()..sort(),
    );

    for (int i = 0; i < outliers.length; i++) {
      if (!outliers[i]) continue; // Skip non-outliers

      // Find closest non-outlier points before and after
      int prevIdx = -1;
      int nextIdx = -1;

      // Search backward for previous valid point
      for (int j = i - 1; j >= 0; j--) {
        if (!outliers[j]) {
          prevIdx = j;
          break;
        }
      }

      // Search forward for next valid point
      for (int j = i + 1; j < outliers.length; j++) {
        if (!outliers[j]) {
          nextIdx = j;
          break;
        }
      }

      // Replace the outlier with an appropriate value
      if (prevIdx != -1 && nextIdx != -1) {
        // Interpolate between previous and next valid points
        double prevVal = coordinates[prevIdx][index];
        double nextVal = coordinates[nextIdx][index];
        double factor = (i - prevIdx) / (nextIdx - prevIdx);
        coordinates[i][index] = prevVal + (nextVal - prevVal) * factor;
      } else if (prevIdx != -1) {
        // Use the previous valid point
        coordinates[i][index] = coordinates[prevIdx][index];
      } else if (nextIdx != -1) {
        // Use the next valid point
        coordinates[i][index] = coordinates[nextIdx][index];
      } else {
        // No valid neighbors, use median
        coordinates[i][index] = median;
      }
    }
  }

  /// Internal method to detect outliers in a single dimension using MAD
  static List<bool> _detectOutliersMAD(
    List<double> values, {
    double threshold = 3.0,
  }) {
    try {
      // Calculate median
      List<double> sortedValues = List.from(values)..sort();
      double median = _calculateMedian(sortedValues);

      // Calculate absolute deviations from median
      List<double> absoluteDeviations =
          values.map((v) => (v - median).abs()).toList();

      // Calculate MAD (Median Absolute Deviation)
      absoluteDeviations.sort();
      double mad = _calculateMedian(absoluteDeviations);

      // Handle case where MAD is zero (all values are identical)
      if (mad < 0.0001) {
        // Use small epsilon instead of exactly 0
        return List.filled(values.length, false);
      }

      // Normalize MAD (multiply by 1.4826 for normal distribution)
      double normalizedMAD = mad * 1.4826;

      // Detect outliers
      List<bool> outliers =
          values
              .map((v) => ((v - median).abs() / normalizedMAD) > threshold)
              .toList();

      // Limit the number of outliers to detect (max 20% of the data)
      final int maxOutliers = (values.length * 0.2).round();
      if (outliers.where((isOutlier) => isOutlier).length > maxOutliers) {
        // If too many outliers detected, keep only the most extreme ones
        List<_ValueWithIndex> deviations = [];
        for (int i = 0; i < values.length; i++) {
          double deviation = ((values[i] - median).abs() / normalizedMAD);
          deviations.add(_ValueWithIndex(deviation, i));
        }

        // Sort by deviation (descending)
        deviations.sort((a, b) => b.value.compareTo(a.value));

        // Reset outliers
        outliers = List.filled(values.length, false);

        // Mark only the top N as outliers
        for (int i = 0; i < maxOutliers && i < deviations.length; i++) {
          if (deviations[i].value > threshold) {
            outliers[deviations[i].index] = true;
          }
        }
      }

      return outliers;
    } catch (e) {
      print('Error in _detectOutliersMAD: $e');
      // In case of any error, mark no values as outliers
      return List.filled(values.length, false);
    }
  }

  /// Calculate median of a sorted list
  static double _calculateMedian(List<double> sortedValues) {
    if (sortedValues.isEmpty) return 0;

    int middle = sortedValues.length ~/ 2;
    if (sortedValues.length % 2 == 1) {
      return sortedValues[middle];
    } else {
      return (sortedValues[middle - 1] + sortedValues[middle]) / 2.0;
    }
  }
}

/// Helper class to keep track of values and their original indices
class _ValueWithIndex {
  final double value;
  final int index;

  _ValueWithIndex(this.value, this.index);
}
