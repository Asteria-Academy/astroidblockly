import 'dart:convert';
import 'dart:collection';
import 'package:astroid_test_webview_app/services/bluetooth_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../router/app_router.dart';

class AstroidWebViewScreen extends StatefulWidget {
  const AstroidWebViewScreen({
    super.key,
    required this.args,
  });

  final Map<String, String> args;

  @override
  State<AstroidWebViewScreen> createState() => _AstroidWebViewScreenState();
}

class _AstroidWebViewScreenState extends State<AstroidWebViewScreen> {
  final BluetoothService _btService = BluetoothService.instance;

   Future<void> _runCommandSequence(String commandJsonArray) async {
    if (_btService.connectionState != BluetoothConnectionState.connected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Robot not connected!"),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    try {
      final List<dynamic> commands = jsonDecode(commandJsonArray);
      debugPrint("--- Sending Command Sequence ---");

      for (var command in commands) {
        final String commandString = jsonEncode(command);
        await _btService.sendCommand(commandString);
        await Future.delayed(const Duration(milliseconds: 50));
      }

      debugPrint("--- Sequence Complete ---");
    } catch (e) {
      debugPrint("Error processing command sequence: $e");
    }
  }


  @override
  Widget build(BuildContext context) {
    final action = widget.args['action'] ?? 'new_project';
    final projectId = widget.args['id'] ?? '';
    final initialUrl = "http://localhost:8080/web_build/index.html?action=$action&id=$projectId";
    
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) return;

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
                    // This is the primary communication channel from WebView to Flutter
                    window.astroidAppChannel = function(message) {
                      window.flutter_inappwebview.callHandler('astroidAppChannel', message);
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
            ),
            onWebViewCreated: (controller) {
              controller.addJavaScriptHandler(
                handlerName: 'astroidAppChannel',
                callback: (args) {
                  final message = args[0] as String;
                  debugPrint("Message from WebView: $message");

                  try {
                    final Map<String, dynamic> data = jsonDecode(message);
                    if (data.containsKey('event') && data['event'] == 'show_bt_status') {
                      Navigator.pushNamed(context, AppRoutes.connect);
                    }
                  } catch (e) {
                    _runCommandSequence(message);
                  }
                },
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