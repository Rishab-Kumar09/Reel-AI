import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:flutter_firebase_app_new/core/theme/app_theme.dart';
import 'package:flutter_firebase_app_new/features/feed/data/services/transcription_service.dart';
import 'package:flutter_firebase_app_new/features/feed/data/models/video_model.dart';
import 'package:flutter_firebase_app_new/features/feed/presentation/widgets/loading_game.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:share_plus/share_plus.dart';

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
  String _currentQuality = 'high'; // Track current quality
  bool _isBuffering = false;
  bool _isGeneratingTranscript = false; // Add this
  String? _transcript; // Add this
  double _networkSpeed = 0;
  Timer? _speedCheckTimer;
  DateTime? _lastBufferTime;
  int _bufferCount = 0;
  static const int BUFFER_THRESHOLD = 3;
  static const Duration BUFFER_TIME_WINDOW = Duration(minutes: 1);
  double _bufferProgress = 0.0; // Add buffer progress tracking

  @override
  void initState() {
    super.initState();
    if (widget.shouldPreload) {
      _initializeVideo();
    }
    _startSpeedCheck();
  }

  void _startSpeedCheck() {
    _speedCheckTimer?.cancel();
    _speedCheckTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _checkNetworkSpeed();
    });
  }

  Future<void> _checkNetworkSpeed() async {
    try {
      final startTime = DateTime.now();
      final response =
          await http.get(Uri.parse('https://www.google.com/favicon.ico'));
      if (response.statusCode == 200) {
        final endTime = DateTime.now();
        final duration = endTime.difference(startTime);
        final speed = response.bodyBytes.length / duration.inSeconds;
        setState(() {
          _networkSpeed = speed;
        });
        _adjustQualityBasedOnNetwork(speed);
      }
    } catch (e) {
      print('Error checking network speed: $e');
    }
  }

  void _adjustQualityBasedOnNetwork(double speed) {
    // Speed thresholds in bytes per second
    const lowThreshold = 50 * 1024; // 50 KB/s
    const mediumThreshold = 200 * 1024; // 200 KB/s

    String newQuality;
    if (speed < lowThreshold) {
      newQuality = 'low';
    } else if (speed < mediumThreshold) {
      newQuality = 'medium';
    } else {
      newQuality = 'high';
    }

    if (newQuality != _currentQuality) {
      _switchQuality(newQuality);
    }
  }

  Future<void> _switchQuality(String newQuality) async {
    try {
      // Get video qualities from Firestore
      final videoName = widget.videoUrl.split('/').last.split('?').first;
      final qualitiesDoc = await FirebaseFirestore.instance
          .collection('video_qualities')
          .doc(videoName)
          .get();

      if (!qualitiesDoc.exists) return;

      final urls = Map<String, String>.from(qualitiesDoc.data()!['urls']);
      final newUrl = urls[newQuality];

      if (newUrl != null && newUrl != widget.videoUrl) {
        final currentPosition = _controller.value.position;
        final wasPlaying = _controller.value.isPlaying;

        // Initialize new controller
        final newController = VideoPlayerController.network(
          newUrl,
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
        );

        await newController.initialize();
        await newController.seekTo(currentPosition);
        if (wasPlaying) {
          await newController.play();
        }
        newController.setVolume(_isMuted ? 0 : 1);

        // Dispose old controller
        await _controller.dispose();

        setState(() {
          _controller = newController;
          _currentQuality = newQuality;
        });
      }
    } catch (e) {
      print('Error switching quality: $e');
    }
  }

  void _handleBuffering() {
    if (_controller.value.isBuffering) {
      setState(() {
        _isBuffering = true;
      });

      // Track buffer events
      final now = DateTime.now();
      if (_lastBufferTime != null &&
          now.difference(_lastBufferTime!) < BUFFER_TIME_WINDOW) {
        _bufferCount++;
        if (_bufferCount >= BUFFER_THRESHOLD) {
          // Too many buffers in short time, switch to lower quality
          _switchToLowerQuality();
          _bufferCount = 0;
        }
      } else {
        _bufferCount = 1;
      }
      _lastBufferTime = now;

      // Update buffer progress
      if (_controller.value.duration != Duration.zero) {
        final buffered = _controller.value.buffered;
        if (buffered.isNotEmpty) {
          final lastBufferedRange = buffered.last;
          setState(() {
            _bufferProgress = lastBufferedRange.end.inMilliseconds /
                _controller.value.duration.inMilliseconds;
          });
        }
      }
    } else {
      setState(() {
        _isBuffering = false;
      });
    }
  }

  void _switchToLowerQuality() {
    final qualities = ['high', 'medium', 'low'];
    final currentIndex = qualities.indexOf(_currentQuality);
    if (currentIndex < qualities.length - 1) {
      _switchQuality(qualities[currentIndex + 1]);
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

      // Try to get quality variants
      try {
        final videoName = videoUrl.split('/').last.split('?').first;
        final qualitiesDoc = await FirebaseFirestore.instance
            .collection('video_qualities')
            .doc(videoName)
            .get();

        if (qualitiesDoc.exists) {
          final urls = Map<String, String>.from(qualitiesDoc.data()!['urls']);
          // Start with appropriate quality based on network speed
          if (_networkSpeed > 0) {
            _adjustQualityBasedOnNetwork(_networkSpeed);
            final newUrl = urls[_currentQuality];
            if (newUrl != null) {
              print('Starting with ${_currentQuality} quality');
              _controller = VideoPlayerController.network(
                newUrl,
                videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
              );
            } else {
              _controller = VideoPlayerController.network(
                videoUrl,
                videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
              );
            }
          } else {
            _controller = VideoPlayerController.network(
              videoUrl,
              videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
            );
          }
        } else {
          _controller = VideoPlayerController.network(
            videoUrl,
            videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
          );
        }
      } catch (e) {
        print('Error getting quality variants: $e');
        _controller = VideoPlayerController.network(
          videoUrl,
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
        );
      }

      // Add listeners
      _controller.addListener(_handleVideoError);
      _controller.addListener(_handleBuffering);
      _controller.addListener(() {
        if (_controller.value.isPlaying && _showThumbnail && mounted) {
          setState(() {
            _showThumbnail = false;
          });
        }
      });

      // Initialize with progressive loading
      await _controller.initialize();

      // Set initial volume
      _controller.setVolume(1.0);
      _isMuted = false;
      widget.onMuteStateChanged?.call(_isMuted);

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _error = null;
          _isBuffering = false;
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
        _isBuffering = false;
      });
    }
  }

  @override
  void dispose() {
    _speedCheckTimer?.cancel();
    if (_isInitialized) {
      _controller.removeListener(_handleVideoError);
      _controller.removeListener(_handleBuffering);
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

  void _generateTranscript() async {
    if (_isGeneratingTranscript) return;

    setState(() {
      _isGeneratingTranscript = true;
    });

    try {
      // Show loading game in bottom sheet
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        isDismissible: false,
        backgroundColor: Colors.transparent,
        builder: (context) => DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) => Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 8, bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Text(
                  'Generating Transcript...',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Play this game while you wait!',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
                Expanded(
                  child: LoadingGame(
                    onTranscriptReady: () {
                      Navigator.of(context).pop();
                      _showTranscriptBottomSheet();
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      final transcriptionService = TranscriptionService();

      // First delete all existing transcripts
      await transcriptionService.deleteAllTranscripts();
      print('Deleted all existing transcripts');

      final videoId = widget.videoUrl.split('/').last.split('?').first;
      final video = VideoModel(
        id: videoId,
        videoUrl: widget.videoUrl,
        thumbnailUrl: widget.thumbnailUrl,
        title: 'Video',
        description: '',
        username: '',
        userId: '',
        category: 'general',
        createdAt: DateTime.now(),
        likes: 0,
        comments: 0,
        shares: 0,
        isVertical: widget.isVertical,
        topics: ['General'],
        skills: ['Content Creation'],
        difficultyLevel: 'beginner',
        duration: 0,
      );

      final newTranscript =
          await transcriptionService.generateTranscript(video);
      setState(() {
        _transcript = newTranscript;
      });

      if (!mounted) return;

      // Close game and show transcript
      Navigator.of(context).pop();
      _showTranscriptBottomSheet();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating transcript: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isGeneratingTranscript = false;
      });
    }
  }

  void _showTranscriptBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Video Transcript',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Regenerate button
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        tooltip: 'Regenerate transcript',
                        onPressed: () async {
                          try {
                            final transcriptionService = TranscriptionService();
                            final videoId = widget.videoUrl
                                .split('/')
                                .last
                                .split('?')
                                .first;

                            // Delete existing transcript
                            await transcriptionService
                                .deleteTranscript(videoId);

                            // Show loading indicator
                            setState(() {
                              _isGeneratingTranscript = true;
                              _transcript = null;
                            });

                            // Generate new transcript
                            final video = VideoModel(
                              id: videoId,
                              userId: '',
                              username: '',
                              videoUrl: widget.videoUrl,
                              thumbnailUrl: widget.thumbnailUrl,
                              title: '',
                              description: '',
                              category: 'general',
                              topics: [],
                              skills: [],
                              difficultyLevel: 'beginner',
                              duration: 0,
                              likes: 0,
                              comments: 0,
                              shares: 0,
                            );

                            final newTranscript = await transcriptionService
                                .generateTranscript(video);

                            if (!mounted) return;
                            setState(() {
                              _transcript = newTranscript;
                              _isGeneratingTranscript = false;
                            });

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content:
                                    Text('Transcript regenerated successfully'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } catch (e) {
                            setState(() {
                              _isGeneratingTranscript = false;
                            });
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content:
                                    Text('Error regenerating transcript: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                      ),
                      // Share button
                      IconButton(
                        icon: const Icon(Icons.share),
                        tooltip: 'Share transcript',
                        onPressed: () async {
                          try {
                            final transcriptionService = TranscriptionService();
                            final videoId = widget.videoUrl
                                .split('/')
                                .last
                                .split('?')
                                .first;
                            final transcript = await transcriptionService
                                .shareTranscript(videoId);

                            // Get temporary directory
                            final directory = await getTemporaryDirectory();
                            final file =
                                File('${directory.path}/transcript.txt');

                            // Write transcript to file
                            await file.writeAsString(transcript);

                            // Share the file
                            await Share.shareXFiles(
                              [XFile(file.path)],
                              text: 'Video Transcript',
                            );

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Share transcript'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } catch (e) {
                            // Fallback to clipboard if share fails
                            try {
                              await Clipboard.setData(
                                  ClipboardData(text: _transcript ?? ''));
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'Share failed, copied to clipboard instead'),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                            } catch (clipboardError) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error sharing transcript: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                      ),
                      // Delete button
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Delete transcript',
                        onPressed: () async {
                          try {
                            final transcriptionService = TranscriptionService();
                            final videoId = widget.videoUrl
                                .split('/')
                                .last
                                .split('?')
                                .first;

                            await transcriptionService
                                .deleteTranscript(videoId);
                            setState(() {
                              _transcript = null;
                            });
                            if (!mounted) return;

                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Transcript deleted'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error deleting transcript: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                      ),
                      // Close button
                      IconButton(
                        icon: const Icon(Icons.close),
                        tooltip: 'Close',
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Text(
                    _transcript ?? 'No transcript available',
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
            TextButton(
              onPressed: () {
                setState(() {
                  _error = null;
                  _initializeVideo();
                });
              },
              child: const Text('Retry', style: TextStyle(color: Colors.white)),
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
                            Stack(
                              fit: StackFit.expand,
                              children: [
                                CachedNetworkImage(
                                  imageUrl: widget.thumbnailUrl,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) =>
                                      const SizedBox(),
                                  errorWidget: (context, url, error) =>
                                      const SizedBox(),
                                ),
                                // Loading overlay
                                if (!_isInitialized || _isBuffering)
                                  Container(
                                    color: Colors.black.withOpacity(0.5),
                                    child: Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            _isBuffering
                                                ? 'Buffering...'
                                                : 'Loading video...',
                                            style: AppTheme.bodySmall.copyWith(
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
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
                          if (!_isInitialized && !_showThumbnail ||
                              _isBuffering)
                            const Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                              ),
                            ),
                          // Transcript button (adjusted position)
                          Positioned(
                            left: 16,
                            top:
                                80, // Changed from 16 to 80 to lower the position
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: GestureDetector(
                                onTap: _isGeneratingTranscript
                                    ? null
                                    : () => _generateTranscript(),
                                child: _isGeneratingTranscript
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.description,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                              ),
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
                            Stack(
                              fit: StackFit.expand,
                              children: [
                                CachedNetworkImage(
                                  imageUrl: widget.thumbnailUrl,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) =>
                                      const SizedBox(),
                                  errorWidget: (context, url, error) =>
                                      const SizedBox(),
                                ),
                                // Loading overlay
                                if (!_isInitialized || _isBuffering)
                                  Container(
                                    color: Colors.black.withOpacity(0.5),
                                    child: Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            _isBuffering
                                                ? 'Buffering...'
                                                : 'Loading video...',
                                            style: AppTheme.bodySmall.copyWith(
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
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
                          if (!_isInitialized && !_showThumbnail ||
                              _isBuffering)
                            const Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                              ),
                            ),
                          // Transcript button (adjusted position)
                          Positioned(
                            left: 16,
                            top:
                                80, // Changed from 16 to 80 to lower the position
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: GestureDetector(
                                onTap: _isGeneratingTranscript
                                    ? null
                                    : () => _generateTranscript(),
                                child: _isGeneratingTranscript
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.description,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                              ),
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

        // Combined Video Controls and Actions
        Positioned(
          right: 16,
          bottom: 100,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
            ],
          ),
        ),
      ],
    );
  }
}
