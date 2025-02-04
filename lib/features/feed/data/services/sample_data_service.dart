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
      await storageRef.putData(response.bodyBytes, SettableMetadata(
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
        'vertical_video1.mp4': 'https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4',
        'vertical_video2.mp4': 'https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4',
        'vertical_video3.mp4': 'https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerFun.mp4',
        'vertical_video4.mp4': 'https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerJoyrides.mp4',
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

        print('Video processed successfully. Size: ${mediaInfo!.filesize} bytes');
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

  Future<void> uploadVideoFromDevice() async {
    Timer? statusTimer;
    try {
      print('Starting video upload process...');
      
      // Test Firebase Storage access
      try {
        print('\nTesting Firebase Storage access...');
        final testRef = _storage.ref().child('test/permission_check.txt');
        final testBytes = Uint8List.fromList('test'.codeUnits);
        await testRef.putData(testBytes);
        await testRef.delete();
        print('Firebase Storage access test: SUCCESS');
      } catch (e) {
        print('Firebase Storage access test: FAILED');
        print('Error: $e');
        if (e is FirebaseException) {
          print('Firebase Error Code: ${e.code}');
          print('Firebase Error Message: ${e.message}');
        }
        throw 'Failed to access Firebase Storage. Please check your Firebase configuration and permissions.';
      }
      
      // Pick video file with explicit web mode settings
      print('Opening file picker with web mode settings...');
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
        withData: true,
        withReadStream: false,
        allowCompression: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final PlatformFile file = result.files.first;
        
        // Debug file information
        print('\nFile Debug Information:');
        print('- Name: ${file.name}');
        print('- Size: ${(file.size / (1024 * 1024)).toStringAsFixed(2)} MB');
        print('- Has bytes: ${file.bytes != null}');
        print('- Bytes length: ${file.bytes?.length ?? 0}');
        
        // Validate file size (max 100MB)
        if (file.size > 100 * 1024 * 1024) {
          throw 'Video file is too large. Maximum size is 100MB.';
        }

        // Validate we have the bytes
        if (file.bytes == null || file.bytes!.isEmpty) {
          print('Error: File bytes are null or empty');
          throw 'Failed to read file data. Please try selecting the file again.';
        }

        // Generate unique filename with timestamp
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final String fileName = '${timestamp}_${file.name.replaceAll(' ', '_')}';
        print('\nProcessing upload:');
        print('- Generated filename: $fileName');
        print('- Timestamp: $timestamp');

        try {
          // Create storage reference with proper path encoding
          final String safePath = Uri.encodeComponent('videos/$fileName');
          final storageRef = _storage.ref().child(safePath);
          print('- Created storage reference: $safePath');

          // Create upload task
          print('\nInitializing upload task...');
          final UploadTask task = storageRef.putData(
            file.bytes!,
            SettableMetadata(
              contentType: 'video/mp4',
              customMetadata: {
                'originalName': file.name,
                'size': file.size.toString(),
                'timestamp': timestamp.toString(),
                'uploadTimestamp': DateTime.now().toIso8601String(),
              },
            ),
          );
          print('- Upload task created');

          bool uploadComplete = false;
          int elapsedSeconds = 0;
          int lastBytesTransferred = 0;

          // Start periodic status updates
          statusTimer = Timer.periodic(Duration(seconds: 5), (timer) {
            if (uploadComplete) {
              timer.cancel();
              return;
            }
            elapsedSeconds += 5;
            final currentBytes = task.snapshot.bytesTransferred;
            final totalBytes = task.snapshot.totalBytes;
            final progress = (currentBytes / totalBytes) * 100;
            final speed = currentBytes > lastBytesTransferred 
                ? ((currentBytes - lastBytesTransferred) / 5 / 1024).toStringAsFixed(2) 
                : '0';
            
            print('\nPeriodic Status Update (${elapsedSeconds}s elapsed):');
            print('- Progress: ${progress.toStringAsFixed(2)}%');
            print('- Uploaded: ${(currentBytes / (1024 * 1024)).toStringAsFixed(2)} MB');
            print('- Total Size: ${(totalBytes / (1024 * 1024)).toStringAsFixed(2)} MB');
            print('- Upload Speed: $speed KB/s');
            print('- Upload task state: ${task.snapshot.state}');
            
            if (progress > 0) {
              final estimatedSecondsLeft = progress < 100 
                  ? ((totalBytes - currentBytes) / (currentBytes / elapsedSeconds)).toInt()
                  : 0;
              print('- Estimated time remaining: ${estimatedSecondsLeft}s');
            }
            
            // Check if upload is stalled
            if (currentBytes > 0 && currentBytes == lastBytesTransferred) {
              print('⚠️ Warning: Upload appears to be stalled');
              print('- No progress in the last 5 seconds');
              print('- If this persists, check network connection');
            } else if (currentBytes == 0 && elapsedSeconds > 15) {
              print('⚠️ Warning: Upload hasn\'t started after ${elapsedSeconds}s');
              print('- This might indicate a connection issue');
              print('- Or a problem with Firebase Storage permissions');
            }
            
            lastBytesTransferred = currentBytes;
          });

          // Monitor upload progress with enhanced error handling
          task.snapshotEvents.listen(
            (TaskSnapshot snapshot) {
              if (uploadComplete) return;
              
              final progress = (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
              final uploadedMB = (snapshot.bytesTransferred / (1024 * 1024)).toStringAsFixed(2);
              final totalMB = (snapshot.totalBytes / (1024 * 1024)).toStringAsFixed(2);
              final currentSpeed = snapshot.bytesTransferred > lastBytesTransferred 
                  ? ((snapshot.bytesTransferred - lastBytesTransferred) / 5 / 1024).toStringAsFixed(2) 
                  : "0";
              
              print('\nUpload Progress Update:');
              print('- Progress: ${progress.toStringAsFixed(2)}%');
              print('- Transferred: $uploadedMB MB / $totalMB MB');
              print('- Current Speed: $currentSpeed KB/s');
              print('- State: ${snapshot.state}');
              
              if (progress > 0) {
                final estimatedSecondsLeft = progress < 100 
                    ? ((snapshot.totalBytes - snapshot.bytesTransferred) / (snapshot.bytesTransferred / elapsedSeconds)).toInt()
                    : 0;
                print('- Estimated time remaining: ${estimatedSecondsLeft}s');
              }
              
              if (snapshot.state == TaskState.error) {
                print('❌ Error state detected in snapshot');
                uploadComplete = true;
                statusTimer?.cancel();
                throw 'Upload entered error state';
              }
            },
            onError: (error) {
              statusTimer?.cancel();
              print('\n❌ Upload Stream Error:');
              print('- Error Type: ${error.runtimeType}');
              if (error is FirebaseException) {
                print('- Firebase Error Code: ${error.code}');
                print('- Firebase Error Message: ${error.message}');
                print('- Firebase Stack Trace: ${error.stackTrace}');
              }
              throw error;
            },
            cancelOnError: true,
          );

          try {
            print('\nWaiting for upload completion...');
            final TaskSnapshot snapshot = await task;
            
            print('\nUpload Completion Status:');
            print('- Final state: ${snapshot.state}');
            print('- Total bytes transferred: ${snapshot.bytesTransferred}');
            print('- Reference path: ${snapshot.ref.fullPath}');
            
            final String downloadUrl = await snapshot.ref.getDownloadURL();
            print('- Download URL obtained: $downloadUrl');

            // Add to Firestore
            print('\nAdding video metadata to Firestore...');
            await _addVideo(
              userId: 'user_uploaded',
              username: '@user',
              videoUrl: downloadUrl,
              thumbnailUrl: 'https://picsum.photos/seed/${fileName}/300/500',
              description: 'User uploaded video 📱 #upload',
              category: 'user_content',
              isVertical: true,
              topics: ['User Content'],
              skills: ['Content Creation'],
              difficultyLevel: 'beginner',
              aiMetadata: {
                'content_tags': ['User Content', 'Original'],
                'uploadInfo': {
                  'originalSize': file.size,
                  'uploadTime': DateTime.now().toIso8601String(),
                  'fileName': fileName,
                },
                'key_moments': {
                  'start': [0, 30],
                  'middle': [31, 60],
                  'end': [61, 90],
                },
              },
            );
            print('Video metadata added to Firestore successfully');
            print('\nUpload process completed successfully!');
            
          } catch (timeoutError) {
            print('\nError during upload:');
            print('- Error Type: ${timeoutError.runtimeType}');
            print('- Error Message: $timeoutError');
            
            try {
              print('Attempting to clean up failed upload...');
              await storageRef.delete();
              print('Cleaned up incomplete upload successfully');
            } catch (cleanupError) {
              print('Failed to clean up incomplete upload: $cleanupError');
            }
            
            throw timeoutError;
          }
        } catch (uploadError) {
          print('\nUpload process error:');
          print('- Error Type: ${uploadError.runtimeType}');
          if (uploadError is FirebaseException) {
            print('- Firebase Error Code: ${uploadError.code}');
            print('- Firebase Error Message: ${uploadError.message}');
          }
          print('- Full Error: $uploadError');
          throw 'Upload failed: ${uploadError is FirebaseException ? uploadError.message : uploadError}';
        }
      } else {
        print('No video selected or file picker was cancelled');
        throw 'No video was selected';
      }
    } catch (e) {
      print('\nFinal error in uploadVideoFromDevice:');
      print('- Error Type: ${e.runtimeType}');
      print('- Error Message: $e');
      rethrow;
    }
  }
} 