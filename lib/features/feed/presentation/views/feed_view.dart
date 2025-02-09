import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter/services.dart';
import 'package:flutter_firebase_app_new/core/theme/app_theme.dart';
import 'package:flutter_firebase_app_new/features/feed/presentation/controllers/feed_controller.dart';
import 'package:flutter_firebase_app_new/features/feed/presentation/widgets/video_player_item.dart';
import 'package:flutter_firebase_app_new/features/feed/presentation/widgets/video_actions.dart';
import 'package:flutter_firebase_app_new/features/feed/presentation/widgets/video_description.dart';
import 'package:flutter_firebase_app_new/features/feed/data/services/sample_data_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_firebase_app_new/features/feed/presentation/views/comments_view.dart';
import 'package:flutter_firebase_app_new/features/feed/presentation/controllers/comments_controller.dart';
import 'package:flutter_firebase_app_new/features/feed/data/models/video_model.dart';

class FeedView extends StatefulWidget {
  const FeedView({super.key});

  @override
  State<FeedView> createState() => _FeedViewState();
}

class _FeedViewState extends State<FeedView> {
  final FeedController _feedController = Get.put(FeedController());
  final PageController _pageController = PageController();
  final SampleDataService _sampleDataService = SampleDataService();
  final RxBool _isMuted = false.obs;
  final Map<int, GlobalKey<VideoPlayerItemState>> _videoPlayerKeys = {};

  GlobalKey<VideoPlayerItemState> _getPlayerKey(int index) {
    if (!_videoPlayerKeys.containsKey(index)) {
      _videoPlayerKeys[index] = GlobalKey<VideoPlayerItemState>();
    }
    return _videoPlayerKeys[index]!;
  }

  @override
  void dispose() {
    _pageController.dispose();
    _videoPlayerKeys.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: _feedController.setCategory,
            color: Colors.black87,
            itemBuilder: (BuildContext context) {
              return _feedController.categories.map((String value) {
                final isSelected =
                    _feedController.selectedCategory.value == value;
                return PopupMenuItem<String>(
                  value: value,
                  child: Row(
                    children: [
                      if (isSelected)
                        const Icon(Icons.check, color: Colors.white, size: 18),
                      if (isSelected) const SizedBox(width: 8),
                      Text(
                        value.capitalize ?? value,
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.textPrimaryColor,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList();
            },
          ),
        ],
      ),
      body: Obx(() {
        if (_feedController.isLoading.value && _feedController.videos.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!_feedController.isLoading.value &&
            _feedController.videos.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'No videos found',
                  style: AppTheme.headlineSmall.copyWith(
                    color: AppTheme.textPrimaryColor,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      print('Attempting to add sample videos...');
                      await _sampleDataService.addSampleVideos();
                      print('Sample videos added successfully');
                      Get.snackbar(
                        'Success',
                        'Sample videos added successfully',
                        snackPosition: SnackPosition.BOTTOM,
                        backgroundColor: Colors.green.withOpacity(0.1),
                        colorText: Colors.green,
                        duration: const Duration(seconds: 3),
                      );
                      await _feedController.loadVideos(refresh: true);
                    } catch (e) {
                      print('Error adding sample videos from empty state: $e');
                      String errorMessage = e.toString();
                      if (e is FirebaseException) {
                        errorMessage = 'Firebase Error: ${e.message}';
                        print('Firebase error code: ${e.code}');
                        print('Firebase error message: ${e.message}');
                      }
                      Get.snackbar(
                        'Error',
                        errorMessage,
                        snackPosition: SnackPosition.BOTTOM,
                        backgroundColor: Colors.red.withOpacity(0.1),
                        colorText: Colors.red,
                        duration: const Duration(seconds: 5),
                      );
                    }
                  },
                  child: const Text('Add Sample Videos'),
                ),
              ],
            ),
          );
        }

        return PageView.builder(
          controller: _pageController,
          scrollDirection: Axis.vertical,
          onPageChanged: (index) {
            if (index == _feedController.videos.length - 2) {
              _feedController.loadVideos();
            }
          },
          itemCount: _feedController.videos.length,
          itemBuilder: (context, index) {
            final video = _feedController.videos[index];
            return GestureDetector(
              onVerticalDragUpdate: (details) {
                // Allow vertical scrolling
                if (details.primaryDelta! > 0) {
                  // Scrolling down
                  if (index > 0) {
                    _pageController.previousPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  }
                } else if (details.primaryDelta! < 0) {
                  // Scrolling up
                  if (index < _feedController.videos.length - 1) {
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  }
                }
              },
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  // Video Player
                  VideoPlayerItem(
                    key: _getPlayerKey(index),
                    videoUrl: video.videoUrl,
                    thumbnailUrl: video.thumbnailUrl,
                    isVertical: video.isVertical ?? false,
                    onMuteStateChanged: (isMuted) => _isMuted.value = isMuted,
                    shouldPreload: _shouldPreloadVideo(index),
                  ),

                  // Combined Video Controls and Actions
                  Positioned(
                    right: 16,
                    bottom: 100,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Obx(() => VideoActions(
                              onLike: () => _feedController.likeVideo(video.id),
                              onComment: () => _showComments(video),
                              onShare: () =>
                                  _feedController.shareVideo(video.id),
                              onMuteToggle: () {
                                final playerState =
                                    _getPlayerKey(index).currentState;
                                if (playerState != null) {
                                  playerState.toggleMute();
                                }
                              },
                              likes: '${video.likes}',
                              comments: '${video.comments}',
                              shares: '${video.shares}',
                              isMuted: _isMuted.value,
                              isLiked: _feedController.isVideoLiked(video.id),
                            )),
                      ],
                    ),
                  ),

                  // Video Description (moved slightly higher to avoid overlap)
                  Positioned(
                    left: 16,
                    right:
                        88, // Increased to give more space for right-side buttons
                    bottom: 24,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        VideoDescription(
                          username: video.username,
                          description: video.description,
                          songName: 'Original Audio',
                          title: video.title ?? 'Untitled Video',
                        ),
                        if (video.aiMetadata != null &&
                            video.aiMetadata!['content_tags'] != null)
                          Wrap(
                            spacing: 8,
                            children:
                                (video.aiMetadata!['content_tags'] as List)
                                    .map((tag) => Chip(
                                          label: Text(
                                            '#$tag',
                                            style: AppTheme.bodySmall.copyWith(
                                              color: AppTheme.textPrimaryColor,
                                            ),
                                          ),
                                          backgroundColor: AppTheme.primaryColor
                                              .withOpacity(0.2),
                                        ))
                                    .take(3)
                                    .toList(),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      }),
    );
  }

  void _showComments(VideoModel video) {
    Get.bottomSheet(
      CommentsView(videoId: video.id),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
    );
  }

  bool _shouldPreloadVideo(int index) {
    final currentPage =
        _pageController.hasClients ? (_pageController.page?.round() ?? 0) : 0;

    // Preload previous, current, and next video
    return index == currentPage - 1 || // previous video
        index == currentPage || // current video
        index == currentPage + 1; // next video
  }
}
