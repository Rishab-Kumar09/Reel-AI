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
    try {
      // Load environment file if not already loaded
      if (dotenv.env.isEmpty) {
        dotenv.load(fileName: ".env");
      }
      _openAIKey = dotenv.env['OPENAI_API_KEY'] ?? '';
      if (_openAIKey.isEmpty) {
        throw Exception('OpenAI API key not found in .env file');
      }
      print(
          'TranscriptionService initialized successfully with API key length: ${_openAIKey.length}');
    } catch (e) {
      print('Error initializing TranscriptionService: $e');
      rethrow;
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
      print('Starting transcript generation for video: ${video.id}');

      // Check if transcript already exists
      final existingTranscript = await getTranscript(video.id);
      if (existingTranscript != null) {
        print('Found existing transcript for video: ${video.id}');
        return existingTranscript;
      }

      print('Downloading and processing video: ${video.videoUrl}');
      // 1. Download and process video in parallel chunks
      final videoChunks = await _downloadAndProcessVideo(video.videoUrl);
      print('Video processed into ${videoChunks.length} chunks');

      // 2. Get transcripts for all chunks in parallel
      print('Starting transcription of chunks');
      final transcriptFutures =
          videoChunks.map((chunk) => _getWhisperTranscript(chunk));
      final transcripts = await Future.wait(transcriptFutures);
      print('All chunks transcribed successfully');

      // 3. Combine transcripts
      final combinedTranscript = transcripts.join(' ');
      print('Combined transcript length: ${combinedTranscript.length}');

      // 4. Format with GPT based on category
      print('Formatting transcript with GPT');
      final formattedContent = await _formatWithGPT(
        combinedTranscript,
        video.category,
      );
      print('Transcript formatted successfully');

      // 5. Save to both Firestore and local cache
      print('Saving transcript to storage');
      await _saveTranscript(video.id, formattedContent);
      print('Transcript saved successfully');

      return formattedContent;
    } catch (e, stackTrace) {
      print('Error generating transcript: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<List<List<int>>> _downloadAndProcessVideo(String videoUrl) async {
    try {
      List<int> videoBytes;
      File? tempFile;
      File? compressedFile;

      // Check if the URL is a local file path
      if (videoUrl.startsWith('file://') || videoUrl.startsWith('/')) {
        final file = File(videoUrl.replaceFirst('file://', ''));
        tempFile = file;
      } else {
        // Download video from remote URL
        final response = await http.get(Uri.parse(videoUrl));
        if (response.statusCode != 200) {
          throw 'Failed to download video from URL';
        }

        // Save to temporary file
        final tempDir = await getTemporaryDirectory();
        tempFile = File(
            '${tempDir.path}/temp_video_${DateTime.now().millisecondsSinceEpoch}.mp4');
        await tempFile.writeAsBytes(response.bodyBytes);
      }

      print('Compressing video before transcription...');
      try {
        // Compress video with lower quality for transcription
        final MediaInfo? mediaInfo = await VideoCompress.compressVideo(
          tempFile.path,
          quality: VideoQuality.LowQuality, // Use low quality for transcription
          deleteOrigin: false,
          includeAudio: true, // Keep audio as we need it for transcription
        );

        if (mediaInfo?.file == null) {
          throw 'Video compression failed';
        }

        compressedFile = mediaInfo!.file!;
        print(
            'Video compressed successfully. Original size: ${tempFile.lengthSync()}, Compressed size: ${compressedFile.lengthSync()}');

        // Read compressed video bytes
        videoBytes = await compressedFile.readAsBytes();
      } catch (e) {
        print('Error compressing video: $e');
        print('Falling back to original video');
        videoBytes = await tempFile.readAsBytes();
      }

      // Process in parallel using compute
      final processedChunks = await compute(_processVideoChunks, {
        'videoBytes': videoBytes,
        'chunkSize': _chunkSize,
        'maxDuration': _maxAudioDuration,
      });

      // Cleanup
      if (compressedFile != null && await compressedFile.exists()) {
        await compressedFile.delete();
      }
      if (tempFile != null &&
          await tempFile.exists() &&
          !videoUrl.startsWith('file://') &&
          !videoUrl.startsWith('/')) {
        await tempFile.delete();
      }
      await VideoCompress.deleteAllCache();

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
      print('Preparing Whisper API request');
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

      print('Adding video data to request (${videoData.length} bytes)');
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          videoData,
          filename: 'chunk.mp4',
        ),
      );

      print('Sending request to Whisper API');
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print('Whisper API response status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final text = data['text'] as String;
        if (text.trim().isEmpty) {
          return "No clear speech detected in this segment. This may be a non-verbal video or contain only background sounds/music.";
        }
        print('Successfully got transcript of length: ${text.length}');
        return text;
      } else {
        print('Whisper API error response: ${response.body}');
        throw 'Failed to get transcript: ${response.statusCode} - ${response.body}';
      }
    } catch (e, stackTrace) {
      print('Error in Whisper API: $e');
      print('Stack trace: $stackTrace');
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
          'model': 'gpt-4-turbo-preview',
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
    // Base prompt that adapts based on video category
    if (category.toLowerCase().contains('education') ||
        category.toLowerCase().contains('tutorial') ||
        category.toLowerCase().contains('cooking') ||
        category.toLowerCase().contains('tech')) {
      return '''You are a video transcription assistant. Your task is to format the given transcript.
IMPORTANT RULES:
1. Only use information directly from the video transcript. DO NOT add any external information or general knowledge.
2. If something is unclear or missing from the transcript, do not fill in gaps with assumed information.
3. Use exact quotes from the video when possible.
4. Keep the original meaning and content intact.
5. Do not make assumptions or add explanations not mentioned in the video.

Format the transcript using these sections:

1. Summary
- Brief overview of what was actually shown/demonstrated in the video
- Keep it factual and based only on what was explicitly shown

2. Tools/Ingredients (if not mentioned)
- List only items/tools/ingredients specifically shown or mentioned in the video
- If none were mentioned, skip this section

3. Detailed Steps/Breakdown
- Chronological breakdown of what happens in the video
- Use timestamps if available
- Include exact quotes when relevant
- Focus on actions and demonstrations shown

4. Additional Notes (if relevant)
- Any specific tips, warnings, or important points explicitly mentioned
- Any unique aspects of the demonstration that were highlighted
- Skip this section if no additional points were made

Remember: Only include information that was explicitly shown or stated in the video. Do not add external knowledge or assumptions.''';
    } else {
      // For non-educational videos or videos with minimal speech
      return '''You are a video content assistant. Your task is to describe the content from the given transcript.
Even if there is minimal speech or unclear audio, try to format what you can understand.

Format the content using these sections:

1. Content Overview
- Brief description of what the video appears to be about
- If there's minimal speech, focus on any clear sounds, music, or ambient audio
- If the transcript is unclear or minimal, state that explicitly

2. Key Moments/Detailed steps
- Note any clear speech or significant sounds
- Include any understandable quotes or audio elements
- if any steps or points are mentioned in the video, include them in this section
- If minimal speech, just mention that and skip to next section

3. General Notes
- Any other relevant observations from the audio
- Mention if the audio is unclear, minimal, or missing in parts
- Note if this appears to be a non-verbal or music-focused video

Remember: Be honest about unclear or minimal audio. Don't make assumptions about content you can't clearly hear.
If the transcript is very minimal, it's okay to have a brief response focusing on what IS clear.''';
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

  Future<Map<String, String>> generateSocialPosts(String videoId,
      {String? existingTranscript}) async {
    try {
      // First check if posts already exist in Firestore
      final doc =
          await _firestore.collection('social_posts').doc(videoId).get();
      if (doc.exists) {
        final posts = doc.data();
        if (posts != null &&
            posts['twitter'] != null &&
            posts['linkedin'] != null &&
            posts['facebook'] != null) {
          return {
            'twitter': posts['twitter'] as String,
            'linkedin': posts['linkedin'] as String,
            'facebook': posts['facebook'] as String,
          };
        }
      }

      final transcript = existingTranscript ?? await getTranscript(videoId);
      if (transcript == null) {
        throw 'Transcript not found';
      }

      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer $_openAIKey',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'model': 'gpt-3.5-turbo',
          'messages': [
            {
              'role': 'system',
              'content':
                  '''You are a social media expert who creates engaging posts.
Your task is to create three versions of a social media post from a video transcript.
CRITICAL: DO NOT USE ANY EMOJIS OR SPECIAL CHARACTERS IN YOUR RESPONSE.

Format your response EXACTLY as follows:

Twitter Thread:
Create a thread (max 3 tweets) that captures the key points.
Each tweet should be on a new line, starting with a number and dash (1-, 2-, etc.).
Keep each tweet concise and impactful.
Use plain text only, no emojis or special characters.

LinkedIn Post:
Create a single professional yet engaging post.
Focus on professional insights and value.
Keep it under 200 words.
Use plain text only, no emojis or special characters.

Facebook Post:
Create a friendly, conversational post.
Keep it relatable and shareable.
Keep it under 200 words.
Use plain text only, no emojis or special characters.

Rules:
- ABSOLUTELY NO EMOJIS OR SPECIAL CHARACTERS
- Use only plain text and standard punctuation
- Use only information from the transcript
- Make each post engaging and shareable
- Include relevant hashtags (max 2 per post)
- Keep the tone matching the platform:
  * Twitter: Concise and impactful
  * LinkedIn: Professional and insightful
  * Facebook: Casual and conversational
- IMPORTANT: Always maintain the exact format with "Twitter Thread:", "LinkedIn Post:", and "Facebook Post:" headers'''
            },
            {
              'role': 'user',
              'content': transcript,
            },
          ],
          'temperature': 0.3,
          'max_tokens': 500,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final content = data['choices'][0]['message']['content'];

        // More robust parsing
        String twitterThread = '';
        String linkedInPost = '';
        String facebookPost = '';

        if (content.contains('Twitter Thread:') &&
            content.contains('LinkedIn Post:') &&
            content.contains('Facebook Post:')) {
          final parts = content.split('\n\n');
          for (int i = 0; i < parts.length; i++) {
            if (parts[i].startsWith('Twitter Thread:')) {
              twitterThread = _removeEmojis(
                  parts[i].replaceFirst('Twitter Thread:', '').trim());
            } else if (parts[i].startsWith('LinkedIn Post:')) {
              linkedInPost = _removeEmojis(
                  parts[i].replaceFirst('LinkedIn Post:', '').trim());
            } else if (parts[i].startsWith('Facebook Post:')) {
              facebookPost = _removeEmojis(
                  parts[i].replaceFirst('Facebook Post:', '').trim());
            }
          }
        } else {
          // Fallback if format is not exact
          final parts = content.split('\n\n');
          twitterThread = _removeEmojis(parts[0]);
          linkedInPost = parts.length > 1
              ? _removeEmojis(parts[1])
              : _removeEmojis(parts[0]);
          facebookPost = parts.length > 2
              ? _removeEmojis(parts[2])
              : _removeEmojis(parts[0]);
        }

        // Store the generated posts in Firestore
        await _firestore.collection('social_posts').doc(videoId).set({
          'twitter': twitterThread,
          'linkedin': linkedInPost,
          'facebook': facebookPost,
          'createdAt': FieldValue.serverTimestamp(),
        });

        return {
          'twitter': twitterThread,
          'linkedin': linkedInPost,
          'facebook': facebookPost,
        };
      } else {
        throw 'Failed to generate social posts: ${response.statusCode}';
      }
    } catch (e) {
      print('Error generating social posts: $e');
      rethrow;
    }
  }

  String _removeEmojis(String text) {
    // Remove emojis and other special characters
    return text
        .replaceAll(
            RegExp(
                r'[\u{1F300}-\u{1F9FF}]|[\u{2600}-\u{26FF}]|[\u{2700}-\u{27BF}]|[\u{1F000}-\u{1FAFF}]|[\u{FE00}-\u{FE0F}]',
                unicode: true),
            '')
        .replaceAll(RegExp(r'[^\x00-\x7F]+'), '') // Remove non-ASCII characters
        .replaceAll(RegExp(r'\s+'), ' ') // Clean up extra whitespace
        .trim();
  }
}
