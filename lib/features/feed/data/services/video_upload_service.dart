import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_firebase_app_new/features/auth/presentation/controllers/auth_controller.dart';
import 'package:flutter_firebase_app_new/features/feed/data/services/transcription_service.dart';
import 'package:flutter_firebase_app_new/features/feed/data/models/video_model.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_compress/video_compress.dart';
import 'package:path/path.dart' as path;

class VideoUploadService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final AuthController _authController = Get.find<AuthController>();
  final TranscriptionService _transcriptionService = TranscriptionService();

  // Add subscription variable
  Subscription? _compressSubscription;

  void dispose() {
    _compressSubscription?.unsubscribe();
    _compressSubscription = null;
  }

  Future<void> uploadVideo(
    File videoFile, {
    Map<String, dynamic>? metadata,
    Function(double)? onProgress,
  }) async {
    try {
      final currentUser = _authController.user.value;
      if (currentUser == null) throw 'No user logged in';

      // 1. Process and upload video
      final String videoUrl = await _processAndUploadVideo(
        videoFile,
        onProgress: onProgress,
      );

      // 2. Generate thumbnail
      final String thumbnailUrl = await _generateAndUploadThumbnail(
        videoFile.path,
        path.basename(videoFile.path),
      );

      // 3. Create video document
      final videoDoc = await _firestore.collection('videos').add({
        'userId': currentUser.id,
        'username': currentUser.name ?? currentUser.email,
        'videoUrl': videoUrl,
        'thumbnailUrl': thumbnailUrl,
        'title': metadata?['title'] ?? 'Untitled Video',
        'description': metadata?['description'] ?? 'New video upload',
        'category': metadata?['category'] ?? 'general',
        'topics': metadata?['tags']?.cast<String>() ?? ['General'],
        'skills': ['Content Creation'],
        'difficultyLevel': metadata?['difficultyLevel'] ?? 'beginner',
        'duration': 180,
        'likes': 0,
        'comments': 0,
        'shares': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'transcriptStatus': 'pending',
      });

      // 4. Start transcript generation in background
      _generateTranscriptInBackground(
          videoDoc.id, videoUrl, metadata?['category'] ?? 'general');
    } catch (e) {
      print('Error in uploadVideo: $e');
      rethrow;
    }
  }

  Future<String> _processAndUploadVideo(File videoFile,
      {Function(double)? onProgress}) async {
    try {
      final fileName = 'video_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final storageRef = _storage.ref().child('videos/$fileName');

      // Upload video
      final uploadTask = storageRef.putFile(
        videoFile,
        SettableMetadata(contentType: 'video/mp4'),
      );

      // Monitor progress
      uploadTask.snapshotEvents.listen((snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        onProgress?.call(progress);
      });

      // Wait for upload to complete
      await uploadTask;
      return await storageRef.getDownloadURL();
    } catch (e) {
      print('Error processing/uploading video: $e');
      rethrow;
    }
  }

  Future<String> _generateAndUploadThumbnail(
      String videoPath, String videoFileName) async {
    try {
      final thumbnailFile = await VideoCompress.getFileThumbnail(
        videoPath,
        quality: 50,
        position: 1000,
      );

      final thumbnailFileName = 'thumb_$videoFileName';
      final thumbnailRef =
          _storage.ref().child('thumbnails/$thumbnailFileName');

      await thumbnailRef.putFile(
        thumbnailFile,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      return await thumbnailRef.getDownloadURL();
    } catch (e) {
      print('Error generating thumbnail: $e');
      return 'https://picsum.photos/seed/${DateTime.now().millisecondsSinceEpoch}/300/500';
    }
  }

  void _generateTranscriptInBackground(
      String videoId, String videoUrl, String category) {
    // Use compute or isolate for background processing
    Future(() async {
      try {
        final videoModel = VideoModel.fromFirestore(
            await _firestore.collection('videos').doc(videoId).get());

        final transcript =
            await _transcriptionService.generateTranscript(videoModel);

        // Update video document with transcript status
        await _firestore.collection('videos').doc(videoId).update({
          'transcriptStatus': 'completed',
          'transcriptUpdatedAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        print('Error generating transcript in background: $e');
        await _firestore.collection('videos').doc(videoId).update({
          'transcriptStatus': 'failed',
          'transcriptError': e.toString(),
        });
      }
    });
  }

  Future<void> processExistingVideos() async {
    try {
      final videos = await _firestore
          .collection('videos')
          .where('transcriptStatus', isNull: true)
          .limit(10)
          .get();

      for (var video in videos.docs) {
        _generateTranscriptInBackground(
          video.id,
          video.data()['videoUrl'],
          video.data()['category'] ?? 'general',
        );
      }
    } catch (e) {
      print('Error processing existing videos: $e');
      rethrow;
    }
  }
}
