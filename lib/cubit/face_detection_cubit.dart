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
import '../services/model_service.dart';

part 'face_detection_state.dart';

class FaceDetectionCubit extends Cubit<FaceDetectionState> {
  FaceDetectionCubit({
    required mlkitFaceCameraRepository,
    required ModelService modelService,
  }) : _mlkitFaceCameraRepository = mlkitFaceCameraRepository,
       _modelService = modelService,
       super(FaceDetectionState.initial());

  final MLKITFaceCameraRepository _mlkitFaceCameraRepository;
  final ModelService _modelService;

  StreamSubscription? _faceDetectionStreamSubscription;
  CameraController? _cameraController;
  late File _dataFile;
  late double _screenWidth;
  late double _screenHeight;
  Timer? _predictionTimer;
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
      result.add(queue[i]);
    }
    return result;
  }

  // Start periodic predictions if model is loaded
  void startPeriodicPredictions() {
    if (state.modelLoaded && _predictionTimer == null) {
      // Make predictions every 1 second
      _predictionTimer = Timer.periodic(
        const Duration(milliseconds: 500),
        (_) => _makePrediction(),
      );
    }
  }

  // Stop periodic predictions
  void stopPeriodicPredictions() {
    _predictionTimer?.cancel();
    _predictionTimer = null;
  }

  // Make a prediction using the loaded model
  Future<void> _makePrediction() async {
    if (!state.modelLoaded || state.queue.isEmpty) return;

    try {
      // Get coordinates from the queue
      final coordinates = _queueToList(state.queue);

      // Need at least a few points for a meaningful prediction
      if (coordinates.length < 10) return;

      // Run inference
      final prediction = await _modelService.runInference(coordinates);

      // Update state with prediction results
      emit(
        state.copyWith(
          currentActivity: prediction['class'],
          confidenceScore: prediction['confidence'],
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

      // Create session with metadata
      final session = FaceTrackingSession(
        timestamp: DateTime.now(),
        activityType: activityType,
        sequenceLength: AppConstants.sequenceLength,
        cameraFps: AppConstants.cameraFps,
        coordinates: _queueToList(state.queue),
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

      // Update status message with success
      emit(
        state.copyWith(statusMessage: '$activityType data saved successfully!'),
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
            // print('coordinates: $centerX, $centerY');
            emit(
              state.copyWith(
                isSmiling: smileProb > AppConstants.smilingThreshold,
                centerX: centerX.toInt(),
                centerY: centerY.toInt(),
                queue:
                    state.queue
                      ..add([centerX / _screenWidth, centerY / _screenHeight]),
              ),
            );
          });

      // Start periodic predictions if model is loaded
      if (state.modelLoaded) {
        startPeriodicPredictions();
      }
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
    stopCameraImageStream();
    disposeStatefulIsolate();
    _modelService.dispose();
  }
}
