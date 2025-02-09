import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:firebase_storage/firebase_storage.dart';

class VideoPlayerItem extends StatefulWidget {
  final String videoUrl;
  final bool isVertical;
  final Function(bool)? onMuteStateChanged;

  const VideoPlayerItem({
    super.key,
    required this.videoUrl,
    required this.isVertical,
    this.onMuteStateChanged,
  });

  @override
  State<VideoPlayerItem> createState() => VideoPlayerItemState();
}

class VideoPlayerItemState extends State<VideoPlayerItem> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _isMuted = false;
  bool _isPlaying = true;
  String? _error;
  bool _isDoubleTapEnabled = true;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<String> _getValidVideoUrl() async {
    try {
      if (widget.videoUrl
          .startsWith('https://firebasestorage.googleapis.com')) {
        // Extract the path from the URL
        final uri = Uri.parse(widget.videoUrl);
        final path = uri.path.split('/o/')[1].split('?')[0];
        final decodedPath = Uri.decodeComponent(path);

        // Get a fresh URL with a new token
        final ref = FirebaseStorage.instance.ref().child(decodedPath);
        final freshUrl = await ref.getDownloadURL();
        print('Got fresh URL for video');
        return freshUrl;
      }
      return widget.videoUrl;
    } catch (e) {
      print('Error getting valid video URL: $e');
      throw 'Failed to get valid video URL: $e';
    }
  }

  void _handleVideoError() {
    final error = _controller.value.errorDescription;
    if (error != null) {
      print('Video player error: $error');
      if (error.contains('expired') || error.contains('token')) {
        // If the error is related to expired token, try to reinitialize with fresh URL
        print('Attempting to refresh video URL and reinitialize...');
        _initializeVideo();
      } else if (mounted) {
        setState(() {
          _error = 'Error playing video: $error';
        });
      }
    }
  }

  Future<void> _initializeVideo() async {
    try {
      // Dispose of any existing controller first
      if (_isInitialized) {
        await _controller.pause();
        await _controller.dispose();
        _isInitialized = false;
      }

      // Try to get a fresh URL first
      final videoUrl = await _getValidVideoUrl();
      print('Initializing video with URL: $videoUrl');

      _controller = VideoPlayerController.network(
        videoUrl,
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
      );

      // Add error listener
      _controller.addListener(_handleVideoError);

      // Initialize with audio unmuted by default
      await _controller.initialize();
      _controller.setVolume(1.0);
      _isMuted = false;
      widget.onMuteStateChanged?.call(_isMuted);

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _error = null; // Clear any previous errors
        });
        // Auto-play and loop
        _controller.play();
        _controller.setLooping(true);
      }
    } catch (e) {
      print('Error initializing video: $e');
      setState(() {
        _error = 'Error loading video: $e';
      });
    }
  }

  @override
  void dispose() {
    // Ensure we stop playback and release resources
    if (_isInitialized) {
      _controller.removeListener(_handleVideoError);
      _controller.pause();
      _controller.dispose();
      _isInitialized = false;
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(VideoPlayerItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.videoUrl != oldWidget.videoUrl) {
      // Video URL changed, reinitialize with new URL
      _initializeVideo();
    }
  }

  void toggleMute() {
    if (!_isInitialized) return;
    setState(() {
      _isMuted = !_isMuted;
      _controller.setVolume(_isMuted ? 0 : 1);
      widget.onMuteStateChanged?.call(_isMuted);
    });
  }

  void togglePlayPause() {
    if (!_isInitialized) return;
    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
      } else {
        _controller.play();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.white,
              size: 48,
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
            ),
          ],
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
          onTap: togglePlayPause,
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
                          width: _controller.value.size.width,
                          height: _controller.value.size.height,
                          child: VideoPlayer(_controller),
                        ),
                      ),
                    )
                  : AspectRatio(
                      aspectRatio: _controller.value.aspectRatio,
                      child: VideoPlayer(_controller),
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
