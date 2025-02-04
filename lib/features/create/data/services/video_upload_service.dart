import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:video_compress/video_compress.dart';
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;
import 'dart:convert';

class VideoUploadService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // OpenShot API configuration
  static const String _openShotApiUrl = 'YOUR_OPENSHOT_API_URL';
  static const String _openShotApiKey = 'YOUR_OPENSHOT_API_KEY';

  Future<Map<String, dynamic>> uploadVideo({
    required File videoFile,
    required String userId,
    required String category,
    required List<String> topics,
    required List<String> skills,
    required String difficultyLevel,
    required String description,
  }) async {
    try {
      // 1. Compress video
      final MediaInfo? mediaInfo = await VideoCompress.compressVideo(
        videoFile.path,
        quality: VideoQuality.MediumQuality,
        deleteOrigin: false,
      );

      if (mediaInfo == null) throw Exception('Video compression failed');

      // 2. Generate thumbnail
      final thumbnailFile = await VideoCompress.getFileThumbnail(videoFile.path);
      
      // 3. Upload compressed video to Firebase Storage
      final videoFileName = '${DateTime.now().millisecondsSinceEpoch}_${path.basename(videoFile.path)}';
      final videoRef = _storage.ref().child('videos/$videoFileName');
      final uploadTask = await videoRef.putFile(File(mediaInfo.path!));
      final videoUrl = await uploadTask.ref.getDownloadURL();

      // 4. Upload thumbnail
      final thumbnailFileName = 'thumb_$videoFileName';
      final thumbnailRef = _storage.ref().child('thumbnails/$thumbnailFileName');
      await thumbnailRef.putFile(thumbnailFile);
      final thumbnailUrl = await thumbnailRef.getDownloadURL();

      // 5. Process video with OpenShot API for AI enhancements
      final aiMetadata = await _processVideoWithAI(File(mediaInfo.path!));

      // 6. Save video metadata to Firestore
      final videoDoc = await _firestore.collection('videos').add({
        'userId': userId,
        'videoUrl': videoUrl,
        'thumbnailUrl': thumbnailUrl,
        'category': category,
        'topics': topics,
        'skills': skills,
        'difficultyLevel': difficultyLevel,
        'description': description,
        'duration': mediaInfo.duration,
        'likes': 0,
        'comments': 0,
        'shares': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'aiMetadata': aiMetadata,
      });

      return {
        'success': true,
        'videoId': videoDoc.id,
        'videoUrl': videoUrl,
        'thumbnailUrl': thumbnailUrl,
      };
    } catch (e) {
      print('Error uploading video: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    } finally {
      // Clean up
      await VideoCompress.deleteAllCache();
    }
  }

  Future<Map<String, dynamic>> _processVideoWithAI(File videoFile) async {
    try {
      // 1. Upload video to OpenShot API
      final uploadRequest = http.MultipartRequest(
        'POST',
        Uri.parse('$_openShotApiUrl/upload'),
      )
        ..headers.addAll({
          'Authorization': 'Bearer $_openShotApiKey',
        })
        ..files.add(
          await http.MultipartFile.fromPath('video', videoFile.path),
        );

      final uploadResponse = await uploadRequest.send();
      final uploadResult = await http.Response.fromStream(uploadResponse);
      
      if (uploadResponse.statusCode != 200) {
        throw Exception('Failed to upload video to OpenShot API');
      }

      final uploadData = json.decode(uploadResult.body);
      final projectId = uploadData['project_id'];

      // 2. Request AI processing
      final processResponse = await http.post(
        Uri.parse('$_openShotApiUrl/process/$projectId'),
        headers: {
          'Authorization': 'Bearer $_openShotApiKey',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'tasks': [
            'scene_detection',
            'content_analysis',
            'transcription',
            'thumbnail_generation',
          ],
        }),
      );

      if (processResponse.statusCode != 200) {
        throw Exception('Failed to process video with AI');
      }

      final processData = json.decode(processResponse.body);

      // 3. Extract AI-generated metadata
      return {
        'scenes': processData['scenes'],
        'content_tags': processData['content_tags'],
        'transcription': processData['transcription'],
        'key_moments': processData['key_moments'],
      };
    } catch (e) {
      print('Error processing video with AI: $e');
      return {};
    }
  }
} 