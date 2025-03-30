import 'dart:convert';

/// Model class for storing face tracking sessions with metadata
class FaceTrackingSession {
  final DateTime timestamp;
  final String activityType;
  final int sequenceLength;
  final int cameraFps;
  final List<List<double>> coordinates;

  FaceTrackingSession({
    required this.timestamp,
    required this.activityType,
    required this.sequenceLength,
    required this.cameraFps,
    required this.coordinates,
  });

  /// Convert session to JSON
  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'activityType': activityType,
      'sequenceLength': sequenceLength,
      'cameraFps': cameraFps,
      'coordinates': coordinates,
    };
  }

  /// Create session from JSON
  factory FaceTrackingSession.fromJson(Map<String, dynamic> json) {
    return FaceTrackingSession(
      timestamp: DateTime.parse(json['timestamp']),
      activityType: json['activityType'],
      sequenceLength: json['sequenceLength'],
      cameraFps: json['cameraFps'],
      coordinates:
          (json['coordinates'] as List)
              .map((item) => (item as List).map((e) => e as double).toList())
              .toList(),
    );
  }

  /// String representation for debugging
  @override
  String toString() {
    return jsonEncode(toJson());
  }
}
