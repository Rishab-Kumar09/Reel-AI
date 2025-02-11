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
      final userId = _authController.user.value?.id;
      print('Loading videos for user ID: $userId');
      if (userId == null) return;

      final querySnapshot = await _firestore
          .collection('videos')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      print('Found ${querySnapshot.docs.length} videos for user');

      userVideos.value = querySnapshot.docs
          .map((doc) => VideoModel.fromFirestore(doc))
          .toList();

      print('Loaded ${userVideos.length} videos into userVideos list');
    } catch (e) {
      print('Error loading user videos: $e');
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

      if (likesSnapshot.docs.isEmpty) {
        likedVideos.clear();
        return;
      }

      // Get the video IDs from likes
      final videoIds = likesSnapshot.docs
          .map((doc) => doc.get('videoId') as String)
          .toList();

      print('Video IDs from likes: $videoIds');

      // Fetch all liked videos
      final videosSnapshot = await _firestore
          .collection('videos')
          .where(FieldPath.documentId, whereIn: videoIds)
          .get();

      print('Found ${videosSnapshot.docs.length} liked videos');

      likedVideos.value = videosSnapshot.docs
          .map((doc) => VideoModel.fromFirestore(doc))
          .toList();

      print('Loaded ${likedVideos.length} videos into likedVideos list');
    } catch (e) {
      print('Error loading liked videos: $e');
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

      // 1. Delete from Firestore
      await _firestore.collection('videos').doc(video.id).delete();
      print('Deleted video document from Firestore');

      // 2. Delete associated data in a batch
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

      await batch.commit();
      print('Deleted all associated data (likes and comments)');

      // 3. Remove from local lists
      userVideos.removeWhere((v) => v.id == video.id);
      likedVideos.removeWhere((v) => v.id == video.id);

      // 4. Refresh lists
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
