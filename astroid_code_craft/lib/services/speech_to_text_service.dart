import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';

class SpeechToTextService {
  final SpeechToText _speechToText = SpeechToText();
  bool _isInitialized = false;

  // Notifiers to update the UI
  final ValueNotifier<bool> isListening = ValueNotifier(false);
  final ValueNotifier<String> lastWords = ValueNotifier("");

  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      _isInitialized = await _speechToText.initialize(
        onError: (error) => print('STT Error: $error'),
        onStatus: (status) => _onStatusChanged(status),
      );
    } catch (e) {
      print("Could not initialize SpeechToText: $e");
      _isInitialized = false;
    }
    return _isInitialized;
  }

  /// Starts listening for speech.
  /// [onResult] is a callback that will be fired with the FINAL transcribed text.
  void startListening({required Function(String) onResult}) {
    if (!_isInitialized || isListening.value) return;

    lastWords.value = "";
    isListening.value = true;
    _speechToText.listen(
      onResult: (SpeechRecognitionResult result) {
        // Update live transcript
        lastWords.value = result.recognizedWords;

        // When listening is done, fire the callback and stop
        if (result.finalResult) {
          isListening.value = false;
          onResult(result.recognizedWords);
        }
      },
      listenFor: Duration(seconds: 30), // Max listen duration
      pauseFor: Duration(seconds: 5), // Time of silence before stopping
      localeId: "id_ID", // Change to your desired locale
    );
  }

  /// Manually stops the listening process.
  void stopListening() {
    if (!_isInitialized || !isListening.value) return;

    _speechToText.stop();
    isListening.value = false;
  }

  void _onStatusChanged(String status) {
    print('STT Status: $status');
    if (status == 'notListening' || status == 'done') {
      isListening.value = false;
    }
  }

  /// Disposes of the notifiers
  void dispose() {
    isListening.dispose();
    lastWords.dispose();
  }
}