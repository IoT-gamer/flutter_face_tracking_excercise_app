import 'package:flutter/material.dart';
import 'package:flutter_face_tracking_exercise_app/screens/face_tracking_screen.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'device/mlkit_face_camera_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  WakelockPlus.enable();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      home: FaceTrackingScreen(
        mlkitFaceCameraRepository: MLKITFaceCameraRepository(),
      ),
    );
  }
}
