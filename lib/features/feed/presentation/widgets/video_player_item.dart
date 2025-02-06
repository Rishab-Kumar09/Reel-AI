import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoPlayerItem extends StatefulWidget {
  final String videoUrl;
  final bool isVertical;
  final Function(bool) onMuteStateChanged;

  const VideoPlayerItem({
    Key? key,
    required this.videoUrl,
    required this.onMuteStateChanged,
    this.isVertical = false,
  }) : super(key: key);

  @override
  State<VideoPlayerItem> createState() => VideoPlayerItemState();
}

class VideoPlayerItemState extends State<VideoPlayerItem> {
  late VideoPlayerController _videoPlayerController;
  bool _isPlaying = true;
  bool _isInitialized = false;
  bool _isMuted = false;
  String? _error;
  bool _isDoubleTapEnabled = true;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  void _initializeVideo() async {
    try {
      _videoPlayerController = VideoPlayerController.network(widget.videoUrl);
      await _videoPlayerController.initialize();

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }

      _videoPlayerController.setLooping(true);
      _videoPlayerController.play();
    } catch (e) {
      print('Error initializing video ${widget.videoUrl}: $e');
      if (mounted) {
        setState(() {
          _error = 'Error loading video: $e';
        });
      }
    }
  }

  @override
  void dispose() {
    _videoPlayerController.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    setState(() {
      _isPlaying = !_isPlaying;
      _isPlaying
          ? _videoPlayerController.play()
          : _videoPlayerController.pause();
    });
  }

  void toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
      _videoPlayerController.setVolume(_isMuted ? 0 : 1);
      widget.onMuteStateChanged(_isMuted);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            _error!,
            style: const TextStyle(color: Colors.white),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (!_isInitialized) {
      return const Center(
        child: CircularProgressIndicator(
          color: Colors.white,
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // Video Container
        GestureDetector(
          onTap: _togglePlayPause,
          onDoubleTapDown: (details) {
            if (!_isDoubleTapEnabled) return;
            _isDoubleTapEnabled = false;
            Future.delayed(const Duration(milliseconds: 500), () {
              _isDoubleTapEnabled = true;
            });
          },
          behavior: HitTestBehavior.opaque,
          child: Container(
            color: Colors.black,
            child: Center(
              child: widget.isVertical
                  ? SizedBox.expand(
                      child: FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: _videoPlayerController.value.size.width,
                          height: _videoPlayerController.value.size.height,
                          child: VideoPlayer(_videoPlayerController),
                        ),
                      ),
                    )
                  : AspectRatio(
                      aspectRatio: _videoPlayerController.value.aspectRatio,
                      child: VideoPlayer(_videoPlayerController),
                    ),
            ),
          ),
        ),

        // Play/Pause overlay
        if (!_isPlaying)
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow,
                color: Colors.white,
                size: 50,
              ),
            ),
          ),
      ],
    );
  }
}
