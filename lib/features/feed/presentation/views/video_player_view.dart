import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_firebase_app_new/features/feed/data/models/video_model.dart';
import 'package:flutter_firebase_app_new/core/theme/app_theme.dart';
import 'package:flutter_firebase_app_new/features/feed/presentation/widgets/video_player_item.dart';
import 'package:flutter_firebase_app_new/features/feed/presentation/widgets/video_actions.dart';
import 'package:flutter_firebase_app_new/features/feed/presentation/widgets/video_description.dart';
import 'package:flutter_firebase_app_new/features/feed/presentation/views/comments_view.dart';
import 'package:flutter_firebase_app_new/core/routes/app_routes.dart';
import 'package:flutter_firebase_app_new/features/discover/presentation/controllers/discover_controller.dart';

class VideoPlayerView extends StatefulWidget {
  const VideoPlayerView({super.key});

  @override
  State<VideoPlayerView> createState() => _VideoPlayerViewState();
}

class _VideoPlayerViewState extends State<VideoPlayerView> {
  late VideoModel video;
  final RxBool _isMuted = false.obs;
  final GlobalKey<VideoPlayerItemState> _playerKey = GlobalKey();
  late final DiscoverController _discoverController;

  void _showComments() {
    Get.bottomSheet(
      CommentsView(videoId: video.id),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
    );
  }

  @override
  void initState() {
    super.initState();
    video = Get.arguments as VideoModel;
    // Initialize the DiscoverController if it doesn't exist
    _discoverController = Get.put(DiscoverController());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Get.back(),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Video Player
          VideoPlayerItem(
            key: _playerKey,
            videoUrl: video.videoUrl,
            isVertical: video.isVertical ?? false,
            onMuteStateChanged: (isMuted) => _isMuted.value = isMuted,
          ),

          // Video Actions
          Positioned(
            right: 16,
            bottom: 100,
            child: Obx(() => VideoActions(
                  onLike: () => _discoverController.likeVideo(video.id),
                  onComment: _showComments,
                  onShare: () => _discoverController.shareVideo(video.id),
                  onMuteToggle: () {
                    final playerState = _playerKey.currentState;
                    if (playerState != null) {
                      playerState.toggleMute();
                    }
                  },
                  likes: '${video.likes}',
                  comments: '${video.comments}',
                  shares: '${video.shares}',
                  isMuted: _isMuted.value,
                  isLiked: _discoverController.isVideoLiked(video.id),
                )),
          ),

          // Video Description
          Positioned(
            left: 16,
            right: 88,
            bottom: 24,
            child: VideoDescription(
              username: video.username,
              description: video.description,
              songName: 'Original Audio',
              title: video.title,
            ),
          ),
        ],
      ),
    );
  }
}
