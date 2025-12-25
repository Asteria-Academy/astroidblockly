import 'dart:convert';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Bridges the Astroid Blockly WebView and the Flutter agentic AI flow.
class WorkspaceBridgeService {
  WorkspaceBridgeService._privateConstructor();
  static final WorkspaceBridgeService _instance =
      WorkspaceBridgeService._privateConstructor();
  static WorkspaceBridgeService get instance => _instance;

  InAppWebViewController? _controller;

  void register(InAppWebViewController controller) {
    _controller = controller;
  }

  void unregister(InAppWebViewController controller) {
    if (_controller == controller) {
      _controller = null;
    }
  }

  bool get isConnected => _controller != null;

  Future<String?> exportWorkspaceJson() async {
    final controller = _controller;
    if (controller == null) return null;
    final result = await controller.evaluateJavascript(
      source:
          "window.exportAgenticWorkspace ? window.exportAgenticWorkspace() : '{}';",
    );
    if (result is String) return result;
    return result?.toString();
  }

  Future<String?> exportCommandJson() async {
    final controller = _controller;
    if (controller == null) return null;
    final result = await controller.evaluateJavascript(
      source:
          "window.generateCodeForExecution ? window.generateCodeForExecution() : '[]';",
    );
    if (result is String) return result;
    return result?.toString();
  }

  Future<bool> applyWorkspaceJson(String workspaceJson) async {
    final controller = _controller;
    if (controller == null) return false;
    final encoded = jsonEncode(workspaceJson);
    final result = await controller.evaluateJavascript(
      source: """
        (function() {
          if (window.applyAgenticWorkspace) {
            return window.applyAgenticWorkspace($encoded);
          }
          return false;
        })();
      """,
    );
    return result == true;
  }
}
