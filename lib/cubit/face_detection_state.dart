part of 'face_detection_cubit.dart';

class FaceDetectionState extends Equatable {
  final CameraController? cameraController;
  final bool isSmiling;
  final int centerX;
  final int centerY;
  final CircularBuffer<List<double>> queue;
  final String error;
  final String statusMessage;
  // Model-related fields
  final bool modelAvailable;
  final bool modelLoaded;
  final String currentActivity;
  final double confidenceScore;
  // Outlier detection fields
  final List<List<double>> originalCoordinates;
  final List<List<double>> filteredCoordinates;
  final List<bool> adjustedPoints;
  // Outlier statistics
  final int totalPoints; // Total points processed
  final int totalOutliersDetected; // Total outliers detected
  final int currentOutliers; // Outliers in current frame
  final double outlierPercentage; // Overall percentage of outliers
  final bool showOutlierVisualization;

  const FaceDetectionState({
    this.cameraController,
    required this.isSmiling,
    required this.centerX,
    required this.centerY,
    required this.queue,
    required this.error,
    required this.statusMessage,
    required this.modelAvailable,
    required this.modelLoaded,
    required this.currentActivity,
    required this.confidenceScore,
    required this.originalCoordinates,
    required this.filteredCoordinates,
    required this.adjustedPoints,
    required this.totalPoints,
    required this.totalOutliersDetected,
    required this.currentOutliers,
    required this.outlierPercentage,
    required this.showOutlierVisualization,
  });

  factory FaceDetectionState.initial() {
    return FaceDetectionState(
      cameraController: null,
      isSmiling: false,
      centerX: -9999,
      centerY: -9999,
      queue: CircularBuffer<List<double>>(AppConstants.sequenceLength),
      error: "",
      statusMessage: "",
      modelAvailable: false,
      modelLoaded: false,
      currentActivity: "Unknown",
      confidenceScore: 0.0,
      originalCoordinates: const [],
      filteredCoordinates: const [],
      adjustedPoints: const [],
      totalPoints: 0,
      totalOutliersDetected: 0,
      currentOutliers: 0,
      outlierPercentage: 0.0,
      showOutlierVisualization: false,
    );
  }

  @override
  List<Object?> get props => [
    cameraController,
    isSmiling,
    centerX,
    centerY,
    queue,
    error,
    statusMessage,
    modelAvailable,
    modelLoaded,
    currentActivity,
    confidenceScore,
    originalCoordinates,
    filteredCoordinates,
    adjustedPoints,
    totalPoints,
    totalOutliersDetected,
    currentOutliers,
    outlierPercentage,
    showOutlierVisualization,
  ];

  @override
  bool get stringify => true;

  FaceDetectionState copyWith({
    CameraController? cameraController,
    bool? isSmiling,
    int? centerX,
    int? centerY,
    CircularBuffer<List<double>>? queue,
    String? error,
    String? statusMessage,
    bool? modelAvailable,
    bool? modelLoaded,
    String? currentActivity,
    double? confidenceScore,
    List<List<double>>? originalCoordinates,
    List<List<double>>? filteredCoordinates,
    List<bool>? adjustedPoints,
    int? totalPoints,
    int? totalOutliersDetected,
    int? currentOutliers,
    double? outlierPercentage,
    bool? showOutlierVisualization,
  }) {
    return FaceDetectionState(
      cameraController: cameraController ?? this.cameraController,
      isSmiling: isSmiling ?? this.isSmiling,
      centerX: centerX ?? this.centerX,
      centerY: centerY ?? this.centerY,
      queue: queue ?? this.queue,
      error: error ?? this.error,
      statusMessage: statusMessage ?? this.statusMessage,
      modelAvailable: modelAvailable ?? this.modelAvailable,
      modelLoaded: modelLoaded ?? this.modelLoaded,
      currentActivity: currentActivity ?? this.currentActivity,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      originalCoordinates: originalCoordinates ?? this.originalCoordinates,
      filteredCoordinates: filteredCoordinates ?? this.filteredCoordinates,
      adjustedPoints: adjustedPoints ?? this.adjustedPoints,
      totalPoints: totalPoints ?? this.totalPoints,
      totalOutliersDetected:
          totalOutliersDetected ?? this.totalOutliersDetected,
      currentOutliers: currentOutliers ?? this.currentOutliers,
      outlierPercentage: outlierPercentage ?? this.outlierPercentage,
      showOutlierVisualization:
          showOutlierVisualization ?? this.showOutlierVisualization,
    );
  }
}
