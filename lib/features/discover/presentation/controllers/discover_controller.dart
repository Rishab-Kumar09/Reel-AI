import 'dart:async';
import 'dart:math' as math;
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
  final RxSet<String> _processingLikes = <String>{}.obs;
  StreamSubscription<QuerySnapshot>? _videosSubscription;
  StreamSubscription<QuerySnapshot>? _likesSubscription;
  StreamSubscription<QuerySnapshot>? _trendingSubscription;

  // Pagination
  DocumentSnapshot? _lastDocument;
  static const int _limit = 10;
  final RxBool hasMore = true.obs;

  Timer? _searchDebounce;
  Map<String, Timer> _likeDebounceTimers = {};

  @override
  void onInit() {
    super.onInit();
    _setupVideoStream();
    _setupTrendingStream();
    _setupLikesStream();
  }

  @override
  void onClose() {
    _videosSubscription?.cancel();
    _likesSubscription?.cancel();
    _trendingSubscription?.cancel();
    _searchDebounce?.cancel();
    _likeDebounceTimers.values.forEach((timer) => timer.cancel());
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

  void _setupTrendingStream() {
    print('Setting up trending videos stream...');
    _trendingSubscription?.cancel();

    _trendingSubscription = _firestore
        .collection('videos')
        .orderBy('likes', descending: true)
        .limit(5)
        .snapshots()
        .listen(
      (snapshot) {
        print('Received trending videos update');
        trendingVideos.value =
            snapshot.docs.map((doc) => VideoModel.fromFirestore(doc)).toList();
        print('Updated trending videos: ${trendingVideos.length}');
      },
      onError: (error) {
        print('Error in trending videos stream: $error');
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

      // Start with base query
      Query query = _firestore.collection('videos');

      // Add category filter if not 'all'
      if (selectedCategory.value != 'all') {
        print('Filtering by category: ${selectedCategory.value}');
        query = query.where('category',
            isEqualTo: selectedCategory.value.toLowerCase());
      }

      // Add ordering and limit
      query = query.orderBy('createdAt', descending: true).limit(_limit);

      // Add pagination if not refreshing
      if (_lastDocument != null && !refresh) {
        query = query.startAfterDocument(_lastDocument!);
      }

      final QuerySnapshot snapshot = await query.get().catchError((error) {
        print('Firestore query error: $error');
        if (error.toString().contains('indexes?create_composite=')) {
          print('Missing index detected. Please create the required index.');
          // Handle missing index gracefully
          return null;
        }
        throw error;
      });

      // If snapshot is null (due to missing index), return empty results
      if (snapshot == null) {
        print('Query failed, possibly due to missing index');
        hasMore.value = false;
        videos.clear();
        return;
      }

      print(
          'Found ${snapshot.docs.length} videos for category: ${selectedCategory.value}');

      if (snapshot.docs.isEmpty) {
        hasMore.value = false;
        if (refresh) videos.clear();
        return;
      }

      _lastDocument = snapshot.docs.last;
      var newVideos =
          snapshot.docs.map((doc) => VideoModel.fromFirestore(doc)).toList();

      // Apply tag filter to new videos if any tags are selected
      if (selectedTags.isNotEmpty) {
        print('Applying tag filtering: ${selectedTags.join(', ')}');
        newVideos = newVideos
            .where((video) =>
                video.topics.any((topic) => selectedTags.contains(topic)))
            .toList();
        print('After tag filtering: ${newVideos.length} videos remain');
      }

      // Apply search filter if there's a search query
      if (searchQuery.isNotEmpty) {
        print('Applying search filter: ${searchQuery.value}');
        newVideos = newVideos.where((video) {
          final title = video.title.toLowerCase();
          final description = video.description.toLowerCase();
          final username = video.username.toLowerCase();
          final topics = video.topics.map((t) => t.toLowerCase()).toList();

          return title.contains(searchQuery.value) ||
              description.contains(searchQuery.value) ||
              username.contains(searchQuery.value) ||
              topics.any((t) => t.contains(searchQuery.value));
        }).toList();
        print('After search filtering: ${newVideos.length} videos remain');
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
      // Handle error gracefully
      if (refresh) videos.clear();
      hasMore.value = false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadTrendingVideos() async {
    try {
      print('Refreshing trending videos...');
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
      selectedCategory.value = category.toLowerCase();
      // Reset pagination when changing category
      _lastDocument = null;
      loadMoreVideos(refresh: true);
    }
  }

  void search(String query) async {
    print('Search called with query: $query');

    // Cancel previous debounce timer
    _searchDebounce?.cancel();

    // Set up new debounce timer
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      searchQuery.value = query.trim().toLowerCase();
      // Use loadMoreVideos to handle all filters together
      loadMoreVideos(refresh: true);
    });
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
    // If a like operation is already in progress for this video, ignore the new request
    if (_processingLikes.contains(videoId)) {
      print('Like operation already in progress for video: $videoId');
      return;
    }

    // Cancel any existing debounce timer for this video
    _likeDebounceTimers[videoId]?.cancel();

    // Set up new debounce timer
    _likeDebounceTimers[videoId] =
        Timer(const Duration(milliseconds: 300), () async {
      try {
        _processingLikes.add(videoId);

        final userId = _authController.user.value?.id;
        if (userId == null) return;

        final videoRef = _firestore.collection('videos').doc(videoId);
        final likeRef =
            _firestore.collection('likes').doc('${videoId}_$userId');

        await _firestore.runTransaction((transaction) async {
          // Read both documents inside the transaction for consistency
          final videoDoc = await transaction.get(videoRef);
          final likeDoc = await transaction.get(likeRef);

          if (!videoDoc.exists) {
            print('Video document does not exist: $videoId');
            return;
          }

          final currentLikes = videoDoc.data()?['likes'] ?? 0;

          if (likeDoc.exists) {
            // Unlike - ensure likes don't go below 0
            if (currentLikes > 0) {
              transaction.delete(likeRef);
              transaction.update(videoRef, {
                'likes': math.max<int>(
                    0, currentLikes - 1), // Ensure we don't go below 0
              });
              likedVideoIds.remove(videoId);
            }
          } else {
            // Like
            transaction.set(likeRef, {
              'userId': userId,
              'videoId': videoId,
              'createdAt': FieldValue.serverTimestamp(),
            });
            transaction.update(videoRef, {
              'likes': currentLikes + 1,
            });
            likedVideoIds.add(videoId);
          }
        });

        // Get the updated video document after transaction completes
        final updatedVideoDoc = await videoRef.get();
        if (updatedVideoDoc.exists) {
          final updatedVideo = VideoModel.fromFirestore(updatedVideoDoc);

          // Update local state for regular videos
          final videoIndex = videos.indexWhere((v) => v.id == videoId);
          if (videoIndex != -1) {
            videos[videoIndex] = updatedVideo;
          }

          // Also update trending videos if this video is in there
          final trendingIndex =
              trendingVideos.indexWhere((v) => v.id == videoId);
          if (trendingIndex != -1) {
            trendingVideos[trendingIndex] = updatedVideo;
          }
        }
      } catch (e) {
        print('Error toggling like: $e');
      } finally {
        _processingLikes.remove(videoId);
        _likeDebounceTimers.remove(videoId);
      }
    });
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

  Future<void> refreshLikeCounts() async {
    try {
      print('Starting like count refresh...');
      isLoading.value = true;

      final videosSnapshot = await _firestore.collection('videos').get();
      print('Found ${videosSnapshot.docs.length} videos to process');

      final batch = _firestore.batch();
      var updatedCount = 0;

      for (var videoDoc in videosSnapshot.docs) {
        final likesSnapshot = await _firestore
            .collection('likes')
            .where('videoId', isEqualTo: videoDoc.id)
            .count()
            .get();

        final actualLikeCount = likesSnapshot.count;
        final currentLikeCount = videoDoc.data()['likes'] ?? 0;

        if (actualLikeCount != currentLikeCount) {
          print(
              'Fixing like count for video ${videoDoc.id}: $currentLikeCount -> $actualLikeCount');
          batch.update(videoDoc.reference, {'likes': actualLikeCount});
          updatedCount++;
        }
      }

      if (updatedCount > 0) {
        await batch.commit();
        print('Updated like counts for $updatedCount videos');
        await loadMoreVideos(refresh: true);
        await loadTrendingVideos();
      }

      Get.snackbar(
        'Success',
        'Like counts refreshed. Updated $updatedCount videos.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green.withOpacity(0.1),
        colorText: Colors.green,
      );
    } catch (e) {
      print('Error refreshing like counts: $e');
      Get.snackbar(
        'Error',
        'Failed to refresh like counts: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.withOpacity(0.1),
        colorText: Colors.red,
      );
    } finally {
      isLoading.value = false;
    }
  }
}
