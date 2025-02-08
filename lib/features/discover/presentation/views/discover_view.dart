import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_firebase_app_new/core/theme/app_theme.dart';
import 'package:flutter_firebase_app_new/core/constants/app_constants.dart';
import 'package:flutter_firebase_app_new/features/discover/presentation/controllers/discover_controller.dart';
import 'package:flutter_firebase_app_new/features/feed/presentation/views/video_player_view.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_firebase_app_new/features/feed/data/models/video_model.dart';

class DiscoverView extends StatelessWidget {
  const DiscoverView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(DiscoverController());

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      onChanged: controller.search,
                      decoration: InputDecoration(
                        hintText: 'Search videos...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.filter_list),
                    onPressed: () => _showFilterDialog(context, controller),
                  ),
                ],
              ),
            ),

            // Categories
            SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: AppConstants.mainCategories.length,
                itemBuilder: (context, index) {
                  final category = AppConstants.mainCategories[index];
                  return Obx(() {
                    final isSelected =
                        controller.selectedCategory.value == category;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(category.capitalize ?? category),
                        selected: isSelected,
                        onSelected: (_) => controller.setCategory(category),
                      ),
                    );
                  });
                },
              ),
            ),

            // Content
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  await Future.wait([
                    controller.loadMoreVideos(refresh: true),
                    controller.loadTrendingVideos(),
                  ]);
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Trending Section
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'Trending',
                          style: AppTheme.headlineSmall,
                        ),
                      ),
                      SizedBox(
                        height: 200,
                        child: Obx(() {
                          if (controller.isTrendingLoading.value) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }

                          if (controller.trendingVideos.isEmpty) {
                            return const Center(
                              child: Text('No trending videos'),
                            );
                          }

                          return ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: controller.trendingVideos.length,
                            itemBuilder: (context, index) {
                              final video = controller.trendingVideos[index];
                              return _buildTrendingVideoCard(video);
                            },
                          );
                        }),
                      ),

                      // All Videos Grid
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'All Videos',
                              style: AppTheme.headlineSmall,
                            ),
                            Obx(() {
                              if (controller.selectedTags.isNotEmpty) {
                                return TextButton(
                                  onPressed: controller.clearFilters,
                                  child: const Text('Clear Filters'),
                                );
                              }
                              return const SizedBox.shrink();
                            }),
                          ],
                        ),
                      ),
                      Obx(() {
                        if (controller.isLoading.value &&
                            controller.videos.isEmpty) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }

                        if (!controller.isLoading.value &&
                            controller.videos.isEmpty) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32.0),
                              child: Text(
                                'No videos found',
                                style: AppTheme.titleMedium,
                              ),
                            ),
                          );
                        }

                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(8),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.8,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),
                          itemCount: controller.videos.length,
                          itemBuilder: (context, index) {
                            final video = controller.videos[index];
                            return _buildVideoCard(video);
                          },
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendingVideoCard(VideoModel video) {
    return GestureDetector(
      onTap: () => Get.to(() => const VideoPlayerView(), arguments: video),
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 8),
        child: Card(
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildVideoThumbnail(video),
              _buildGradientOverlay(),
              _buildVideoInfo(video, showLikes: true),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoCard(VideoModel video) {
    return GestureDetector(
      onTap: () => Get.to(() => const VideoPlayerView(), arguments: video),
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildVideoThumbnail(video),
            _buildGradientOverlay(),
            _buildVideoInfo(video),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoThumbnail(VideoModel video) {
    return CachedNetworkImage(
      imageUrl: video.thumbnailUrl,
      fit: BoxFit.cover,
      placeholder: (context, url) => Container(
        color: Colors.grey[900],
        child: const Center(child: CircularProgressIndicator()),
      ),
      errorWidget: (context, url, error) => Container(
        color: Colors.grey[900],
        child: const Icon(Icons.error),
      ),
    );
  }

  Widget _buildGradientOverlay() {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black.withOpacity(0.7),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoInfo(VideoModel video, {bool showLikes = false}) {
    return Positioned(
      left: 8,
      right: 8,
      bottom: 8,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            video.title,
            style: AppTheme.titleSmall.copyWith(color: Colors.white),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  video.username,
                  style: AppTheme.bodySmall.copyWith(color: Colors.white70),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (showLikes) ...[
                const Icon(
                  Icons.favorite,
                  color: Colors.red,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  '${video.likes}',
                  style: AppTheme.bodySmall.copyWith(color: Colors.white70),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  void _showFilterDialog(BuildContext context, DiscoverController controller) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter by Tags'),
        content: SizedBox(
          width: double.maxFinite,
          child: Obx(() {
            final allTags = controller.videos
                .expand((video) => video.topics)
                .toSet()
                .toList();

            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: allTags.map((tag) {
                final isSelected = controller.selectedTags.contains(tag);
                return FilterChip(
                  label: Text(tag),
                  selected: isSelected,
                  onSelected: (_) {
                    controller.toggleTag(tag);
                  },
                );
              }).toList(),
            );
          }),
        ),
        actions: [
          TextButton(
            onPressed: () {
              controller.clearFilters();
              Navigator.pop(context);
            },
            child: const Text('Clear All'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}
