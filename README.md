# Flutter Face Tracking Exercise App

A Flutter application for collecting face movement data to train machine learning models for exercise activity detection. This app tracks a user's face position during different activities, saves the data for training ML models, and can display real-time predictions using a trained model.

## Overview

This app uses the device's front camera and Google's ML Kit to track facial movements. It records the coordinates of the face during different activities (walking, standing, or custom activities) and saves this data for later use in training machine learning models.

The primary use case is positioning a phone or tablet on a stationary part of an exercise machine (like a treadmill or elliptical trainer) to track the user's face movements while exercising. This data can then be used to train ML models to detect exercise activities based solely on facial movement patterns. Once trained, the model can be integrated back into the app for real-time activity detection.

## Features

- Real-time face detection and tracking
- Advanced outlier detection and filtering using Median Absolute Deviation (MAD)
- Recording of face position coordinates
- Storage of activity data with proper labeling
- Real-time activity prediction using a trained model
- Support for multiple activity types:
  - Walking
  - Standing
  - Custom activities (user-defined)
- Visual feedback with face tracking dot
- Interactive outlier visualization
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
- tflite_flutter: For running trained ML models
- flutter_archive: For handling model files

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

### Data Collection Mode

1. Launch the app and grant camera permissions
2. Position your device on a stable surface with the front camera facing you
3. Tap "Start Detection" to begin face tracking
4. Perform the desired activity (walking, standing, etc.)
5. Tap the appropriate button to save the data with the correct activity label
6. Collect multiple samples for better ML training results
7. Use the "Delete Data" button to clear all saved data if needed
8. Toggle "Outlier Viz" to view outlier detection visualization

### Model Prediction Mode

If you have a trained model:

1. Place the TensorFlow Lite model file (`face_activity_classifier.tflite`) and class names file (`class_names.json`) in the `assets/models/` directory
2. Launch the app and tap "Start Detection"
3. The app will automatically load the model and display real-time predictions of your activity
4. The prediction includes the activity type and a confidence score

## Data Format

The app collects face tracking data and saves it in JSON format. Each tracking session includes:

- Timestamp
- Activity type (walking, standing, or custom)
- Sequence length (number of coordinate points)
- Camera FPS (frames per second)
- Normalized coordinates (x,y) of the face center, with outliers filtered via MAD algorithm

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

## Data Processing

### Outlier Detection

The app implements the Median Absolute Deviation (MAD) algorithm to detect and handle outliers in face tracking data:

- **Algorithm**: Identifies coordinate points that deviate significantly from the median
- **Handling**: Instead of removing outliers (which would disrupt the sequence length needed for the model), the system replaces them with interpolated values
- **Visualization**: The app provides an interactive visualization showing original points (gray), detected outliers (red), and their adjusted values (green)
- **Statistics**: Tracks and displays outlier percentages for both current frame and session-wide metrics

This outlier filtering improves model prediction accuracy and ensures higher quality training data by smoothing out erratic movements or tracking errors.

## Data Storage Location

The data is stored in the device's local storage. The app uses the `path_provider` package to determine the correct directory for saving files.

For Android, the path is typically:
```
/Android/data/iot.games.flutter_face_tracking_excercise_app/files/face_tracking_data/
```

Use `path_provider` to get the correct path for iOS and Android.

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
├── services/
│   └── model_service.dart     # TensorFlow Lite model handling
├── utils/
│   └── outlier_detection_utils.dart # MAD outlier detection algorithm
├── widgets/
│   ├── dot_painter.dart       # Visual indicator for face tracking
│   ├── metadata_indicator_widget.dart  # Display for FPS and points info
│   ├── model_results_widget.dart  # Display for model predictions
│   ├── outlier_visualization_widget.dart # Visualization for outlier detection
│   └── status_message_widget.dart  # Display for status messages
└── main.dart                # Application entry point
```

## Machine Learning Integration

### Training a Model

The data collected with this app is designed to be used with the Face Activity Classifier ML model located in the `ml_models/face_activity/` directory. See the [ML model README](ml_models/face_activity/README.md) for details on how to train a model with the collected data.

### Using a Trained Model

After training the model:

1. Copy the generated TensorFlow Lite model (`face_activity_classifier.tflite`) to the `assets/models/` directory
2. Copy the class names file (`class_names.json`) to the `assets/models/` directory
3. Ensure these assets are included in your `pubspec.yaml`:
   ```yaml
   flutter:
     assets:
       - assets/models/
   ```
4. Run the app and enjoy real-time activity predictions!

## Customization

### Constants

You can modify various parameters in `constants/constants.dart`:

- `sequenceLength`: Number of data points to collect per session
- `cameraFps`: Camera frame rate for tracking
- `dotRadius`: Size of the tracking dot
- `smilingThreshold`: Threshold for smile detection (not currently used for classification)
- `madOutlierThreshold`: Sensitivity of the MAD outlier detection (lower values = more aggressive filtering)
- `assetsModelFolder`: Folder where the model files are stored
- `modelFilename`: Name of the TensorFlow Lite model file
- `classNamesFilename`: Name of the class names file

### Adding New Activity Types

To add predefined activity types:

1. Add constants in `constants/constants.dart`
2. Add convenience methods in `face_detection_cubit.dart`
3. Add buttons in `face_tracking_screen.dart`
4. Update the machine learning model to recognize the new activities

## Troubleshooting

- **Camera not initializing**: Ensure camera permissions are granted
- **Face not detected**: Ensure adequate lighting and position your face within camera view
- **App crashing**: Check logs for ML Kit or camera-related errors
- **Data not saving**: Verify storage permissions are granted
- **Model not loading**: Ensure model files are in the correct location and pubspec.yaml is properly configured
- **Poor predictions**: Collect more training data or adjust the model architecture in the Python script
- **Low outlier detection**: Adjust the `madOutlierThreshold` constant (lower values increase sensitivity)

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- Google ML Kit for face detection capabilities
- TensorFlow Lite for on-device machine learning inferencing
- Flutter team for the excellent framework