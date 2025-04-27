import 'package:fftea/fftea.dart';
import 'package:integral_isolates/integral_isolates.dart';

/// Service for calculating FFT (Fast Fourier Transform) on face tracking data using fftea package
class FFTService {
  static final StatefulIsolate _statefulIsolate = StatefulIsolate(
    backpressureStrategy: ReplaceBackpressureStrategy(),
  );

  /// Disposes the isolate
  void dispose() {
    _statefulIsolate.dispose();
  }

  /// Computes FFT of x-coordinate data and returns frequency with max amplitude
  ///
  /// [xCoordinates] list of x-coordinates
  /// [fps] frames per second for sampling rate calculation
  /// Returns a Future with a map containing frequency and amplitude data
  Future<Map<String, dynamic>> computeDominantFrequency(
    List<double> xCoordinates,
    int fps,
  ) async {
    try {
      // Calculate FFT in isolate for better performance
      return await _statefulIsolate.compute(_calculateFFT, {
        'coordinates': xCoordinates,
        'fps': fps,
      });
    } catch (e) {
      print('Error computing FFT: $e');
      return {
        'dominantFrequency': 0.0,
        'maxAmplitude': 0.0,
        'frequencies': <double>[],
        'amplitudes': <double>[],
      };
    }
  }

  /// Static method for calculating FFT in isolate using the fftea package
  static Future<Map<String, dynamic>> _calculateFFT(
    Map<dynamic, dynamic> params,
  ) async {
    List<double> coordinates = List<double>.from(params['coordinates']);
    int fps = params['fps'];

    // Need at least a few points for FFT
    if (coordinates.length < 4) {
      return {
        'dominantFrequency': 0.0,
        'maxAmplitude': 0.0,
        'frequencies': <double>[],
        'amplitudes': <double>[],
      };
    }

    try {
      // Remove mean (center the signal)
      double mean = coordinates.reduce((a, b) => a + b) / coordinates.length;
      List<double> centered = coordinates.map((x) => x - mean).toList();

      // Calculate next power of 2 for FFT efficiency
      int nextPow2 = _nextPowerOf2(centered.length);

      // Pad array if needed
      if (nextPow2 != centered.length) {
        centered = _padArray(centered, nextPow2);
      }

      // Create FFT instance
      final fft = FFT(centered.length);

      // Perform real FFT
      final freq = fft.realFft(centered);

      // Convert to magnitudes and frequencies
      final magnitudes = freq.magnitudes();

      // Calculate corresponding frequencies
      final frequencies = <double>[];
      for (int i = 0; i < magnitudes.length; i++) {
        // Convert bin index to Hz
        frequencies.add(i * fps / centered.length);
      }

      // Find the dominant frequency (maximum amplitude, excluding DC)
      double maxAmplitude = 0.0;
      double dominantFrequency = 0.0;

      // Start from index 1 to skip DC component (0 Hz)
      for (int i = 1; i < magnitudes.length; i++) {
        if (magnitudes[i] > maxAmplitude) {
          maxAmplitude = magnitudes[i];
          dominantFrequency = frequencies[i];
        }
      }

      return {
        'dominantFrequency': dominantFrequency,
        'maxAmplitude': maxAmplitude,
        'frequencies': frequencies,
        'amplitudes': magnitudes,
      };
    } catch (e) {
      print('Error in FFT calculation: $e');
      return {
        'dominantFrequency': 0.0,
        'maxAmplitude': 0.0,
        'frequencies': <double>[],
        'amplitudes': <double>[],
      };
    }
  }

  /// Computes the next power of 2 that is >= n
  static int _nextPowerOf2(int n) {
    int power = 1;
    while (power < n) {
      power *= 2;
    }
    return power;
  }

  /// Pads an array to the desired length by adding zeros
  static List<double> _padArray(List<double> array, int length) {
    List<double> result = List.filled(length, 0.0);
    for (int i = 0; i < array.length; i++) {
      result[i] = array[i];
    }
    return result;
  }
}
