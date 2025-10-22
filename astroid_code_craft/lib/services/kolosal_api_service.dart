import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/chat_message.dart';

class KolosalApiService {

  final String _baseUrl = 'https://api.kolosal.ai';
  final String _apiKey = dotenv.env['KOLOSAL_API_KEY'] ?? 'API_KEY_NOT_FOUND';

  String _roleToString(ChatRole role) {
    switch (role) {
      case ChatRole.user:
        return 'user';
      case ChatRole.ai:
        return 'assistant';
      case ChatRole.system:
        return 'system';
    }
  }

  /// --- THIS FUNCTION IS UPGRADED ---
  /// It now accepts a List<ChatMessage> instead of a single String
  Future<String> getChatCompletion(List<ChatMessage> history) async {

    if (_apiKey == 'API_KEY_NOT_FOUND') {
      throw Exception('API Key not found in .env file');
    }

    final Uri apiUrl = Uri.parse('$_baseUrl/v1/chat/completions');

    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $_apiKey',
    };

    // 2. Convert your List<ChatMessage> into the OpenAI format
    final List<Map<String, String>> messages = history
        .map((msg) => {
          'role': _roleToString(msg.role),
          'content': msg.text,
        })
        .toList();

    final body = json.encode({
      'model': 'moonshotai/kimi-k2-0905', // Remember to change this
      'messages': messages, // <-- 3. Send the full history
      'temperature': 0.7,
    });

    try {
      final response = await http.post(
        apiUrl,
        headers: headers,
        body: body,
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(utf8.decode(response.bodyBytes));
        final String aiText = jsonResponse['choices'][0]['message']['content'];
        return aiText.trim();
      } else {
        throw Exception(
          'Failed to load response (Code ${response.statusCode}): ${response.body}',
        );
      }
    } on SocketException {
      throw Exception(
        'Failed to connect to the server. Is the server running and the URL correct?',
      );
    } catch (e) {
      throw Exception('An unknown error occurred: $e');
    }
  }
}