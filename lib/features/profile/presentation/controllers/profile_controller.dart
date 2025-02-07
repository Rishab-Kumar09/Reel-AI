import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_firebase_app_new/features/auth/presentation/controllers/auth_controller.dart';
import 'package:flutter_firebase_app_new/features/feed/data/models/video_model.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

class ProfileController extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthController _authController = Get.find<AuthController>();

  final RxList<VideoModel> userVideos = <VideoModel>[].obs;
  final RxList<VideoModel> likedVideos = <VideoModel>[].obs;
  final RxBool isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadUserVideos();
    loadLikedVideos();
  }

  Future<void> loadUserVideos() async {
    try {
      isLoading.value = true;
      final currentUser = _authController.user.value;
      final userEmail = _authController.firebaseUser.value?.email;
      print('Loading videos for user email: $userEmail');
      if (userEmail == null) return;

      final querySnapshot = await _firestore
          .collection('videos')
          .where('username', isEqualTo: userEmail)
          .orderBy('createdAt', descending: true)
          .get();

      print('Found ${querySnapshot.docs.length} videos for user');

      // Print each video document for debugging
      querySnapshot.docs.forEach((doc) {
        print('Video doc: ${doc.data()}');
      });

      userVideos.value = querySnapshot.docs
          .map((doc) => VideoModel.fromFirestore(doc))
          .toList();

      print('Loaded ${userVideos.length} videos into the list');
    } catch (e, stackTrace) {
      print('Error loading user videos: $e');
      print('Stack trace: $stackTrace');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadLikedVideos() async {
    try {
      isLoading.value = true;
      final userId = _authController.user.value?.id;
      print('Loading liked videos for user ID: $userId');
      if (userId == null) return;

      // First get all likes by the user
      final likesSnapshot = await _firestore
          .collection('likes')
          .where('userId', isEqualTo: userId)
          .get();

      print('Found ${likesSnapshot.docs.length} likes');

      // Get the video IDs from likes, sorted by createdAt
      final sortedLikes = likesSnapshot.docs.toList()
        ..sort((a, b) => (b.get('createdAt') as Timestamp)
            .compareTo(a.get('createdAt') as Timestamp));

      final videoIds =
          sortedLikes.map((doc) => doc.get('videoId') as String).toList();

      print('Video IDs from likes: $videoIds');

      if (videoIds.isEmpty) {
        likedVideos.clear();
        return;
      }

      // Fetch all liked videos
      final videosSnapshot = await _firestore
          .collection('videos')
          .where(FieldPath.documentId, whereIn: videoIds)
          .get();

      print('Found ${videosSnapshot.docs.length} liked videos');

      // Create a map of videos for ordering based on likes order
      final videosMap = Map.fromEntries(
          videosSnapshot.docs.map((doc) => MapEntry(doc.id, doc)));

      // Order videos based on the sorted likes order
      final orderedVideos = videoIds
          .where((id) => videosMap.containsKey(id))
          .map((id) => VideoModel.fromFirestore(videosMap[id]!))
          .toList();

      likedVideos.value = orderedVideos;

      print('Loaded ${likedVideos.length} liked videos into the list');
    } catch (e, stackTrace) {
      print('Error loading liked videos: $e');
      print('Stack trace: $stackTrace');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> refreshVideos() async {
    await Future.wait([
      loadUserVideos(),
      loadLikedVideos(),
    ]);
  }

  Future<void> deleteVideo(VideoModel video) async {
    try {
      isLoading.value = true;

      print('Attempting to delete video: ${video.id}');

      // 1. Extract storage paths from URLs
      String? videoStoragePath;
      String? thumbnailStoragePath;

      try {
        final videoUri = Uri.parse(video.videoUrl);
        final thumbnailUri = Uri.parse(video.thumbnailUrl);

        // Extract paths after /o/ and before ?
        videoStoragePath =
            Uri.decodeComponent(videoUri.path.split('/o/')[1].split('?')[0]);
        thumbnailStoragePath = Uri.decodeComponent(
            thumbnailUri.path.split('/o/')[1].split('?')[0]);

        print('Video storage path: $videoStoragePath');
        print('Thumbnail storage path: $thumbnailStoragePath');
      } catch (e) {
        print('Error extracting storage paths: $e');
        // Continue with deletion even if path extraction fails
      }

      // 2. Delete from Firestore first (this ensures video won't be visible even if storage deletion fails)
      await _firestore.collection('videos').doc(video.id).delete();
      print('Deleted video document from Firestore');

      // 3. Delete video file from Storage using direct path
      if (videoStoragePath != null) {
        try {
          final videoRef =
              FirebaseStorage.instance.ref().child(videoStoragePath);
          await videoRef.delete();
          print('Deleted video file from Storage');
        } catch (e) {
          print('Error deleting video file: $e');
          // Continue with other deletions
        }
      }

      // 4. Delete thumbnail from Storage using direct path
      if (thumbnailStoragePath != null) {
        try {
          final thumbnailRef =
              FirebaseStorage.instance.ref().child(thumbnailStoragePath);
          await thumbnailRef.delete();
          print('Deleted thumbnail from Storage');
        } catch (e) {
          print('Error deleting thumbnail: $e');
          // Continue with other deletions
        }
      }

      // 5. Delete associated data in a single batch
      final batch = _firestore.batch();

      // Delete likes
      final likesQuery = await _firestore
          .collection('likes')
          .where('videoId', isEqualTo: video.id)
          .get();

      for (var doc in likesQuery.docs) {
        batch.delete(doc.reference);
      }

      // Delete comments
      final commentsQuery = await _firestore
          .collection('comments')
          .where('videoId', isEqualTo: video.id)
          .get();

      for (var doc in commentsQuery.docs) {
        batch.delete(doc.reference);
      }

      // Commit all deletions in a single batch
      await batch.commit();
      print('Deleted all associated data (likes and comments)');

      // 6. Remove from local lists
      userVideos.removeWhere((v) => v.id == video.id);
      likedVideos.removeWhere((v) => v.id == video.id);

      // 7. Refresh the lists to ensure consistency
      await refreshVideos();

      Get.snackbar(
        'Success',
        'Video deleted successfully',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green.withOpacity(0.1),
        colorText: Colors.green,
      );
    } catch (e) {
      print('Error deleting video: $e');
      Get.snackbar(
        'Error',
        'Failed to delete video: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.withOpacity(0.1),
        colorText: Colors.red,
      );
    } finally {
      isLoading.value = false;
    }
  }
}
