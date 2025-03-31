# Face Activity Classifier

This module contains a 1D Convolutional Neural Network (CNN) for classifying human activity (walking vs. standing) based on face tracking data recorded by a mobile camera.

## Overview

The model uses the movement patterns of a person's face (x,y coordinates) to determine whether they are walking or standing still. This can be useful for:

- Fitness tracking applications
- Gaming applications
- Augmented reality experiences
- Health monitoring systems
- Human-computer interaction
- Accessibility applications

## Data Format

The model expects input data in the following JSON format:

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

Each entry represents a sequence of face coordinates, with a label indicating the activity.

## Directory Structure

```
ml_models/
└── face_activity/
    ├── model.py               # Main script for training the CNN model
    ├── requirements.txt       # Python dependencies
    ├── README.md              # This file
    ├── outputs/
    │   ├── models/            # Trained models
    │   │   ├── face_activity_classifier.h5       # Keras model
    │   │   ├── face_activity_classifier.tflite   # TensorFlow Lite model
    │   │   ├── face_activity_classifier_metadata.json  # Model metadata
    │   │   └── class_names.json                  # Class names mapping
    │   └── visualizations/    # Generated plots and visualizations
    └── data/
        └── face_tracking_data.json  # Training data
```

## Setup and Dependencies

1. Set up a Python environment (Python 3.8+ recommended)
2. Install dependencies:

```bash
pip install -r requirements.txt
```

## Usage

### Training the Model

To train the model from scratch:

```bash
python model.py
```

The script will:
1. Load data from `face_tracking_data.json`
2. Preprocess and normalize the data
3. Train the 1D CNN model
4. Save the model in both Keras (.h5) and TensorFlow Lite (.tflite) formats
5. Generate visualizations of the training process and sample data
6. Export class names and metadata for use in Flutter

### Inference in Flutter

To use the trained model in your Flutter app:

1. Copy the following files to your Flutter project's assets:
   - `outputs/models/face_activity_classifier.tflite`
   - `outputs/models/class_names.json`

2. Add the TensorFlow Lite package to your Flutter project:

```yaml
# In pubspec.yaml
dependencies:
  tflite_flutter: ^0.11.0
```

3. Load and use the model in your Flutter code:

```dart
import 'package:tflite_flutter/tflite_flutter.dart';

// Load the model
final interpreter = await Interpreter.fromAsset('assets/face_activity_classifier.tflite');

// Prepare input data (normalized face coordinates)
var inputData = [/* your sequence of [x,y] coordinates */];

// Reshape to match the model's input shape [1, sequence_length, 2]
var reshapedInput = [inputData];

// Prepare output buffer
var outputBuffer = List.filled(2, 0).reshape([1, 2]);

// Run inference
interpreter.run(reshapedInput, outputBuffer);

// Get the prediction (index with highest probability)
int predictedClassIndex = outputBuffer[0].indexOf(outputBuffer[0].reduce(max));

// Map to class name (walking or standing)
String predictedClass = classNames[predictedClassIndex];
```

## Model Architecture

The model uses a 1D CNN architecture with the following layers:

1. Convolutional layer (64 filters, kernel size 3)
2. Max pooling layer (pool size 2)
3. Convolutional layer (128 filters, kernel size 3)
4. Max pooling layer (pool size 2)
5. Convolutional layer (128 filters, kernel size 3)
6. Max pooling layer (pool size 2)
7. Flatten layer
8. Dense layer (128 neurons)
9. Dropout layer (0.5)
10. Output layer (softmax activation)

## Customization

You can modify the script to:

- Adjust the model architecture for better performance
- Change hyperparameters (learning rate, batch size, etc.)
- Add support for more activity classes
- Incorporate additional features beyond x,y coordinates

## Troubleshooting

Common issues:

1. **Variable sequence lengths**: Ensure all your sequences have the same length or implement padding in your data preprocessing.
2. **Low accuracy**: Try collecting more training data or adjusting the model architecture.
3. **Model size too large**: You can further quantize the model or reduce the number of parameters.
4. **Slow inference**: Consider using a simpler model architecture or further optimizing the TFLite model.

## License

This project is licensed under the MIT License - see the LICENSE file for details.
