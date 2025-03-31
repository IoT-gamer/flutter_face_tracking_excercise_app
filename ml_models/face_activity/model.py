import json
import os
import numpy as np
import tensorflow as tf
from tensorflow.keras.models import Sequential
from tensorflow.keras.layers import Conv1D, MaxPooling1D, Flatten, Dense, Dropout
from tensorflow.keras.utils import to_categorical
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import LabelEncoder
import matplotlib.pyplot as plt

# Set random seed for reproducibility
np.random.seed(42)
tf.random.set_seed(42)

def load_data(file_path):
    """
    Load and preprocess the face tracking data.
    
    Args:
        file_path: Path to the JSON file containing face tracking data
        
    Returns:
        X: Feature array of shape (n_samples, sequence_length, n_features)
        y: Labels array
    """
    # Load the JSON data
    with open(file_path, 'r') as f:
        data = json.load(f)
    
    X = []
    y = []
    
    for entry in data:
        # Extract coordinates and convert to numpy array
        coords = np.array(entry['coordinates'])
        
        # Ensure all sequences have the same length
        if coords.shape[0] == entry['sequenceLength']:
            # Normalize coordinates if not already normalized
            if np.max(coords) > 1.0:
                coords = coords / np.max(coords)
            
            # Add to features and labels
            X.append(coords)
            y.append(entry['activityType'])
    
    # Convert to numpy arrays
    X = np.array(X)
    
    # Encode labels
    label_encoder = LabelEncoder()
    y_encoded = label_encoder.fit_transform(y)
    
    # Convert to categorical
    y_categorical = to_categorical(y_encoded)
    
    return X, y_categorical, label_encoder.classes_

def create_model(input_shape, num_classes):
    """
    Create a 1D CNN model for activity classification.
    
    Args:
        input_shape: Shape of input data (sequence_length, n_features)
        num_classes: Number of classes to predict
        
    Returns:
        Compiled Keras model
    """
    model = Sequential([
        # First convolutional layer
        Conv1D(filters=64, kernel_size=3, activation='relu', input_shape=input_shape),
        MaxPooling1D(pool_size=2),
        
        # Second convolutional layer
        Conv1D(filters=128, kernel_size=3, activation='relu'),
        MaxPooling1D(pool_size=2),
        
        # Third convolutional layer
        Conv1D(filters=128, kernel_size=3, activation='relu'),
        MaxPooling1D(pool_size=2),
        
        # Flatten the output and feed it into dense layers
        Flatten(),
        Dense(128, activation='relu'),
        Dropout(0.5),
        Dense(num_classes, activation='softmax')
    ])
    
    # Compile the model
    model.compile(
        optimizer='adam',
        loss='categorical_crossentropy',
        metrics=['accuracy']
    )
    
    return model

def train_and_evaluate():
    """
    Main function to train and evaluate the model.
    """
    # Load and preprocess data
    file_path = 'face_tracking_data.json'
    X, y, class_names = load_data(file_path)
    
    # Get dimensions
    n_samples, seq_length, n_features = X.shape
    print(f"Dataset shape: {X.shape}, {len(class_names)} classes: {class_names}")
    
    # Split into training and testing sets
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42
    )
    
    # Create and compile the model
    model = create_model(input_shape=(seq_length, n_features), num_classes=len(class_names))
    model.summary()
    
    # Train the model
    history = model.fit(
        X_train, y_train,
        epochs=50,
        batch_size=32,
        validation_split=0.2,
        verbose=1
    )
    
    # Evaluate the model
    loss, accuracy = model.evaluate(X_test, y_test)
    print(f"Test accuracy: {accuracy:.4f}")
    
    # Make predictions on the test set
    y_pred = model.predict(X_test)
    y_pred_classes = np.argmax(y_pred, axis=1)
    y_true_classes = np.argmax(y_test, axis=1)
    
    # Plot training history
    plt.figure(figsize=(12, 4))
    
    plt.subplot(1, 2, 1)
    plt.plot(history.history['accuracy'])
    plt.plot(history.history['val_accuracy'])
    plt.title('Model Accuracy')
    plt.ylabel('Accuracy')
    plt.xlabel('Epoch')
    plt.legend(['Train', 'Validation'], loc='lower right')
    
    plt.subplot(1, 2, 2)
    plt.plot(history.history['loss'])
    plt.plot(history.history['val_loss'])
    plt.title('Model Loss')
    plt.ylabel('Loss')
    plt.xlabel('Epoch')
    plt.legend(['Train', 'Validation'], loc='upper right')
    
    plt.tight_layout()
    plt.savefig('training_history.png')
    plt.show()
    
    # Save the model in Keras format
    model.save('face_activity_classifier.h5')
    print("Model saved as 'face_activity_classifier.h5'")
    
    # Export to TensorFlow Lite format
    export_to_tflite(model, 'face_activity_classifier.tflite')
    
    return model, history, class_names

def visualize_sample(X, y, class_names, sample_idx=0):
    """
    Visualize a sample sequence from the dataset.
    
    Args:
        X: Feature array
        y: Labels array
        class_names: Array of class names
        sample_idx: Index of the sample to visualize
    """
    sample = X[sample_idx]
    label = class_names[np.argmax(y[sample_idx])]
    
    plt.figure(figsize=(10, 6))
    
    # Plot X coordinates
    plt.subplot(2, 1, 1)
    plt.plot(sample[:, 0])
    plt.title(f'X Coordinates - {label}')
    plt.ylabel('X Position')
    
    # Plot Y coordinates
    plt.subplot(2, 1, 2)
    plt.plot(sample[:, 1])
    plt.title(f'Y Coordinates - {label}')
    plt.ylabel('Y Position')
    plt.xlabel('Frame Number')
    
    plt.tight_layout()
    plt.savefig(f'sample_{label}.png')
    plt.show()

def export_to_tflite(model, output_path):
    """
    Export Keras model to TensorFlow Lite format for mobile deployment.
    
    Args:
        model: Trained Keras model
        output_path: Path to save the TFLite model
    """
    # Convert the model to TensorFlow Lite format
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    
    # Apply optimizations
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    
    # Quantize the model to reduce size (optional)
    converter.target_spec.supported_types = [tf.float16]
    
    # Convert the model
    tflite_model = converter.convert()
    
    # Save the model to disk
    with open(output_path, 'wb') as f:
        f.write(tflite_model)
    
    # Get the file size in KB
    file_size = round(len(tflite_model) / 1024, 2)
    print(f"TensorFlow Lite model saved at {output_path} ({file_size} KB)")
    
    # Generate metadata file with class labels
    try:
        with open(output_path.replace('.tflite', '_metadata.json'), 'w') as f:
            json.dump({
                'input_shape': list(model.input.shape),
                'output_shape': list(model.output.shape),
                'class_names': list(model.output.shape)
            }, f, indent=2)
        print(f"Model metadata saved at {output_path.replace('.tflite', '_metadata.json')}")
    except Exception as e:
        print(f"Failed to save metadata: {e}")

def predict_new_sequence(model, new_data, class_names):
    """
    Predict the activity for a new sequence.
    
    Args:
        model: Trained Keras model
        new_data: New sequence data of shape (1, sequence_length, n_features)
        class_names: Array of class names
        
    Returns:
        Predicted class and probability
    """
    # Make prediction
    prediction = model.predict(new_data)
    predicted_class_idx = np.argmax(prediction[0])
    predicted_class = class_names[predicted_class_idx]
    probability = prediction[0][predicted_class_idx]
    
    return predicted_class, probability

if __name__ == "__main__":
    # Create directories for output
    os.makedirs('outputs', exist_ok=True)
    os.makedirs('outputs/visualizations', exist_ok=True)
    os.makedirs('outputs/models', exist_ok=True)
    
    # Train and evaluate the model
    model, history, class_names = train_and_evaluate()
    
    # Load data for visualization
    X, y, _ = load_data('face_tracking_data.json')
    
    # Visualize a "walking" sample (assuming index 0 is walking)
    walking_indices = np.where(np.argmax(y, axis=1) == np.where(class_names == 'walking')[0][0])[0]
    if len(walking_indices) > 0:
        visualize_sample(X, y, class_names, sample_idx=walking_indices[0])
    
    # Visualize a "standing" sample (assuming index 1 is standing)
    standing_indices = np.where(np.argmax(y, axis=1) == np.where(class_names == 'standing')[0][0])[0]
    if len(standing_indices) > 0:
        visualize_sample(X, y, class_names, sample_idx=standing_indices[0])
    
    # Save class names to a JSON file for use in Flutter
    with open('outputs/models/class_names.json', 'w') as f:
        json.dump({'class_names': list(class_names)}, f)
        print("Class names saved to outputs/models/class_names.json")
    
    print("Training and evaluation complete!")
    print("The TFLite model can now be included in your Flutter app's assets folder")