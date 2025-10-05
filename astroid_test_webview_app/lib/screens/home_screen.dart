// lib/screens/home_screen.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../router/app_router.dart';
import 'package:google_fonts/google_fonts.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1433),
      body: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          final h = c.maxHeight;

          // Skala responsif (selaras dengan splash)
          final frameInsetScale = 1.05; // utk border HUD
          final topNavW = math.min(w * 0.5, 520.0);
          final topNavH = math.min(h * 0.15, 72.0);

          final panelW = math.min(w * 0.78, 960.0);
          final panelH = math.min(h * 0.56, 380.0);

          final subtitleFont = math.min(w * 0.03, 20.0);

          final ctaW = math.min(w * 0.22, 320.0);
          final ctaH = math.min(h * 0.10, 64.0);

          return Stack(
            children: [
              // 1) Galaxy background
              Positioned.fill(
                child: Image.asset('assets/splash/bg.png', fit: BoxFit.cover),
              ),

              // 2) Top segmented nav
              Align(
                alignment: const Alignment(0, -0.7),
                child: _TopSegmentedNav(
                  width: topNavW,
                  height: topNavH,
                  onTapHome: () {},
                  onTapWorkspace: () {
                    Navigator.pushReplacementNamed(context, AppRoutes.webview);
                  },
                  onTapConnect: () {
                    // TODO: navigate ke connect
                  },
                ),
              ),

              // 3) Panel tengah (galaxy card)
              Align(
                alignment: const Alignment(0, 0.4),
                child: _GalaxyPanel(
                  width: panelW,
                  height: panelH,
                  subtitleFont: subtitleFont,
                  ctaWidth: ctaW,
                  ctaHeight: ctaH,
                ),
              ),

              // 4) Frame HUD overlay paling atas (seperti di splash)
              Positioned(
                top: -15,
                left: -15,
                width: c.maxWidth * frameInsetScale,
                height: c.maxHeight * frameInsetScale,
                child: IgnorePointer(
                  child: Image.asset(
                    'assets/splash/border.png',
                    fit: BoxFit.fill,
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

class _TopSegmentedNav extends StatelessWidget {
  const _TopSegmentedNav({
    required this.width,
    required this.height,
    required this.onTapHome,
    required this.onTapWorkspace,
    required this.onTapConnect,
  });

  final double width;
  final double height;
  final VoidCallback onTapHome;
  final VoidCallback onTapWorkspace;
  final VoidCallback onTapConnect;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(height * 0.45);
    final segmentHeight = height - (height * 0.28);
    final dividerColor = const Color(0xFFA4F2FF).withOpacity(0.4);

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
          color: const Color(0xFF73F0FF).withOpacity(0.8),
          width: 2.4,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6AE8FF).withOpacity(0.28),
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
              label: 'WORKSPACE',
              width: width * 0.5,
              icon: Icons.satellite_alt_outlined,
              height: segmentHeight,
              onTap: onTapWorkspace,
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
        : const Color(0xFF8BD8FF).withOpacity(0.65);

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
                color: const Color(0xFF80F1FF).withOpacity(0.45),
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
  });

  final double width;
  final double height;
  final double subtitleFont;
  final double ctaWidth;
  final double ctaHeight;

  @override
  Widget build(BuildContext context) {
    final shortestSide = math.min(width, height);
    final outerRadius = BorderRadius.circular(shortestSide * 0.08);
    final innerRadius = BorderRadius.circular(shortestSide * 0.07);
    final panelPadding = shortestSide * 0.05;
    final logoVisualWidth = math.min(width * 0.5, height * 0.7);
    final logoSlotHeight = height * 0.18;
    final buttonSpacing = ctaWidth * 0.08;
    final runSpacing = ctaHeight * 0.35;
    final goToWorkspace = () =>
        Navigator.pushReplacementNamed(context, AppRoutes.webview);

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
            color: const Color(0xFFB29CFF).withOpacity(0.35),
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
            // Let the logo grow visually while keeping the layout height stable.
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
                    color: const Color(0xFF6EE7FF).withOpacity(0.4),
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
                  onTap: goToWorkspace,
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
                  onTap: goToWorkspace,
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
                  onTap: () {},
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

    return InkWell(
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
              color: shadowColor.withOpacity(0.55),
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
    );
  }
}
