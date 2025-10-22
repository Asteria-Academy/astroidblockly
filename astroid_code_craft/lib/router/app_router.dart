// lib/router/app_router.dart
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;

// === Import halamanmu ===
import '../screens/splash_gate.dart';
import '../screens/home_screen.dart';
// import '../screens/settings_page.dart';
import '../screens/astroid_webview_screen.dart';
import '../screens/mission_control_screen.dart';
import '../screens/connect_screen.dart';
import '../screens/connecting_screen.dart';
import '../models/project.dart';
import '../screens/code_chat_screen.dart';

/// Kumpulan nama route supaya konsisten & mudah diubah
class AppRoutes {
  static const splash = '/splash';
  static const home = '/home';
  static const settings = '/settings';
  static const webview = '/webview';
  static const missionControl = '/mission-control';
  static const connect = '/connect';
  static const connecting = '/connecting';

  // --- ADD THE NEW ROUTE ---
  static const codeChat = '/code-chat';
}

/// Router utama: hubungkan name → page
Route<dynamic> onGenerateRoute(RouteSettings settings) {
  switch (settings.name) {
    case AppRoutes.splash:
      return _page(const SplashGate());

    case AppRoutes.home:
      return _page(const HomeScreen());

    case AppRoutes.webview:
      final args = settings.arguments as Map<String, String>? ?? {'action': 'new_project'};
      return _page(AstroidWebViewScreen(args: args));

    case AppRoutes.missionControl:
      final args = settings.arguments as Map<String, dynamic>;
      final projects = args['projects'] as List<Project>;
      final controller = args['controller'] as InAppWebViewController?;
      return _page(MissionControlScreen(projects: projects, controller: controller));

    case AppRoutes.connect:
      return _page(const ConnectScreen());

    case AppRoutes.connecting:
      final device = settings.arguments as fbp.BluetoothDevice;
      return _page(ConnectingScreen(device: device));

  // --- ADD THE NEW CASE ---
    case AppRoutes.codeChat:
      return _page(const CodeChatScreen());

    default:
      return _notFound(settings.name);
  }
}

/// Helper bikin MaterialPageRoute singkat
MaterialPageRoute _page(Widget child) =>
    MaterialPageRoute(builder: (_) => child);

/// Route not found
Route<dynamic> _notFound(String? name) =>
    MaterialPageRoute(builder: (_) => const HomeScreen());