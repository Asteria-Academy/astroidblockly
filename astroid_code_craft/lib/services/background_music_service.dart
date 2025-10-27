import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

class BackgroundMusicService with WidgetsBindingObserver {
  static final BackgroundMusicService _instance =
      BackgroundMusicService._internal();
  factory BackgroundMusicService() => _instance;
  BackgroundMusicService._internal() {
    WidgetsBinding.instance.addObserver(this);
  }

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;

  Future<void> startBackgroundMusic() async {
    if (_isPlaying) return;

    try {
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.setVolume(0.2);
      await _audioPlayer.setAudioContext(
        AudioContext(
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.ambient,
            options: {AVAudioSessionOptions.mixWithOthers},
          ),
          android: AudioContextAndroid(
            isSpeakerphoneOn: false,
            stayAwake: false,
            contentType: AndroidContentType.music,
            usageType: AndroidUsageType.media,
            audioFocus: AndroidAudioFocus.gain,
          ),
        ),
      );
      await _audioPlayer.play(AssetSource('sounds/Fluffy_Clouds.mp3'));
      _isPlaying = true;
      debugPrint('🎵 Background music started');
    } catch (e) {
      debugPrint('❌ Error starting background music: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        pauseBackgroundMusic();
        break;
      case AppLifecycleState.resumed:
        resumeBackgroundMusic();
        break;
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        break;
    }
  }

  Future<void> stopBackgroundMusic() async {
    if (!_isPlaying) return;

    try {
      await _audioPlayer.stop();
      _isPlaying = false;
      debugPrint('🔇 Background music stopped');
    } catch (e) {
      debugPrint('❌ Error stopping background music: $e');
    }
  }

  Future<void> pauseBackgroundMusic() async {
    if (!_isPlaying) return;

    try {
      await _audioPlayer.pause();
      debugPrint('⏸️ Background music paused');
    } catch (e) {
      debugPrint('❌ Error pausing background music: $e');
    }
  }

  Future<void> resumeBackgroundMusic() async {
    if (!_isPlaying) return;

    try {
      await _audioPlayer.resume();
      debugPrint('▶️ Background music resumed');
    } catch (e) {
      debugPrint('❌ Error resuming background music: $e');
    }
  }

  Future<void> setVolume(double volume) async {
    try {
      await _audioPlayer.setVolume(volume.clamp(0.0, 1.0));
    } catch (e) {
      debugPrint('❌ Error setting volume: $e');
    }
  }

  bool get isPlaying => _isPlaying;

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _audioPlayer.dispose();
  }
}
