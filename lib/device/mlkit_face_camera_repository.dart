import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:flutter_face_tracking_exercise_app/constants/constants.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:integral_isolates/integral_isolates.dart';

class MLKITFaceCameraRepository {
  // repository for face detection using camera and mlkit

  late StatefulIsolate _statefulIsolate;
  late RootIsolateToken _rootIsolateToken;
  late CameraDescription _camera;
  late CameraController _cameraController;
  static final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true,
      enableTracking: true,
      enableContours: false,
    ),
  );
  static final StreamController _streamController = StreamController();

  // create isolate for face detection
  Future<void> createIsolate() async {
    _statefulIsolate = StatefulIsolate(
      backpressureStrategy: ReplaceBackpressureStrategy(),
    );
  }

  static void _initPluginForIsolate(RootIsolateToken rootIsolateToken) {
    BackgroundIsolateBinaryMessenger.ensureInitialized(rootIsolateToken);
    print('I am init!');
  }

  // dispose isolate
  void disposeIsolate() {
    _statefulIsolate.dispose();
  }

  // initialize front camera
  Future<void> getCamera() async {
    final cameras = await availableCameras();
    _camera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
    );
  }

  Future<CameraController?> initializeCamera() async {
    // final camera = await _getCamera();
    //WidgetsFlutterBinding.ensureInitialized();
    _cameraController = CameraController(
      _camera,
      //ResolutionPreset.max,
      ResolutionPreset.high,
      fps: AppConstants.cameraFps,
      enableAudio: AppConstants.enableAudio,
      imageFormatGroup:
          Platform.isAndroid
              ? ImageFormatGroup
                  .nv21 // for Android
              : ImageFormatGroup.bgra8888, // for iOS
    );
    print('camera initialized: ${_cameraController.value.isInitialized}');
    print('start camera initialize');
    // delay to allow the camera to initialize
    try {
      await _cameraController.initialize();
      return _cameraController;
    } on CameraException catch (e) {
      print('error initializing camera');
      print(e);
      return null;
    }
  }

  static final Map<DeviceOrientation, int> _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  InputImage? _inputImageFromCameraImage(
    CameraDescription camera,
    CameraController cameraController,
    CameraImage image,
  ) {
    {
      final sensorOrientation = camera.sensorOrientation;
      InputImageRotation? rotation;
      if (Platform.isIOS) {
        rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
      } else if (Platform.isAndroid) {
        var rotationCompensation =
            _orientations[cameraController.value.deviceOrientation];
        if (rotationCompensation == null) return null;
        if (camera.lensDirection == CameraLensDirection.front) {
          // front-facing
          rotationCompensation =
              (sensorOrientation + rotationCompensation) % 360;
        } else {
          // back-facing
          rotationCompensation =
              (sensorOrientation - rotationCompensation + 360) % 360;
        }
        rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
      }
      if (rotation == null) return null;

      // get image format
      final format = InputImageFormatValue.fromRawValue(image.format.raw);
      // validate format depending on platform
      // only supported formats:
      // * nv21 for Android
      // * bgra8888 for iOS
      if (format == null ||
          (Platform.isAndroid && format != InputImageFormat.nv21) ||
          (Platform.isIOS && format != InputImageFormat.bgra8888))
        return null;

      // since format is constraint to nv21 or bgra8888, both only have one plane
      if (image.planes.length != 1) return null;
      final plane = image.planes.first;

      // compose InputImage using bytes
      return InputImage.fromBytes(
        bytes: plane.bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation, // used only in Android
          format: format, // used only in iOS
          bytesPerRow: plane.bytesPerRow, // used only in iOS
        ),
      );
    }
  }

  static Face? _getLargestFace(List<Face> faces) {
    if (faces.isEmpty) return null;
    var largestFace = faces.first;
    for (var face in faces) {
      if (face.boundingBox.width * face.boundingBox.height >
          largestFace.boundingBox.width * largestFace.boundingBox.height) {
        largestFace = face;
      }
    }
    return largestFace;
  }

  static Map<String, double> _getFaceCenter(Face face) {
    return {
      'x': face.boundingBox.left + face.boundingBox.width / 2,
      'y': face.boundingBox.top + face.boundingBox.height / 2,
    };
  }

  static Future<Map<String, dynamic>> _faceDetection(
    Map<dynamic, dynamic> inputMessage,
  ) async {
    final inputImage = inputMessage['input-image'];
    final rootIsolateToken = inputMessage['token'];
    //final inputImage = _inputImageFromCameraImage(image);
    BackgroundIsolateBinaryMessenger.ensureInitialized(rootIsolateToken);
    print('start face detection function');
    if (inputImage != null) {
      final faces = await _faceDetector.processImage(inputImage);
      final largestFace = _getLargestFace(faces);
      if (largestFace != null) {
        return {
          'center': _getFaceCenter(largestFace),
          'smilingProbability': largestFace.smilingProbability,
        };
      } else {
        return {
          'center': {'x': -9999, 'y': -9999},
          'smilingProbability': 0.0,
        };
      }
    } else {
      return {
        'center': {'x': -9999, 'y': -9999},
        'smilingProbability': 0.0,
      };
    }
  }

  Stream<dynamic> faceDetectionStream() {
    // int count = 0;
    _rootIsolateToken = RootIsolateToken.instance!;
    print('root isolate token: $_rootIsolateToken');
    _cameraController.startImageStream((CameraImage cameraImage) async {
      // if (count % 1 == 0) {
      var inputImage = _inputImageFromCameraImage(
        _camera,
        _cameraController,
        cameraImage,
      );

      var result = await _statefulIsolate.compute(_faceDetection, {
        "input-image": inputImage,
        "token": _rootIsolateToken,
      });
      _streamController.add(result);
      // }
      // count++;
    });
    return _streamController.stream;
  }

  void statefulIsolateDispose() {
    _statefulIsolate.dispose();
  }

  // stop image stream from camera
  void stopImageStream() {
    _cameraController.stopImageStream();
    //_faceDetector.close();
    //_streamController.close();
  }
}
