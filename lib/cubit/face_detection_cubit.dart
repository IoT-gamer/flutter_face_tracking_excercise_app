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

part 'face_detection_state.dart';

class FaceDetectionCubit extends Cubit<FaceDetectionState> {
  FaceDetectionCubit({required mlkitFaceCameraRepository})
    : _mlkitFaceCameraRepository = mlkitFaceCameraRepository,
      super(FaceDetectionState.initial());

  final MLKITFaceCameraRepository _mlkitFaceCameraRepository;

  StreamSubscription? _faceDetectionStreamSubscription;
  CameraController? _cameraController;
  late File _dataFile;
  late double _screenWidth;
  late double _screenHeight;
  static const String _faceDataFilename = AppConstants.faceDataFilename;

  //get path for saving face detection result
  Future<String?> get _localPath async {
    final directory = await getExternalStorageDirectory();
    print('directory path: ${directory?.path}');
    return directory?.path;
  }

  // get unified data file for saving face detection results
  Future<File> get _localDataFile async {
    final path = await _localPath;
    return File('$path/$_faceDataFilename');
  }

  // create isolate for face detection
  Future<void> createIsolate() async {
    try {
      await _mlkitFaceCameraRepository.createIsolate();
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  // get camera
  Future<void> getCamera() async {
    try {
      await _mlkitFaceCameraRepository.getCamera();
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  // initialize camera
  Future<void> initializeCamera() async {
    try {
      _cameraController = await _mlkitFaceCameraRepository.initializeCamera();
      emit(state.copyWith(cameraController: _cameraController));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  // set up face detection
  Future<void> setUpFaceDetection() async {
    try {
      await getCamera();
      await initializeCamera();
      await createIsolate();
      _dataFile = await _localDataFile;
      _screenWidth = state.cameraController!.value.previewSize!.height;
      _screenHeight = state.cameraController!.value.previewSize!.width;
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  // Helper method to convert CircularBuffer to List for storage
  List<List<double>> _queueToList(CircularBuffer<List<double>> queue) {
    final result = <List<double>>[];
    for (var i = 0; i < queue.length; i++) {
      result.add(queue[i]);
    }
    return result;
  }

  // save face detection result to file with activity type
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
            print('coordinates: $centerX, $centerY');
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
    } catch (e) {
      print('error subscribing to face detection');
      print(e);
      emit(state.copyWith(error: e.toString()));
    }
  }

  // unsubscribe from faceDetectionStream
  Future<void> unsubscribeFromFaceDetection() async {
    try {
      await _faceDetectionStreamSubscription?.cancel();
      _faceDetectionStreamSubscription = null;
      stopCameraImageStream();
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  // stop camera image stream
  Future<void> stopCameraImageStream() async {
    try {
      _mlkitFaceCameraRepository.stopImageStream();
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  // dispose stateful isolate
  Future<void> disposeStatefulIsolate() async {
    try {
      _mlkitFaceCameraRepository.statefulIsolateDispose();
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  // clean up
  void cleanUp() {
    print('cleaning up');
    stopCameraImageStream();
    disposeStatefulIsolate();
  }
}
