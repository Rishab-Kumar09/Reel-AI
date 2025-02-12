import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ChatService {
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  final String _baseUrl = 'https://api.openai.com/v1/chat/completions';
  String? get _apiKey => dotenv.env['OPENAI_API_KEY'];

  Future<String> getAnswerFromTranscript(
      String transcript, String question) async {
    if (_apiKey == null) {
      throw Exception('OpenAI API key not found');
    }

    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
      },
      body: jsonEncode({
        'model': 'gpt-4-turbo-preview',
        'messages': [
          {
            'role': 'system',
            'content':
                '''You are a helpful assistant that answers questions about video transcripts.
            You should only answer questions based on the information provided in the transcript.
            If the answer cannot be found in the transcript, politely say so.
            Keep your answers concise and to the point.
            The following is the transcript of the video:
            
            $transcript'''
          },
          {
            'role': 'user',
            'content': question,
          }
        ],
        'temperature': 0.7,
        'max_tokens': 150,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['choices'][0]['message']['content'];
    } else {
      throw Exception('Failed to get answer from GPT: ${response.body}');
    }
  }
}
