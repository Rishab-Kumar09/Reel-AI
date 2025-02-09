import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cached_network_image/cached_network_image.dart';

class VideoPlayerItem extends StatefulWidget {
  final String videoUrl;
  final String thumbnailUrl;
  final bool isVertical;
  final Function(bool)? onMuteStateChanged;
  final bool shouldPreload;

  const VideoPlayerItem({
    super.key,
    required this.videoUrl,
    required this.thumbnailUrl,
    required this.isVertical,
    this.onMuteStateChanged,
    this.shouldPreload = false,
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
  bool _showThumbnail = true;

  @override
  void initState() {
    super.initState();
    if (widget.shouldPreload) {
      _initializeVideo();
    }
  }

  Future<String> _getValidVideoUrl() async {
    try {
      if (widget.videoUrl
          .startsWith('https://firebasestorage.googleapis.com')) {
        final uri = Uri.parse(widget.videoUrl);
        final path = uri.path.split('/o/')[1].split('?')[0];
        final decodedPath = Uri.decodeComponent(path);
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
      if (_isInitialized) {
        await _controller.pause();
        await _controller.dispose();
        _isInitialized = false;
      }

      final videoUrl = await _getValidVideoUrl();
      print('Initializing video with URL: $videoUrl');

      _controller = VideoPlayerController.network(
        videoUrl,
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
      );

      _controller.addListener(_handleVideoError);
      _controller.addListener(() {
        if (_controller.value.isPlaying && _showThumbnail && mounted) {
          setState(() {
            _showThumbnail = false;
          });
        }
      });

      await _controller.initialize();
      _controller.setVolume(1.0);
      _isMuted = false;
      widget.onMuteStateChanged?.call(_isMuted);

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _error = null;
        });

        if (widget.shouldPreload) {
          _controller.play();
          _controller.setLooping(true);
        }
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
      _initializeVideo();
    }

    // Start loading if shouldPreload changes to true
    if (widget.shouldPreload && !oldWidget.shouldPreload) {
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
    if (!_isInitialized) {
      _initializeVideo();
      return;
    }
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
            const Icon(Icons.error_outline, color: Colors.white, size: 48),
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
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (_showThumbnail)
                            CachedNetworkImage(
                              imageUrl: widget.thumbnailUrl,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => const SizedBox(),
                              errorWidget: (context, url, error) =>
                                  const SizedBox(),
                            ),
                          if (_isInitialized)
                            FittedBox(
                              fit: BoxFit.cover,
                              child: SizedBox(
                                width: _controller.value.size.width,
                                height: _controller.value.size.height,
                                child: VideoPlayer(_controller),
                              ),
                            ),
                          if (!_isInitialized && !_showThumbnail)
                            const Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                              ),
                            ),
                        ],
                      ),
                    )
                  : AspectRatio(
                      aspectRatio: _controller.value.aspectRatio,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (_showThumbnail)
                            CachedNetworkImage(
                              imageUrl: widget.thumbnailUrl,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => const SizedBox(),
                              errorWidget: (context, url, error) =>
                                  const SizedBox(),
                            ),
                          if (_isInitialized) VideoPlayer(_controller),
                          if (!_isInitialized && !_showThumbnail)
                            const Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                              ),
                            ),
                        ],
                      ),
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
