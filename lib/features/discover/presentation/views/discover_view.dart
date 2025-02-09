import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_firebase_app_new/core/theme/app_theme.dart';
import 'package:flutter_firebase_app_new/core/constants/app_constants.dart';
import 'package:flutter_firebase_app_new/features/discover/presentation/controllers/discover_controller.dart';
import 'package:flutter_firebase_app_new/features/feed/presentation/views/video_player_view.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_firebase_app_new/features/feed/data/models/video_model.dart';
import 'dart:async';

class DiscoverView extends StatefulWidget {
  const DiscoverView({super.key});

  @override
  State<DiscoverView> createState() => _DiscoverViewState();
}

class _DiscoverViewState extends State<DiscoverView>
    with AutomaticKeepAliveClientMixin {
  final DiscoverController controller = Get.put(DiscoverController());
  final ScrollController _scrollController = ScrollController();
  Timer? _debounce;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_debounce?.isActive ?? false) return;
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          controller.loadMoreVideos();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Discover',
          style: AppTheme.titleLarge,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => controller.refreshLikeCounts(),
            tooltip: 'Refresh like counts',
          ),
        ],
      ),
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
                onRefresh: () => controller.loadMoreVideos(refresh: true),
                child: CustomScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    // Trending Section
                    SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                itemCount: controller.trendingVideos.length,
                                itemBuilder: (context, index) {
                                  final video =
                                      controller.trendingVideos[index];
                                  return _buildTrendingVideoCard(video);
                                },
                              );
                            }),
                          ),
                        ],
                      ),
                    ),

                    // All Videos Header
                    SliverToBoxAdapter(
                      child: Padding(
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
                    ),

                    // All Videos Grid
                    Obx(() {
                      if (controller.isLoading.value &&
                          controller.videos.isEmpty) {
                        return const SliverFillRemaining(
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      if (!controller.isLoading.value &&
                          controller.videos.isEmpty) {
                        return SliverFillRemaining(
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32.0),
                              child: Text(
                                'No videos found',
                                style: AppTheme.titleMedium,
                              ),
                            ),
                          ),
                        );
                      }

                      return SliverPadding(
                        padding: const EdgeInsets.all(16),
                        sliver: SliverGrid(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: 9 / 16,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              if (index >= controller.videos.length) {
                                // Load more videos when reaching the end
                                if (!controller.isLoading.value) {
                                  WidgetsBinding.instance
                                      .addPostFrameCallback((_) {
                                    controller.loadMoreVideos();
                                  });
                                }
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }
                              final video = controller.videos[index];
                              return _buildVideoCard(video);
                            },
                            childCount: controller.videos.length +
                                (controller.hasMore.value ? 1 : 0),
                          ),
                        ),
                      );
                    }),
                  ],
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
      placeholder: (context, url) => const Center(
        child: CircularProgressIndicator(),
      ),
      errorWidget: (context, url, error) => const Center(
        child: Icon(
          Icons.play_circle_outline,
          size: 32,
          color: AppTheme.primaryColor,
        ),
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
    final controller = Get.find<DiscoverController>();
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
                Obx(() {
                  final isLiked = controller.isVideoLiked(video.id);
                  return GestureDetector(
                    onTap: () => controller.toggleLike(video.id),
                    child: Row(
                      children: [
                        Icon(
                          Icons.favorite,
                          color: isLiked ? Colors.red : Colors.white70,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${video.likes}',
                          style: AppTheme.bodySmall
                              .copyWith(color: Colors.white70),
                        ),
                      ],
                    ),
                  );
                }),
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
