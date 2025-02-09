import 'dart:async';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_firebase_app_new/features/feed/data/models/video_model.dart';
import 'package:flutter_firebase_app_new/core/constants/app_constants.dart';
import 'package:flutter_firebase_app_new/features/auth/presentation/controllers/auth_controller.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

class DiscoverController extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthController _authController = Get.find<AuthController>();
  final RxList<VideoModel> videos = <VideoModel>[].obs;
  final RxList<VideoModel> trendingVideos = <VideoModel>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isTrendingLoading = false.obs;
  final RxString selectedCategory = 'all'.obs;
  final RxString searchQuery = ''.obs;
  final RxList<String> selectedTags = <String>[].obs;
  final RxSet<String> likedVideoIds = <String>{}.obs;
  StreamSubscription<QuerySnapshot>? _videosSubscription;
  StreamSubscription<QuerySnapshot>? _likesSubscription;

  // Pagination
  DocumentSnapshot? _lastDocument;
  static const int _limit = 10;
  final RxBool hasMore = true.obs;

  @override
  void onInit() {
    super.onInit();
    _setupVideoStream();
    loadTrendingVideos();
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
        final loadedVideos =
            snapshot.docs.map((doc) => VideoModel.fromFirestore(doc)).toList();

        // Only update the initial set of videos, don't replace the entire list
        if (videos.isEmpty) {
          videos.value = loadedVideos;
        }
        print('Updated videos list with ${loadedVideos.length} videos');
      },
      onError: (error) {
        print('Error in video stream: $error');
      },
    );
  }

  Future<void> loadMoreVideos({bool refresh = false}) async {
    if (isLoading.value) return;
    if (!hasMore.value && !refresh) return;

    try {
      isLoading.value = true;
      print('Loading more videos...');

      if (refresh) {
        videos.clear();
        _lastDocument = null;
        hasMore.value = true;
      }

      Query query = _firestore
          .collection('videos')
          .orderBy('createdAt', descending: true)
          .limit(_limit);

      if (selectedCategory.value != 'all') {
        query = query.where('category', isEqualTo: selectedCategory.value);
      }

      if (_lastDocument != null && !refresh) {
        query = query.startAfterDocument(_lastDocument!);
      }

      final QuerySnapshot snapshot = await query.get();
      print('Found ${snapshot.docs.length} videos');

      if (snapshot.docs.isEmpty) {
        hasMore.value = false;
        return;
      }

      _lastDocument = snapshot.docs.last;
      final newVideos =
          snapshot.docs.map((doc) => VideoModel.fromFirestore(doc)).toList();

      // Apply tag filter to new videos
      if (selectedTags.isNotEmpty) {
        print('Applying tag filtering: ${selectedTags.join(', ')}');
        newVideos
            .where((video) =>
                video.topics.any((topic) => selectedTags.contains(topic)))
            .toList();
        print('After tag filtering: ${newVideos.length} videos remain');
      }

      // Only set hasMore to false if we got less videos than the limit
      hasMore.value = snapshot.docs.length >= _limit;

      if (refresh) {
        videos.value = newVideos;
      } else {
        videos.addAll(newVideos);
      }
      print(
          'Updated videos list with ${newVideos.length} videos. Total: ${videos.length}');
    } catch (e, stackTrace) {
      print('Error loading more videos: $e');
      print('Stack trace: $stackTrace');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadTrendingVideos() async {
    try {
      print('Loading trending videos...');
      isTrendingLoading.value = true;

      final querySnapshot = await _firestore
          .collection('videos')
          .orderBy('likes', descending: true)
          .limit(5)
          .get();

      print('Found ${querySnapshot.docs.length} trending videos');
      trendingVideos.value = querySnapshot.docs
          .map((doc) => VideoModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error loading trending videos: $e');
    } finally {
      isTrendingLoading.value = false;
    }
  }

  void setCategory(String category) {
    print('Setting category to: $category');
    if (selectedCategory.value != category) {
      selectedCategory.value = category;
      loadMoreVideos(refresh: true);
    }
  }

  void search(String query) async {
    print('Search called with query: $query');
    searchQuery.value = query.trim();
    // Always refresh the video stream when search query changes
    _setupVideoStream();
  }

  void toggleTag(String tag) {
    print('Toggling tag: $tag');
    if (selectedTags.contains(tag)) {
      selectedTags.remove(tag);
      print('Removed tag: $tag');
    } else {
      selectedTags.add(tag);
      print('Added tag: $tag');
    }
    loadMoreVideos(refresh: true);
  }

  void clearFilters() {
    print('Clearing all filters');
    selectedCategory.value = 'all';
    searchQuery.value = '';
    selectedTags.clear();
    loadMoreVideos(refresh: true);
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

  Future<void> toggleLike(String videoId) async {
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
          likedVideoIds.remove(videoId);
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
          likedVideoIds.add(videoId);
        }
      });

      // Update local state for trending videos
      final trendingIndex = trendingVideos.indexWhere((v) => v.id == videoId);
      if (trendingIndex != -1) {
        final video = trendingVideos[trendingIndex];
        trendingVideos[trendingIndex] = VideoModel(
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

      // Update local state for regular videos
      final videoIndex = videos.indexWhere((v) => v.id == videoId);
      if (videoIndex != -1) {
        final video = videos[videoIndex];
        videos[videoIndex] = VideoModel(
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
      print('Error toggling like: $e');
    }
  }

  bool isVideoLiked(String videoId) {
    return likedVideoIds.contains(videoId);
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
    } catch (e) {
      print('Error liking video: $e');
    }
  }

  Future<void> shareVideo(String videoId) async {
    try {
      // Find the video in the videos list
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
    } catch (e) {
      print('Error sharing video: $e');
    }
  }
}
