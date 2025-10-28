import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionDeniedPage extends StatefulWidget {
  // Callback to trigger re-check in MyApp
  final Future<void> Function() onPermissionGranted;

  const PermissionDeniedPage({Key? key, required this.onPermissionGranted})
      : super(key: key);

  @override
  State<PermissionDeniedPage> createState() => _PermissionDeniedPageState();
}

class _PermissionDeniedPageState extends State<PermissionDeniedPage>
    with WidgetsBindingObserver { // Add the observer mixin

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // Register observer
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // Unregister observer
    super.dispose();
  }

  // Lifecycle Listener
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // When app resumes (potentially from settings), re-check permission
    if (state == AppLifecycleState.resumed) {
      print("App resumed, checking permission status...");
      // Call the callback passed from MyApp to trigger re-check and potential navigation
      widget.onPermissionGranted();
    }
  }
  //  End Lifecycle Listener


  // Function to request permission again or open settings
  Future<void> _handlePermissionRequest() async {
    final status = await Permission.camera.request();

    if (status.isGranted) {
      // If granted immediately, trigger the callback
      widget.onPermissionGranted();
    } else if (status.isPermanentlyDenied) {
      _showSettingsDialog(); // Suggest opening settings
    } else {
      // Still denied, show a message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Camera permission is required to proceed.')),
        );
      }
    }
  }

  // Function to directly open app settings
  Future<void> _openSettings() async {
    await openAppSettings();
    // No need to call onPermissionGranted here, the lifecycle listener will handle it on resume
  }

  // Helper to show a dialog guiding user to settings for permanent denial
  void _showSettingsDialog() {
    if (!mounted) return; // Check if widget is still active
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Permission Denied'),
        content: const Text(
            'Camera permission was permanently denied. Please enable it manually in the app settings to use this feature.'),
        actions: <Widget>[
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          TextButton(
            child: const Text('Open Settings'),
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog first
              _openSettings(); // Then open settings
            },
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    // Wrap Scaffold with SafeArea
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Camera Permission Needed'),
        ),
        body: Center( // Center content
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center, // Center vertically
              crossAxisAlignment: CrossAxisAlignment.center,// Center horizontally
              children: [
                Icon(
                  Icons.no_photography_outlined,
                  size: 80,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Camera Access Required',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Text(
                  'This app requires camera access to detect objects in real-time. Please grant permission to enable this feature.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  icon: const Icon(Icons.camera_enhance),
                  label: const Text('Grant Permission'),
                  // Call the request handler directly
                  onPressed: _handlePermissionRequest,
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  icon: const Icon(Icons.settings_suggest, size: 20),
                  label: const Text('Open App Settings'),
                  onPressed: _openSettings,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}