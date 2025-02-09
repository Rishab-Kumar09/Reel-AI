import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:video_compress/video_compress.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class ThumbnailMigrationScript {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Configuration
  static const int batchSize = 10;
  static const int maxRetries = 3;

  // Migration state
  int _processedCount = 0;
  int _successCount = 0;
  int _failureCount = 0;
  bool _isRunning = false;
  String? _lastProcessedVideoId;

  Future<void> startMigration({String? startAfterId}) async {
    if (_isRunning) {
      print('Migration is already running');
      return;
    }

    try {
      _isRunning = true;
      print('Starting thumbnail migration...');

      // Create query for videos without thumbnails or with placeholder thumbnails
      Query query = _firestore
          .collection('videos')
          .where('thumbnailUrl', isEqualTo: null)
          .orderBy(FieldPath.documentId)
          .limit(batchSize);

      // If startAfterId is provided, start after that document
      if (startAfterId != null) {
        final startAfterDoc =
            await _firestore.collection('videos').doc(startAfterId).get();
        if (startAfterDoc.exists) {
          query = query.startAfterDocument(startAfterDoc);
        }
      }

      while (_isRunning) {
        final querySnapshot = await query.get();

        if (querySnapshot.docs.isEmpty) {
          print('No more videos to process');
          break;
        }

        // Process videos in parallel with a limit
        await Future.wait(
          querySnapshot.docs.map((doc) => _processVideo(doc)),
        ).catchError((error, stackTrace) {
          print('Error processing video: $error');
          print('Stack trace: $stackTrace');
        });

        // Update last processed ID
        _lastProcessedVideoId = querySnapshot.docs.last.id;

        // Get next batch
        query = _firestore
            .collection('videos')
            .where('thumbnailUrl', isEqualTo: null)
            .orderBy(FieldPath.documentId)
            .startAfter([_lastProcessedVideoId]).limit(batchSize);

        // Print progress
        print(
            'Processed: $_processedCount, Success: $_successCount, Failed: $_failureCount');
        print('Last processed ID: $_lastProcessedVideoId');
      }

      print('Migration completed!');
      print('Final stats:');
      print('Total processed: $_processedCount');
      print('Successful: $_successCount');
      print('Failed: $_failureCount');
    } catch (e, stackTrace) {
      print('Error during migration: $e');
      print('Stack trace: $stackTrace');
      print('Last processed video ID: $_lastProcessedVideoId');
    } finally {
      _isRunning = false;
      await VideoCompress.deleteAllCache();
    }
  }

  Future<void> _processVideo(DocumentSnapshot doc) async {
    _processedCount++;
    final videoData = doc.data() as Map<String, dynamic>;
    final videoUrl = videoData['videoUrl'] as String?;

    if (videoUrl == null) {
      print('Video URL is null for document ${doc.id}');
      _failureCount++;
      return;
    }

    try {
      // Download video to temporary file
      final tempDir = await getTemporaryDirectory();
      final videoFile = File('${tempDir.path}/temp_${doc.id}.mp4');

      print('Downloading video: $videoUrl');
      final response = await http.get(Uri.parse(videoUrl));
      await videoFile.writeAsBytes(response.bodyBytes);

      // Generate thumbnail
      print('Generating thumbnail for video ${doc.id}');
      final thumbnailFile = await VideoCompress.getFileThumbnail(
        videoFile.path,
        quality: 50,
        position: 1000, // 1 second into video
      );

      // Upload thumbnail
      final thumbnailFileName = 'thumb_${doc.id}.jpg';
      final thumbnailRef =
          _storage.ref().child('thumbnails/$thumbnailFileName');

      print('Uploading thumbnail for video ${doc.id}');
      await thumbnailRef.putFile(
        thumbnailFile,
        SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {
            'videoId': doc.id,
            'generatedAt': DateTime.now().toIso8601String(),
          },
        ),
      );

      // Get thumbnail URL
      final thumbnailUrl = await thumbnailRef.getDownloadURL();

      // Update Firestore document
      await doc.reference.update({
        'thumbnailUrl': thumbnailUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('Successfully processed video ${doc.id}');
      _successCount++;

      // Cleanup
      await videoFile.delete();
      await thumbnailFile.delete();
    } catch (e, stackTrace) {
      print('Error processing video ${doc.id}: $e');
      print('Stack trace: $stackTrace');
      _failureCount++;
    }
  }

  void stopMigration() {
    _isRunning = false;
    print('Migration stopping after current batch completes...');
  }

  String? getLastProcessedId() => _lastProcessedVideoId;

  Map<String, dynamic> getMigrationStats() {
    return {
      'processedCount': _processedCount,
      'successCount': _successCount,
      'failureCount': _failureCount,
      'isRunning': _isRunning,
      'lastProcessedId': _lastProcessedVideoId,
    };
  }
}
