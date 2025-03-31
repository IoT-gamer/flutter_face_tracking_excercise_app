# Flutter Face Tracking Excercise App

A Flutter application for collecting face movement data to train machine learning models for exercise activity detection. This app tracks a user's face position during different activities and saves the data for training ML models that can detect whether a person is walking or standing.

## Overview

This app uses the device's front camera and Google's ML Kit to track facial movements. It records the coordinates of the face during different activities (walking, standing, or custom activities) and saves this data for later use in training machine learning models.

The primary use case is positioning a phone or tablet on a stationary part of an exercise machine (like a treadmill or elliptical trainer) to track the user's face movements while exercising. This data can then be used to train ML models to detect exercise activities based solely on facial movement patterns.

## Features

- Real-time face detection and tracking
- Recording of face position coordinates
- Storage of activity data with proper labeling
- Support for multiple activity types:
  - Walking
  - Standing
  - Custom activities (user-defined)
- Visual feedback with face tracking dot
- Status messages for operation feedback
- Data management (save/delete functionality)

## Requirements

- Flutter 3.29.2 or higher
- Dart 3.7.2 or higher
- Android SDK 21+ or iOS 12+
- Camera permissions

## Dependencies

- camera: For accessing device camera
- google_mlkit_face_detection: For face detection
- bloc/flutter_bloc: For state management
- equatable: For value equality
- path_provider: For file access
- circular_buffer: For storing sequences of coordinates
- integral_isolates: For background processing
- wakelock_plus: To keep screen on during tracking

## Installation

1. Clone the repository:
```bash
git clone https://github.com/IoT-gamer/flutter_face_tracking_excercise_app.git
cd flutter_face_tracking_excercise_app
```

2. Install dependencies:
```bash
flutter pub get
```

3. Run the app:
```bash
flutter run
```

## Usage

1. Launch the app and grant camera permissions
2. Position your device on a stable surface with the front camera facing you
3. Tap "Start Detection" to begin face tracking
4. Perform the desired activity (walking, standing, etc.)
5. Tap the appropriate button to save the data with the correct activity label
6. Collect multiple samples for better ML training results
7. Use the "Delete Data" button to clear all saved data if needed

## Data Format

The app collects face tracking data and saves it in JSON format. Each tracking session includes:

- Timestamp
- Activity type (walking, standing, or custom)
- Sequence length (number of coordinate points)
- Camera FPS (frames per second)
- Normalized coordinates (x,y) of the face center

Example of saved data:

```json
[
  {
    "timestamp": "2025-03-30T12:34:56.789Z",
    "activityType": "walking",
    "sequenceLength": 100,
    "cameraFps": 30,
    "coordinates": [[0.45, 0.32], [0.46, 0.33], ...]
  },
  {
    "timestamp": "2025-03-30T12:40:12.345Z",
    "activityType": "standing",
    "sequenceLength": 100,
    "cameraFps": 30,
    "coordinates": [[0.50, 0.50], [0.51, 0.51], ...]
  }
]
```

## Project Structure

```
lib/
├── constants/
│   └── constants.dart        # Application constants
├── cubit/
│   ├── face_detection_cubit.dart    # State management
│   └── face_detection_state.dart    # State definitions
├── device/
│   └── mlkit_face_camera_repository.dart  # Camera and ML Kit integration
├── models/
│   └── face_tracking_session.dart   # Data model for tracking sessions
├── screens/
│   └── face_tracking_screen.dart    # Main UI screen
├── widgets/
│   └── dot_painter.dart     # Visual indicator for face tracking
└── main.dart                # Application entry point
```

## Machine Learning Integration

The data collected with this app is designed to be used with the Face Activity Classifier ML model located in the `ml_models/face_activity/` directory. See the [ML model README](ml_models/face_activity/README.md) for details on how to train a model with the collected data.

## Customization

### Constants

You can modify various parameters in `constants/constants.dart`:

- `sequenceLength`: Number of data points to collect per session
- `cameraFps`: Camera frame rate for tracking
- `dotRadius`: Size of the tracking dot
- `smilingThreshold`: Threshold for smile detection (not currently used for classification)

### Adding New Activity Types

To add predefined activity types:

1. Add constants in `constants/constants.dart`
2. Add convenience methods in `face_detection_cubit.dart`
3. Add buttons in `face_tracking_screen.dart`

## Troubleshooting

- **Camera not initializing**: Ensure camera permissions are granted
- **Face not detected**: Ensure adequate lighting and position your face within camera view
- **App crashing**: Check logs for ML Kit or camera-related errors
- **Data not saving**: Verify storage permissions are granted

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- Google ML Kit for face detection capabilities
- Flutter team for the excellent framework
