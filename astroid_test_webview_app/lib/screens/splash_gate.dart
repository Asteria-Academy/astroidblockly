// lib/screens/splash_gate.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../router/app_router.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Server lokal utk memuat Blockly dari /assets
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
  late final AnimationController _progressCtl; // 0..1
  late final AnimationController _meteorCtl; // bobbing kecil

  @override
  void initState() {
    super.initState();
    _progressCtl =
        AnimationController(vsync: this, duration: const Duration(seconds: 60))
          ..addStatusListener((s) {
            if (s == AnimationStatus.completed) {
              if (!mounted) return;
              Navigator.pushReplacementNamed(context, AppRoutes.webview);
            }
          });

    _meteorCtl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 10),
    )..repeat(reverse: true);

    _boot();
  }

  Future<void> _boot() async {
    // Precache dulu supaya layer tidak “pop in”
    Future<void> safePrecache(String path) async {
      try {
        await precacheImage(AssetImage(path), context);
      } catch (e) {
        debugPrint('precache skip $path -> $e');
      }
    }

    await Future.wait([
      safePrecache('assets/splash/bg.png'),
      safePrecache('assets/splash/border.png'),
      safePrecache('assets/brand/logo.png'),
      safePrecache('assets/splash/bar_track.png'),
      safePrecache('assets/splash/bar_fill.png'),
      safePrecache('assets/splash/meteor.png'),
    ]);

    // Start server (abaikan error kalau sudah start)
    try {
      await localhostServer.start();
    } catch (_) {}

    // Jalankan animasi progress (kalau perlu, kamu bisa update manual step-by-step)
    _progressCtl.forward(from: 0);
    debugPrint('start anim -> ${_progressCtl.value}');
  }

  @override
  void dispose() {
    _progressCtl.dispose();
    _meteorCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1433),
      body: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          final h = c.maxHeight;

          // Skala proporsional
          final titleW = math.min(w * 0.56, 720.0);
          final barW = math.min(w * 0.42, 520.0);
          final barH = math.min(h * 0.11, 68.0);
          final meteorSize = barH * 1.6;
          final barVerticalInset = (meteorSize - barH) / 2;

          return Stack(
            children: [
              // 1) Galaxy background
              Positioned.fill(
                child: Image.asset('assets/splash/bg.png', fit: BoxFit.cover),
              ),

              // 2) Title “ASTROID BLOCKLY”
              Align(
                alignment: const Alignment(0, -0.2),
                child: Image.asset('assets/brand/logo.png', width: titleW),
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
                                  final clamped = p.clamp(0.0, 1.0).toDouble();
                                  if (clamped <= 0) {
                                    return const SizedBox.shrink();
                                  }
                                  final clipWidth = barBox.maxWidth * clamped;
                                  return Align(
                                    alignment: Alignment.centerLeft,
                                    child: ClipRect(
                                      clipper: _ProgressClipper(clipWidth),
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
                        animation: Listenable.merge([_progressCtl, _meteorCtl]),
                        builder: (context, _) {
                          final p = Curves.easeInOut.transform(
                            _progressCtl.value,
                          );
                          final bob = (_meteorCtl.value - 0.5) * (barH * 0.18);
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
              // 4) Frame HUD di paling atas
              Positioned(
                top: -15,
                left: -15,
                width: c.maxWidth * 1.05, // Set manually for width
                height: c.maxHeight * 1.05, // Set manually for height
                child: IgnorePointer(
                  child: Image.asset(
                    'assets/splash/border.png',
                    fit: BoxFit.fill,
                  ),
                ),
              ),

              // 5) Branding
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
            ],
          );
        },
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
