// lib/screens/code_chat_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Import all our services, models, and prompts
import '../services/kolosal_api_service.dart';
import '../services/speech_to_text_service.dart';
import '../services/bluetooth_service.dart';
import '../services/agentic_ai_service.dart';
import '../models/chat_message.dart';
import '../models/agentic_response.dart';
import '../config/app_prompts.dart';

class CodeChatScreen extends StatelessWidget {
  const CodeChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1433), // Theme: Main BG
      appBar: AppBar(
        // Theme: AppBar Style
        title: Text('Astroid CodeCraft', style: GoogleFonts.titanOne()),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      // Since landscape is enforced, we use a Row
      body: Row(
        children: [
          // --- Left Panel: Code Editor ---
          Expanded(
            flex: 6, // 60% of the screen
            child: _CodeEditorPlaceholder(),
          ),

          // --- Right Panel: Chatbot ---
          Expanded(
            flex: 4, // 40% of the screen
            child: Container(
              decoration: BoxDecoration(
                // Theme: Panel BG
                color: const Color(0xFF1A244A),
                border: Border(
                  // Theme: Subtle border
                  left: BorderSide(color: Colors.blueGrey[700]!, width: 1),
                ),
              ),
              child: _ChatBotPanel(), // The chat logic is inside here
            ),
          ),
        ],
      ),
    );
  }
}

// --- Placeholder for the Code Editor ---

class _CodeEditorPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      color: const Color(0xFF0a122e), // Darker editor bg
      child: TextField(
        expands: true,
        maxLines: null,
        minLines: null,
        style: GoogleFonts.firaCode(fontSize: 14, color: Colors.white),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: '// Your robot code goes here...',
          hintStyle: GoogleFonts.firaCode(
            fontSize: 14,
            color: Colors.white70, // Theme: Subtitle/Hint text
          ),
        ),
      ),
    );
  }
}

// --- Chatbot Panel Widget (Contains all our chat logic) ---

class _ChatBotPanel extends StatefulWidget {
  @override
  _ChatBotPanelState createState() => _ChatBotPanelState();
}

class _ChatBotPanelState extends State<_ChatBotPanel> {
  // Services
  final KolosalApiService _apiService = KolosalApiService();
  final SpeechToTextService _sttService = SpeechToTextService();
  late final AgenticAIService _agenticService;

  // State Controllers
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounceTimer; // The inactivity timer

  // UI State
  bool _isProcessing = false; // Is the AI "typing"?
  bool _sttInitialized = false;

  // Local Context
  final List<ChatMessage> _chatHistory = [
    ChatMessage(
      text: AppPrompts.systemPrompt, // From our config file
      role: ChatRole.system,
    )
  ];

  @override
  void initState() {
    super.initState();
    
    // Initialize agentic service
    _agenticService = AgenticAIService(
      apiService: _apiService,
      bluetoothService: BluetoothService.instance,
    );
    
    _sttService.initialize().then((isReady) {
      if (!mounted) return;
      setState(() {
        _sttInitialized = isReady;
      });
    });
  }

  @override
  void dispose() {
    _sttService.dispose();
    _textController.dispose();
    _scrollController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _handleUserSubmit(String text) {
    if (text.trim().isEmpty) return;
    final userMessage = ChatMessage(
      text: text.trim(),
      role: ChatRole.user,
    );
    if (!mounted) return;
    setState(() {
      _chatHistory.add(userMessage);
      _textController.clear();
    });
    _scrollToBottom();
    _startDebounceTimer();
  }

  void _startDebounceTimer() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(Duration(seconds: 3), () {
      _getAiResponse();
    });
  }

  Future<void> _getAiResponse() async {
    if (_isProcessing ||
        _chatHistory.isEmpty ||
        _chatHistory.last.role != ChatRole.user) {
      return;
    }

    if (!mounted) return;
    setState(() {
      _isProcessing = true;
    });
    _scrollToBottom();

    final Future<void> minDelay = Future.delayed(Duration(milliseconds: 1500));
    
    // Use agentic service instead of direct API call
    final Future<AgenticResponse> agenticCall = () async {
      try {
        final context = List<ChatMessage>.from(_chatHistory);
        return await _agenticService.processMessage(
          _chatHistory.last.text,
          context,
        );
      } catch (e) {
        debugPrint("Error getting agentic AI response: $e");
        return AgenticResponse(
          message: "Sorry, I can't catch what you mean. Can you try again?",
        );
      }
    }();

    final List<dynamic> results = await Future.wait([agenticCall, minDelay]);
    final AgenticResponse agenticResponse = results[0] as AgenticResponse;

    if (!mounted) return;
    setState(() {
      // Add the AI response to chat history
      _chatHistory.add(ChatMessage(
        text: agenticResponse.message,
        role: ChatRole.ai,
      ));
      _isProcessing = false;
    });
    _scrollToBottom();

    if (!mounted) return;
    if (_chatHistory.last.role == ChatRole.user) {
      Timer(Duration(milliseconds: 500), _getAiResponse);
    }
  }

  void _handleVoiceInput() {
    if (!_sttInitialized) return;
    if (_sttService.isListening.value) {
      _sttService.stopListening();
    } else {
      _sttService.startListening(
        onResult: (finalText) {
          _handleUserSubmit(finalText);
        },
      );
    }
  }

  void _scrollToBottom() {
    Timer(Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Filter out the system prompt for display
    final displayedMessages =
    _chatHistory.where((msg) => msg.role != ChatRole.system).toList();

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: EdgeInsets.all(8),
            itemCount: displayedMessages.length + (_isProcessing ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == displayedMessages.length && _isProcessing) {
                return _buildTypingIndicator();
              }
              final message = displayedMessages[index];
              return _ChatBubble(message: message);
            },
          ),
        ),
        Divider(height: 1, color: Colors.blueGrey[700]),
        _buildTextInputArea(),
      ],
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          _ChatBubble(
            message: ChatMessage(text: "...", role: ChatRole.ai),
          ),
        ],
      ),
    );
  }

  Widget _buildTextInputArea() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Row(
        children: [
          IconButton(
            icon: ValueListenableBuilder<bool>(
              valueListenable: _sttService.isListening,
              builder: (context, isListening, _) {
                return Icon(
                  isListening ? Icons.stop_circle_outlined : Icons.mic_none_rounded,
                  color: const Color(0xFFA4F2FF),
                );
              },
            ),
            onPressed: _handleVoiceInput,
          ),
          Expanded(
            child: TextField(
              controller: _textController,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Chat with AstroidBot...",
                hintStyle: TextStyle(color: Colors.white70),
                border: InputBorder.none,
              ),
              onSubmitted: _handleUserSubmit,
            ),
          ),
          IconButton(
            icon: Icon(Icons.send, color: const Color(0xFFA4F2FF)), // Theme: Bright Icon
            onPressed: () => _handleUserSubmit(_textController.text),
          ),
        ],
      ),
    );
  }
}

// --- Chat Bubble Widget (Themed) ---

class _ChatBubble extends StatelessWidget {
  final ChatMessage message;
  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final bool isUser = message.role == ChatRole.user;
    return Container(
      margin: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
        isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser
                    ? const Color(0xFF4A7CFF)
                    : const Color(0xFF0F1D3C),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                message.text,
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}