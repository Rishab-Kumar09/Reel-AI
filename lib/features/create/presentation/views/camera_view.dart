import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:get/get.dart';
import 'package:flutter_firebase_app_new/core/theme/app_theme.dart';
import 'package:flutter_firebase_app_new/features/feed/data/services/sample_data_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:flutter_firebase_app_new/features/create/presentation/widgets/video_metadata_form.dart';

class CameraView extends StatefulWidget {
  const CameraView({super.key});

  @override
  State<CameraView> createState() => _CameraViewState();
}

class _CameraViewState extends State<CameraView> {
  late CameraController _cameraController;
  bool _isInitialized = false;
  bool _isRecording = false;
  bool _isFrontCamera = false;
  String? _videoPath;
  Timer? _recordingTimer;
  int _recordingDuration = 0;
  static const int maxRecordingDuration = 90; // 90 seconds max

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
        cameras[_isFrontCamera ? 1 : 0],
        ResolutionPreset.max,
        enableAudio: true,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _cameraController.initialize();

      // Lock to portrait mode and set optimal video recording size
      await _cameraController
          .lockCaptureOrientation(DeviceOrientation.portraitUp);

      // Set video recording format to highest quality
      await _cameraController.prepareForVideoRecording();

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

  void _startTimer() {
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _recordingDuration++;
      });

      if (_recordingDuration >= maxRecordingDuration) {
        _stopRecording();
      }
    });
  }

  void _stopTimer() {
    _recordingTimer?.cancel();
    _recordingTimer = null;
    _recordingDuration = 0;
  }

  Future<void> _startRecording() async {
    if (!_isInitialized) return;

    try {
      final Directory appDir = await getTemporaryDirectory();
      final String videoDirectory = '${appDir.path}/Videos';
      await Directory(videoDirectory).create(recursive: true);

      final String fileName =
          'video_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final String filePath = '$videoDirectory/$fileName';

      await _cameraController.startVideoRecording();
      _startTimer();

      setState(() {
        _isRecording = true;
        _videoPath = filePath;
      });
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to start recording: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.withOpacity(0.1),
        colorText: Colors.red,
      );
    }
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) return;

    try {
      final XFile video = await _cameraController.stopVideoRecording();
      _stopTimer();

      setState(() {
        _isRecording = false;
      });

      // Show metadata form
      Get.dialog(
        Dialog(
          child: StatefulBuilder(
            builder: (context, setState) {
              bool isLoading = false;
              double uploadProgress = 0.0;
              return Stack(
                children: [
                  VideoMetadataForm(
                    isLoading: isLoading,
                    onSubmit: (metadata) async {
                      setState(() {
                        isLoading = true;
                        uploadProgress = 0.0;
                      });

                      try {
                        final sampleDataService = SampleDataService();
                        await sampleDataService.uploadRecordedVideo(
                          File(video.path),
                          metadata: metadata,
                          onProgress: (progress) {
                            setState(() {
                              uploadProgress = progress;
                            });
                          },
                        );
                        Get.back(); // Close the dialog
                        Get.back(); // Return to previous screen
                        Get.snackbar(
                          'Success',
                          'Video uploaded successfully',
                          snackPosition: SnackPosition.BOTTOM,
                          backgroundColor: Colors.green.withOpacity(0.1),
                          colorText: Colors.green,
                        );
                      } catch (e) {
                        print('Error uploading video: $e');
                        Get.snackbar(
                          'Error',
                          e.toString(),
                          snackPosition: SnackPosition.BOTTOM,
                          backgroundColor: Colors.red.withOpacity(0.1),
                          colorText: Colors.red,
                        );
                      } finally {
                        setState(() {
                          isLoading = false;
                        });
                      }
                    },
                  ),
                  if (isLoading && uploadProgress > 0)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black54,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(
                              value: uploadProgress,
                              color: AppTheme.primaryColor,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Uploading video... ${(uploadProgress * 100).toInt()}%',
                              style: AppTheme.bodyLarge.copyWith(
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to stop recording: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.withOpacity(0.1),
        colorText: Colors.red,
      );
    }
  }

  Future<void> _toggleCamera() async {
    if (!_isInitialized || _isRecording) return;

    try {
      final cameras = await availableCameras();
      if (cameras.length < 2) return;

      setState(() {
        _isFrontCamera = !_isFrontCamera;
        _isInitialized = false;
      });

      await _cameraController.dispose();
      await _initializeCamera();
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to switch camera: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.withOpacity(0.1),
        colorText: Colors.red,
      );
    }
  }

  @override
  void dispose() {
    _stopTimer();
    _cameraController.dispose();
    super.dispose();
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
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

          // Recording Timer
          if (_isRecording)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatDuration(_recordingDuration),
                        style: AppTheme.bodyMedium.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
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
                  onTap: _isRecording ? _stopRecording : _startRecording,
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
                    child: _isRecording
                        ? const Center(
                            child: Icon(
                              Icons.stop,
                              color: Colors.white,
                              size: 32,
                            ),
                          )
                        : null,
                  ),
                ),

                // Flip Camera Button
                IconButton(
                  icon: const Icon(Icons.flip_camera_ios),
                  color: Colors.white,
                  iconSize: 32,
                  onPressed: _toggleCamera,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
