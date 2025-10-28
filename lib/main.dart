import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:yolo/pages/bottomnav_page.dart';
import 'package:yolo/pages/permission_denied_page.dart';

List<CameraDescription> gAvailableCameras = [];
// Use a ValueNotifier to hold the permission status and trigger rebuilds
final ValueNotifier<PermissionStatus> cameraPermissionStatusNotifier =
ValueNotifier(PermissionStatus.denied); // Initialize as denied

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Get initial status WITHOUT requesting yet, to avoid immediate popup
  // Let PermissionDeniedPage handle the first request if needed
  cameraPermissionStatusNotifier.value = await Permission.camera.status;

  // Initialize cameras only if already granted (e.g., app restarted after granting)
  if (cameraPermissionStatusNotifier.value.isGranted) {
    try {
      gAvailableCameras = await availableCameras();
      print('Cameras initialized on startup (permission was already granted).');
    } catch (e) {
      gAvailableCameras = [];
      print('Could not get cameras on startup: $e');
    }
  } else {
    print('Camera permission not granted on startup.');
    gAvailableCameras = [];
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Listen to the notifier to rebuild when permission status changes
    return ValueListenableBuilder<PermissionStatus>(
      valueListenable: cameraPermissionStatusNotifier,
      builder: (context, status, child) {
        print("MyApp rebuild triggered. Permission status: $status"); // Debug print
        return MaterialApp(
          title: 'YOLO Detection',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
            useMaterial3: true,
            brightness: Brightness.light,
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
            brightness: Brightness.dark,
          ),
          themeMode: ThemeMode.system,
          debugShowCheckedModeBanner: false,
          home: status.isGranted
              ? BottomNavPage(cameras: gAvailableCameras)
          // Pass a callback to re-check and update status
              : PermissionDeniedPage(onPermissionGranted: _checkAndInitializeCameras),
        );
      },
    );
  }

  // Function to re-check permission, initialize cameras, and update notifier
  Future<void> _checkAndInitializeCameras() async {
    print("Checking permissions again...");
    final status = await Permission.camera.status; // Check current status
    if (status.isGranted) {
      print("Permission now granted. Initializing cameras...");
      try {
        gAvailableCameras = await availableCameras();
        print("Cameras initialized successfully after granting permission.");
        //Update the notifier to trigger MyApp rebuild
        cameraPermissionStatusNotifier.value = status;
      } catch (e) {
        print('Could not get cameras after granting permission: $e');
        gAvailableCameras = [];
        // Even if camera init fails, update status to potentially remove permission page
        cameraPermissionStatusNotifier.value = status;
      }
    } else {
      print("Permission still not granted after check.");
      // Optionally update notifier if status changed (e.g., to permanently denied)
      if (status != cameraPermissionStatusNotifier.value) {
        cameraPermissionStatusNotifier.value = status;
      }
    }
  }
}