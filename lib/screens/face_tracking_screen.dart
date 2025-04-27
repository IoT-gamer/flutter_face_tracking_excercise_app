import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../constants/constants.dart';
import '../cubit/face_detection_cubit.dart';
import '../device/mlkit_face_camera_repository.dart';
import '../services/model_service.dart';
import '../widgets/dot_painter.dart';
import '../widgets/frequency_bar_chart_widget.dart';
import '../widgets/metadata_indicator_widget.dart';
import '../widgets/model_results_widget.dart';
import '../widgets/outlier_visualization_widget.dart';
import '../widgets/status_message_widget.dart';

class FaceTrackingScreen extends StatelessWidget {
  const FaceTrackingScreen({
    super.key,
    required this.mlkitFaceCameraRepository,
    required this.modelService,
  });

  final MLKITFaceCameraRepository mlkitFaceCameraRepository;
  final ModelService modelService;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create:
          (context) => FaceDetectionCubit(
            mlkitFaceCameraRepository: mlkitFaceCameraRepository,
            modelService: modelService,
          ),
      child: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _customActivityController =
      TextEditingController();

  @override
  void dispose() {
    _customActivityController.dispose();
    context.read<FaceDetectionCubit>().cleanUp();
    super.dispose();
  }

  void _showCustomActivityDialog(
    BuildContext context,
    FaceDetectionCubit cubit,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Save Custom Activity'),
          content: TextField(
            controller: _customActivityController,
            decoration: const InputDecoration(hintText: 'Enter activity name'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (_customActivityController.text.isNotEmpty) {
                  cubit.saveFaceData(_customActivityController.text);
                  _customActivityController.clear();
                  Navigator.pop(context);
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final faceDetectionCubit = context.read<FaceDetectionCubit>();
    final size = MediaQuery.of(context).size;

    return Container(
      alignment: Alignment.topCenter,
      child: BlocBuilder<FaceDetectionCubit, FaceDetectionState>(
        builder: (context, state) {
          return Stack(
            fit: StackFit.expand,
            children: [
              if (state.cameraController != null)
                CameraPreview(state.cameraController!),
              if (state.cameraController != null &&
                  state.centerX != -9999 &&
                  state.centerY != -9999)
                CustomPaint(
                  painter: DotPainter(
                    Offset(
                      size.width -
                          state.centerX.toDouble() *
                              size.width /
                              state.cameraController!.value.previewSize!.height,
                      state.centerY.toDouble() *
                          size.height /
                          state.cameraController!.value.previewSize!.width,
                    ),
                  ),
                ),

              // Frequency Bar Chart - placed near the bottom but above buttons
              Positioned(
                bottom: 200, // Position above the button panel
                left: 0,
                right: 0,
                child: FrequencyBarChartWidget(
                  dominantFrequency: state.dominantFrequency,
                  maxAmplitude: state.maxAmplitude,
                  frequencies: state.frequencies,
                  amplitudes: state.amplitudes,
                  isVisible: state.showFrequencyChart,
                ),
              ),

              // Status message display
              if (state.statusMessage.isNotEmpty)
                Positioned(
                  top: 50,
                  left: 0,
                  right: 0,
                  child: StatusMessageWidget(message: state.statusMessage),
                ),

              // Model prediction results - positioned at the top
              if (state.modelAvailable)
                Positioned(
                  top: state.statusMessage.isNotEmpty ? 120 : 50,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Column(
                      children: [
                        ModelResultsWidget(
                          modelAvailable: state.modelAvailable,
                          modelLoaded: state.modelLoaded,
                          currentActivity: state.currentActivity,
                          confidenceScore: state.confidenceScore,
                        ),
                        // Add the outlier visualization if enabled with all state statistics
                        if (state.showOutlierVisualization &&
                            state.filteredCoordinates.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: OutlierVisualizationWidget(
                              originalCoordinates: state.originalCoordinates,
                              filteredCoordinates: state.filteredCoordinates,
                              adjustedPoints: state.adjustedPoints,
                              totalPoints: state.totalPoints,
                              totalOutliersDetected:
                                  state.totalOutliersDetected,
                              currentOutliers: state.currentOutliers,
                              outlierPercentage: state.outlierPercentage,
                              showVisualization: state.showOutlierVisualization,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

              // Metadata indicator with outlier stats and frequency toggle
              Positioned(
                top: 10,
                right: 10,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    MetadataIndicatorWidget(
                      fps: AppConstants.cameraFps,
                      queueLength: state.queue.length,
                      maxQueueLength: AppConstants.sequenceLength,
                      modelLoaded: state.modelLoaded,
                    ),
                    if (state.modelLoaded)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: GestureDetector(
                          onTap: () {
                            faceDetectionCubit.toggleOutlierVisualization();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 5,
                              horizontal: 10,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  state.showOutlierVisualization
                                      ? Colors.green.withOpacity(0.7)
                                      : Colors.black.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  state.showOutlierVisualization
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Outlier Viz (${state.outlierPercentage.toStringAsFixed(1)}%)',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    // Frequency chart toggle button
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: GestureDetector(
                        onTap: () {
                          faceDetectionCubit.toggleFrequencyChart();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 5,
                            horizontal: 10,
                          ),
                          decoration: BoxDecoration(
                            color:
                                state.showFrequencyChart
                                    ? Colors.blue.withOpacity(0.7)
                                    : Colors.black.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                state.showFrequencyChart
                                    ? Icons.analytics
                                    : Icons.analytics_outlined,
                                color: Colors.white,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Frequency Analysis',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Bottom button panel with safer zone positioning
              Positioned(
                bottom: 30, // Safe distance from bottom
                left: 0,
                right: 0,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                await faceDetectionCubit.setUpFaceDetection();
                                faceDetectionCubit.subscribeToFaceDetection();
                              },
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                              child: const Text('Start Detection'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed:
                                  () =>
                                      faceDetectionCubit.saveFaceDataWalking(),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                              child: const Text('Save Walking'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed:
                                  () =>
                                      faceDetectionCubit.saveFaceDataStanding(),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                              child: const Text('Save Standing'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed:
                                  () => _showCustomActivityDialog(
                                    context,
                                    faceDetectionCubit,
                                  ),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                backgroundColor: Colors.green.shade700,
                              ),
                              child: const Text(
                                'Custom Activity',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed:
                                  () => faceDetectionCubit.deleteAllFaceData(),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                backgroundColor: Colors.red.shade700,
                              ),
                              child: const Text(
                                'Delete Data',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
