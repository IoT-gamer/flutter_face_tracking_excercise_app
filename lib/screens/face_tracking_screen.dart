// statesless widget that contains bloc provider and home page

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubit/face_detection_cubit.dart';
import '../device/mlkit_face_camera_repository.dart';
import '../widgets/dot_painter.dart';

class FaceTrackingScreen extends StatelessWidget {
  const FaceTrackingScreen({
    super.key,
    required this.mlkitFaceCameraRepository,
  });

  final MLKITFaceCameraRepository mlkitFaceCameraRepository;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create:
          (context) => FaceDetectionCubit(
            mlkitFaceCameraRepository: mlkitFaceCameraRepository,
          ),
      child: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final faceDetectionCubit = context.read<FaceDetectionCubit>();
    final size = MediaQuery.of(context).size;
    final deviceRatio = size.width / size.height;
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

              // Status message display
              if (state.statusMessage.isNotEmpty)
                Positioned(
                  top: 50,
                  left: 0,
                  right: 0,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      state.statusMessage,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
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
                                  () => faceDetectionCubit.deleteAllFaceData(),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                backgroundColor:
                                    Colors
                                        .red
                                        .shade700, // Red color for delete button
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
