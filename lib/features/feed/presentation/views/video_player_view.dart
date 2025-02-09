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
  final RxBool _isRetrying = false.obs;

  @override
  void initState() {
    super.initState();
    video = Get.arguments as VideoModel;
    _discoverController = Get.put(DiscoverController());
  }

  @override
  void dispose() {
    // Ensure video player is disposed
    final playerState = _playerKey.currentState;
    if (playerState != null) {
      playerState.dispose();
    }
    super.dispose();
  }

  void _showComments() {
    Get.bottomSheet(
      CommentsView(videoId: video.id),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
    );
  }

  Future<void> _retryPlayback() async {
    _isRetrying.value = true;

    // Properly dispose of the current player
    final playerState = _playerKey.currentState;
    if (playerState != null) {
      playerState.dispose();
    }

    // Wait a bit before recreating
    await Future.delayed(const Duration(milliseconds: 500));

    if (mounted) {
      setState(() {
        _isRetrying.value = false;
      });
    }
  }

  void _handleBack() {
    // Ensure cleanup before navigation
    final playerState = _playerKey.currentState;
    if (playerState != null) {
      playerState.dispose();
    }
    Get.back();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _handleBack();
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: _handleBack,
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: _retryPlayback,
            ),
          ],
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Video Player
            Obx(() => _isRetrying.value
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Colors.white,
                    ),
                  )
                : VideoPlayerItem(
                    key: _playerKey,
                    videoUrl: video.videoUrl,
                    thumbnailUrl: video.thumbnailUrl,
                    isVertical: video.isVertical ?? false,
                    onMuteStateChanged: (isMuted) => _isMuted.value = isMuted,
                  )),

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
      ),
    );
  }
}
