// lib/screens/home_screen.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:showcaseview/showcaseview.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/project.dart';
import '../router/app_router.dart';
import '../services/preferences_service.dart';
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

  final _audioCache = AudioCache(prefix: 'assets/sounds/');

  late final AudioPlayer _bubblePointOnePlayer;
  late final AudioPlayer _bubblePointTwoPlayer;

  static const String _bubblePointOneAsset = 'Bubble_Point_1.wav';
  static const String _bubblePointTwoAsset = 'Bubble_Point_2.wav';

  // Showcase keys
  final GlobalKey _navHomeKey = GlobalKey();
  final GlobalKey _navCodeKey = GlobalKey();
  final GlobalKey _navChallengesKey = GlobalKey();
  final GlobalKey _navConnectKey = GlobalKey();
  final GlobalKey _createAdventureKey = GlobalKey();
  final GlobalKey _continueJourneyKey = GlobalKey();
  final GlobalKey _missionControlKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _bubblePointOnePlayer = AudioPlayer();
    _bubblePointTwoPlayer = AudioPlayer();
    unawaited(_bubblePointOnePlayer.setPlayerMode(PlayerMode.lowLatency));
    unawaited(_bubblePointTwoPlayer.setPlayerMode(PlayerMode.lowLatency));

    final audioContext = AudioContext(
      iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
      android: AudioContextAndroid(
        isSpeakerphoneOn: false,
        stayAwake: false,
        contentType: AndroidContentType.sonification,
        usageType: AndroidUsageType.media,
        audioFocus: AndroidAudioFocus.none,
      ),
    );
    unawaited(_bubblePointOnePlayer.setAudioContext(audioContext));
    unawaited(_bubblePointTwoPlayer.setAudioContext(audioContext));

    // Register ShowcaseView with configuration
    ShowcaseView.register(
      enableAutoScroll: false,
      disableBarrierInteraction: false,
      disableMovingAnimation: true,
      disableScaleAnimation: true,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      unawaited(_audioCache.load(_bubblePointOneAsset));
      unawaited(_audioCache.load(_bubblePointTwoAsset));
      debugPrint("Audio files have been pre-cached to the device.");

      // Check if showcase should be shown (first run only)
      final prefs = await PreferencesService.getInstance();
      if (!prefs.hasShownShowcase() && mounted) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          ShowcaseView.get().startShowCase([
            _navHomeKey,
            _navCodeKey,
            _navChallengesKey,
            _navConnectKey,
            _createAdventureKey,
            _continueJourneyKey,
            _missionControlKey,
          ]);
          await prefs.setShowcaseShown(true);
        }
      }
    });
  }

  void _startShowcase() {
    debugPrint('🎯 _startShowcase called, mounted=$mounted');
    if (!mounted) {
      debugPrint('🎯 Cannot start showcase: widget not mounted');
      return;
    }

    try {
      debugPrint('🎯 Starting showcase now!');
      ShowcaseView.get().startShowCase([
        _navHomeKey,
        _navCodeKey,
        _navChallengesKey,
        _navConnectKey,
        _createAdventureKey,
        _continueJourneyKey,
        _missionControlKey,
      ]);
    } catch (e) {
      debugPrint('🎯 Error starting showcase: $e');
    }
  }

  Future<void> _playBubblePointOne() =>
      _playSound(_bubblePointOnePlayer, _bubblePointOneAsset);

  Future<void> _playBubblePointTwo() =>
      _playSound(_bubblePointTwoPlayer, _bubblePointTwoAsset);

  Future<void> _playSound(AudioPlayer player, String fileName) async {
    try {
      final prefs = await PreferencesService.getInstance();
      final volume = prefs.getWebViewVolume();

      final file = await _audioCache.loadAsFile(fileName);

      await player.stop();
      await player.setVolume(volume);
      await player.play(DeviceFileSource(file.path));
    } catch (e) {
      debugPrint('Failed to play sound effect ($fileName): $e');
    }
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
  void dispose() {
    unawaited(_bubblePointOnePlayer.dispose());
    unawaited(_bubblePointTwoPlayer.dispose());
    ShowcaseView.get().unregister();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _buildScaffold(context);
  }

  Widget _buildScaffold(BuildContext context) {
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
                    final topNavW = math.min(w * 0.7, 650.0);
                    final topNavH = math.min(h * 0.15, 72.0);

                    final panelW = math.min(w * 0.78, 960.0);
                    final panelH = math.min(h * 0.56, 380.0);

                    final subtitleFont = math.min(w * 0.03, 20.0);

                    final ctaW = math.min(w * 0.22, 320.0);
                    final ctaH = math.min(h * 0.10, 64.0);
                    final canContinueJourney =
                        !_isLoading && _projects.isNotEmpty;

                    void onHomeTap() {
                      _playBubblePointOne();
                    }

                    void onCodeTap() {
                      _playBubblePointOne();
                      Navigator.pushNamed(context, AppRoutes.codeChat);
                    }

                    void onConnectTap() {
                      _playBubblePointOne();
                      Navigator.pushNamed(context, AppRoutes.connect);
                    }

                    void onChallengesTap() {
                      _playBubblePointOne();
                      Navigator.pushNamed(context, AppRoutes.challengeSelect);
                    }

                    void onCreateAdventureTap() {
                      _playBubblePointTwo();
                      Navigator.pushReplacementNamed(
                        context,
                        AppRoutes.webview,
                        arguments: {'action': 'new_project'},
                      );
                    }

                    final VoidCallback? onContinueJourneyTap =
                        canContinueJourney
                        ? () {
                            _playBubblePointTwo();
                            Navigator.pushReplacementNamed(
                              context,
                              AppRoutes.webview,
                              arguments: {'action': 'load_last'},
                            );
                          }
                        : null;

                    void onMissionControlTap() {
                      _playBubblePointTwo();
                      Navigator.pushNamed(
                        context,
                        AppRoutes.missionControl,
                        arguments: {
                          'projects': _projects,
                          'controller': _hiddenWebViewController,
                        },
                      ).then((_) {
                        if (mounted) {
                          _fetchProjectList();
                        }
                      });
                    }

                    return Stack(
                      children: [
                        Positioned(
                          right: 16,
                          bottom: 16,
                          child: _SettingsButton(
                            onTap: () async {
                              _playBubblePointOne();
                              debugPrint('🎯 Settings button tapped');
                              final result = await Navigator.pushNamed(
                                context,
                                AppRoutes.settings,
                              );
                              debugPrint(
                                '🎯 Returned from settings, result=$result',
                              );

                              if (!mounted) return;

                              if (result == true) {
                                debugPrint(
                                  '🎯 Result is true, calling _startShowcase',
                                );
                                await Future.delayed(
                                  const Duration(milliseconds: 300),
                                );
                                if (mounted) _startShowcase();
                              }
                            },
                          ),
                        ),

                        // 2) Top segmented nav
                        Align(
                          alignment: const Alignment(0, -0.7),
                          child: _TopSegmentedNav(
                            width: topNavW,
                            height: topNavH,
                            onTapHome: onHomeTap,
                            onTapCode: onCodeTap,
                            onTapChallenges: onChallengesTap,
                            onTapConnect: onConnectTap,
                            navHomeKey: _navHomeKey,
                            navCodeKey: _navCodeKey,
                            navChallengesKey: _navChallengesKey,
                            navConnectKey: _navConnectKey,
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
                            canContinueJourney: canContinueJourney,
                            onCreateAdventureTap: onCreateAdventureTap,
                            onContinueJourneyTap: onContinueJourneyTap,
                            onMissionControlTap: onMissionControlTap,
                            createAdventureKey: _createAdventureKey,
                            continueJourneyKey: _continueJourneyKey,
                            missionControlKey: _missionControlKey,
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
    required this.onTapChallenges,
    required this.onTapConnect,
    required this.navHomeKey,
    required this.navCodeKey,
    required this.navChallengesKey,
    required this.navConnectKey,
  });

  final double width;
  final double height;
  final VoidCallback onTapHome;
  final VoidCallback onTapCode;
  final VoidCallback onTapChallenges;
  final VoidCallback onTapConnect;
  final GlobalKey navHomeKey;
  final GlobalKey navCodeKey;
  final GlobalKey navChallengesKey;
  final GlobalKey navConnectKey;

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
            child: Showcase(
              key: navHomeKey,
              title: AppLocalizations.of(context)!.showcaseHomeTitle,
              description: AppLocalizations.of(context)!.showcaseHomeDesc,
              targetBorderRadius: BorderRadius.circular(segmentHeight * 0.48),
              tooltipBackgroundColor: const Color(0xFF0F1D3C),
              tooltipBorderRadius: BorderRadius.circular(16),
              titleTextStyle: GoogleFonts.titanOne(
                fontSize: 16,
                color: const Color(0xFFA5F1FF),
                letterSpacing: 0.8,
              ),
              descTextStyle: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFFF5FDFF),
                fontWeight: FontWeight.w400,
              ),
              tooltipPadding: const EdgeInsets.all(20),
              showArrow: false,
              tooltipActionConfig: const TooltipActionConfig(
                position: TooltipActionPosition.outside,
                alignment: MainAxisAlignment.spaceBetween,
              ),
              tooltipActions: [
                TooltipActionButton(
                  type: TooltipDefaultActionType.skip,
                  name: AppLocalizations.of(context)!.btnSkip,
                ),
                TooltipActionButton(
                  type: TooltipDefaultActionType.next,
                  name: AppLocalizations.of(context)!.btnNext,
                ),
              ],
              child: _NavPill(
                label: AppLocalizations.of(context)!.navHome,
                icon: Icons.rocket_launch_outlined,
                active: true,
                height: segmentHeight,
                onTap: onTapHome,
              ),
            ),
          ),
          _NavDivider(color: dividerColor, height: segmentHeight),
          Expanded(
            child: Showcase(
              key: navCodeKey,
              title: AppLocalizations.of(context)!.showcaseCodeTitle,
              description: AppLocalizations.of(context)!.showcaseCodeDesc,
              targetBorderRadius: BorderRadius.circular(segmentHeight * 0.48),
              tooltipBackgroundColor: const Color(0xFF0F1D3C),
              tooltipBorderRadius: BorderRadius.circular(16),
              titleTextStyle: GoogleFonts.titanOne(
                fontSize: 16,
                color: const Color(0xFFA5F1FF),
                letterSpacing: 0.8,
              ),
              descTextStyle: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFFF5FDFF),
                fontWeight: FontWeight.w400,
              ),
              tooltipPadding: const EdgeInsets.all(20),
              showArrow: false,
              tooltipActionConfig: const TooltipActionConfig(
                position: TooltipActionPosition.outside,
                alignment: MainAxisAlignment.spaceBetween,
              ),
              tooltipActions: [
                TooltipActionButton(
                  type: TooltipDefaultActionType.previous,
                  name: AppLocalizations.of(context)!.btnPrevious,
                ),
                TooltipActionButton(
                  type: TooltipDefaultActionType.next,
                  name: AppLocalizations.of(context)!.btnNext,
                ),
              ],
              child: _NavPill(
                label: AppLocalizations.of(context)!.navCode,
                icon: Icons.satellite_alt_outlined,
                height: segmentHeight,
                onTap: onTapCode,
              ),
            ),
          ),
          _NavDivider(color: dividerColor, height: segmentHeight),
          Expanded(
            child: Showcase(
              key: navChallengesKey,
              title: AppLocalizations.of(context)!.showcaseChallengesTitle,
              description: AppLocalizations.of(context)!.showcaseChallengesDesc,
              targetBorderRadius: BorderRadius.circular(segmentHeight * 0.48),
              tooltipBackgroundColor: const Color(0xFF0F1D3C),
              tooltipBorderRadius: BorderRadius.circular(16),
              titleTextStyle: GoogleFonts.titanOne(
                fontSize: 16,
                color: const Color(0xFFA5F1FF),
                letterSpacing: 0.8,
              ),
              descTextStyle: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFFF5FDFF),
                fontWeight: FontWeight.w400,
              ),
              tooltipPadding: const EdgeInsets.all(20),
              showArrow: false,
              tooltipActionConfig: const TooltipActionConfig(
                position: TooltipActionPosition.outside,
                alignment: MainAxisAlignment.spaceBetween,
              ),
              tooltipActions: [
                TooltipActionButton(
                  type: TooltipDefaultActionType.previous,
                  name: AppLocalizations.of(context)!.btnPrevious,
                ),
                TooltipActionButton(
                  type: TooltipDefaultActionType.next,
                  name: AppLocalizations.of(context)!.btnNext,
                ),
              ],
              child: _NavPill(
                label: AppLocalizations.of(context)!.navPlay,
                icon: Icons.stars_outlined,
                height: segmentHeight,
                onTap: onTapChallenges,
              ),
            ),
          ),
          _NavDivider(color: dividerColor, height: segmentHeight),
          Expanded(
            child: Showcase(
              key: navConnectKey,
              title: AppLocalizations.of(context)!.showcaseConnectTitle,
              description: AppLocalizations.of(context)!.showcaseConnectDesc,
              targetBorderRadius: BorderRadius.circular(segmentHeight * 0.48),
              tooltipBackgroundColor: const Color(0xFF0F1D3C),
              tooltipBorderRadius: BorderRadius.circular(16),
              titleTextStyle: GoogleFonts.titanOne(
                fontSize: 16,
                color: const Color(0xFFA5F1FF),
                letterSpacing: 0.8,
              ),
              descTextStyle: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFFF5FDFF),
                fontWeight: FontWeight.w400,
              ),
              tooltipPadding: const EdgeInsets.all(20),
              showArrow: false,
              tooltipActionConfig: const TooltipActionConfig(
                position: TooltipActionPosition.outside,
                alignment: MainAxisAlignment.spaceBetween,
              ),
              tooltipActions: [
                TooltipActionButton(
                  type: TooltipDefaultActionType.previous,
                  name: AppLocalizations.of(context)!.btnPrevious,
                ),
                TooltipActionButton(
                  type: TooltipDefaultActionType.next,
                  name: AppLocalizations.of(context)!.btnNext,
                ),
              ],
              child: _NavPill(
                label: AppLocalizations.of(context)!.navConnect,
                icon: Icons.wifi_tethering_outlined,
                height: segmentHeight,
                onTap: onTapConnect,
              ),
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
    this.active = false,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final double height;
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
    required this.canContinueJourney,
    required this.onCreateAdventureTap,
    required this.onContinueJourneyTap,
    required this.onMissionControlTap,
    required this.createAdventureKey,
    required this.continueJourneyKey,
    required this.missionControlKey,
  });

  final double width;
  final double height;
  final double subtitleFont;
  final double ctaWidth;
  final double ctaHeight;
  final bool canContinueJourney;
  final VoidCallback onCreateAdventureTap;
  final VoidCallback? onContinueJourneyTap;
  final VoidCallback onMissionControlTap;
  final GlobalKey createAdventureKey;
  final GlobalKey continueJourneyKey;
  final GlobalKey missionControlKey;

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
              AppLocalizations.of(context)!.ctaSubtitle,
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
                Showcase(
                  key: createAdventureKey,
                  title: AppLocalizations.of(context)!.showcaseCreateTitle,
                  description: AppLocalizations.of(context)!.showcaseCreateDesc,
                  targetBorderRadius: BorderRadius.circular(ctaHeight * 0.5),
                  tooltipBackgroundColor: const Color(0xFF0F1D3C),
                  tooltipBorderRadius: BorderRadius.circular(16),
                  titleTextStyle: GoogleFonts.titanOne(
                    fontSize: 16,
                    color: const Color(0xFFA5F1FF),
                    letterSpacing: 0.8,
                  ),
                  descTextStyle: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xFFF5FDFF),
                    fontWeight: FontWeight.w400,
                  ),
                  tooltipPadding: const EdgeInsets.all(20),
                  showArrow: false,
                  tooltipActionConfig: const TooltipActionConfig(
                    position: TooltipActionPosition.outside,
                    alignment: MainAxisAlignment.spaceBetween,
                  ),
                  tooltipActions: [
                    TooltipActionButton(
                      type: TooltipDefaultActionType.previous,
                      name: AppLocalizations.of(context)!.btnPrevious,
                    ),
                    TooltipActionButton(
                      type: TooltipDefaultActionType.next,
                      name: AppLocalizations.of(context)!.btnNext,
                    ),
                  ],
                  child: _CTAButton(
                    width: ctaWidth,
                    height: ctaHeight,
                    label: AppLocalizations.of(context)!.btnCreateAdventure,
                    icon: Icons.auto_awesome_outlined,
                    iconColor: const Color(0xFF3B2D63),
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE6CAFF), Color(0xFFF6EDFF)],
                    ),
                    borderColor: const Color(0xFFFDF5FF),
                    shadowColor: const Color(0xFFE3CFFF),
                    onTap: onCreateAdventureTap,
                  ),
                ),
                Showcase(
                  key: continueJourneyKey,
                  title: AppLocalizations.of(context)!.showcaseContinueTitle,
                  description: AppLocalizations.of(
                    context,
                  )!.showcaseContinueDesc,
                  targetBorderRadius: BorderRadius.circular(ctaHeight * 0.5),
                  tooltipBackgroundColor: const Color(0xFF0F1D3C),
                  tooltipBorderRadius: BorderRadius.circular(16),
                  titleTextStyle: GoogleFonts.titanOne(
                    fontSize: 16,
                    color: const Color(0xFFA5F1FF),
                    letterSpacing: 0.8,
                  ),
                  descTextStyle: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xFFF5FDFF),
                    fontWeight: FontWeight.w400,
                  ),
                  tooltipPadding: const EdgeInsets.all(20),
                  showArrow: false,
                  tooltipActionConfig: const TooltipActionConfig(
                    position: TooltipActionPosition.outside,
                    alignment: MainAxisAlignment.spaceBetween,
                  ),
                  tooltipActions: [
                    TooltipActionButton(
                      type: TooltipDefaultActionType.previous,
                      name: AppLocalizations.of(context)!.btnPrevious,
                    ),
                    TooltipActionButton(
                      type: TooltipDefaultActionType.next,
                      name: AppLocalizations.of(context)!.btnNext,
                    ),
                  ],
                  child: _CTAButton(
                    width: ctaWidth,
                    height: ctaHeight,
                    label: AppLocalizations.of(context)!.btnContinueJourney,
                    icon: Icons.play_circle_outline,
                    iconColor: const Color(0xFF153548),
                    gradient: const LinearGradient(
                      colors: [Color(0xFFB5F2FF), Color(0xFFD7F9FF)],
                    ),
                    borderColor: const Color(0xFFE8FCFF),
                    shadowColor: const Color(0xFFB5F2FF),
                    onTap: canContinueJourney ? onContinueJourneyTap : null,
                  ),
                ),
                Showcase(
                  key: missionControlKey,
                  title: AppLocalizations.of(context)!.showcaseMissionTitle,
                  description: AppLocalizations.of(
                    context,
                  )!.showcaseMissionDesc,
                  targetBorderRadius: BorderRadius.circular(ctaHeight * 0.5),
                  tooltipBackgroundColor: const Color(0xFF0F1D3C),
                  tooltipBorderRadius: BorderRadius.circular(16),
                  titleTextStyle: GoogleFonts.titanOne(
                    fontSize: 16,
                    color: const Color(0xFFA5F1FF),
                    letterSpacing: 0.8,
                  ),
                  descTextStyle: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xFFF5FDFF),
                    fontWeight: FontWeight.w400,
                  ),
                  tooltipPadding: const EdgeInsets.all(20),
                  showArrow: false,
                  tooltipActionConfig: const TooltipActionConfig(
                    position: TooltipActionPosition.outside,
                    alignment: MainAxisAlignment.spaceBetween,
                  ),
                  tooltipActions: [
                    TooltipActionButton(
                      type: TooltipDefaultActionType.previous,
                      name: AppLocalizations.of(context)!.btnPrevious,
                    ),
                    TooltipActionButton(
                      type: TooltipDefaultActionType.next,
                      name: AppLocalizations.of(context)!.btnFinish,
                    ),
                  ],
                  child: _CTAButton(
                    width: ctaWidth,
                    height: ctaHeight,
                    label: AppLocalizations.of(context)!.btnMissionControl,
                    icon: Icons.inventory_2_outlined,
                    iconColor: const Color(0xFF452720),
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFDCA8), Color(0xFFFFF5E6)],
                    ),
                    borderColor: const Color(0xFFFFF8EF),
                    shadowColor: const Color(0xFFFFE4C4),
                    onTap: canContinueJourney ? onMissionControlTap : null,
                  ),
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

class _SettingsButton extends StatelessWidget {
  const _SettingsButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
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
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: const Icon(
          Icons.settings_outlined,
          color: Color(0xFFF5FDFF),
          size: 28,
        ),
      ),
    );
  }
}
