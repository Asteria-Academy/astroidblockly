import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

final InAppLocalhostServer localhostServer = InAppLocalhostServer(
  port: 8080,
  documentRoot: 'assets',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await localhostServer.start();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: AstroidWebViewScreen(),
    );
  }
}

class AstroidWebViewScreen extends StatefulWidget {
  const AstroidWebViewScreen({super.key});

  @override
  State<AstroidWebViewScreen> createState() => _AstroidWebViewScreenState();
}

class _AstroidWebViewScreenState extends State<AstroidWebViewScreen> {
  // InAppWebViewController? _webViewController; // <-- DELETE THIS LINE

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: InAppWebView(
          initialUrlRequest: URLRequest(url: WebUri("http://localhost:8080/index.html")),
          initialSettings: InAppWebViewSettings(
            mediaPlaybackRequiresUserGesture: false,
            javaScriptCanOpenWindowsAutomatically: true,
            isInspectable: kDebugMode,
          ),
          onWebViewCreated: (controller) {

            controller.addJavaScriptHandler(
              handlerName: 'Print',
              callback: (args) {
                debugPrint("Message from WebView: ${args[0]}");
              },
            );
          },
          onConsoleMessage: (controller, consoleMessage) {
            debugPrint("WebView Console: [${consoleMessage.messageLevel}] ${consoleMessage.message}");
          },
        ),
      ),
    );
  }
}