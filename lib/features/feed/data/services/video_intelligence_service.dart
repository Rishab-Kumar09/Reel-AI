import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:video_player/video_player.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class VideoIntelligenceService {
  static final VideoIntelligenceService _instance =
      VideoIntelligenceService._internal();
  VideoIntelligenceService._internal();
  factory VideoIntelligenceService() => _instance;

  final String _baseUrl = 'https://vision.googleapis.com/v1';
  String? get _apiKey => dotenv.env['VISION_API_KEY'];

  /// Test the OCR feature with a sample image
  Future<void> testOCR() async {
    try {
      // Sample image URL with text (you can replace this with any image URL containing text)
      const testImageUrl =
          'https://i.imgur.com/vEiVeXi.png'; // Example image with text

      Get.dialog(
        const Center(
          child: CircularProgressIndicator(),
        ),
        barrierDismissible: false,
      );

      final extractedText = await extractTextFromImage(testImageUrl);

      Get.back(); // Close loading dialog

      Get.dialog(
        AlertDialog(
          title: const Text('OCR Test Results'),
          content: SingleChildScrollView(
            child: Text(extractedText.isEmpty
                ? 'No text detected in the image'
                : extractedText),
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      Get.back(); // Close loading dialog
      Get.snackbar(
        'Error',
        'Failed to perform OCR test: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<String> extractTextFromImage(String imageUrl) async {
    try {
      if (_apiKey == null) {
        throw Exception('Vision API key not found in .env file');
      }

      // Download the image and convert to base64
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode != 200) {
        throw Exception('Failed to download image');
      }

      final base64Image = base64Encode(response.bodyBytes);

      // Make Vision API request
      final apiResponse = await http.post(
        Uri.parse('$_baseUrl/images:annotate?key=$_apiKey'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'requests': [
            {
              'image': {
                'content': base64Image,
              },
              'features': [
                {'type': 'TEXT_DETECTION'}
              ],
            }
          ],
        }),
      );

      if (apiResponse.statusCode == 200) {
        final data = json.decode(apiResponse.body);
        final responses = data['responses'] as List;
        if (responses.isNotEmpty) {
          final textAnnotations = responses[0]['textAnnotations'];
          if (textAnnotations != null && textAnnotations.isNotEmpty) {
            return textAnnotations[0]['description'] as String;
          }
        }
      } else {
        throw Exception(
            'Vision API error: ${apiResponse.statusCode} - ${apiResponse.body}');
      }

      return '';
    } catch (e) {
      print('Error in Vision API: $e');
      return '';
    }
  }

  Future<String> extractTextFromVideo(String videoUrl) async {
    try {
      if (_apiKey == null) {
        throw Exception('Vision API key not found in .env file');
      }

      // For YouTube URLs, we need to extract the video ID and use a direct video URL
      if (videoUrl.contains('youtu.be') || videoUrl.contains('youtube.com')) {
        final videoId = _extractYouTubeId(videoUrl);
        if (videoId == null) throw Exception('Invalid YouTube URL');
        throw Exception(
            'YouTube videos are not supported directly. Please provide a direct video URL.');
      }

      // Initialize video player
      final controller = VideoPlayerController.network(videoUrl);
      await controller.initialize();

      final StringBuilder textBuilder = StringBuilder();

      // Extract frames at 1-second intervals
      final duration = controller.value.duration;
      final frameCount = duration.inSeconds;

      for (int i = 0; i < frameCount; i++) {
        // Seek to position
        await controller.seekTo(Duration(seconds: i));
        await Future.delayed(
            Duration(milliseconds: 100)); // Wait for seek to complete

        // Get frame
        final frame = await _captureFrame(controller);
        if (frame == null) continue;

        // Convert frame to base64
        final base64Image = base64Encode(frame);

        // Make Vision API request
        final response = await http.post(
          Uri.parse('$_baseUrl/images:annotate?key=$_apiKey'),
          headers: {
            'Content-Type': 'application/json',
          },
          body: json.encode({
            'requests': [
              {
                'image': {'content': base64Image},
                'features': [
                  {'type': 'TEXT_DETECTION'}
                ]
              }
            ]
          }),
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final responses = data['responses'] as List;
          if (responses.isNotEmpty) {
            final textAnnotations = responses[0]['textAnnotations'];
            if (textAnnotations != null && textAnnotations.isNotEmpty) {
              textBuilder.write(textAnnotations[0]['description']);
              textBuilder.write('\n');
            }
          }
        }
      }

      // Clean up
      await controller.dispose();

      return textBuilder.toString().trim();
    } catch (e) {
      print('Error in Vision API: $e');
      return '';
    }
  }

  String? _extractYouTubeId(String url) {
    RegExp regExp = RegExp(
      r'^.*((youtu.be\/)|(v\/)|(\/u\/\w\/)|(embed\/)|(watch\?))\??v?=?([^#&?]*).* ',
      caseSensitive: false,
      multiLine: false,
    );
    final match = regExp.firstMatch(url);
    return match?.group(7);
  }

  Future<List<int>?> _captureFrame(VideoPlayerController controller) async {
    try {
      // This is a placeholder - actual frame capture would need to be implemented
      // using platform-specific code or a different package
      throw UnimplementedError('Frame capture not implemented');
    } catch (e) {
      print('Error capturing frame: $e');
      return null;
    }
  }
}

class StringBuilder {
  final StringBuffer _buffer = StringBuffer();

  void write(String? text) {
    if (text != null && text.isNotEmpty) {
      _buffer.write(text);
    }
  }

  @override
  String toString() => _buffer.toString();
}
