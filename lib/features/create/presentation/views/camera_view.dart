import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:get/get.dart';
import 'package:flutter_firebase_app_new/core/theme/app_theme.dart';
import 'package:flutter_firebase_app_new/features/feed/data/services/sample_data_service.dart';

class CameraView extends StatefulWidget {
  const CameraView({super.key});

  @override
  State<CameraView> createState() => _CameraViewState();
}

class _CameraViewState extends State<CameraView> {
  late CameraController _cameraController;
  bool _isInitialized = false;
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        Get.snackbar(
          'Error',
          'No cameras found',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.withOpacity(0.1),
          colorText: Colors.red,
        );
        return;
      }

      _cameraController = CameraController(
        cameras[0],
        ResolutionPreset.high,
        enableAudio: true,
      );

      await _cameraController.initialize();
      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to initialize camera: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.withOpacity(0.1),
        colorText: Colors.red,
      );
    }
  }

  Future<void> _toggleRecording() async {
    if (!_isInitialized) return;

    try {
      if (_isRecording) {
        final XFile video = await _cameraController.stopVideoRecording();
        setState(() {
          _isRecording = false;
        });

        // Upload the recorded video
        try {
          final sampleDataService = SampleDataService();
          await sampleDataService.uploadVideoFromDevice();
          Get.snackbar(
            'Success',
            'Video uploaded successfully',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.green.withOpacity(0.1),
            colorText: Colors.green,
          );
          Get.back(); // Return to previous screen
        } catch (e) {
          Get.snackbar(
            'Error',
            'Failed to upload video: $e',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.red.withOpacity(0.1),
            colorText: Colors.red,
          );
        }
      } else {
        await _cameraController.startVideoRecording();
        setState(() {
          _isRecording = true;
        });
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to ${_isRecording ? 'stop' : 'start'} recording: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.withOpacity(0.1),
        colorText: Colors.red,
      );
    }
  }

  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera Preview
          Center(
            child: CameraPreview(_cameraController),
          ),

          // Controls
          Positioned(
            bottom: 32,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Close Button
                IconButton(
                  icon: const Icon(Icons.close),
                  color: Colors.white,
                  iconSize: 32,
                  onPressed: () => Get.back(),
                ),

                // Record Button
                GestureDetector(
                  onTap: _toggleRecording,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isRecording ? Colors.red : Colors.white,
                      border: Border.all(
                        color: Colors.white,
                        width: 4,
                      ),
                    ),
                  ),
                ),

                // Flip Camera Button
                IconButton(
                  icon: const Icon(Icons.flip_camera_ios),
                  color: Colors.white,
                  iconSize: 32,
                  onPressed: () async {
                    final cameras = await availableCameras();
                    final currentCamera = _cameraController.description;
                    final newCamera = cameras.firstWhere(
                      (camera) =>
                          camera.lensDirection != currentCamera.lensDirection,
                      orElse: () => currentCamera,
                    );

                    if (newCamera != currentCamera) {
                      await _cameraController.dispose();
                      _cameraController = CameraController(
                        newCamera,
                        ResolutionPreset.high,
                        enableAudio: true,
                      );
                      await _cameraController.initialize();
                      setState(() {});
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
