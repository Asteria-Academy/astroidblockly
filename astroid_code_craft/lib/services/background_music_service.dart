import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

class BackgroundMusicService {
  static final BackgroundMusicService _instance =
      BackgroundMusicService._internal();
  factory BackgroundMusicService() => _instance;
  BackgroundMusicService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;

  Future<void> startBackgroundMusic() async {
    if (_isPlaying) return;

    try {
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.setVolume(0.3);
      await _audioPlayer.play(AssetSource('sounds/Fluffy_Clouds.mp3'));
      _isPlaying = true;
      debugPrint('🎵 Background music started');
    } catch (e) {
      debugPrint('❌ Error starting background music: $e');
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
    _audioPlayer.dispose();
  }
}
