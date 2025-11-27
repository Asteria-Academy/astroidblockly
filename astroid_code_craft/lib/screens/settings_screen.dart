// lib/screens/settings_screen.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import '../l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app.dart';
import '../services/preferences_service.dart';
import '../services/background_music_service.dart';
import 'package:google_fonts/google_fonts.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _audioCache = AudioCache(prefix: 'assets/sounds/');
  late final AudioPlayer _bubblePointOnePlayer;
  late final AudioPlayer _bubblePointTwoPlayer;

  static const String _bubblePointOneAsset = 'Bubble_Point_1.wav';
  static const String _bubblePointTwoAsset = 'Bubble_Point_2.wav';

  double _musicVolume = 0.2;
  double _webViewVolume = 1.0;
  bool _isLoading = true;
  String _currentLanguage = 'en';

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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_audioCache.load(_bubblePointOneAsset));
      unawaited(_audioCache.load(_bubblePointTwoAsset));
      _loadSettings();
    });
  }

  Future<void> _loadSettings() async {
    final prefs = await PreferencesService.getInstance();
    final sharedPrefs = await SharedPreferences.getInstance();
    final savedLanguage = sharedPrefs.getString('language') ?? 'en';
    if (mounted) {
      setState(() {
        _musicVolume = prefs.getMusicVolume();
        _webViewVolume = prefs.getWebViewVolume();
        _currentLanguage = savedLanguage;
        _isLoading = false;
      });
    }
  }

  Future<void> _changeLanguage(String languageCode) async {
    _playBubblePointOne();
    final sharedPrefs = await SharedPreferences.getInstance();
    await sharedPrefs.setString('language', languageCode);
    if (mounted) {
      setState(() {
        _currentLanguage = languageCode;
      });
      if (context.mounted) {
        MyApp.setLocale(context, Locale(languageCode));
      }
    }
  }

  Future<void> _playBubblePointOne() =>
      _playSound(_bubblePointOnePlayer, _bubblePointOneAsset);

  Future<void> _playSound(AudioPlayer player, String fileName) async {
    try {
      final file = await _audioCache.loadAsFile(fileName);
      await player.stop();
      await player.setVolume(_webViewVolume);
      await player.play(DeviceFileSource(file.path));
    } catch (e) {
      debugPrint('Failed to play sound effect ($fileName): $e');
    }
  }

  Future<void> _showTutorial() async {
    _playBubblePointOne();
    debugPrint('🎯 Show tutorial clicked, popping with result=true');

    if (mounted) {
      Navigator.pop(context, true); // Return true to trigger showcase
    }
  }

  void _showAbout() {
    _playBubblePointOne();
    final l10n = AppLocalizations.of(context)!;
    showAboutDialog(
      context: context,
      applicationName: l10n.aboutAppName,
      applicationVersion: l10n.aboutVersion,
      applicationIcon: Image.asset(
        'assets/brand/mascotnobg.png',
        width: 64,
        height: 64,
      ),
      applicationLegalese: l10n.aboutLegalese,
      children: <Widget>[
        const SizedBox(height: 16),
        Text(l10n.aboutDescription, style: GoogleFonts.inter(fontSize: 14)),
      ],
    );
  }

  Future<void> _changeMusicVolume(double value) async {
    final prefs = await PreferencesService.getInstance();
    await prefs.setMusicVolume(value);

    final musicService = BackgroundMusicService();
    if (value > 0) {
      await musicService.setVolume(value);
      await musicService.startBackgroundMusic();
    } else {
      await musicService.stopBackgroundMusic();
    }

    if (mounted) {
      setState(() {
        _musicVolume = value;
      });
    }
  }

  Future<void> _changeWebViewVolume(double value) async {
    final prefs = await PreferencesService.getInstance();
    await prefs.setWebViewVolume(value);

    if (mounted) {
      setState(() {
        _webViewVolume = value;
      });
    }
  }

  @override
  void dispose() {
    unawaited(_bubblePointOnePlayer.dispose());
    unawaited(_bubblePointTwoPlayer.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1433),
      body: Stack(
        children: [
          // Background
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
            child: LayoutBuilder(
              builder: (context, c) {
                final w = c.maxWidth;
                final h = c.maxHeight;

                final panelW = math.min(w * 0.78, 960.0);
                final panelH = math.min(h * 0.70, 500.0);
                final titleFont = math.min(w * 0.04, 28.0);

                return Stack(
                  children: [
                    // Back button
                    Positioned(
                      left: 16,
                      top: 16,
                      child: _BackButton(
                        onTap: () {
                          _playBubblePointOne();
                          Navigator.pop(context);
                        },
                      ),
                    ),

                    // Settings panel
                    Align(
                      alignment: const Alignment(0, 0.1),
                      child: _SettingsPanel(
                        width: panelW,
                        height: panelH,
                        titleFont: titleFont,
                        musicVolume: _musicVolume,
                        webViewVolume: _webViewVolume,
                        isLoading: _isLoading,
                        currentLanguage: _currentLanguage,
                        onShowTutorial: _showTutorial,
                        onMusicVolumeChange: _changeMusicVolume,
                        onWebViewVolumeChange: _changeWebViewVolume,
                        onWebViewVolumeChangeEnd: () async {
                          await _playBubblePointOne();
                        },
                        onShowAbout: _showAbout,
                        onLanguageChange: _changeLanguage,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          // Mascot at bottom
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

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            colors: [Color(0xFF122A4D), Color(0xFF0F1D3C)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          border: Border.all(
            color: const Color.fromARGB(204, 115, 240, 255),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color.fromARGB(71, 106, 232, 255),
              blurRadius: 16,
              spreadRadius: 1,
            ),
          ],
        ),
        child: const Icon(
          Icons.arrow_back_rounded,
          color: Color(0xFFF5FDFF),
          size: 24,
        ),
      ),
    );
  }
}

class _SettingsPanel extends StatelessWidget {
  const _SettingsPanel({
    required this.width,
    required this.height,
    required this.titleFont,
    required this.musicVolume,
    required this.webViewVolume,
    required this.isLoading,
    required this.currentLanguage,
    required this.onShowTutorial,
    required this.onMusicVolumeChange,
    required this.onWebViewVolumeChange,
    required this.onWebViewVolumeChangeEnd,
    required this.onShowAbout,
    required this.onLanguageChange,
  });

  final double width;
  final double height;
  final double titleFont;
  final double musicVolume;
  final double webViewVolume;
  final bool isLoading;
  final String currentLanguage;
  final VoidCallback onShowTutorial;
  final ValueChanged<double> onMusicVolumeChange;
  final ValueChanged<double> onWebViewVolumeChange;
  final VoidCallback onWebViewVolumeChangeEnd;
  final VoidCallback onShowAbout;
  final ValueChanged<String> onLanguageChange;

  @override
  Widget build(BuildContext context) {
    final shortestSide = math.min(width, height);
    final outerRadius = BorderRadius.circular(shortestSide * 0.08);
    final innerRadius = BorderRadius.circular(shortestSide * 0.07);
    final panelPadding = shortestSide * 0.05;

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
        padding: EdgeInsets.all(panelPadding * 1.2),
        decoration: BoxDecoration(
          borderRadius: innerRadius,
          gradient: const LinearGradient(
            colors: [Color(0x80213C7A), Color(0x801B2856)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.settings_outlined,
                    size: titleFont * 0.9,
                    color: const Color(0xFFF4FDFF),
                  ),
                  SizedBox(width: titleFont * 0.3),
                  Text(
                    AppLocalizations.of(context)!.settingsTitle.toUpperCase(),
                    style: GoogleFonts.titanOne(
                      fontSize: titleFont * 0.75,
                      color: const Color(0xFFF4FDFF),
                      letterSpacing: 2,
                      shadows: [
                        Shadow(
                          color: const Color.fromARGB(102, 110, 231, 255),
                          blurRadius: 18,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: panelPadding),

            // Divider
            Container(
              height: 2,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    const Color.fromARGB(102, 164, 242, 255),
                    Colors.transparent,
                  ],
                ),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
            SizedBox(height: panelPadding),

            // Settings items
            Expanded(
              child: isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF64E7FF),
                      ),
                    )
                  : ListView(
                      children: [
                        // Language selector (First - affects entire UI)
                        _SettingsTile(
                          icon: Icons.language,
                          title: AppLocalizations.of(context)!.settingsLanguage,
                          subtitle: currentLanguage == 'en'
                              ? AppLocalizations.of(context)!.languageEnglish
                              : AppLocalizations.of(
                                  context,
                                )!.languageIndonesian,
                          trailing: PopupMenuButton<String>(
                            icon: const Icon(
                              Icons.arrow_drop_down,
                              color: Color(0xFF64E7FF),
                            ),
                            color: const Color(0xFF0F1D3C),
                            onSelected: onLanguageChange,
                            itemBuilder: (BuildContext context) =>
                                <PopupMenuEntry<String>>[
                                  PopupMenuItem<String>(
                                    value: 'en',
                                    child: Row(
                                      children: [
                                        if (currentLanguage == 'en')
                                          const Icon(
                                            Icons.check,
                                            color: Color(0xFF64E7FF),
                                            size: 20,
                                          )
                                        else
                                          const SizedBox(width: 20),
                                        const SizedBox(width: 8),
                                        Text(
                                          AppLocalizations.of(
                                            context,
                                          )!.languageEnglish,
                                          style: GoogleFonts.inter(
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem<String>(
                                    value: 'id',
                                    child: Row(
                                      children: [
                                        if (currentLanguage == 'id')
                                          const Icon(
                                            Icons.check,
                                            color: Color(0xFF64E7FF),
                                            size: 20,
                                          )
                                        else
                                          const SizedBox(width: 20),
                                        const SizedBox(width: 8),
                                        Text(
                                          AppLocalizations.of(
                                            context,
                                          )!.languageIndonesian,
                                          style: GoogleFonts.inter(
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                          ),
                        ),
                        SizedBox(height: panelPadding),

                        // Show Tutorial (Second - key onboarding feature)
                        _SettingsTile(
                          icon: Icons.school_outlined,
                          title: AppLocalizations.of(context)!.settingsTutorial,
                          subtitle: AppLocalizations.of(context)!.settingsTutorialDesc,
                          trailing: const Icon(
                            Icons.chevron_right,
                            color: Color(0xFF64E7FF),
                          ),
                          onTap: onShowTutorial,
                        ),
                        SizedBox(height: panelPadding),

                        // Music Volume (Middle - feature-specific)
                        _SliderTile(
                          icon: Icons.music_note_outlined,
                          title: AppLocalizations.of(
                            context,
                          )!.settingsMusicVolume,
                          value: musicVolume,
                          min: 0.0,
                          max: 1.0,
                          divisions: 20,
                          label: '${(musicVolume * 100).round()}%',
                          onChanged: onMusicVolumeChange,
                        ),
                        SizedBox(height: panelPadding),

                        // WebView Volume (Middle - feature-specific)
                        _SliderTile(
                          icon: Icons.videogame_asset_outlined,
                          title: AppLocalizations.of(
                            context,
                          )!.settingsSoundVolume,
                          value: webViewVolume,
                          min: 0.0,
                          max: 1.0,
                          divisions: 20,
                          label: '${(webViewVolume * 100).round()}%',
                          onChanged: onWebViewVolumeChange,
                          onChangeEnd: onWebViewVolumeChangeEnd,
                        ),
                        SizedBox(height: panelPadding),

                        // TODO: Uncomment when haptic features are implemented
                        // // Haptic Feedback Toggle
                        // _SettingsTile(
                        //   icon: Icons.vibration,
                        //   title: 'Haptic Feedback',
                        //   subtitle: 'Enable vibration feedback',
                        //   trailing: Switch(
                        //     value: false,
                        //     onChanged: (value) {},
                        //     activeColor: const Color(0xFF64E7FF),
                        //   ),
                        // ),
                        // SizedBox(height: panelPadding),

                        // About Button (Always last)
                        _SettingsTile(
                          icon: Icons.language,
                          title: AppLocalizations.of(context)!.settingsLanguage,
                          subtitle: currentLanguage == 'en'
                              ? AppLocalizations.of(context)!.languageEnglish
                              : AppLocalizations.of(
                                  context,
                                )!.languageIndonesian,
                          trailing: PopupMenuButton<String>(
                            icon: const Icon(
                              Icons.arrow_drop_down,
                              color: Color(0xFF64E7FF),
                            ),
                            color: const Color(0xFF0F1D3C),
                            onSelected: onLanguageChange,
                            itemBuilder: (BuildContext context) =>
                                <PopupMenuEntry<String>>[
                                  PopupMenuItem<String>(
                                    value: 'en',
                                    child: Row(
                                      children: [
                                        if (currentLanguage == 'en')
                                          const Icon(
                                            Icons.check,
                                            color: Color(0xFF64E7FF),
                                            size: 20,
                                          )
                                        else
                                          const SizedBox(width: 20),
                                        const SizedBox(width: 8),
                                        Text(
                                          AppLocalizations.of(
                                            context,
                                          )!.languageEnglish,
                                          style: GoogleFonts.inter(
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem<String>(
                                    value: 'id',
                                    child: Row(
                                      children: [
                                        if (currentLanguage == 'id')
                                          const Icon(
                                            Icons.check,
                                            color: Color(0xFF64E7FF),
                                            size: 20,
                                          )
                                        else
                                          const SizedBox(width: 20),
                                        const SizedBox(width: 8),
                                        Text(
                                          AppLocalizations.of(
                                            context,
                                          )!.languageIndonesian,
                                          style: GoogleFonts.inter(
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                          ),
                        ),
                        SizedBox(height: panelPadding),

                        // About Button (Always last)
                        _SettingsTile(
                          icon: Icons.info_outline,
                          title: AppLocalizations.of(context)!.settingsAbout,
                          subtitle:
                              '${AppLocalizations.of(context)!.aboutAppName} v${AppLocalizations.of(context)!.aboutVersion}',
                          trailing: const Icon(
                            Icons.chevron_right,
                            color: Color(0xFF64E7FF),
                          ),
                          onTap: onShowAbout,
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: const LinearGradient(
            colors: [Color(0x40122A4D), Color(0x400F1D3C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: const Color.fromARGB(102, 115, 240, 255),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: const LinearGradient(
                  colors: [Color(0xFF41D8FF), Color(0xFF4A7CFF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color.fromARGB(115, 128, 241, 255),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(icon, size: 28, color: Colors.white),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.titanOne(
                      fontSize: 13,
                      color: const Color(0xFFF5FDFF),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: const Color(0xFFB8E7FF),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 12), trailing!],
          ],
        ),
      ),
    );
  }
}

class _SliderTile extends StatelessWidget {
  const _SliderTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.label,
    required this.onChanged,
    this.onChangeEnd,
  });

  final IconData icon;
  final String title;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String label;
  final ValueChanged<double> onChanged;
  final VoidCallback? onChangeEnd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          colors: [Color(0x40122A4D), Color(0x400F1D3C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: const Color.fromARGB(102, 115, 240, 255),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: const LinearGradient(
                colors: [Color(0xFF41D8FF), Color(0xFF4A7CFF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color.fromARGB(115, 128, 241, 255),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, size: 22, color: Colors.white),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.titanOne(
                        fontSize: 13,
                        color: const Color(0xFFF5FDFF),
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      label,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF64E7FF),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SliderTheme(
                  data: SliderThemeData(
                    activeTrackColor: const Color(0xFF64E7FF),
                    inactiveTrackColor: const Color(0xFF1E3A5F),
                    thumbColor: const Color(0xFF41D8FF),
                    overlayColor: const Color(0x3364E7FF),
                    trackHeight: 4,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 8,
                    ),
                  ),
                  child: Slider(
                    value: value,
                    min: min,
                    max: max,
                    divisions: divisions,
                    onChanged: onChanged,
                    onChangeEnd: onChangeEnd != null
                        ? (_) => onChangeEnd!()
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
