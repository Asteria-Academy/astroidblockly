// lib/screens/home_screen.dart
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../models/project.dart';
import '../router/app_router.dart';
import 'package:google_fonts/google_fonts.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  InAppWebViewController? _hiddenWebViewController;

  List<Project> _projects = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _fetchProjectList() async {
    if (_hiddenWebViewController == null) return;

    try {
      final result = await _hiddenWebViewController!.callAsyncJavaScript(
        functionBody: "return window.getProjectList();",
      );

      if (result?.value != null) {
        final List<dynamic> projectListJson = jsonDecode(result!.value);
        final projects = projectListJson
            .map((json) => Project.fromJson(json))
            .toList();

        projects.sort((a, b) => b.lastModified.compareTo(a.lastModified));
        if (mounted) {
          setState(() {
            _projects = projects;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching project list: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
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
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.25,
              child: Image.asset(
                'assets/brand/mascotnobg.png',
                fit: BoxFit.contain,
              ),
            ),
          ),

          SafeArea(
            child: Stack(
              children: [
                Positioned(
                  left: -1,
                  top: -1,
                  width: 1,
                  height: 1,
                  child: InAppWebView(
                    initialUrlRequest: URLRequest(
                      url: WebUri("http://localhost:8080/web_build/index.html"),
                    ),
                    onWebViewCreated: (controller) {
                      _hiddenWebViewController = controller;
                    },
                    onLoadStop: (controller, url) {
                      _fetchProjectList();
                    },
                  ),
                ),
                LayoutBuilder(
                  builder: (context, c) {
                    final w = c.maxWidth;
                    final h = c.maxHeight;

                    // Skala responsif (selaras dengan splash)
                    final topNavW = math.min(w * 0.5, 520.0);
                    final topNavH = math.min(h * 0.15, 72.0);

                    final panelW = math.min(w * 0.78, 960.0);
                    final panelH = math.min(h * 0.56, 380.0);

                    final subtitleFont = math.min(w * 0.03, 20.0);

                    final ctaW = math.min(w * 0.22, 320.0);
                    final ctaH = math.min(h * 0.10, 64.0);

                    return Stack(
                      children: [
                        // 2) Top segmented nav
                        Align(
                          alignment: const Alignment(0, -0.7),
                          child: _TopSegmentedNav(
                            width: topNavW,
                            height: topNavH,
                            onTapHome: () {},
                            onTapCode: () {
                              Navigator.pushNamed(context, AppRoutes.codeChat);
                            },
                            onTapConnect: () {
                              Navigator.pushNamed(context, AppRoutes.connect);
                            },
                          ),
                        ),

                        // 3) Panel tengah (galaxy card)
                        Align(
                          alignment: const Alignment(0, 0.5),
                          child: _GalaxyPanel(
                            width: panelW,
                            height: panelH,
                            subtitleFont: subtitleFont,
                            ctaWidth: ctaW,
                            ctaHeight: ctaH,
                            isLoading: _isLoading,
                            hasProjects: _projects.isNotEmpty,
                            onMissionControlTap: () {
                              Navigator.pushNamed(
                                context,
                                AppRoutes.missionControl,
                                arguments: {
                                  'projects': _projects,
                                  'controller': _hiddenWebViewController,
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            bottom: -20 * 4,
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.5,
              child: Image.asset(
                'assets/brand/mascotnobg.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopSegmentedNav extends StatelessWidget {
  const _TopSegmentedNav({
    required this.width,
    required this.height,
    required this.onTapHome,
    required this.onTapCode,
    required this.onTapConnect,
  });

  final double width;
  final double height;
  final VoidCallback onTapHome;
  final VoidCallback onTapCode;
  final VoidCallback onTapConnect;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(height * 0.45);
    final segmentHeight = height - (height * 0.28);
    final dividerColor = const Color.fromARGB(102, 164, 242, 255);

    return Container(
      width: width,
      height: height,
      padding: EdgeInsets.symmetric(
        horizontal: height * 0.14,
        vertical: height * 0.14,
      ),
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: const LinearGradient(
          colors: [Color(0xFF122A4D), Color(0xFF0F1D3C)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border: Border.all(
          color: const Color.fromARGB(204, 115, 240, 255),
          width: 2.4,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color.fromARGB(71, 106, 232, 255),
            blurRadius: 24,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _NavPill(
              label: 'HOME',
              width: width * 0.3,
              icon: Icons.rocket_launch_outlined,
              active: true,
              height: segmentHeight,
              onTap: onTapHome,
            ),
          ),
          _NavDivider(color: dividerColor, height: segmentHeight),
          Expanded(
            child: _NavPill(
              label: 'CODE',
              width: width * 0.5,
              icon: Icons.satellite_alt_outlined,
              height: segmentHeight,
              onTap: onTapCode,
            ),
          ),
          _NavDivider(color: dividerColor, height: segmentHeight),
          Expanded(
            child: _NavPill(
              label: 'CONNECT',
              width: width * 0.3,
              icon: Icons.wifi_tethering_outlined,
              height: segmentHeight,
              onTap: onTapConnect,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavDivider extends StatelessWidget {
  const _NavDivider({required this.color, required this.height});

  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: height * 0.08,
      child: Center(
        child: Container(
          width: 1.6,
          height: height * 0.72,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
    );
  }
}

class _NavPill extends StatelessWidget {
  const _NavPill({
    required this.label,
    required this.icon,
    required this.height,
    this.width = double.infinity,
    this.active = false,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final double height;
  final double width;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(height * 0.48);
    final gradient = active
        ? const LinearGradient(
            colors: [Color(0xFF41D8FF), Color(0xFF4A7CFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : const LinearGradient(
            colors: [Color(0x00222E5C), Color(0x33222E5C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );
    final borderColor = active
        ? const Color(0xFFA7F8FF)
        : const Color.fromARGB(166, 139, 216, 255);

    final textStyle = GoogleFonts.titanOne(
      fontSize: height * 0.25,
      color: Colors.white,
      letterSpacing: 0.2,
    );

    return InkWell(
      borderRadius: borderRadius,
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: borderRadius,
          border: Border.all(color: borderColor, width: 1.6),
          boxShadow: [
            if (active)
              BoxShadow(
                color: const Color.fromARGB(115, 128, 241, 255),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
          ],
        ),
        padding: EdgeInsets.symmetric(horizontal: height * 0.24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: height * 0.35, color: const Color(0xFFF5FDFF)),
            SizedBox(width: height * 0.16),
            Flexible(
              child: Text(label, textAlign: TextAlign.center, style: textStyle),
            ),
          ],
        ),
      ),
    );
  }
}

class _GalaxyPanel extends StatelessWidget {
  const _GalaxyPanel({
    required this.width,
    required this.height,
    required this.subtitleFont,
    required this.ctaWidth,
    required this.ctaHeight,
    required this.isLoading,
    required this.hasProjects,
    required this.onMissionControlTap,
  });

  final double width;
  final double height;
  final double subtitleFont;
  final double ctaWidth;
  final double ctaHeight;
  final bool isLoading;
  final bool hasProjects;
  final VoidCallback onMissionControlTap;

  @override
  Widget build(BuildContext context) {
    final shortestSide = math.min(width, height);
    final outerRadius = BorderRadius.circular(shortestSide * 0.08);
    final innerRadius = BorderRadius.circular(shortestSide * 0.07);
    final panelPadding = shortestSide * 0.05;
    final logoVisualWidth = math.min(width * 0.6, height * 0.8);
    final logoSlotHeight = height * 0.18;
    final buttonSpacing = ctaWidth * 0.08;
    final runSpacing = ctaHeight * 0.35;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: outerRadius,
        gradient: const LinearGradient(
          colors: [Color(0x64283268), Color(0x6515234F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: const Color(0xFFB7A6FF),
          width: math.max(4, height * 0.015),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color.fromARGB(89, 178, 156, 255),
            blurRadius: 28,
            spreadRadius: 4,
          ),
        ],
      ),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: panelPadding,
        ).copyWith(top: panelPadding * 2, bottom: panelPadding),
        decoration: BoxDecoration(
          borderRadius: innerRadius,
          gradient: const LinearGradient(
            colors: [Color(0x80213C7A), Color(0x801B2856)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.max,
          children: [
            SizedBox(
              height: logoSlotHeight,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: OverflowBox(
                  minHeight: 0,
                  minWidth: 0,
                  maxWidth: logoVisualWidth,
                  maxHeight: height * 0.4,
                  alignment: Alignment.bottomCenter,
                  child: Image.asset(
                    'assets/brand/logo_crop.png',
                    width: logoVisualWidth,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            SizedBox(height: height * 0.04),
            Text(
              'BUILD, PLAY, AND COMMAND',
              textAlign: TextAlign.center,
              style: GoogleFonts.titanOne(
                fontSize: subtitleFont,
                color: const Color(0xFFF4FDFF),
                letterSpacing: 1.8,
                shadows: [
                  Shadow(
                    color: const Color.fromARGB(102, 110, 231, 255),
                    blurRadius: 18,
                  ),
                ],
              ),
            ),
            SizedBox(height: height * 0.08),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: buttonSpacing,
              runSpacing: runSpacing,
              children: [
                _CTAButton(
                  width: ctaWidth,
                  height: ctaHeight,
                  label: 'CREATE ADVENTURE',
                  icon: Icons.auto_awesome_outlined,
                  iconColor: const Color(0xFF3B2D63),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE6CAFF), Color(0xFFF6EDFF)],
                  ),
                  borderColor: const Color(0xFFFDF5FF),
                  shadowColor: const Color(0xFFE3CFFF),
                  onTap: () => Navigator.pushReplacementNamed(
                    context,
                    AppRoutes.webview,
                    arguments: {'action': 'new_project'},
                  ),
                ),
                _CTAButton(
                  width: ctaWidth,
                  height: ctaHeight,
                  label: 'CONTINUE JOURNEY',
                  icon: Icons.travel_explore_outlined,
                  iconColor: const Color(0xFF17456A),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF64E7FF), Color(0xFF9FFCF6)],
                  ),
                  borderColor: const Color(0xFFE4FFFF),
                  shadowColor: const Color(0xFF7EE5F6),
                  onTap: (isLoading || !hasProjects)
                      ? null
                      : () => Navigator.pushReplacementNamed(
                          context,
                          AppRoutes.webview,
                          arguments: {'action': 'load_last'},
                        ),
                ),
                _CTAButton(
                  width: ctaWidth,
                  height: ctaHeight,
                  label: 'MISSION CONTROL',
                  icon: Icons.public_outlined,
                  iconColor: const Color(0xFF362A6B),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFD8CBFF), Color(0xFFECE0FF)],
                  ),
                  borderColor: const Color(0xFFF6EEFF),
                  shadowColor: const Color(0xFFBEAEFF),
                  onTap: onMissionControlTap,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CTAButton extends StatelessWidget {
  const _CTAButton({
    required this.width,
    required this.height,
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.gradient,
    required this.borderColor,
    required this.shadowColor,
    this.onTap,
  });

  final double width;
  final double height;
  final String label;
  final IconData icon;
  final Color iconColor;
  final LinearGradient gradient;
  final Color borderColor;
  final Color shadowColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(height * 0.5);
    final textStyle = GoogleFonts.titanOne(
      fontSize: height * 0.28,
      letterSpacing: 0.2,
      color: const Color(0xFF11203D),
    );

    final bool isEnabled = onTap != null;

    return Opacity(
      opacity: isEnabled ? 1.0 : 0.5,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: radius,
            border: Border.all(color: borderColor, width: height * 0.06),
            boxShadow: [
              BoxShadow(
                color: shadowColor.withAlpha(140),
                blurRadius: 24,
                spreadRadius: 2,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          padding: EdgeInsets.symmetric(horizontal: height * 0.36),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: height * 0.4, color: iconColor),
              SizedBox(width: height * 0.24),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: textStyle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
