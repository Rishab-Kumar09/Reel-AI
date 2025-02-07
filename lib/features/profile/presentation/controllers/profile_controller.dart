import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_firebase_app_new/features/auth/presentation/controllers/auth_controller.dart';
import 'package:flutter_firebase_app_new/features/feed/data/models/video_model.dart';

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
}
