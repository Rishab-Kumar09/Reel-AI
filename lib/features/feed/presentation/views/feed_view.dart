import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_firebase_app_new/core/theme/app_theme.dart';
import 'package:flutter_firebase_app_new/features/feed/presentation/controllers/feed_controller.dart';
import 'package:flutter_firebase_app_new/features/feed/presentation/widgets/video_player_item.dart';
import 'package:flutter_firebase_app_new/features/feed/presentation/widgets/video_actions.dart';
import 'package:flutter_firebase_app_new/features/feed/presentation/widgets/video_description.dart';
import 'package:flutter_firebase_app_new/features/feed/data/services/sample_data_service.dart';
import 'package:firebase_core/firebase_core.dart';

class FeedView extends StatefulWidget {
  const FeedView({super.key});

  @override
  State<FeedView> createState() => _FeedViewState();
}

class _FeedViewState extends State<FeedView> {
  final FeedController _feedController = Get.put(FeedController());
  final PageController _pageController = PageController();
  final SampleDataService _sampleDataService = SampleDataService();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Category filter
            Obx(() => DropdownButton<String>(
                  value: _feedController.selectedCategory.value,
                  dropdownColor: AppTheme.surfaceColor,
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.textPrimaryColor,
                  ),
                  items: _feedController.categories.map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(
                        value.capitalize ?? value,
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.textPrimaryColor,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      _feedController.setCategory(newValue);
                    }
                  },
                )),
            const SizedBox(width: 16),
            // Difficulty filter
            Obx(() => DropdownButton<String>(
                  value: _feedController.selectedDifficulty.value,
                  dropdownColor: AppTheme.surfaceColor,
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.textPrimaryColor,
                  ),
                  items: [
                    'all',
                    'beginner',
                    'intermediate',
                    'advanced',
                  ].map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(
                        value.capitalize ?? value,
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.textPrimaryColor,
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      _feedController.setDifficulty(newValue);
                    }
                  },
                )),
          ],
        ),
        centerTitle: true,
        actions: [
          // Upload video button
          IconButton(
            icon: const Icon(Icons.upload_file),
            onPressed: () async {
              try {
                Get.snackbar(
                  'Upload',
                  'Select a video from your device',
                  snackPosition: SnackPosition.BOTTOM,
                  duration: const Duration(seconds: 2),
                );

                await _sampleDataService.uploadVideoFromDevice();

                Get.snackbar(
                  'Success',
                  'Video uploaded and added to feed',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: Colors.green.withOpacity(0.1),
                  colorText: Colors.green,
                  duration: const Duration(seconds: 3),
                );

                // Refresh the feed to show the new video
                await _feedController.loadVideos(refresh: true);
              } catch (e) {
                print('Error uploading video: $e');
                String errorMessage = e.toString();
                if (e is FirebaseException) {
                  errorMessage = 'Firebase Error: ${e.message}';
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
          ),
          // Add sample data button (only for development)
          IconButton(
            icon: const Icon(Icons.add_box),
            onPressed: () async {
              try {
                Get.snackbar(
                  'Uploading',
                  'Starting to upload sample videos...',
                  snackPosition: SnackPosition.BOTTOM,
                  duration: const Duration(seconds: 2),
                );

                await _sampleDataService.uploadSampleVideos();

                Get.snackbar(
                  'Success',
                  'Videos uploaded successfully. Adding to feed...',
                  snackPosition: SnackPosition.BOTTOM,
                  duration: const Duration(seconds: 2),
                );

                await _sampleDataService.addSampleVideos();
                Get.snackbar(
                  'Success',
                  'Sample videos added successfully',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: Colors.green.withOpacity(0.1),
                  colorText: Colors.green,
                );
                _feedController.loadVideos(refresh: true);
              } catch (e) {
                print('Error adding sample videos from app bar: $e');
                Get.snackbar(
                  'Error',
                  'Failed to add sample videos: $e',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: Colors.red.withOpacity(0.1),
                  colorText: Colors.red,
                  duration: const Duration(seconds: 5),
                );
              }
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
                    videoUrl: video.videoUrl,
                    isVertical: video.isVertical ?? false,
                  ),

                  // Video Actions
                  Positioned(
                    right: 16,
                    bottom: 100,
                    child: VideoActions(
                      onLike: () => _feedController.likeVideo(video.id),
                      onComment: () {
                        // TODO: Implement comment functionality
                        Get.toNamed('/comments', arguments: video.id);
                      },
                      onShare: () => _feedController.shareVideo(video.id),
                      likes: '${video.likes}',
                      comments: '${video.comments}',
                      shares: '${video.shares}',
                    ),
                  ),

                  // Video Description
                  Positioned(
                    left: 16,
                    right: 72,
                    bottom: 24,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        VideoDescription(
                          username: video.username,
                          description: video.description,
                          songName: 'Original Audio',
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
}
