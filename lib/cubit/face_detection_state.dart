part of 'face_detection_cubit.dart';

class FaceDetectionState extends Equatable {
  final CameraController? cameraController;
  final bool isSmiling;
  final int centerX;
  final int centerY;
  final CircularBuffer<List<double>> queue;
  final String error;
  final String statusMessage;

  const FaceDetectionState({
    this.cameraController,
    required this.isSmiling,
    required this.centerX,
    required this.centerY,
    required this.queue,
    required this.error,
    required this.statusMessage,
  });

  factory FaceDetectionState.initial() {
    return FaceDetectionState(
      cameraController: null,
      isSmiling: false,
      centerX: -9999,
      centerY: -9999,
      queue: CircularBuffer<List<double>>(100),
      error: "",
      statusMessage: "",
    );
  }

  @override
  List<Object> get props => [centerX, centerY, queue, error, statusMessage];

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
  }) {
    return FaceDetectionState(
      cameraController: cameraController ?? this.cameraController,
      isSmiling: isSmiling ?? this.isSmiling,
      centerX: centerX ?? this.centerX,
      centerY: centerY ?? this.centerY,
      queue: queue ?? this.queue,
      error: error ?? this.error,
      statusMessage: statusMessage ?? this.statusMessage,
    );
  }
}
