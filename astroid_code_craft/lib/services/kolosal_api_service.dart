import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';

class KolosalApiService {

  final String _baseUrl = 'https://api.kolosal.ai';

  // ** ⚠️ NEVER hardcode API keys in a real app. **
  // Load this from a secure place (like flutter_dotenv).
  final String _apiKey = 'kol_live_kXWm7H2oJ37I-zpPplpD96j4A5bd611k';

  /// Fetches a chat completion from the Kolosal AI API.
  ///
  /// [userText] is the text transcript from the speech-to-text conversion.
  Future<String> getChatCompletion(String userText) async {
    final Uri apiUrl = Uri.parse('$_baseUrl/v1/chat/completions');

    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $_apiKey',
    };

    final body = json.encode({
      'model': 'moonshotai/kimi-k2-0905',
      'messages': [
        {'role': 'user', 'content': userText}
      ],
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

        // This is the standard path for the text response
        final String aiText = jsonResponse['choices'][0]['message']['content'];
        return aiText.trim();
      } else {
        // Throw a specific error with the API's message
        throw Exception(
          'Failed to load response (Code ${response.statusCode}): ${response.body}',
        );
      }
    } on SocketException {
      throw Exception(
        'Failed to connect to the server. Is the server running and the URL correct?',
      );
    } catch (e) {
      // Re-throw any other errors
      throw Exception('An unknown error occurred: $e');
    }
  }
}