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

  // Maximum number of video controllers to keep in memory
  static const int _maxControllers = 9;

  // LRU cache for video controllers
  final Map<String, VideoPlayerController> _videoControllers = {};
  final List<String> _controllerQueue = [];

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
    _videoControllers.clear();
    _controllerQueue.clear();
    super.dispose();
  }

  Future<void> _disposeOldestController() async {
    if (_controllerQueue.isEmpty) return;

    final oldestUrl = _controllerQueue.removeAt(0);
    final controller = _videoControllers.remove(oldestUrl);
    if (controller != null) {
      await controller.dispose();
      print('Disposed controller for video: $oldestUrl');
    }
  }

  Future<VideoPlayerController?> _getVideoController(String videoUrl) async {
    // If controller exists, move it to the end of the queue (most recently used)
    if (_videoControllers.containsKey(videoUrl)) {
      _controllerQueue.remove(videoUrl);
      _controllerQueue.add(videoUrl);
      return _videoControllers[videoUrl];
    }

    try {
      // If we're at max capacity, remove the oldest controller
      while (_videoControllers.length >= _maxControllers) {
        await _disposeOldestController();
      }

      final controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
      _videoControllers[videoUrl] = controller;
      _controllerQueue.add(videoUrl);

      await controller.initialize();
      await controller.seekTo(Duration.zero);
      await controller.setVolume(0.0);

      print('Initialized new controller for video: $videoUrl');
      return controller;
    } catch (e) {
      print('Error initializing video controller for $videoUrl: $e');
      // Remove from queue and map if initialization failed
      _controllerQueue.remove(videoUrl);
      _videoControllers.remove(videoUrl);
      return null;
    }
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
                  // Add menu button for user's own videos
                  if (video.userId == _authController.user.value?.id)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Theme(
                        data: Theme.of(context).copyWith(
                          popupMenuTheme: PopupMenuThemeData(
                            color: AppTheme.surfaceColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        child: PopupMenuButton<String>(
                          icon: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Icon(
                              Icons.more_vert,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          onSelected: (value) {
                            if (value == 'delete') {
                              Get.dialog(
                                AlertDialog(
                                  title: Text(
                                    'Delete Video',
                                    style: AppTheme.titleMedium,
                                  ),
                                  content: Text(
                                    'Are you sure you want to delete this video? This action cannot be undone.',
                                    style: AppTheme.bodyMedium,
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Get.back(),
                                      child: Text(
                                        'Cancel',
                                        style: AppTheme.bodyMedium.copyWith(
                                          color: AppTheme.textSecondaryColor,
                                        ),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        Get.back();
                                        _profileController.deleteVideo(video);
                                      },
                                      child: Text(
                                        'Delete',
                                        style: AppTheme.bodyMedium.copyWith(
                                          color: AppTheme.errorColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem<String>(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.delete_outline,
                                    size: 20,
                                    color: AppTheme.errorColor,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Delete Video',
                                    style: AppTheme.bodyMedium.copyWith(
                                      color: AppTheme.errorColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
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
