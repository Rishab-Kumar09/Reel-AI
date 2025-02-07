import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_firebase_app_new/features/feed/data/models/video_model.dart';
import 'package:flutter_firebase_app_new/core/theme/app_theme.dart';
import 'package:flutter_firebase_app_new/features/feed/presentation/widgets/video_player_item.dart';
import 'package:flutter_firebase_app_new/features/feed/presentation/widgets/video_actions.dart';
import 'package:flutter_firebase_app_new/features/feed/presentation/widgets/video_description.dart';

class VideoPlayerView extends StatefulWidget {
  const VideoPlayerView({super.key});

  @override
  State<VideoPlayerView> createState() => _VideoPlayerViewState();
}

class _VideoPlayerViewState extends State<VideoPlayerView> {
  late VideoModel video;
  final RxBool _isMuted = false.obs;
  final GlobalKey<VideoPlayerItemState> _playerKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    video = Get.arguments as VideoModel;
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
            child: VideoActions(
              onLike: () {}, // Implement like functionality
              onComment: () {
                Get.toNamed('/comments', arguments: video.id);
              },
              onShare: () {}, // Implement share functionality
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
            ),
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
