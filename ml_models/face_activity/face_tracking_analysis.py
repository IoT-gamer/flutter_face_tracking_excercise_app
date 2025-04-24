import json
import numpy as np
import matplotlib.pyplot as plt
import random
from scipy.fft import fft
import os
from datetime import datetime

def load_data(filename):
    """Load JSON data from file"""
    with open(filename, 'r') as file:
        data = json.load(file)
    return data

def select_random_walking_sequences(data, n=5):
    """Select n random sequences where activityType is walking"""
    walking_sequences = [seq for seq in data if seq["activityType"] == "walking"]
    
    if len(walking_sequences) < n:
        print(f"Warning: Only {len(walking_sequences)} walking sequences available. Using all of them.")
        return walking_sequences
    
    return random.sample(walking_sequences, n)

def create_time_axis(sequence):
    """Create a time axis in seconds based on sequence length and FPS"""
    seq_length = len(sequence["coordinates"])
    fps = sequence["cameraFps"]
    return np.linspace(0, seq_length / fps, seq_length)

def extract_coordinates(sequence):
    """Extract x and y coordinates from a sequence"""
    coordinates = np.array(sequence["coordinates"])
    x = coordinates[:, 0]
    y = coordinates[:, 1]
    return x, y

def compute_fft(signal, fps):
    """Compute FFT of the signal"""
    n = len(signal)
    fft_result = fft(signal)
    # Only take the first half of the FFT result (the rest is redundant)
    fft_result = fft_result[:n//2]
    # Create frequency axis
    freq = np.linspace(0, fps/2, n//2)
    # Compute magnitude
    magnitude = np.abs(fft_result)
    # Normalize
    magnitude = magnitude / np.max(magnitude)
    return freq, magnitude

def plot_sequence_and_fft(sequence, index, output_dir=None):
    """Plot coordinates and their FFT for a sequence"""
    # Extract data
    time = create_time_axis(sequence)
    x, y = extract_coordinates(sequence)
    # subtract mean to center the data
    x -= np.mean(x)
    y -= np.mean(y)
    fps = sequence["cameraFps"]
    timestamp = sequence["timestamp"]
    parsed_time = datetime.fromisoformat(timestamp.replace('Z', '+00:00'))
    formatted_time = parsed_time.strftime("%Y-%m-%d %H:%M:%S")
    
    # Compute FFT
    freq_x, fft_x = compute_fft(x, fps)
    freq_y, fft_y = compute_fft(y, fps)
    
    # Create figure with 2x2 subplots
    fig, axs = plt.subplots(2, 2, figsize=(12, 10))
    fig.suptitle(f"Walking Sequence {index+1} (Timestamp: {formatted_time})", fontsize=16)
    
    # Plot coordinates over time
    axs[0, 0].plot(time, x)
    axs[0, 0].set_title("X Coordinate vs Time")
    axs[0, 0].set_xlabel("Time (seconds)")
    axs[0, 0].set_ylabel("X Coordinate")
    axs[0, 0].grid(True)
    
    axs[0, 1].plot(time, y)
    axs[0, 1].set_title("Y Coordinate vs Time")
    axs[0, 1].set_xlabel("Time (seconds)")
    axs[0, 1].set_ylabel("Y Coordinate")
    axs[0, 1].grid(True)
    
    # Plot FFT
    axs[1, 0].plot(freq_x, fft_x)
    axs[1, 0].set_title("FFT of X Coordinate")
    axs[1, 0].set_xlabel("Frequency (Hz)")
    axs[1, 0].set_ylabel("Normalized Magnitude")
    axs[1, 0].grid(True)
    
    axs[1, 1].plot(freq_y, fft_y)
    axs[1, 1].set_title("FFT of Y Coordinate")
    axs[1, 1].set_xlabel("Frequency (Hz)")
    axs[1, 1].set_ylabel("Normalized Magnitude")
    axs[1, 1].grid(True)
    
    plt.tight_layout()
    
    # Save figure if output directory is specified
    if output_dir:
        os.makedirs(output_dir, exist_ok=True)
        plt.savefig(os.path.join(output_dir, f"walking_sequence_{index+1}.png"))
        
    plt.show()

def plot_2d_trajectory(sequence, index, output_dir=None):
    """Plot 2D trajectory of face movement"""
    x, y = extract_coordinates(sequence)
    
    plt.figure(figsize=(8, 8))
    plt.plot(x, y, 'b-')
    plt.plot(x[0], y[0], 'go', markersize=10, label='Start')
    plt.plot(x[-1], y[-1], 'ro', markersize=10, label='End')
    
    # Draw arrows to show direction
    arrow_indices = np.linspace(0, len(x)-2, 10, dtype=int)
    for i in arrow_indices:
        plt.arrow(x[i], y[i], 
                 (x[i+1] - x[i])*0.9, (y[i+1] - y[i])*0.9,
                 head_width=0.01, head_length=0.015, 
                 fc='k', ec='k')
    
    plt.title(f"2D Face Trajectory - Walking Sequence {index+1}")
    plt.xlabel("X Coordinate")
    plt.ylabel("Y Coordinate")
    plt.grid(True)
    plt.legend()
    
    # Keep aspect ratio equal
    plt.axis('equal')
    
    # Save figure if output directory is specified
    if output_dir:
        os.makedirs(output_dir, exist_ok=True)
        plt.savefig(os.path.join(output_dir, f"trajectory_sequence_{index+1}.png"))
        
    plt.show()

def main():
    # File path
    file_path = "face_tracking_data.json"
    
    # Create output directory for saving plots
    output_dir = "face_tracking_plots"
    
    # Load data
    print(f"Loading data from {file_path}...")
    data = load_data(file_path)
    print(f"Loaded {len(data)} sequences")
    
    # Select random walking sequences
    print("Selecting random walking sequences...")
    selected_sequences = select_random_walking_sequences(data, 10)
    print(f"Selected {len(selected_sequences)} sequences")
    
    # Plot each sequence
    for i, sequence in enumerate(selected_sequences):
        print(f"\nAnalyzing sequence {i+1}...")
        plot_sequence_and_fft(sequence, i, output_dir)
        plot_2d_trajectory(sequence, i, output_dir)
        
    print(f"\nAll plots have been saved to the '{output_dir}' directory")

if __name__ == "__main__":
    main()