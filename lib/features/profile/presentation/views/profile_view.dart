import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_firebase_app_new/core/theme/app_theme.dart';
import 'package:flutter_firebase_app_new/features/auth/presentation/controllers/auth_controller.dart';
import 'package:flutter_firebase_app_new/features/profile/presentation/controllers/profile_controller.dart';
import 'package:flutter_firebase_app_new/features/feed/data/models/video_model.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_firebase_app_new/features/feed/data/services/sample_data_service.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_firebase_app_new/core/routes/app_routes.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView>
    with SingleTickerProviderStateMixin {
  final _authController = Get.find<AuthController>();
  final _profileController = Get.put(ProfileController());
  late TabController _tabController;
  final Map<String, VideoPlayerController> _videoControllers = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    for (var controller in _videoControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<VideoPlayerController?> _getVideoController(String videoUrl) async {
    if (!_videoControllers.containsKey(videoUrl)) {
      try {
        final controller =
            VideoPlayerController.networkUrl(Uri.parse(videoUrl));
        _videoControllers[videoUrl] = controller;
        await controller.initialize();
        // Seek to the first frame
        await controller.seekTo(Duration.zero);
        await controller.setVolume(0.0);
        return controller;
      } catch (e) {
        print('Error initializing video controller for $videoUrl: $e');
        return null;
      }
    }
    return _videoControllers[videoUrl];
  }

  Widget _buildVideoThumbnail(VideoModel video) {
    return FutureBuilder<VideoPlayerController?>(
      future: _getVideoController(video.videoUrl),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
          return const Center(
            child: Icon(
              Icons.play_circle_outline,
              size: 32,
              color: AppTheme.primaryColor,
            ),
          );
        }

        return SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: snapshot.data!.value.size.width,
              height: snapshot.data!.value.size.height,
              child: VideoPlayer(snapshot.data!),
            ),
          ),
        );
      },
    );
  }

  Widget _buildVideoGrid(List<VideoModel> videos) {
    if (_profileController.isLoading.value) {
      return const Center(child: CircularProgressIndicator());
    }

    if (videos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.videocam_off,
              size: 64,
              color: AppTheme.textSecondaryColor,
            ),
            const SizedBox(height: 16),
            Text(
              'No videos yet',
              style: AppTheme.titleMedium.copyWith(
                color: AppTheme.textSecondaryColor,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _profileController.refreshVideos,
      child: GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 9 / 16,
        ),
        itemCount: videos.length,
        itemBuilder: (context, index) {
          final video = videos[index];
          return GestureDetector(
            onTap: () {
              Get.toNamed(Routes.videoPlayer, arguments: video);
            },
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: AppTheme.surfaceColor,
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Video thumbnail
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _buildVideoThumbnail(video),
                  ),
                  // Play icon overlay
                  const Center(
                    child: Icon(
                      Icons.play_circle_outline,
                      size: 32,
                      color: Colors.white,
                    ),
                  ),
                  // Video info overlay
                  Container(
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
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          video.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.bodySmall.copyWith(
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.favorite,
                              size: 12,
                              color: Colors.red,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${video.likes}',
                              style: AppTheme.bodySmall.copyWith(
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _handleLogout() async {
    try {
      await _authController.signOut();
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to logout: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.withOpacity(0.1),
        colorText: Colors.red,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: Obx(() {
        final user = _authController.user.value;

        return NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // Profile Image
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                      backgroundImage: user?.photoUrl != null
                          ? CachedNetworkImageProvider(user!.photoUrl!)
                          : null,
                      child: user?.photoUrl == null
                          ? Text(
                              user?.name?.substring(0, 1).toUpperCase() ??
                                  user?.email.substring(0, 1).toUpperCase() ??
                                  'U',
                              style: AppTheme.headlineLarge.copyWith(
                                color: AppTheme.primaryColor,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(height: 16),

                    // User Info
                    Text(
                      user?.name ?? 'No Name',
                      style: AppTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user?.email ?? '',
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                    if (user?.bio != null && user!.bio!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        user.bio!,
                        style: AppTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ],

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverAppBarDelegate(
                TabBar(
                  controller: _tabController,
                  tabs: const [
                    Tab(text: 'My Videos'),
                    Tab(text: 'Liked'),
                  ],
                  labelStyle: AppTheme.titleSmall,
                  unselectedLabelStyle: AppTheme.bodyMedium,
                  indicatorColor: AppTheme.primaryColor,
                ),
              ),
            ),
          ],
          body: TabBarView(
            controller: _tabController,
            children: [
              // My Videos Tab
              Obx(() => _buildVideoGrid(_profileController.userVideos)),
              // Liked Videos Tab
              Obx(() => _buildVideoGrid(_profileController.likedVideos)),
            ],
          ),
        );
      }),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _SliverAppBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
