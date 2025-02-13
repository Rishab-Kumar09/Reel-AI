import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_firebase_app_new/features/feed/data/models/video_model.dart';
import 'package:video_compress/video_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:async';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

class TranscriptionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late final String _openAIKey;
  static const int _maxAudioDuration = 60; // Maximum audio duration in seconds
  static const int _chunkSize = 10 * 1024 * 1024; // 10MB chunks for Whisper API
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 2);

  TranscriptionService() {
    _initializeApiKey();
  }

  void _initializeApiKey() {
    _openAIKey = dotenv.env['OPENAI_API_KEY'] ?? '';
    if (_openAIKey.isEmpty) {
      print('Warning: OpenAI API key not found in .env file');
    }
  }

  bool get isApiKeyValid => _openAIKey.isNotEmpty;

  Future<String?> getTranscript(String videoId) async {
    if (!isApiKeyValid) {
      throw Exception(
          'OpenAI API key not found or invalid. Please check your configuration.');
    }

    try {
      // Check cache first
      final cacheDir = await getTemporaryDirectory();
      final cacheFile = File('${cacheDir.path}/transcript_$videoId.txt');

      if (await cacheFile.exists()) {
        return await cacheFile.readAsString();
      }

      final doc = await _firestore.collection('transcripts').doc(videoId).get();
      if (doc.exists) {
        final content = doc.data()?['content'] as String?;
        // Cache the result
        if (content != null) {
          await cacheFile.writeAsString(content);
        }
        return content;
      }
      return null;
    } catch (e) {
      print('Error getting transcript: $e');
      return null;
    }
  }

  Future<String> generateTranscript(VideoModel video) async {
    if (!isApiKeyValid) {
      throw Exception(
          'OpenAI API key not found or invalid. Please check your configuration.');
    }

    try {
      // Check if transcript already exists
      final existingTranscript = await getTranscript(video.id);
      if (existingTranscript != null) return existingTranscript;

      // Download video and send directly to Whisper
      final transcript = await _processVideoAndGetTranscript(video.videoUrl);

      // Format with GPT based on category
      final formattedContent = await _formatWithGPTWithRetry(
        transcript,
        video.category,
      );

      // Save to both Firestore and local cache
      await _saveTranscript(video.id, formattedContent);

      return formattedContent;
    } catch (e) {
      print('Error generating transcript: $e');
      rethrow;
    }
  }

  Future<String> _processVideoAndGetTranscript(String videoUrl) async {
    try {
      // Create a temporary file for the video
      final tempDir = await getTemporaryDirectory();
      final videoFile = File('${tempDir.path}/temp_video.mp4');

      // Download video
      final response = await http.get(Uri.parse(videoUrl));
      if (response.statusCode != 200) {
        throw 'Failed to download video from URL';
      }

      await videoFile.writeAsBytes(response.bodyBytes);

      try {
        // Compress video for Whisper
        print('Compressing video for transcription...');
        final MediaInfo? compressedVideo = await VideoCompress.compressVideo(
          videoFile.path,
          quality: VideoQuality
              .LowQuality, // Use low quality since we only need audio
          deleteOrigin: false,
          includeAudio: true,
          frameRate: 1, // Minimum frame rate since we only need audio
        );

        if (compressedVideo?.file == null) {
          throw 'Failed to compress video';
        }

        final compressedFile = compressedVideo!.file!;
        final compressedSize = await compressedFile.length();
        print('Compressed video size: ${compressedSize / (1024 * 1024)}MB');

        // Check compressed file size
        if (compressedSize > 25 * 1024 * 1024) {
          throw 'Video file is too large even after compression. Maximum size allowed is 25MB.';
        }

        // Send to Whisper API
        var request = http.MultipartRequest(
          'POST',
          Uri.parse('https://api.openai.com/v1/audio/transcriptions'),
        );

        request.headers.addAll({
          'Authorization': 'Bearer $_openAIKey',
        });

        request.fields['model'] = 'whisper-1';
        request.fields['language'] = 'en';
        request.fields['response_format'] = 'json';
        request.fields['temperature'] = '0.1';

        request.files.add(
          await http.MultipartFile.fromPath(
            'file',
            compressedFile.path,
            filename: 'video.mp4',
          ),
        );

        final streamedResponse = await request.send();
        final apiResponse = await http.Response.fromStream(streamedResponse);

        if (apiResponse.statusCode == 200) {
          final data = json.decode(apiResponse.body);
          return data['text'];
        } else {
          print('Whisper API error response: ${apiResponse.body}');
          throw 'Failed to get transcript: ${apiResponse.statusCode} - ${apiResponse.body}';
        }
      } finally {
        // Clean up temp files
        try {
          await videoFile.delete();
          await VideoCompress.deleteAllCache();
        } catch (e) {
          print('Warning: Failed to delete temporary files: $e');
        }
      }
    } catch (e) {
      print('Error processing video: $e');
      await VideoCompress.deleteAllCache();
      rethrow;
    }
  }

  Future<String> _formatWithGPTWithRetry(
      String transcript, String category) async {
    int retryCount = 0;
    while (retryCount < _maxRetries) {
      try {
        return await _formatWithGPT(transcript, category);
      } catch (e) {
        retryCount++;
        if (retryCount == _maxRetries) {
          rethrow;
        }
        print('Retrying GPT API call (${retryCount}/${_maxRetries})');
        await Future.delayed(_retryDelay * retryCount);
      }
    }
    throw Exception('Failed to format transcript after $_maxRetries retries');
  }

  String _getOptimizedPrompt(String category) {
    return '''You are a transcript formatter. Your task is to format the given video transcript into a clear, readable structure.
IMPORTANT: Only use information that is explicitly mentioned in the transcript. DO NOT add any external knowledge or assumptions.
If something is unclear or ambiguous in the transcript, preserve that ambiguity rather than making assumptions.

Format the transcript maintaining these principles:
1. Organize the content in a logical sequence as presented in the video
2. Break into relevant sections based on topic changes in the video
3. Use timestamps if they are available in the transcript
4. Preserve exact quotes and technical terms as they appear in the video
5. Do not add any explanations or context that wasn't explicitly stated in the video

Remember: Your role is purely organizational - do not enhance, explain, or add to the video's content.''';
  }

  Future<String> _formatWithGPT(String transcript, String category) async {
    try {
      final systemPrompt = _getOptimizedPrompt(category);

      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer $_openAIKey',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'model': 'gpt-4-turbo-preview',
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {
              'role': 'user',
              'content': '''Here is the raw transcript to format:

$transcript

Remember: Only use information from this transcript. Do not add any external knowledge or explanations.'''
            },
          ],
          'temperature':
              0.1, // Lower temperature for more consistent, literal output
          'max_tokens': 4000,
          'frequency_penalty': 0.0,
          'presence_penalty': 0.0,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['choices'][0]['message']['content'];
      } else {
        throw 'Failed to format transcript: ${response.statusCode} - ${response.body}';
      }
    } catch (e) {
      print('Error in GPT API: $e');
      rethrow;
    }
  }

  Future<void> _saveTranscript(String videoId, String content) async {
    try {
      // Save to Firestore
      await _firestore.collection('transcripts').doc(videoId).set({
        'content': content,
        'createdAt': FieldValue.serverTimestamp(),
        'format': 'markdown',
        'version': 3,
      });

      // Cache locally
      final cacheDir = await getTemporaryDirectory();
      final cacheFile = File('${cacheDir.path}/transcript_$videoId.txt');
      await cacheFile.writeAsString(content);
    } catch (e) {
      print('Error saving transcript: $e');
      rethrow;
    }
  }

  Future<void> deleteAllTranscripts() async {
    try {
      // Delete from Firestore
      final QuerySnapshot transcripts =
          await _firestore.collection('transcripts').get();
      final batch = _firestore.batch();
      for (var doc in transcripts.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      // Clear local cache
      final cacheDir = await getTemporaryDirectory();
      final cacheFiles = await cacheDir
          .list()
          .where((entity) => entity.path.contains('transcript_'))
          .toList();
      for (var file in cacheFiles) {
        await file.delete();
      }

      print('All transcripts deleted successfully');
    } catch (e) {
      print('Error deleting transcripts: $e');
      rethrow;
    }
  }

  Future<String> shareTranscript(String videoId) async {
    final transcript = await getTranscript(videoId);
    if (transcript == null) {
      throw 'Transcript not found';
    }
    return transcript;
  }

  Future<void> deleteTranscript(String videoId) async {
    try {
      // Delete from Firestore
      await _firestore.collection('transcripts').doc(videoId).delete();

      // Delete from local cache
      final cacheDir = await getTemporaryDirectory();
      final cacheFile = File('${cacheDir.path}/transcript_$videoId.txt');
      if (await cacheFile.exists()) {
        await cacheFile.delete();
      }

      print('Transcript deleted successfully');
    } catch (e) {
      print('Error deleting transcript: $e');
      rethrow;
    }
  }
}
