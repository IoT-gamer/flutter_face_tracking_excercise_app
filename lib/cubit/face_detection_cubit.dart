import 'dart:async';
import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:camera/camera.dart';
import 'package:circular_buffer/circular_buffer.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_face_tracking_exercise_app/constants/constants.dart';
import 'package:path_provider/path_provider.dart';

import '../device/mlkit_face_camera_repository.dart';

part 'face_detection_state.dart';

class FaceDetectionCubit extends Cubit<FaceDetectionState> {
  FaceDetectionCubit({required mlkitFaceCameraRepository})
    : _mlkitFaceCameraRepository = mlkitFaceCameraRepository,
      super(FaceDetectionState.initial());

  final MLKITFaceCameraRepository _mlkitFaceCameraRepository;

  StreamSubscription? _faceDetectionStreamSubscription;
  CameraController? _cameraController;
  late File _fileWalking;
  late File _fileStanding;
  late double _screenWidth;
  late double _screenHeight;
  static const String _faceDataWalkingFilename =
      AppConstants.faceDataWalkingFilename;
  static const String _faceDataStandingFilename =
      AppConstants.faceDataStandingFilename;

  //get path for saving face detection result
  Future<String?> get _localPath async {
    // final directory = await getApplicationDocumentsDirectory();
    final directory = await getExternalStorageDirectory();
    print('directory path: ${directory?.path}');
    return directory?.path;
  }

  // get file for saving face detection result
  Future<File> get _localFileWalking async {
    final path = await _localPath;
    return File('$path/$_faceDataWalkingFilename');
  }

  Future<File> get _localFileStanding async {
    final path = await _localPath;
    return File('$path/$_faceDataStandingFilename');
  }

  // create isolate for face detection
  Future<void> createIsolate() async {
    try {
      await _mlkitFaceCameraRepository.createIsolate();
      //appLifecycleListener();
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
      _fileWalking = await _localFileWalking;
      _fileStanding = await _localFileStanding;
      _screenWidth = state.cameraController!.value.previewSize!.height;
      _screenHeight = state.cameraController!.value.previewSize!.width;
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  // save face detection result to file
  Future<void> saveFaceDataWalking() async {
    try {
      // Set saving status
      emit(state.copyWith(statusMessage: 'Saving walking data...'));

      await _fileWalking.writeAsString(
        state.queue.toString(),
        mode: FileMode.append,
      );

      print('_fileWalking path: ${_fileWalking.path}');
      // Update status message with success
      emit(state.copyWith(statusMessage: 'Walking data saved successfully!'));

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
          statusMessage: 'Error saving walking data',
        ),
      );
      print('error saving face data: $e');

      // Clear error status message after a delay
      Future.delayed(
        const Duration(seconds: AppConstants.statusMessageDuration),
        () {
          emit(state.copyWith(statusMessage: ''));
        },
      );
    }
  }

  Future<void> saveFaceDataStanding() async {
    try {
      // Set saving status
      emit(state.copyWith(statusMessage: 'Saving standing data...'));

      await _fileStanding.writeAsString(
        state.queue.toString(),
        mode: FileMode.append,
      );

      // Update status message with success
      emit(state.copyWith(statusMessage: 'Standing data saved successfully!'));

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
          statusMessage: 'Error saving standing data',
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

  Future<void> deleteAllFaceData() async {
    try {
      // Set deleting status
      emit(state.copyWith(statusMessage: 'Deleting saved data...'));

      // Delete both files if they exist
      if (await _fileWalking.exists()) {
        await _fileWalking.delete();
      }

      if (await _fileStanding.exists()) {
        await _fileStanding.delete();
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
