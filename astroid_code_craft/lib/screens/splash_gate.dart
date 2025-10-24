import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../router/app_router.dart';
import '../services/background_music_service.dart';

// A flag to easily turn the on-screen logs on or off.
// SET THIS TO 'false' BEFORE BUILDING THE FINAL APK FOR YOUR FRIEND.
const bool _showDebugLogs = false;
bool isServerRunning = false;

final InAppLocalhostServer localhostServer = InAppLocalhostServer(
  port: 8080,
  documentRoot: 'assets',
);

class SplashGate extends StatefulWidget {
  const SplashGate({super.key});
  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> with TickerProviderStateMixin {
  late final AnimationController _progressCtl;
  late final AnimationController _meteorCtl;
  final List<String> _logs = [];

  // Helper method to add a log and update the UI
  void _log(String message) {
    if (mounted) {
      setState(() {
        final timestamp = DateTime.now()
            .toIso8601String()
            .split('T')
            .last
            .substring(0, 8);
        _logs.add('[$timestamp] $message');
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _progressCtl =
        AnimationController(
          vsync: this,
          duration: const Duration(seconds: 3),
        )..addStatusListener((s) {
          if (s == AnimationStatus.completed) {
            _log(
              "Animation completed. Starting background music and navigating to home.",
            );

            // Start background music
            BackgroundMusicService().startBackgroundMusic();

            if (!mounted) return;
            Navigator.pushReplacementNamed(context, AppRoutes.home);
          }
        });

    _meteorCtl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..repeat(reverse: true);

    _boot();
  }

  Future<void> _boot() async {
    try {
      _log("Boot process started.");

      if (!localhostServer.isRunning()) {
        _log("Starting localhost server...");
        await localhostServer.start();
        _log("Server task finished.");
      } else {
        _log("Server already running.");
      }

      isServerRunning = localhostServer.isRunning();

      _log("Precaching assets...");
      await _precacheAssets();
      _log("Asset precache finished.");

      _log("Starting animation...");
      _progressCtl.forward();
    } catch (e) {
      _log("FATAL ERROR during boot: $e");
      if (mounted) {
        Navigator.pushReplacementNamed(context, AppRoutes.home);
      }
    }
  }

  Future<void> _precacheAssets() async {
    final imagePaths = [
      'assets/splash/bg.png',
      'assets/brand/logo.png',
      'assets/brand/logo_crop.png',
      'assets/brand/mascotnobg.png',
      'assets/splash/bar_track.png',
      'assets/splash/bar_fill.png',
      'assets/splash/meteor.png',
    ];

    await Future.wait(
      imagePaths.map((path) async {
        try {
          await precacheImage(AssetImage(path), context);
        } catch (e) {
          _log('WARN: Precache failed for $path');
        }
      }),
    );
  }

  @override
  void dispose() {
    _progressCtl.dispose();
    _meteorCtl.dispose();
    super.dispose();
  }

  Widget _buildLogDisplay() {
    if (!_showDebugLogs) {
      return const SizedBox.shrink();
    }

    return Positioned(
      bottom: 30,
      left: 10,
      right: 10,
      height: 150,
      child: Container(
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: const Color.fromARGB(153, 0, 0, 0),
          borderRadius: BorderRadius.circular(8),
        ),
        child: SingleChildScrollView(
          reverse: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _logs
                .map(
                  (logMsg) => Text(
                    logMsg,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10,
                      color: Colors.white,
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1433),
      body: Stack(
        children: [
          // background outside SafeArea
          Positioned.fill(
            child: Image.asset('assets/splash/bg.png', fit: BoxFit.cover),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, c) {
                final w = c.maxWidth;
                final h = c.maxHeight;

                // Skala proporsional
                final titleW = math.min(
                  w * 0.85,
                  1000.0,
                ); // Increased from 0.75
                final titleH = math.min(h * 0.42, 560.0); // Increased from 0.35
                final barW = math.min(w * 0.42, 520.0);
                final barH = math.min(h * 0.11, 68.0);
                final meteorSize = barH * 1.6;
                final barVerticalInset = (meteorSize - barH) / 2;

                return Stack(
                  children: [
                    // 2) Title (mascot image layered above text logo)
                    Align(
                      alignment: const Alignment(0, -0.45),
                      child: SizedBox(
                        width: titleW,
                        height: titleH,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            // Mascot image - BEHIND
                            Positioned(
                              top: titleH * 0.075,
                              left: titleW / 4,
                              child: SizedBox(
                                width: titleW / 1.85,
                                height: titleH,
                                child: Image.asset(
                                  'assets/brand/mascotnobg.png',
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                            // Logo text at mascot's feet - IN FRONT
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: SizedBox(
                                height: titleH * 0.35,
                                child: Image.asset(
                                  'assets/brand/logo_crop.png',
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // 3) Progress bar (track + fill + meteor)
                    Align(
                      alignment: const Alignment(0, 0.4),
                      child: SizedBox(
                        width: barW,
                        height: barH + barVerticalInset * 2,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            // Track
                            Positioned.fill(
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  vertical: barVerticalInset,
                                ),
                                child: Image.asset(
                                  'assets/splash/bar_track.png',
                                  fit: BoxFit.fill,
                                ),
                              ),
                            ),
                            AnimatedBuilder(
                              animation: _progressCtl,
                              builder: (context, _) {
                                final p = Curves.easeInOut.transform(
                                  _progressCtl.value,
                                );
                                return Positioned.fill(
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(
                                      vertical: barVerticalInset,
                                    ),
                                    child: LayoutBuilder(
                                      builder: (context, barBox) {
                                        final clamped = p
                                            .clamp(0.0, 1.0)
                                            .toDouble();
                                        if (clamped <= 0) {
                                          return const SizedBox.shrink();
                                        }
                                        final clipWidth =
                                            barBox.maxWidth * clamped;
                                        return Align(
                                          alignment: Alignment.centerLeft,
                                          child: ClipRect(
                                            clipper: _ProgressClipper(
                                              clipWidth,
                                            ),
                                            child: SizedBox(
                                              width: barBox.maxWidth,
                                              height: barBox.maxHeight,
                                              child: Image.asset(
                                                'assets/splash/bar_fill.png',
                                                fit: BoxFit.fill,
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                );
                              },
                            ),
                            // Meteor di atas bar
                            AnimatedBuilder(
                              animation: Listenable.merge([
                                _progressCtl,
                                _meteorCtl,
                              ]),
                              builder: (context, _) {
                                final p = Curves.easeInOut.transform(
                                  _progressCtl.value,
                                );
                                final bob =
                                    (_meteorCtl.value - 0.5) * (barH * 0.18);
                                final clamped = p.clamp(0.0, 1.0).toDouble();
                                final x = (barW - (meteorSize / 2)) * clamped;
                                return Positioned(
                                  top: bob,
                                  left: x,
                                  child: SizedBox(
                                    width: meteorSize,
                                    height: meteorSize,
                                    child: Image.asset(
                                      'assets/splash/meteor.png',
                                      fit: BoxFit.fitWidth,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                    // 4) Branding
                    Positioned(
                      bottom: 5,
                      left: 0,
                      right: 0,
                      child: Text(
                        'Powered by Astroid Engine',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color.fromARGB(192, 192, 192, 192),
                          fontSize: 12,
                        ),
                      ),
                    ),
                    _buildLogDisplay(),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressClipper extends CustomClipper<Rect> {
  _ProgressClipper(this.width);

  final double width;

  @override
  Rect getClip(Size size) {
    final clampedWidth = width.clamp(0.0, size.width).toDouble();
    return Rect.fromLTWH(0, 0, clampedWidth, size.height);
  }

  @override
  bool shouldReclip(_ProgressClipper oldClipper) => width != oldClipper.width;
}
