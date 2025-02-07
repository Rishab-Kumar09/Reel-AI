import 'dart:async';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_firebase_app_new/features/feed/data/models/video_model.dart';
import 'package:flutter_firebase_app_new/core/constants/app_constants.dart';

class DiscoverController extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final RxList<VideoModel> videos = <VideoModel>[].obs;
  final RxList<VideoModel> trendingVideos = <VideoModel>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isTrendingLoading = false.obs;
  final RxString selectedCategory = 'all'.obs;
  final RxString searchQuery = ''.obs;
  final RxList<String> selectedTags = <String>[].obs;
  StreamSubscription<QuerySnapshot>? _videosSubscription;

  // Pagination
  DocumentSnapshot? _lastDocument;
  static const int _limit = 10;
  final RxBool hasMore = true.obs;

  @override
  void onInit() {
    super.onInit();
    _setupVideoStream();
    loadTrendingVideos();
  }

  @override
  void onClose() {
    _videosSubscription?.cancel();
    super.onClose();
  }

  void _setupVideoStream() {
    print('Setting up video stream...');
    Query query = _firestore
        .collection('videos')
        .orderBy('createdAt', descending: true)
        .limit(_limit);

    if (selectedCategory.value != 'all') {
      print('Applying category filter: ${selectedCategory.value}');
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
        var loadedVideos =
            snapshot.docs.map((doc) => VideoModel.fromFirestore(doc)).toList();

        // Apply search filter in memory
        if (searchQuery.value.isNotEmpty) {
          final searchLower = searchQuery.value.toLowerCase();
          print('Applying search filtering for: $searchLower');
          loadedVideos = loadedVideos
              .where((video) =>
                  video.title.toLowerCase().contains(searchLower) ||
                  video.description.toLowerCase().contains(searchLower) ||
                  video.username.toLowerCase().contains(searchLower))
              .toList();
          print('After search filtering: ${loadedVideos.length} videos remain');
        }

        // Apply tag filter in memory
        if (selectedTags.isNotEmpty) {
          print('Applying tag filtering: ${selectedTags.join(', ')}');
          loadedVideos = loadedVideos
              .where((video) =>
                  video.topics.any((topic) => selectedTags.contains(topic)))
              .toList();
          print('After tag filtering: ${loadedVideos.length} videos remain');
        }

        videos.value = loadedVideos;
        print('Updated videos list with ${loadedVideos.length} videos');
      },
      onError: (error) {
        print('Error in video stream: $error');
      },
    );
  }

  Future<void> loadMoreVideos({bool refresh = false}) async {
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
      var newVideos =
          snapshot.docs.map((doc) => VideoModel.fromFirestore(doc)).toList();

      // Apply filters to new videos
      if (searchQuery.value.isNotEmpty) {
        final searchLower = searchQuery.value.toLowerCase();
        newVideos = newVideos
            .where((video) =>
                video.title.toLowerCase().contains(searchLower) ||
                video.description.toLowerCase().contains(searchLower) ||
                video.username.toLowerCase().contains(searchLower))
            .toList();
      }

      if (selectedTags.isNotEmpty) {
        newVideos = newVideos
            .where((video) =>
                video.topics.any((topic) => selectedTags.contains(topic)))
            .toList();
      }

      videos.addAll(newVideos);
      print('Added ${newVideos.length} more videos to the discover feed');
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

  void search(String query) {
    print('Search called with query: $query');
    searchQuery.value = query.trim();
    if (query.isEmpty || query.length > 2) {
      print('Triggering search for: ${searchQuery.value}');
      loadMoreVideos(refresh: true);
    } else {
      print('Search query too short, minimum 3 characters required');
    }
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
}
