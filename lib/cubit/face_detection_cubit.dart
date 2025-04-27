import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:camera/camera.dart';
import 'package:circular_buffer/circular_buffer.dart';
import 'package:equatable/equatable.dart';
import 'package:path_provider/path_provider.dart';

import '../constants/constants.dart';
import '../device/mlkit_face_camera_repository.dart';
import '../models/face_tracking_session.dart';
import '../services/fft_service.dart';
import '../services/model_service.dart';
import '../utils/outlier_detection_utils.dart';

part 'face_detection_state.dart';

class FaceDetectionCubit extends Cubit<FaceDetectionState> {
  FaceDetectionCubit({
    required MLKITFaceCameraRepository mlkitFaceCameraRepository,
    required ModelService modelService,
  }) : _mlkitFaceCameraRepository = mlkitFaceCameraRepository,
       _modelService = modelService,
       _fftService = FFTService(),
       super(FaceDetectionState.initial());

  final MLKITFaceCameraRepository _mlkitFaceCameraRepository;
  final ModelService _modelService;
  final FFTService _fftService;

  StreamSubscription? _faceDetectionStreamSubscription;
  CameraController? _cameraController;
  late File _dataFile;
  late double _screenWidth;
  late double _screenHeight;
  Timer? _predictionTimer;
  Timer? _fftTimer;
  static const String _faceDataFilename = AppConstants.faceDataFilename;

  // Get path for saving face detection result
  Future<String?> get _localPath async {
    final directory = await getExternalStorageDirectory();
    print('directory path: ${directory?.path}');
    return directory?.path;
  }

  // Get unified data file for saving face detection results
  Future<File> get _localDataFile async {
    final path = await _localPath;
    return File('$path/$_faceDataFilename');
  }

  // Check if model is available and load it
  Future<void> checkModelAvailability() async {
    try {
      final isAvailable = await _modelService.areModelsInAssets();
      emit(state.copyWith(modelAvailable: isAvailable));

      if (isAvailable) {
        final isLoaded = await _modelService.initialize();
        emit(
          state.copyWith(
            modelLoaded: isLoaded,
            statusMessage:
                isLoaded ? 'Model loaded successfully' : 'Failed to load model',
          ),
        );

        // Clear status message after a delay
        if (isLoaded) {
          Future.delayed(
            const Duration(seconds: AppConstants.statusMessageDuration),
            () {
              emit(state.copyWith(statusMessage: ''));
            },
          );
        }
      }
    } catch (e) {
      emit(
        state.copyWith(
          error: 'Error checking model availability: ${e.toString()}',
          modelAvailable: false,
          modelLoaded: false,
        ),
      );
    }
  }

  // Helper method to get a List from CircularBuffer for prediction
  List<List<double>> _queueToList(CircularBuffer<List<double>> queue) {
    final result = <List<double>>[];
    for (var i = 0; i < queue.length; i++) {
      result.add(List.from(queue[i])); // Create a deep copy
    }
    return result;
  }

  // Start periodic predictions if model is loaded
  void startPeriodicPredictions() {
    if (state.modelLoaded && _predictionTimer == null) {
      // Make predictions every 0.5 seconds
      _predictionTimer = Timer.periodic(
        const Duration(milliseconds: 500),
        (_) => _makePrediction(),
      );
    }
  }

  // Start periodic FFT computations
  void startPeriodicFFT() {
    if (_fftTimer == null) {
      // Calculate FFT every 0.75 seconds
      _fftTimer = Timer.periodic(
        const Duration(milliseconds: 750),
        (_) => _computeFFT(),
      );
    }
  }

  // Stop periodic predictions
  void stopPeriodicPredictions() {
    _predictionTimer?.cancel();
    _predictionTimer = null;
  }

  // Stop periodic FFT computations
  void stopPeriodicFFT() {
    _fftTimer?.cancel();
    _fftTimer = null;
  }

  // Compare original and filtered coordinates to find outliers with debugging
  List<bool> _findAdjustedPoints(
    List<List<double>> original,
    List<List<double>> filtered,
  ) {
    List<bool> adjustedPoints = List.filled(original.length, false);

    if (original.isEmpty || filtered.isEmpty) {
      return adjustedPoints;
    }

    // Use a small epsilon for floating point comparison
    const double epsilon = 0.0001;
    int outlierCount = 0;

    // Consider a point adjusted if either x or y coordinate changed by more than epsilon
    for (int i = 0; i < original.length && i < filtered.length; i++) {
      double xDiff = (original[i][0] - filtered[i][0]).abs();
      double yDiff = (original[i][1] - filtered[i][1]).abs();

      // If the difference in either coordinate is significant, mark as adjusted
      adjustedPoints[i] = xDiff > epsilon || yDiff > epsilon;

      // Debug output to verify detection
      if (adjustedPoints[i]) {
        outlierCount++;
        print(
          'Outlier at index $i: Original: ${original[i]}, Filtered: ${filtered[i]}',
        );
        print('Differences: X: $xDiff, Y: $yDiff');
      }
    }

    print('Total adjusted points: $outlierCount out of ${original.length}');

    return adjustedPoints;
  }

  // Reset outlier statistics
  void resetOutlierStats() {
    emit(
      state.copyWith(
        totalPoints: 0,
        totalOutliersDetected: 0,
        currentOutliers: 0,
        outlierPercentage: 0.0,
      ),
    );
  }

  // Extract X coordinates from a list of [x,y] coordinate pairs
  List<double> _extractXCoordinates(List<List<double>> coordinates) {
    return coordinates.map((point) => point[0]).toList();
  }

  // Compute FFT on the filtered coordinates
  Future<void> _computeFFT() async {
    // Minimum number of points needed for meaningful FFT
    if (state.filteredCoordinates.length < 20) return;

    try {
      // Extract X coordinates from the filtered coordinates
      // We use X coordinates as they typically represent horizontal movement
      // which correlates well with walking/exercise patterns
      final xCoordinates = _extractXCoordinates(state.filteredCoordinates);

      // Compute the FFT
      final fftResults = await _fftService.computeDominantFrequency(
        xCoordinates,
        AppConstants.cameraFps,
      );

      // Update state with the FFT results
      // Note: We're no longer automatically setting showFrequencyChart based on valid data
      emit(
        state.copyWith(
          dominantFrequency: fftResults['dominantFrequency'],
          maxAmplitude: fftResults['maxAmplitude'],
          frequencies: List<double>.from(fftResults['frequencies']),
          amplitudes: List<double>.from(fftResults['amplitudes']),
          // Keep the user's preference for chart visibility
          // showFrequencyChart: fftResults['dominantFrequency'] > 0.0, // This was the problem!
        ),
      );

      print('Dominant frequency: ${fftResults['dominantFrequency']} Hz');
    } catch (e) {
      print('Error computing FFT: $e');
      // Don't update the state with error to avoid UI flicker
    }
  }

  // Toggle frequency chart visibility
  void toggleFrequencyChart() {
    // Only toggle if we have valid data, otherwise always keep it off
    if (state.dominantFrequency > 0.0 || state.showFrequencyChart) {
      emit(state.copyWith(showFrequencyChart: !state.showFrequencyChart));
    }
  }

  // Make a prediction using the loaded model
  Future<void> _makePrediction() async {
    if (!state.modelLoaded || state.queue.isEmpty) return;

    try {
      // Get coordinates from the queue - make deep copies to avoid reference issues
      final originalCoordinates = _queueToList(state.queue);

      // Need at least a few points for a meaningful prediction
      if (originalCoordinates.length < 10) return;

      // Create a copy of the original coordinates for processing
      List<List<double>> filteredCoordinates = [];
      for (var point in originalCoordinates) {
        filteredCoordinates.add(List.from(point));
      }

      // Filter outliers using Median Absolute Deviation
      filteredCoordinates = OutlierDetectionUtils.filterOutliersMAD(
        filteredCoordinates,
        threshold: AppConstants.madOutlierThreshold,
      );

      // Find which points were adjusted
      List<bool> adjustedPoints = _findAdjustedPoints(
        originalCoordinates,
        filteredCoordinates,
      );

      // Calculate outlier statistics using state
      int currentOutliers = adjustedPoints.where((adjusted) => adjusted).length;
      int newTotalPoints = state.totalPoints + originalCoordinates.length;
      int newTotalOutliers = state.totalOutliersDetected + currentOutliers;
      double newOutlierPercentage =
          newTotalPoints > 0 ? (newTotalOutliers / newTotalPoints * 100) : 0.0;

      // Log outlier information
      if (currentOutliers > 0) {
        print(
          'Outliers in current frame: $currentOutliers out of ${originalCoordinates.length}',
        );
        print(
          'Total outliers so far: $newTotalOutliers out of $newTotalPoints (${newOutlierPercentage.toStringAsFixed(2)}%)',
        );
      }

      // Run inference with filtered coordinates
      final prediction = await _modelService.runInference(filteredCoordinates);

      // Update state with prediction results and outlier data
      emit(
        state.copyWith(
          currentActivity: prediction['class'],
          confidenceScore: prediction['confidence'],
          originalCoordinates: originalCoordinates,
          filteredCoordinates: filteredCoordinates,
          adjustedPoints: adjustedPoints,
          currentOutliers: currentOutliers,
          totalPoints: newTotalPoints,
          totalOutliersDetected: newTotalOutliers,
          outlierPercentage: newOutlierPercentage,
        ),
      );
    } catch (e) {
      print('Error making prediction: $e');
      // Don't update the state with error to avoid UI flicker
    }
  }

  // Create isolate for face detection
  Future<void> createIsolate() async {
    try {
      await _mlkitFaceCameraRepository.createIsolate();
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  // Get camera
  Future<void> getCamera() async {
    try {
      await _mlkitFaceCameraRepository.getCamera();
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  // Initialize camera
  Future<void> initializeCamera() async {
    try {
      _cameraController = await _mlkitFaceCameraRepository.initializeCamera();
      emit(state.copyWith(cameraController: _cameraController));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  // Set up face detection
  Future<void> setUpFaceDetection() async {
    try {
      await getCamera();
      await initializeCamera();
      await createIsolate();
      _dataFile = await _localDataFile;
      _screenWidth = state.cameraController!.value.previewSize!.height;
      _screenHeight = state.cameraController!.value.previewSize!.width;

      // Reset outlier statistics
      resetOutlierStats();

      // Start with frequency chart hidden
      emit(state.copyWith(showFrequencyChart: false));

      // Check model availability after setting up face detection
      await checkModelAvailability();
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  // Save face detection result to file with activity type
  Future<void> saveFaceData(String activityType) async {
    try {
      // Set saving status
      emit(state.copyWith(statusMessage: 'Saving $activityType data...'));

      // Get coordinates from the queue
      final originalCoordinates = _queueToList(state.queue);

      // Filter outliers before saving - now replacing them, not removing
      final filteredCoordinates = OutlierDetectionUtils.filterOutliersMAD(
        originalCoordinates,
        threshold: AppConstants.madOutlierThreshold,
      );

      // Find which points were adjusted
      List<bool> adjustedPoints = _findAdjustedPoints(
        originalCoordinates,
        filteredCoordinates,
      );

      // Log outlier information
      int outliers = adjustedPoints.where((adjusted) => adjusted).length;
      if (outliers > 0) {
        print(
          'Outliers adjusted for saving: $outliers out of ${originalCoordinates.length}',
        );
      }

      // Create session with metadata
      final session = FaceTrackingSession(
        timestamp: DateTime.now(),
        activityType: activityType,
        sequenceLength: AppConstants.sequenceLength,
        cameraFps: AppConstants.cameraFps,
        coordinates:
            filteredCoordinates, // Use the filtered (adjusted) coordinates
      );

      // Load existing data
      List<dynamic> sessions = [];
      if (await _dataFile.exists()) {
        try {
          final content = await _dataFile.readAsString();
          if (content.isNotEmpty) {
            sessions = jsonDecode(content);
          }
        } catch (e) {
          print('Error reading existing data: $e');
          // Continue with empty sessions if file can't be read
        }
      }

      // Add new session
      sessions.add(session.toJson());

      // Write back to file
      await _dataFile.writeAsString(jsonEncode(sessions));

      print('Data saved to: ${_dataFile.path}');

      // Update state with the filtered coordinates for visualization
      emit(
        state.copyWith(
          statusMessage: '$activityType data saved successfully!',
          originalCoordinates: originalCoordinates,
          filteredCoordinates: filteredCoordinates,
          adjustedPoints: adjustedPoints,
          currentOutliers: outliers,
        ),
      );

      // Clear status message after a delay
      Future.delayed(
        const Duration(seconds: AppConstants.statusMessageDuration),
        () {
          emit(state.copyWith(statusMessage: ''));
        },
      );
    } catch (e) {
      emit(
        state.copyWith(
          error: e.toString(),
          statusMessage: 'Error saving $activityType data',
        ),
      );
      print('Error saving face data: $e');

      // Clear error status message after a delay
      Future.delayed(
        const Duration(seconds: AppConstants.statusMessageDuration),
        () {
          emit(state.copyWith(statusMessage: ''));
        },
      );
    }
  }

  // Convenience methods for specific activity types
  Future<void> saveFaceDataWalking() async {
    await saveFaceData(AppConstants.activityWalking);
  }

  Future<void> saveFaceDataStanding() async {
    await saveFaceData(AppConstants.activityStanding);
  }

  Future<void> deleteAllFaceData() async {
    try {
      // Set deleting status
      emit(state.copyWith(statusMessage: 'Deleting saved data...'));

      // Delete data file if it exists
      if (await _dataFile.exists()) {
        await _dataFile.delete();
      }

      // Update status message with success
      emit(state.copyWith(statusMessage: 'Data deleted successfully!'));

      // Clear status message after a delay
      Future.delayed(
        const Duration(seconds: AppConstants.statusMessageDuration),
        () {
          emit(state.copyWith(statusMessage: ''));
        },
      );
    } catch (e) {
      emit(
        state.copyWith(
          error: e.toString(),
          statusMessage: 'Error deleting data',
        ),
      );

      // Clear error status message after a delay
      Future.delayed(
        const Duration(seconds: AppConstants.statusMessageDuration),
        () {
          emit(state.copyWith(statusMessage: ''));
        },
      );
    }
  }

  // Toggle outlier visualization
  void toggleOutlierVisualization() {
    emit(
      state.copyWith(showOutlierVisualization: !state.showOutlierVisualization),
    );
  }

  Future<void> subscribeToFaceDetection() async {
    print('subscribing to face detection');

    if (_faceDetectionStreamSubscription != null) {
      return;
    }

    try {
      _faceDetectionStreamSubscription = _mlkitFaceCameraRepository
          .faceDetectionStream()
          .listen((face) {
            final smileProb = face['smilingProbability'];
            final centerX = face['center']['x'];
            final centerY = face['center']['y'];

            // Create a copy of the queue and add new data
            final updatedQueue = CircularBuffer<List<double>>(
              AppConstants.sequenceLength,
            );
            for (var i = 0; i < state.queue.length; i++) {
              updatedQueue.add(List.from(state.queue[i]));
            }
            updatedQueue.add([centerX / _screenWidth, centerY / _screenHeight]);

            emit(
              state.copyWith(
                isSmiling: smileProb > AppConstants.smilingThreshold,
                centerX: centerX.toInt(),
                centerY: centerY.toInt(),
                queue: updatedQueue,
              ),
            );
          });

      // Start periodic predictions if model is loaded
      if (state.modelLoaded) {
        startPeriodicPredictions();
      }

      // Start periodic FFT computations
      startPeriodicFFT();
    } catch (e) {
      print('error subscribing to face detection');
      print(e);
      emit(state.copyWith(error: e.toString()));
    }
  }

  // Unsubscribe from faceDetectionStream
  Future<void> unsubscribeFromFaceDetection() async {
    try {
      await _faceDetectionStreamSubscription?.cancel();
      _faceDetectionStreamSubscription = null;
      stopPeriodicPredictions();
      stopPeriodicFFT();
      stopCameraImageStream();
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  // Stop camera image stream
  Future<void> stopCameraImageStream() async {
    try {
      _mlkitFaceCameraRepository.stopImageStream();
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  // Dispose stateful isolate
  Future<void> disposeStatefulIsolate() async {
    try {
      _mlkitFaceCameraRepository.statefulIsolateDispose();
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  // Clean up
  void cleanUp() {
    print('cleaning up');
    stopPeriodicPredictions();
    stopPeriodicFFT();
    stopCameraImageStream();
    disposeStatefulIsolate();
    _modelService.dispose();
    _fftService.dispose();
  }
}
