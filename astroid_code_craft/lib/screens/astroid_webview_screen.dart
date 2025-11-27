// lib/screens/astroid_webview_screen.dart

import 'dart:convert';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../services/bluetooth_service.dart';
import '../services/preferences_service.dart';
import '../router/app_router.dart';
import './splash_gate.dart';
import '../utils/web_app_url.dart';

class AstroidWebViewScreen extends StatefulWidget {
  const AstroidWebViewScreen({super.key, required this.args});
  final Map<String, String> args;

  @override
  State<AstroidWebViewScreen> createState() => _AstroidWebViewScreenState();
}

class _AstroidWebViewScreenState extends State<AstroidWebViewScreen> {
  final BluetoothService _btService = BluetoothService.instance;
  InAppWebViewController? _webViewController;

  @override
  void initState() {
    super.initState();
    // Subscribe to sequencer state changes so we can forward them to the WebView.
    _btService.onSequencerStateChanged = _handleSequencerStateChange;
  }

  @override
  void dispose() {
    // Unsubscribe to avoid leaks.
    _btService.onSequencerStateChanged = null;
    super.dispose();
  }

  void _handleSequencerStateChange(SequencerState state) {
    if (_webViewController == null) return;
    final stateString = state.toString().split('.').last; // 'running' or 'idle'
    debugPrint('Forwarding sequencer state to WebView: $stateString');

    _webViewController!.evaluateJavascript(
      source:
          """
      if (window.updateSequencerState) {
        window.updateSequencerState('$stateString');
      }
    """,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!isServerRunning && !kIsWeb) {
      return const Scaffold(
        body: Center(child: Text("Error: Local web server is not running.")),
      );
    }

    final action = widget.args['action'] ?? 'new_project';
    final projectId = widget.args['id'] ?? '';
    final locale = Localizations.localeOf(context).languageCode;

    final initialUrl = buildWebAppUri(
      action: action,
      projectId: projectId,
      locale: locale,
    ).toString();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) return;
        _btService.stopSequence();
        Navigator.pushReplacementNamed(context, AppRoutes.home);
      },
      child: Scaffold(
        body: SafeArea(
          child: InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri(initialUrl)),
            initialUserScripts: UnmodifiableListView<UserScript>([
              UserScript(
                source: """
                  window.addEventListener('flutterInAppWebViewPlatformReady', function(event) {
                    window.astroidAppChannel = function(message) {
                      const messageString = typeof message === 'string' ? message : JSON.stringify(message);
                      window.flutter_inappwebview.callHandler('astroidAppChannel', messageString);
                    };
                  });
                """,
                injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
              ),
            ]),
            initialSettings: InAppWebViewSettings(
              mediaPlaybackRequiresUserGesture: false,
              javaScriptCanOpenWindowsAutomatically: true,
              isInspectable: kDebugMode,
              useHybridComposition: true,
            ),
            onWebViewCreated: (controller) {
              _webViewController = controller;
              controller.addJavaScriptHandler(
                handlerName: 'astroidAppChannel',
                callback: (args) {
                  final String message = args[0];
                  debugPrint("Message from WebView: $message");
                  try {
                    final decoded = jsonDecode(message);
                    if (decoded is List) {
                      if (!_btService.isConnected) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Robot not connected!"),
                            backgroundColor: Colors.redAccent,
                          ),
                        );
                        return;
                      }

                      String commandJsonToSend = message;

                      if (decoded.isNotEmpty && decoded[0] is List) {
                        debugPrint(
                          "Detected nested command array. Unwrapping...",
                        );
                        final List<dynamic> actualCommands = decoded[0];
                        commandJsonToSend = jsonEncode(actualCommands);
                      }

                      _btService.runCommandSequence(commandJsonToSend);
                    } else if (decoded is Map<String, dynamic>) {
                      if (decoded['event'] == 'show_bt_status') {
                        Navigator.pushNamed(context, AppRoutes.connect);
                      } else if (decoded['event'] == 'stop_code') {
                        _btService.stopSequence();
                      } else if (decoded['event'] == 'open_chat_ai') {
                        Navigator.pushReplacementNamed(
                          context,
                          AppRoutes.codeChat,
                        );
                      } else if (decoded['event'] == 'navigate_home') {
                        _btService.stopSequence();
                        Navigator.pushReplacementNamed(context, AppRoutes.home);
                      }
                    }
                  } catch (e) {
                    debugPrint(
                      'Error processing message from WebView: $e. Message was: $message',
                    );
                  }
                },
              );
            },
            onLoadStop: (controller, url) async {
              controller.evaluateJavascript(
                source:
                    "if (window.setViewMode) { window.setViewMode('blocks'); }",
              );

              // Apply saved volume setting to all audio/video elements
              final prefs = await PreferencesService.getInstance();
              final volume = prefs.getWebViewVolume();
              controller.evaluateJavascript(
                source:
                    """
                  (function() {
                    // Set volume for all existing audio/video elements
                    document.querySelectorAll('audio, video').forEach(function(el) {
                      el.volume = $volume;
                    });
                    
                    // Override HTMLMediaElement volume setter to apply to new elements
                    var originalAudioPlay = HTMLAudioElement.prototype.play;
                    HTMLAudioElement.prototype.play = function() {
                      this.volume = $volume;
                      return originalAudioPlay.apply(this, arguments);
                    };
                    
                    var originalVideoPlay = HTMLVideoElement.prototype.play;
                    HTMLVideoElement.prototype.play = function() {
                      this.volume = $volume;
                      return originalVideoPlay.apply(this, arguments);
                    };
                    
                    // Watch for new audio/video elements being added
                    var observer = new MutationObserver(function(mutations) {
                      mutations.forEach(function(mutation) {
                        mutation.addedNodes.forEach(function(node) {
                          if (node.tagName === 'AUDIO' || node.tagName === 'VIDEO') {
                            node.volume = $volume;
                          }
                        });
                      });
                    });
                    observer.observe(document.body, { childList: true, subtree: true });
                  })();
                """,
              );
            },
            onConsoleMessage: (controller, consoleMessage) {
              debugPrint(
                "WebView Console: [${consoleMessage.messageLevel}] ${consoleMessage.message}",
              );
            },
          ),
        ),
      ),
    );
  }
}
