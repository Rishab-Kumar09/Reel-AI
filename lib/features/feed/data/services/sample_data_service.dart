import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:video_compress/video_compress.dart';
import 'dart:async';
import 'package:mime/mime.dart';
import 'dart:typed_data';
import 'package:get/get.dart';
import 'package:flutter_firebase_app_new/features/auth/presentation/controllers/auth_controller.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

class SampleDataService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final AuthController _authController = Get.find<AuthController>();

  // Add subscription variable
  Subscription? _compressSubscription;

  // Initialize compression subscription
  void _initCompressSubscription() {
    _compressSubscription?.unsubscribe();
    _compressSubscription =
        VideoCompress.compressProgress$.subscribe((progress) {
      print('Compression progress: $progress%');
    });
  }

  // Dispose subscription
  void dispose() {
    _compressSubscription?.unsubscribe();
    _compressSubscription = null;
  }

  Future<String> _uploadVideoToStorage(String videoUrl, String fileName) async {
    try {
      print('Downloading video from: $videoUrl');
      final response = await http.get(Uri.parse(videoUrl));

      if (response.statusCode != 200) {
        throw 'Failed to download video from source';
      }

      print('Uploading video to Firebase Storage: $fileName');
      final storageRef = _storage.ref().child('videos/$fileName');

      // Upload video to Firebase Storage
      await storageRef.putData(
          response.bodyBytes,
          SettableMetadata(
            contentType: 'video/mp4',
          ));

      // Get the download URL
      final downloadUrl = await storageRef.getDownloadURL();
      print('Video uploaded successfully. Download URL: $downloadUrl');

      return downloadUrl;
    } catch (e) {
      print('Error uploading video to storage: $e');
      rethrow;
    }
  }

  Future<Map<String, String>> _getStorageVideoUrls() async {
    try {
      print('Fetching video URLs from Firebase Storage...');
      final storageRef = _storage.ref().child('videos');
      final ListResult result = await storageRef.listAll();

      Map<String, String> videoUrls = {};
      for (var item in result.items) {
        final String url = await item.getDownloadURL();
        print('Found video: ${item.name} -> $url');
        videoUrls[item.name] = url;
      }
      return videoUrls;
    } catch (e) {
      print('Error fetching video URLs: $e');
      rethrow;
    }
  }

  Future<void> addSampleVideos() async {
    try {
      print('Starting to add sample videos...');

      // Get current user
      final currentUser = _authController.user.value;
      if (currentUser == null) {
        throw 'No user logged in';
      }
      print('Adding videos for user: ${currentUser.id}');

      // First test if we can write to Firestore
      try {
        print('Testing Firestore write access...');
        final testDoc = await _firestore.collection('test').add({
          'timestamp': FieldValue.serverTimestamp(),
        });
        await testDoc.delete();
        print('Firestore write test successful');
      } catch (e) {
        print('Error testing Firestore write access: $e');
        throw 'Failed to write to Firestore. Please check if Email/Password authentication is enabled in Firebase Console and Firestore rules are properly set.';
      }

      // First, upload sample videos if they don't exist
      await uploadSampleVideos();

      // Get all video URLs from storage
      final videoUrls = await _getStorageVideoUrls();
      print('Available videos in storage: ${videoUrls.keys.join(", ")}');

      // Video 1
      if (videoUrls.containsKey('vertical_video1.mp4')) {
        print('Adding Video 1...');
        await _addVideo(
          userId: currentUser.id,
          username: currentUser.name ?? currentUser.email,
          videoUrl: videoUrls['vertical_video1.mp4']!,
          thumbnailUrl: 'https://picsum.photos/seed/video1/300/500',
          title: 'Creative Content Creation Tips',
          description: 'Check out this amazing content! 🎥 #creative #awesome',
          category: 'art',
          isVertical: true,
          topics: ['Creative', 'Entertainment'],
          skills: ['Content Creation'],
          difficultyLevel: 'beginner',
          aiMetadata: {
            'content_tags': ['Creative', 'Entertainment', 'Fun'],
            'key_moments': {
              'intro': [0, 15],
              'main': [16, 45],
              'highlight': [46, 75],
              'ending': [76, 90],
            },
          },
        );
        print('Video 1 added successfully');
      }

      // Video 2
      if (videoUrls.containsKey('vertical_video2.mp4')) {
        print('Adding Video 2...');
        await _addVideo(
          userId: currentUser.id,
          username: currentUser.name ?? currentUser.email,
          videoUrl: videoUrls['vertical_video2.mp4']!,
          thumbnailUrl: 'https://picsum.photos/seed/video2/300/500',
          title: 'Epic Adventure Moments',
          description: 'Epic adventure moments 🌟 #adventure #fun',
          category: 'entertainment',
          isVertical: true,
          topics: ['Adventure', 'Fun'],
          skills: ['Adventure Sports'],
          difficultyLevel: 'intermediate',
          aiMetadata: {
            'content_tags': ['Adventure', 'Fun', 'Sports'],
            'key_moments': {
              'setup': [0, 15],
              'action': [16, 45],
              'climax': [46, 75],
              'conclusion': [76, 90],
            },
          },
        );
        print('Video 2 added successfully');
      }

      // Video 3
      if (videoUrls.containsKey('vertical_video3.mp4')) {
        print('Adding Video 3...');
        await _addVideo(
          userId: currentUser.id,
          username: currentUser.name ?? currentUser.email,
          videoUrl: videoUrls['vertical_video3.mp4']!,
          thumbnailUrl: 'https://picsum.photos/seed/video3/300/500',
          title: 'Essential Learning Skills Guide',
          description: 'Learning new skills 📚 #education #learning',
          category: 'education',
          isVertical: true,
          topics: ['Education', 'Skills'],
          skills: ['Learning'],
          difficultyLevel: 'beginner',
          aiMetadata: {
            'content_tags': ['Education', 'Learning', 'Skills'],
            'key_moments': {
              'introduction': [0, 15],
              'explanation': [16, 45],
              'practice': [46, 75],
              'summary': [76, 90],
            },
          },
        );
        print('Video 3 added successfully');
      }

      // Video 4
      if (videoUrls.containsKey('vertical_video4.mp4')) {
        print('Adding Video 4...');
        await _addVideo(
          userId: currentUser.id,
          username: currentUser.name ?? currentUser.email,
          videoUrl: videoUrls['vertical_video4.mp4']!,
          thumbnailUrl: 'https://picsum.photos/seed/video4/300/500',
          title: 'Must-Know Life Hacks',
          description: 'Life hacks you need to know! 💡 #lifehacks #tips',
          category: 'lifehacks',
          isVertical: true,
          topics: ['Life Hacks', 'Tips'],
          skills: ['Problem Solving'],
          difficultyLevel: 'beginner',
          aiMetadata: {
            'content_tags': ['Life Hacks', 'Tips', 'Tricks'],
            'key_moments': {
              'problem': [0, 15],
              'solution': [16, 45],
              'demonstration': [46, 75],
              'tips': [76, 90],
            },
          },
        );
        print('Video 4 added successfully');
      }

      print('All sample videos added successfully');
    } catch (e, stackTrace) {
      print('Error adding sample videos: $e');
      print('Stack trace: $stackTrace');
      if (e is FirebaseException) {
        print('Firebase error code: ${e.code}');
        print('Firebase error message: ${e.message}');
      }
      rethrow;
    }
  }

  Future<void> _addVideo({
    required String userId,
    required String username,
    required String videoUrl,
    required String thumbnailUrl,
    required String title,
    required String description,
    required String category,
    required List<String> topics,
    required List<String> skills,
    required String difficultyLevel,
    required Map<String, dynamic> aiMetadata,
    required bool isVertical,
  }) async {
    try {
      print('Adding video to Firestore: $description');
      final docRef = await _firestore.collection('videos').add({
        'userId': userId,
        'username': username,
        'videoUrl': videoUrl,
        'thumbnailUrl': thumbnailUrl,
        'title': title,
        'description': description,
        'category': category,
        'topics': topics,
        'skills': skills,
        'difficultyLevel': difficultyLevel,
        'duration': 180, // 3 minutes sample duration
        'likes': 0,
        'comments': 0,
        'shares': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'aiMetadata': aiMetadata,
        'isVertical': isVertical,
      });
      print('Video added with ID: ${docRef.id}');
    } catch (e, stackTrace) {
      print('Error in _addVideo: $e');
      print('Stack trace: $stackTrace');
      if (e is FirebaseException) {
        print('Firebase error code: ${e.code}');
        print('Firebase error message: ${e.message}');
      }
      rethrow;
    }
  }

  Future<void> getVideoDownloadUrls() async {
    try {
      print('Getting download URLs for uploaded videos...');
      final storageRef = _storage.ref().child('videos');

      // List all files in the videos directory
      final ListResult result = await storageRef.listAll();

      // Get download URLs for each file
      for (var item in result.items) {
        final String url = await item.getDownloadURL();
        print('${item.name}: $url');
      }
    } catch (e) {
      print('Error getting download URLs: $e');
      rethrow;
    }
  }

  Future<void> uploadSampleVideos() async {
    try {
      print('Starting to upload sample videos to Firebase Storage...');

      // List of vertical format videos from reliable sources
      final Map<String, String> sampleVideos = {
        'vertical_video1.mp4':
            'https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4',
        'vertical_video2.mp4':
            'https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4',
        'vertical_video3.mp4':
            'https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerFun.mp4',
        'vertical_video4.mp4':
            'https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerJoyrides.mp4',
      };

      for (var entry in sampleVideos.entries) {
        try {
          print('Uploading ${entry.key}...');
          final url = await _uploadVideoToStorage(entry.value, entry.key);
          print('Successfully uploaded ${entry.key}: $url');
        } catch (e) {
          print('Error uploading ${entry.key}: $e');
          // Continue with next video even if one fails
          continue;
        }
      }

      print('Finished uploading sample videos');
    } catch (e) {
      print('Error in uploadSampleVideos: $e');
      rethrow;
    }
  }

  Future<String> _uploadVideoFile(File videoFile, String fileName) async {
    try {
      print('Processing video for upload: $fileName');

      // Upload directly if it's already an MP4 file
      if (fileName.toLowerCase().endsWith('.mp4')) {
        print('File is already MP4, uploading directly');
        final storageRef = _storage.ref().child('videos/$fileName');

        // Upload video to Firebase Storage
        await storageRef.putFile(
          videoFile,
          SettableMetadata(contentType: 'video/mp4'),
        );

        // Get the download URL
        final downloadUrl = await storageRef.getDownloadURL();
        print('Video uploaded successfully. Download URL: $downloadUrl');

        return downloadUrl;
      }

      // For non-MP4 files, try to compress and convert
      try {
        print('Attempting to compress video...');
        final MediaInfo? mediaInfo = await VideoCompress.compressVideo(
          videoFile.path,
          quality: VideoQuality.MediumQuality,
          deleteOrigin: false,
          includeAudio: true,
        );

        if (mediaInfo?.file == null) {
          throw 'Failed to process video';
        }

        print(
            'Video processed successfully. Size: ${mediaInfo!.filesize} bytes');
        fileName = '${path.basenameWithoutExtension(fileName)}.mp4';

        final storageRef = _storage.ref().child('videos/$fileName');
        await storageRef.putFile(
          mediaInfo.file!,
          SettableMetadata(
            contentType: 'video/mp4',
            customMetadata: {
              'duration': '${mediaInfo.duration}',
              'width': '${mediaInfo.width}',
              'height': '${mediaInfo.height}',
            },
          ),
        );

        final downloadUrl = await storageRef.getDownloadURL();
        await VideoCompress.deleteAllCache();
        return downloadUrl;
      } catch (e) {
        print('Error compressing video: $e');
        print('Falling back to direct upload...');

        // Fallback: Upload the original file if compression fails
        final storageRef = _storage.ref().child('videos/$fileName');
        await storageRef.putFile(
          videoFile,
          SettableMetadata(contentType: 'video/mp4'),
        );

        final downloadUrl = await storageRef.getDownloadURL();
        return downloadUrl;
      }
    } catch (e) {
      print('Error uploading video to storage: $e');
      await VideoCompress.deleteAllCache();
      rethrow;
    }
  }

  Future<String?> _generateAndUploadThumbnail(
      String videoPath, String videoFileName) async {
    try {
      print('Generating thumbnail for video: $videoPath');

      // Verify video file exists
      final videoFile = File(videoPath);
      if (!await videoFile.exists()) {
        throw 'Video file not found at path: $videoPath';
      }

      // Get video info to determine the best frame for thumbnail
      final mediaInfo = await VideoCompress.getMediaInfo(videoPath);
      if (mediaInfo.duration == null) {
        throw 'Could not get video duration';
      }

      // Generate thumbnail at 1 second or 10% of video duration, whichever is less
      final position = mediaInfo.duration! > 10000
          ? 1000
          : (mediaInfo.duration! * 0.1).round();

      final thumbnailFile = await VideoCompress.getFileThumbnail(
        videoPath,
        quality: 50,
        position: position,
      );

      // Verify thumbnail was generated
      if (!await thumbnailFile.exists()) {
        throw 'Failed to generate thumbnail';
      }

      final thumbnailFileName = 'thumb_$videoFileName';
      final thumbnailRef =
          _storage.ref().child('thumbnails/$thumbnailFileName');

      print('Uploading thumbnail to Firebase Storage');
      final uploadTask = await thumbnailRef.putFile(
        thumbnailFile,
        SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {
            'videoFileName': videoFileName,
            'generatedAt': DateTime.now().toIso8601String(),
          },
        ),
      );

      if (uploadTask.state != TaskState.success) {
        throw 'Failed to upload thumbnail';
      }

      final thumbnailUrl = await thumbnailRef.getDownloadURL();
      print('Thumbnail uploaded successfully. URL: $thumbnailUrl');

      // Clean up the temporary thumbnail file
      try {
        await thumbnailFile.delete();
      } catch (e) {
        print('Warning: Failed to delete temporary thumbnail file: $e');
      }

      return thumbnailUrl;
    } catch (e) {
      print('Error generating/uploading thumbnail: $e');
      // Re-throw the error to be handled by the caller
      throw 'Failed to generate or upload thumbnail: $e';
    }
  }

  Future<void> uploadVideoFromDevice({
    Map<String, dynamic>? metadata,
    Function(double)? onProgress,
  }) async {
    try {
      _initCompressSubscription();
      // Get current user
      final currentUser = _authController.user.value;
      if (currentUser == null) {
        throw 'No user logged in';
      }

      // Pick video file with more restrictive options
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowCompression: true,
        withData: false,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        throw 'No video selected';
      }

      PlatformFile file = result.files.first;
      if (file.path == null) {
        throw 'Invalid file path';
      }

      print('Selected video path: ${file.path}');
      print('Selected video size: ${file.size} bytes');

      // Check file size before processing (50MB limit)
      if (file.size > 50 * 1024 * 1024) {
        throw 'Video file is too large. Please select a video under 50MB.';
      }

      // Clean up any existing cache first
      await VideoCompress.deleteAllCache();

      // Check video duration and trim if necessary
      String videoPath = file.path!;
      print('Getting media info for video...');
      final MediaInfo? mediaInfo = await VideoCompress.getMediaInfo(videoPath);

      if (mediaInfo == null) {
        throw 'Failed to get video information';
      }

      print('Video duration: ${mediaInfo.duration} milliseconds');
      if (mediaInfo.duration != null && mediaInfo.duration! > 90000) {
        print(
            'Video duration exceeds 90 seconds, trimming to first 90 seconds...');

        try {
          print('Starting video compression and trimming...');

          // Stop any ongoing compression
          await VideoCompress.cancelCompression();

          final MediaInfo? trimmedInfo = await VideoCompress.compressVideo(
            videoPath,
            quality: VideoQuality.MediumQuality,
            deleteOrigin: false,
            includeAudio: true,
            startTime: 0,
            duration: 90,
            frameRate: 30,
          );

          if (trimmedInfo?.file == null) {
            throw 'Failed to process video';
          }

          videoPath = trimmedInfo!.file!.path;
          print('Successfully trimmed video. New path: $videoPath');

          // Verify the trimmed file
          final trimmedFile = File(videoPath);
          if (!await trimmedFile.exists()) {
            throw 'Trimmed video file not found';
          }

          final trimmedSize = await trimmedFile.length();
          if (trimmedSize == 0) {
            throw 'Trimmed video file is empty';
          }

          print('Trimmed video size: $trimmedSize bytes');

          // Clean up the original file if it's in the cache
          if (file.path!.contains('/cache/')) {
            try {
              await File(file.path!).delete();
              print('Cleaned up original file');
            } catch (e) {
              print('Error cleaning up original file: $e');
            }
          }
        } catch (e) {
          print('Error during video processing: $e');
          await VideoCompress.deleteAllCache();
          throw 'Failed to process video: $e';
        }
      }

      // Generate a unique filename
      String fileName = 'video_${DateTime.now().millisecondsSinceEpoch}.mp4';
      print('Uploading video to Firebase Storage: $fileName');

      final storageRef = _storage.ref().child('videos/$fileName');
      final videoFile = File(videoPath);

      // Upload in chunks
      final uploadTask = storageRef.putFile(
        videoFile,
        SettableMetadata(
          contentType: 'video/mp4',
          customMetadata: {
            'duration': '${mediaInfo.duration}',
            'size': '${await videoFile.length()}',
          },
        ),
      );

      // Monitor upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        onProgress?.call(progress);
        print('Upload progress: ${(progress * 100).toStringAsFixed(2)}%');
      });

      // Wait for upload to complete
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      print('Video uploaded successfully. Download URL: $downloadUrl');

      // Clean up all temporary files and cache
      try {
        await VideoCompress.deleteAllCache();
        if (videoPath != file.path) {
          await File(videoPath).delete();
        }
      } catch (e) {
        print('Error cleaning up temporary files: $e');
      }

      // After successful video upload, generate and upload thumbnail
      String thumbnailUrl;
      try {
        final generatedUrl =
            await _generateAndUploadThumbnail(videoPath, fileName);
        if (generatedUrl == null) {
          throw 'Generated thumbnail URL is null';
        }
        thumbnailUrl = generatedUrl;
        print('Successfully generated and uploaded thumbnail: $thumbnailUrl');
      } catch (e) {
        print('Warning: Failed to generate thumbnail: $e');
        // Continue with a default thumbnail
        thumbnailUrl =
            'https://picsum.photos/seed/${DateTime.now().millisecondsSinceEpoch}/300/500';
      }

      // Add video metadata to Firestore with actual thumbnail if available
      await _addVideo(
        userId: currentUser.id,
        username: currentUser.name ?? currentUser.email,
        videoUrl: downloadUrl,
        thumbnailUrl: thumbnailUrl,
        title: metadata?['title'] ?? 'Untitled Video',
        description: metadata?['description'] ?? 'New video upload',
        category: metadata?['category'] ?? 'general',
        isVertical: true,
        topics: metadata?['tags']?.cast<String>() ?? ['General'],
        skills: ['Content Creation'],
        difficultyLevel: metadata?['difficultyLevel'] ?? 'beginner',
        aiMetadata: {
          'content_tags': metadata?['tags'] ?? ['User Upload'],
          'key_moments': {
            'full': [
              0,
              mediaInfo.duration != null
                  ? (mediaInfo.duration! / 1000).round()
                  : 90
            ],
          },
        },
      );
    } catch (e) {
      print('Error in uploadVideoFromDevice: $e');
      await VideoCompress.deleteAllCache();
      dispose();
      rethrow;
    } finally {
      // Ensure cleanup happens even if there's an error
      await VideoCompress.deleteAllCache();
      dispose();
    }
  }

  Future<void> uploadRecordedVideo(
    File videoFile, {
    Map<String, dynamic>? metadata,
    Function(double)? onProgress,
  }) async {
    try {
      _initCompressSubscription();
      // Get current user
      final currentUser = _authController.user.value;
      if (currentUser == null) {
        throw 'No user logged in';
      }

      // Check video duration and trim if necessary
      String videoPath = videoFile.path;
      final MediaInfo? mediaInfo = await VideoCompress.getMediaInfo(videoPath);
      if (mediaInfo?.duration != null && mediaInfo!.duration! > 90000) {
        print(
            'Video duration exceeds 90 seconds, trimming to first 90 seconds...');
        // Create a temporary file for the trimmed video
        final tempDir = await getTemporaryDirectory();
        final trimmedPath =
            '${tempDir.path}/trimmed_${DateTime.now().millisecondsSinceEpoch}.mp4';

        try {
          // Compress and trim the video
          final MediaInfo? trimmedInfo = await VideoCompress.compressVideo(
            videoPath,
            quality: VideoQuality.MediumQuality,
            deleteOrigin: false,
            includeAudio: true,
            startTime: 0,
            duration: 90, // 90 seconds
          );

          if (trimmedInfo?.file == null) {
            throw 'Failed to trim video';
          }

          videoPath = trimmedInfo!.file!.path;
          print('Successfully trimmed video to 90 seconds');
        } catch (e) {
          print('Error trimming video: $e');
          throw 'Failed to process video: $e';
        }
      }

      print('Processing video for upload...');
      onProgress?.call(0.1);

      // Generate a unique filename
      String fileName = 'video_${DateTime.now().millisecondsSinceEpoch}.mp4';
      print('Uploading video to Firebase Storage: $fileName');

      final storageRef = _storage.ref().child('videos/$fileName');
      final uploadTask = storageRef.putFile(
        File(videoPath),
        SettableMetadata(contentType: 'video/mp4'),
      );

      // Listen to upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress =
            0.1 + (snapshot.bytesTransferred / snapshot.totalBytes) * 0.8;
        onProgress?.call(progress);
      });

      // Wait for upload to complete
      await uploadTask;
      onProgress?.call(0.9);

      // Get the download URL
      final downloadUrl = await storageRef.getDownloadURL();
      print('Video uploaded successfully. Download URL: $downloadUrl');

      // After successful video upload, generate and upload thumbnail
      final thumbnailUrl =
          await _generateAndUploadThumbnail(videoPath, fileName);

      // Add video metadata to Firestore with actual thumbnail if available
      await _addVideo(
        userId: currentUser.id,
        username: currentUser.name ?? currentUser.email,
        videoUrl: downloadUrl,
        thumbnailUrl: thumbnailUrl ??
            'https://picsum.photos/seed/${DateTime.now().millisecondsSinceEpoch}/300/500',
        title: metadata?['title'] ?? 'Recorded Video',
        description: metadata?['description'] ?? 'Recorded video',
        category: metadata?['category'] ?? 'general',
        isVertical: true,
        topics: metadata?['tags']?.cast<String>() ?? ['General'],
        skills: ['Content Creation'],
        difficultyLevel: metadata?['difficultyLevel'] ?? 'beginner',
        aiMetadata: {
          'content_tags': metadata?['tags'] ?? ['User Recording'],
          'key_moments': {
            'full': [0, 100],
          },
        },
      );
      onProgress?.call(1.0);
    } catch (e) {
      print('Error uploading recorded video: $e');
      rethrow;
    } finally {
      await VideoCompress.deleteAllCache();
      dispose();
    }
  }
}
