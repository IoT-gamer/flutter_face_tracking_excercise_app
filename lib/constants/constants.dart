/// Constants used throughout the application
class AppConstants {
  // File names for saved data
  static const String faceDataWalkingFilename = 'face_data_walk.txt';
  static const String faceDataStandingFilename = 'face_data_stand.txt';

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
}
