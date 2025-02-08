import 'dart:async';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_firebase_app_new/features/feed/data/models/video_model.dart';
import 'package:flutter_firebase_app_new/features/auth/presentation/controllers/auth_controller.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/material.dart';

class FeedController extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthController _authController = Get.find<AuthController>();

  final RxList<VideoModel> videos = <VideoModel>[].obs;
  final RxBool isLoading = false.obs;
  final RxString selectedCategory = 'all'.obs;
  final RxSet<String> likedVideoIds = <String>{}.obs;
  StreamSubscription<QuerySnapshot>? _videosSubscription;
  StreamSubscription<QuerySnapshot>? _likesSubscription;

  // Available categories
  final List<String> categories = [
    'all',
    'tech',
    'lifehacks',
    'education',
    'cooking',
    'art',
    'fun',
  ];

  // Pagination
  DocumentSnapshot? _lastDocument;
  static const int _limit = 5;
  final RxBool hasMore = true.obs;

  @override
  void onInit() {
    super.onInit();
    _setupVideoStream();
    _setupLikesStream();
  }

  @override
  void onClose() {
    _videosSubscription?.cancel();
    _likesSubscription?.cancel();
    super.onClose();
  }

  void _setupVideoStream() {
    print('Setting up video stream...');
    Query query = _firestore
        .collection('videos')
        .orderBy('createdAt', descending: true)
        .limit(_limit);

    if (selectedCategory.value != 'all') {
      query = query.where('category', isEqualTo: selectedCategory.value);
    }

    _videosSubscription?.cancel();
    _videosSubscription = query.snapshots().listen(
      (snapshot) {
        print('Received video update from Firestore');
        if (snapshot.docs.isEmpty) {
          hasMore.value = false;
          return;
        }

        _lastDocument = snapshot.docs.last;
        final newVideos =
            snapshot.docs.map((doc) => VideoModel.fromFirestore(doc)).toList();

        videos.value = newVideos;
        print('Updated videos list with ${newVideos.length} videos');
      },
      onError: (error) {
        print('Error in video stream: $error');
      },
    );
  }

  void _setupLikesStream() {
    final userId = _authController.user.value?.id;
    if (userId == null) return;

    _likesSubscription = _firestore
        .collection('likes')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .listen((snapshot) {
      final likedIds =
          snapshot.docs.map((doc) => doc.get('videoId') as String).toSet();
      likedVideoIds.value = likedIds;
    });
  }

  bool isVideoLiked(String videoId) {
    return likedVideoIds.contains(videoId);
  }

  Future<void> loadVideos({bool refresh = false}) async {
    if (isLoading.value) return;
    if (refresh) {
      videos.clear();
      _lastDocument = null;
      hasMore.value = true;
      _setupVideoStream();
      return;
    }
    if (!hasMore.value) return;

    try {
      isLoading.value = true;
      print('Loading more videos...');

      Query query = _firestore
          .collection('videos')
          .orderBy('createdAt', descending: true)
          .limit(_limit);

      if (selectedCategory.value != 'all') {
        query = query.where('category', isEqualTo: selectedCategory.value);
      }

      if (_lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      }

      final QuerySnapshot snapshot = await query.get();
      if (snapshot.docs.isEmpty) {
        hasMore.value = false;
        return;
      }

      _lastDocument = snapshot.docs.last;
      final newVideos =
          snapshot.docs.map((doc) => VideoModel.fromFirestore(doc)).toList();

      videos.addAll(newVideos);
      print('Added ${newVideos.length} more videos to the feed');
    } catch (e, stackTrace) {
      print('Error loading more videos: $e');
      print('Stack trace: $stackTrace');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> likeVideo(String videoId) async {
    try {
      final userId = _authController.user.value?.id;
      if (userId == null) return;

      final videoRef = _firestore.collection('videos').doc(videoId);
      final likeRef = _firestore.collection('likes').doc('${videoId}_$userId');

      final likeDoc = await likeRef.get();

      await _firestore.runTransaction((transaction) async {
        if (likeDoc.exists) {
          // Unlike
          transaction.delete(likeRef);
          transaction.update(videoRef, {
            'likes': FieldValue.increment(-1),
          });
        } else {
          // Like
          transaction.set(likeRef, {
            'userId': userId,
            'videoId': videoId,
            'createdAt': FieldValue.serverTimestamp(),
          });
          transaction.update(videoRef, {
            'likes': FieldValue.increment(1),
          });
        }
      });

      // Update local state
      final index = videos.indexWhere((video) => video.id == videoId);
      if (index != -1) {
        final video = videos[index];
        videos[index] = VideoModel(
          id: video.id,
          userId: video.userId,
          username: video.username,
          videoUrl: video.videoUrl,
          thumbnailUrl: video.thumbnailUrl,
          title: video.title,
          description: video.description,
          category: video.category,
          topics: video.topics,
          skills: video.skills,
          difficultyLevel: video.difficultyLevel,
          duration: video.duration,
          likes: likeDoc.exists ? video.likes - 1 : video.likes + 1,
          comments: video.comments,
          shares: video.shares,
          createdAt: video.createdAt,
          aiMetadata: video.aiMetadata,
          isVertical: video.isVertical,
        );
      }
    } catch (e) {
      print('Error liking video: $e');
    }
  }

  void setCategory(String category) {
    if (selectedCategory.value != category) {
      selectedCategory.value = category;
      loadVideos(refresh: true);
    }
  }

  Future<void> shareVideo(String videoId) async {
    try {
      // Find the video in the local state
      final video = videos.firstWhere((v) => v.id == videoId);

      // Create a shareable message
      final message = 'Check out this video: ${video.title}\n'
          'By: ${video.username}\n'
          '${video.description}\n\n'
          'Watch it here: ${video.videoUrl}';

      // Show the share dialog
      await Share.share(message, subject: video.title);

      // Update share count in Firestore
      await _firestore.collection('videos').doc(videoId).update({
        'shares': FieldValue.increment(1),
      });

      // Update local state
      final index = videos.indexWhere((v) => v.id == videoId);
      if (index != -1) {
        final video = videos[index];
        videos[index] = VideoModel(
          id: video.id,
          userId: video.userId,
          username: video.username,
          videoUrl: video.videoUrl,
          thumbnailUrl: video.thumbnailUrl,
          title: video.title,
          description: video.description,
          category: video.category,
          topics: video.topics,
          skills: video.skills,
          difficultyLevel: video.difficultyLevel,
          duration: video.duration,
          likes: video.likes,
          comments: video.comments,
          shares: video.shares + 1,
          createdAt: video.createdAt,
          aiMetadata: video.aiMetadata,
          isVertical: video.isVertical,
        );
      }
    } catch (e) {
      print('Error sharing video: $e');
      Get.snackbar(
        'Error',
        'Failed to share video: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.withOpacity(0.1),
        colorText: Colors.red,
      );
    }
  }
}
