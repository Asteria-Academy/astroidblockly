import 'package:astroid_code_craft/models/chat_message.dart';
import 'package:astroid_code_craft/screens/chat_test_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'services/speech_to_text_service.dart';
import 'services/kolosal_api_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Service Test',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: ConversationalChatPage(),
    );
  }
}

class TestPage extends StatefulWidget {
  const TestPage({super.key});

  @override
  _TestPageState createState() => _TestPageState();
}

class _TestPageState extends State<TestPage> {
  // 2. Create instances of your services
  final SpeechToTextService _sttService = SpeechToTextService();
  final KolosalApiService _apiService = KolosalApiService();

  // 3. State variables to manage the UI
  String _transcribedText = "Press the mic to start speaking...";
  String _aiResponse = "";
  String _errorMessage = "";
  bool _isLoading = false;
  bool _sttInitialized = false;

  @override
  void initState() {
    super.initState();
    // 4. Initialize the STT service
    _sttService.initialize().then((isReady) {
      if (isReady) {
        setState(() {
          _sttInitialized = true;
        });
        // Listen to live speech updates
        _sttService.lastWords.addListener(_onSpeechUpdated);
      } else {
        setState(() {
          _errorMessage = "Speech recognition failed to initialize.";
        });
      }
    });
  }

  @override
  void dispose() {
    _sttService.dispose();
    super.dispose();
  }

  /// Update the UI with live speech results
  void _onSpeechUpdated() {
    setState(() {
      _transcribedText = _sttService.lastWords.value;
    });
  }

  /// Main function to handle the voice-to-AI flow
  void _handleVoiceCommand() {
    if (!_sttInitialized) {
      setState(() {
        _errorMessage = "Speech service is not ready.";
      });
      return;
    }

    if (_sttService.isListening.value) {
      _sttService.stopListening();
    } else {
      // Clear old text
      setState(() {
        _transcribedText = "Listening...";
        _aiResponse = "";
        _errorMessage = "";
      });

      // Start listening. The onResult callback fires when speech is FINAL.
      _sttService.startListening(
        onResult: (finalText) {
          setState(() {
            _transcribedText = finalText;
            _isLoading = true; // Show loading spinner
          });
          // 5. Send the final text to the AI service
          _sendToAI(finalText);
        },
      );
    }
  }

  /// Send text to Kolosal and update the UI
  Future<void> _sendToAI(String text) async {
    try {
      final String response = await _apiService.getChatCompletion(text as List<ChatMessage>);
      setState(() {
        _aiResponse = response;
      });
    } catch (e) {
      setState(() {
        _errorMessage = "Error from AI: $e";
      });
    } finally {
      setState(() {
        _isLoading = false; // Hide loading spinner
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Flutter AI Service Test'),
      ),
      // --- BODY CHANGED TO LISTVIEW ---
      // We replace Column/Center with a ListView to make it scrollable.
      body: ListView(
        // Add padding around the whole scrollable area
        padding: const EdgeInsets.all(20.0),
        children: <Widget>[
          // --- Speech to Text Display ---
          Text(
            'You Said:',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _transcribedText,
              style: TextStyle(fontSize: 16),
            ),
          ),
          SizedBox(height: 30),

          // --- AI Response Display ---
          Text(
            'AI Responded:',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          SizedBox(height: 10),
          _buildAiResponseWidget(),

          // --- Error Display ---
          if (_errorMessage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 15.0),
              child: Text(
                _errorMessage,
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),

          // --- ADDED PADDING AT THE BOTTOM ---
          // This ensures the content can scroll up
          // from behind the FloatingActionButton.
          SizedBox(height: 100),
        ],
      ),
      // 6. The main "Record" button
      floatingActionButton: ValueListenableBuilder<bool>(
        valueListenable: _sttService.isListening,
        builder: (context, isListening, child) {
          return FloatingActionButton(
            onPressed: _handleVoiceCommand,
            tooltip: 'Listen',
            backgroundColor: isListening ? Colors.red : Colors.blue,
            child: Icon(isListening ? Icons.stop : Icons.mic),
          );
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  /// Helper widget to show loading or AI response
  Widget _buildAiResponseWidget() {
    if (_isLoading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _aiResponse.isEmpty ? "AI response will appear here..." : _aiResponse,
        style: TextStyle(fontSize: 16, fontStyle: _aiResponse.isEmpty ? FontStyle.italic : FontStyle.normal),
      ),
    );
  }
}