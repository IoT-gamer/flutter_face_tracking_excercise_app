import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'device/mlkit_face_camera_repository.dart';
import 'screens/face_tracking_screen.dart';
import 'services/model_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  WakelockPlus.enable();

  // Initialize model service
  final modelService = ModelService();

  runApp(MyApp(modelService: modelService));
}

class MyApp extends StatelessWidget {
  final ModelService modelService;

  const MyApp({super.key, required this.modelService});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Face Activity Tracker',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: FaceTrackingScreen(
        mlkitFaceCameraRepository: MLKITFaceCameraRepository(),
        modelService: modelService,
      ),
    );
  }
}
