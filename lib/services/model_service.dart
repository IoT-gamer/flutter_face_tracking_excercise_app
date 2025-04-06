import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import '../constants/constants.dart';

/// Service for handling TFLite model operations
class ModelService {
  static const String assetsModelPath =
      'assets/models/${AppConstants.modelFilename}';
  static const String assetsClassNamesPath =
      'assets/models/${AppConstants.classNamesFilename}';

  Interpreter? _interpreter;
  List<String> _classNames = [];
  bool _modelLoaded = false;

  /// Get whether the model is loaded
  bool get isModelLoaded => _modelLoaded;

  /// Get the list of class names
  List<String> get classNames => _classNames;

  /// Initialize the model service
  Future<bool> initialize() async {
    try {
      // Check if model exists in app directory
      final appDir = await getApplicationDocumentsDirectory();
      final modelPath = '${appDir.path}/${AppConstants.modelFilename}';
      final classNamesPath =
          '${appDir.path}/${AppConstants.classNamesFilename}';

      File modelFile = File(modelPath);
      File classNamesFile = File(classNamesPath);

      // If model doesn't exist in app directory, check if it exists in assets
      if (!modelFile.existsSync()) {
        try {
          // Try to load from assets
          await _loadModelFromAssets();
          return _modelLoaded;
        } catch (e) {
          print('Error loading model from assets: $e');
          return false;
        }
      }

      // Load model from local storage
      try {
        _interpreter = Interpreter.fromFile(modelFile);

        // Load class names
        if (classNamesFile.existsSync()) {
          final jsonString = await classNamesFile.readAsString();
          final jsonMap = jsonDecode(jsonString);
          _classNames = List<String>.from(jsonMap['class_names']);
        }

        _modelLoaded = true;
        print('Model loaded from local storage successfully');
        return true;
      } catch (e) {
        print('Error loading model from local storage: $e');
        return false;
      }
    } catch (e) {
      print('Error initializing model service: $e');
      return false;
    }
  }

  /// Load model from assets
  Future<void> _loadModelFromAssets() async {
    try {
      // Check if assets exist
      await rootBundle.load(assetsModelPath);
      await rootBundle.load(assetsClassNamesPath);

      // Create temp directory
      final appDir = await getApplicationDocumentsDirectory();
      final modelFile = File('${appDir.path}/${AppConstants.modelFilename}');
      final classNamesFile = File(
        '${appDir.path}/${AppConstants.classNamesFilename}',
      );

      // Copy assets to app directory
      ByteData modelData = await rootBundle.load(assetsModelPath);
      final modelBuffer = modelData.buffer;
      await modelFile.writeAsBytes(
        modelBuffer.asUint8List(
          modelData.offsetInBytes,
          modelData.lengthInBytes,
        ),
      );

      ByteData classNamesData = await rootBundle.load(assetsClassNamesPath);
      final classNamesBuffer = classNamesData.buffer;
      await classNamesFile.writeAsBytes(
        classNamesBuffer.asUint8List(
          classNamesData.offsetInBytes,
          classNamesData.lengthInBytes,
        ),
      );

      // Load interpreter
      _interpreter = Interpreter.fromFile(modelFile);

      // Load class names
      final jsonString = await rootBundle.loadString(assetsClassNamesPath);
      final jsonMap = jsonDecode(jsonString);
      _classNames = List<String>.from(jsonMap['class_names']);

      _modelLoaded = true;
      print('Model loaded from assets successfully');
    } catch (e) {
      print('Error loading model from assets: $e');
      _modelLoaded = false;
      throw Exception('Failed to load model from assets: $e');
    }
  }

  /// Run inference on the model with the given input
  ///
  /// Returns a tuple of (predictedClass, confidence)
  Future<Map<String, dynamic>> runInference(
    List<List<double>> coordinates,
  ) async {
    if (!_modelLoaded || _interpreter == null) {
      return {'class': 'Model not loaded', 'confidence': 0.0};
    }

    try {
      // Reshape input to match model input shape [1, sequence_length, 2]
      List<List<List<double>>> input = [coordinates];

      // Prepare output buffer for softmax probabilities
      // Assuming model has 2 classes (walking, standing)
      var outputBuffer = List.filled(
        1 * _classNames.length,
        0.0,
      ).reshape([1, _classNames.length]);

      // Run inference
      _interpreter!.run(input, outputBuffer);

      // Get predicted class and confidence
      int predictedClassIndex = 0;
      double maxConfidence = outputBuffer[0][0];

      for (int i = 1; i < outputBuffer[0].length; i++) {
        if (outputBuffer[0][i] > maxConfidence) {
          maxConfidence = outputBuffer[0][i];
          predictedClassIndex = i;
        }
      }

      String predictedClass =
          predictedClassIndex < _classNames.length
              ? _classNames[predictedClassIndex]
              : 'Unknown';

      return {'class': predictedClass, 'confidence': maxConfidence};
    } catch (e) {
      print('Error running inference: $e');
      return {'class': 'Error', 'confidence': 0.0};
    }
  }

  /// Check if models are available in assets
  Future<bool> areModelsInAssets() async {
    try {
      await rootBundle.load(assetsModelPath);
      await rootBundle.load(assetsClassNamesPath);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Dispose resources
  void dispose() {
    _interpreter?.close();
  }
}
