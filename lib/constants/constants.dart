/// Constants used throughout the application
class AppConstants {
  // File names for saved data
  static const String faceDataFilename = 'face_tracking_data.json';

  // Face detection settings
  static const double smilingThreshold =
      0.8; // Probability threshold for detecting a smile
  static const int sequenceLength =
      100; // Number of data points to save at once

  // Camera settings
  static const bool enableAudio = false; // Disable audio for the camera
  static const int cameraFps =
      30; // Target frames per second for face detection

  // UI settings
  static const double dotRadius = 5.0; // Radius of the face tracking dot
  static const int statusMessageDuration =
      3; // Duration in seconds for status messages

  // Activity types
  static const String activityWalking = 'walking';
  static const String activityStanding = 'standing';

  // Trained ML Model settings
  static const String assetsModelFolder = 'assets/models/';
  static const String modelFilename = 'face_activity_classifier.tflite';
  static const String classNamesFilename = 'class_names.json';
}
