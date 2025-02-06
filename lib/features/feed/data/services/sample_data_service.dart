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

class SampleDataService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

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
          userId: 'sample_creator_1',
          username: '@creator_one',
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
          userId: 'sample_creator_2',
          username: '@creator_two',
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
          userId: 'sample_creator_3',
          username: '@creator_three',
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
          userId: 'sample_creator_4',
          username: '@creator_four',
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

  Future<void> uploadVideoFromDevice({
    Map<String, dynamic>? metadata,
    Function(double)? onProgress,
  }) async {
    try {
      // Pick video file
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowCompression: true,
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        throw 'No video selected';
      }

      PlatformFile file = result.files.first;

      if (file.bytes == null && file.path == null) {
        throw 'No video data available - both bytes and path are null';
      }

      // Generate a unique filename
      String fileName = 'video_${DateTime.now().millisecondsSinceEpoch}.mp4';
      print('Uploading video to Firebase Storage: $fileName');

      final storageRef = _storage.ref().child('videos/$fileName');

      try {
        UploadTask uploadTask;
        if (file.bytes != null) {
          uploadTask = storageRef.putData(
            file.bytes!,
            SettableMetadata(contentType: 'video/mp4'),
          );
        } else if (file.path != null) {
          uploadTask = storageRef.putFile(
            File(file.path!),
            SettableMetadata(contentType: 'video/mp4'),
          );
        } else {
          throw 'No valid video data available';
        }

        // Listen to upload progress
        uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
          final progress = snapshot.bytesTransferred / snapshot.totalBytes;
          onProgress?.call(progress);
        });

        // Wait for upload to complete
        await uploadTask;

        // Get the download URL
        final downloadUrl = await storageRef.getDownloadURL();
        print('Video uploaded successfully. Download URL: $downloadUrl');

        // Add video metadata to Firestore
        await _addVideo(
          userId: 'user_${DateTime.now().millisecondsSinceEpoch}',
          username: '@user_${DateTime.now().millisecondsSinceEpoch}',
          videoUrl: downloadUrl,
          thumbnailUrl:
              'https://picsum.photos/seed/${DateTime.now().millisecondsSinceEpoch}/300/500',
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
              'full': [0, 100],
            },
          },
        );
      } catch (e) {
        print('Error uploading video data: $e');
        rethrow;
      }
    } catch (e) {
      print('Error in uploadVideoFromDevice: $e');
      rethrow;
    }
  }

  Future<void> uploadRecordedVideo(
    File videoFile, {
    Map<String, dynamic>? metadata,
    Function(double)? onProgress,
  }) async {
    try {
      // Generate a unique filename
      String fileName = 'video_${DateTime.now().millisecondsSinceEpoch}.mp4';
      print('Uploading recorded video to Firebase Storage: $fileName');

      final storageRef = _storage.ref().child('videos/$fileName');

      // Upload the video file
      final uploadTask = storageRef.putFile(
        videoFile,
        SettableMetadata(contentType: 'video/mp4'),
      );

      // Listen to upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        onProgress?.call(progress);
      });

      // Wait for upload to complete
      await uploadTask;

      // Get the download URL
      final downloadUrl = await storageRef.getDownloadURL();
      print('Video uploaded successfully. Download URL: $downloadUrl');

      // Add video metadata to Firestore
      await _addVideo(
        userId: 'user_${DateTime.now().millisecondsSinceEpoch}',
        username: '@user_${DateTime.now().millisecondsSinceEpoch}',
        videoUrl: downloadUrl,
        thumbnailUrl:
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
    } catch (e) {
      print('Error uploading recorded video: $e');
      rethrow;
    }
  }
}
