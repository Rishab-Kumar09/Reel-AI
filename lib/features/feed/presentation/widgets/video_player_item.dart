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
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/rendering.dart';
import 'package:flutter_firebase_app_new/features/feed/presentation/widgets/transcript_chat.dart';
import 'package:flutter_firebase_app_new/features/feed/presentation/widgets/quiz_bottom_sheet.dart';
import 'package:get/get.dart';

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
  // Add static map for transcript cache
  static final Map<String, String> _transcriptCache = {};

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

  // Add method to get cached transcript
  String? _getCachedTranscript() {
    final videoId = widget.videoUrl.split('/').last.split('?').first;
    return _transcriptCache[videoId];
  }

  // Add method to cache transcript
  void _cacheTranscript(String transcript) {
    final videoId = widget.videoUrl.split('/').last.split('?').first;
    _transcriptCache[videoId] = transcript;
  }

  // Add method to clear cache
  void _clearTranscriptCache() {
    final videoId = widget.videoUrl.split('/').last.split('?').first;
    _transcriptCache.remove(videoId);
  }

  // Replace _generateTranscript with _fetchTranscript
  void _fetchTranscript() async {
    if (_isGeneratingTranscript) return;

    try {
      // Extract the video filename from the URL
      final videoFileName = widget.videoUrl.split('/').last.split('?').first;

      // Get the video document from Firestore to get the actual document ID
      final videoQuery = await FirebaseFirestore.instance
          .collection('videos')
          .where('videoUrl', isGreaterThanOrEqualTo: widget.videoUrl)
          .where('videoUrl', isLessThanOrEqualTo: widget.videoUrl + '\uf8ff')
          .get();

      if (videoQuery.docs.isEmpty) {
        throw 'Video document not found';
      }

      final videoId = videoQuery.docs.first.id;
      final transcriptionService = TranscriptionService();

      setState(() {
        _isGeneratingTranscript = true;
      });

      // First check Firestore
      final existingTranscript =
          await transcriptionService.getTranscript(videoId);
      if (existingTranscript != null) {
        setState(() {
          _transcript = existingTranscript;
        });
        _showTranscriptBottomSheet(_transcript!);
        return;
      }

      // Check cache next
      final cachedTranscript = _getCachedTranscript();
      if (cachedTranscript != null) {
        setState(() {
          _transcript = cachedTranscript;
        });
        _showTranscriptBottomSheet(_transcript!);
        return;
      }

      // If no transcript found
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No transcript available for this video'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error fetching transcript: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isGeneratingTranscript = false;
      });
    }
  }

  // Update the transcript bottom sheet UI to remove delete and close buttons
  void _showTranscriptBottomSheet(String transcript) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (context, scrollController) => TranscriptChat(
          transcript: transcript,
          videoId: VideoModel.getVideoIdFromUrl(widget.videoUrl),
        ),
      ),
    );
  }

  Future<File> _generatePdf(String transcript, String fileName) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(
                level: 0,
                child: pw.Text('Video Transcript',
                    style: pw.TextStyle(fontSize: 24)),
              ),
              pw.SizedBox(height: 20),
              pw.Text(transcript),
            ],
          );
        },
      ),
    );

    final output = await getApplicationDocumentsDirectory();
    final file = File('${output.path}/$fileName');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  // Add this method
  void _showQuiz() async {
    try {
      final videoFileName = widget.videoUrl.split('/').last.split('?').first;
      final videoQuery = await FirebaseFirestore.instance
          .collection('videos')
          .where('videoUrl', isGreaterThanOrEqualTo: widget.videoUrl)
          .where('videoUrl', isLessThanOrEqualTo: widget.videoUrl + '\uf8ff')
          .get();

      if (videoQuery.docs.isEmpty) {
        throw 'Video document not found';
      }

      final videoId = videoQuery.docs.first.id;
      final transcriptionService = TranscriptionService();

      // Show loading indicator
      Get.dialog(
        const Center(
          child: CircularProgressIndicator(),
        ),
        barrierDismissible: false,
      );

      final quiz = await transcriptionService.generateQuiz(videoId);

      // Close loading dialog
      Get.back();

      if (quiz == null) {
        // No quiz available for this content
        Get.snackbar(
          'Quiz Not Available',
          'This video doesn\'t have enough educational content for a quiz.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
          colorText: AppTheme.primaryColor,
        );
        return;
      }

      if (!mounted) return;

      // Show quiz bottom sheet
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          builder: (context, scrollController) => QuizBottomSheet(
            quiz: quiz,
          ),
        ),
      );
    } catch (e) {
      Get.back(); // Close loading dialog if error occurs
      Get.snackbar(
        'Error',
        'Failed to load quiz: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppTheme.errorColor.withOpacity(0.1),
        colorText: AppTheme.errorColor,
      );
    }
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
                            child: Row(
                              children: [
                                // Transcript button
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: GestureDetector(
                                    onTap: _isGeneratingTranscript
                                        ? null
                                        : () => _fetchTranscript(),
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
                                const SizedBox(width: 8),
                                // Quiz button
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: GestureDetector(
                                    onTap: _showQuiz,
                                    child: const Icon(
                                      Icons.quiz,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ],
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
                            child: Row(
                              children: [
                                // Transcript button
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: GestureDetector(
                                    onTap: _isGeneratingTranscript
                                        ? null
                                        : () => _fetchTranscript(),
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
                                const SizedBox(width: 8),
                                // Quiz button
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: GestureDetector(
                                    onTap: _showQuiz,
                                    child: const Icon(
                                      Icons.quiz,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ],
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
