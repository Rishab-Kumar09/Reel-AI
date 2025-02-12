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

class TranscriptionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late final String _openAIKey;
  static const int _maxAudioDuration = 60; // Maximum audio duration in seconds
  static const int _chunkSize =
      25 * 1024 * 1024; // 25MB chunks for parallel processing

  TranscriptionService() {
    _openAIKey = dotenv.env['OPENAI_API_KEY'] ?? '';
    if (_openAIKey.isEmpty) {
      throw Exception('OpenAI API key not found in .env file');
    }
  }

  Future<String?> getTranscript(String videoId) async {
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
    try {
      // Check if transcript already exists
      final existingTranscript = await getTranscript(video.id);
      if (existingTranscript != null) return existingTranscript;

      // 1. Download and process video in parallel chunks
      final videoChunks = await _downloadAndProcessVideo(video.videoUrl);

      // 2. Get transcripts for all chunks in parallel
      final transcriptFutures =
          videoChunks.map((chunk) => _getWhisperTranscript(chunk));
      final transcripts = await Future.wait(transcriptFutures);

      // 3. Combine transcripts
      final combinedTranscript = transcripts.join(' ');

      // 4. Format with GPT based on category (using a more efficient prompt)
      final formattedContent = await _formatWithGPT(
        combinedTranscript,
        video.category,
      );

      // 5. Save to both Firestore and local cache
      await _saveTranscript(video.id, formattedContent);

      return formattedContent;
    } catch (e) {
      print('Error generating transcript: $e');
      rethrow;
    }
  }

  Future<List<List<int>>> _downloadAndProcessVideo(String videoUrl) async {
    try {
      // Download video in chunks
      final response = await http.get(Uri.parse(videoUrl));
      if (response.statusCode != 200) {
        throw 'Failed to download video from URL';
      }

      final videoBytes = response.bodyBytes;
      final chunks = <List<int>>[];

      // Process in parallel using compute
      final processedChunks = await compute(_processVideoChunks, {
        'videoBytes': videoBytes,
        'chunkSize': _chunkSize,
        'maxDuration': _maxAudioDuration,
      });

      return processedChunks;
    } catch (e) {
      print('Error processing video: $e');
      await VideoCompress.deleteAllCache();
      rethrow;
    }
  }

  static Future<List<List<int>>> _processVideoChunks(
      Map<String, dynamic> params) async {
    final videoBytes = params['videoBytes'] as List<int>;
    final chunkSize = params['chunkSize'] as int;
    final chunks = <List<int>>[];

    for (var i = 0; i < videoBytes.length; i += chunkSize) {
      final end = (i + chunkSize < videoBytes.length)
          ? i + chunkSize
          : videoBytes.length;
      chunks.add(videoBytes.sublist(i, end));
    }

    return chunks;
  }

  Future<String> _getWhisperTranscript(List<int> videoData) async {
    try {
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
        http.MultipartFile.fromBytes(
          'file',
          videoData,
          filename: 'chunk.mp4',
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['text'];
      } else {
        throw 'Failed to get transcript: ${response.statusCode} - ${response.body}';
      }
    } catch (e) {
      print('Error in Whisper API: $e');
      rethrow;
    }
  }

  Future<String> _formatWithGPT(String transcript, String category) async {
    try {
      // Use a more efficient system prompt based on category
      final systemPrompt = _getOptimizedPrompt(category);

      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer $_openAIKey',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'model': 'gpt-4o',
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {
              'role': 'user',
              'content': transcript,
            },
          ],
          'temperature': 0.2,
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

  String _getOptimizedPrompt(String category) {
    // Simplified and optimized prompts for each category
    switch (category.toLowerCase()) {
      case 'programming':
      case 'tech':
        return '''Format as: Summary, Prerequisites, Steps (with code), Key Points''';
      case 'cooking':
      case 'recipe':
        return '''Format as: Overview, Ingredients, Steps, Tips''';
      case 'education':
      case 'history':
      case 'science':
        return '''Format as: Topic, Key Points, Detailed Breakdown''';
      case 'fitness':
      case 'workout':
        return '''Format as: Type, Exercises, Safety Tips''';
      default:
        return '''Format as: Overview, Main Points, Details''';
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
