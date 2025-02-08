import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:firebase_storage/firebase_storage.dart';

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
        return await ref.getDownloadURL();
      }
      return widget.videoUrl;
    } catch (e) {
      print('Error getting valid video URL: $e');
      throw 'Failed to get valid video URL';
    }
  }

  void _handleVideoError() {
    final error = _videoPlayerController.value.errorDescription;
    if (error != null) {
      print('Video player error: $error');
      if (mounted) {
        setState(() {
          _error = 'Error playing video: $error';
        });
      }
    }
  }

  void _initializeVideo() async {
    try {
      print('Getting valid video URL...');
      final validUrl = await _getValidVideoUrl();
      print('Initializing video player for URL: $validUrl');

      if (!mounted) return;

      _videoPlayerController = VideoPlayerController.network(
        validUrl,
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );

      // Add listener for errors
      _videoPlayerController.addListener(_handleVideoError);

      // Initialize with error handling
      if (!mounted) return;

      await _videoPlayerController.initialize().catchError((error) {
        print('Error initializing video: $error');
        if (mounted) {
          setState(() {
            _error = 'Error loading video: $error';
          });
        }
        return null;
      });

      if (!mounted) return;

      if (_videoPlayerController.value.isInitialized) {
        setState(() {
          _isInitialized = true;
        });
        _videoPlayerController.setLooping(true);
        _videoPlayerController.play();
      }
    } catch (e) {
      print('Error in _initializeVideo: $e');
      if (mounted) {
        setState(() {
          _error = 'Error loading video: $e';
        });
      }
    }
  }

  @override
  void dispose() {
    print('Disposing video player');
    try {
      if (_videoPlayerController.value.isInitialized) {
        _videoPlayerController.pause();
      }
      _videoPlayerController.removeListener(_handleVideoError);
      _videoPlayerController.dispose();
    } catch (e) {
      print('Error disposing video player: $e');
    }
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
