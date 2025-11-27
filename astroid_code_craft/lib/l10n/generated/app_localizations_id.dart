// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Indonesian (`id`).
class AppLocalizationsId extends AppLocalizations {
  AppLocalizationsId([String locale = 'id']) : super(locale);

  @override
  String get appTitle => 'Astroid Blockly';

  @override
  String get navHome => 'BERANDA';

  @override
  String get navCode => 'KODE';

  @override
  String get navChallenges => 'TANTANGAN';

  @override
  String get navConnect => 'HUBUNGKAN';

  @override
  String get navPlay => 'MAIN';

  @override
  String get showcaseHomeTitle => 'Beranda';

  @override
  String get showcaseHomeDesc =>
      'Pusat komando Anda. Kembali ke sini kapan saja untuk mengakses semua fitur.';

  @override
  String get showcaseCodeTitle => 'Asisten Kode AI';

  @override
  String get showcaseCodeDesc =>
      'Ngobrol dengan AI untuk mendapat bantuan coding dan belajar konsep pemrograman.';

  @override
  String get showcaseChallengesTitle => 'Tantangan';

  @override
  String get showcaseChallengesDesc =>
      'Uji kemampuanmu dengan tantangan coding dan puzzle yang seru.';

  @override
  String get showcaseConnectTitle => 'Hubungkan Robot';

  @override
  String get showcaseConnectDesc =>
      'Hubungkan ke robot fisikmu via Bluetooth untuk menghidupkan kode-mu.';

  @override
  String get showcaseCreateTitle => 'Buat Petualangan';

  @override
  String get showcaseCreateDesc =>
      'Mulai proyek coding baru. Bangun dan program robotmu dari awal!';

  @override
  String get showcaseContinueTitle => 'Lanjutkan';

  @override
  String get showcaseContinueDesc =>
      'Lanjutkan proyek terakhirmu dan terus bangun ciptaanmu.';

  @override
  String get showcaseMissionTitle => 'Kontrol Misi';

  @override
  String get showcaseMissionDesc =>
      'Lihat dan kelola semua proyekmu yang tersimpan. Muat, hapus, atau ganti namanya di sini.';

  @override
  String get btnSkip => 'Lewati';

  @override
  String get btnNext => 'Lanjut';

  @override
  String get btnPrevious => 'Kembali';

  @override
  String get btnFinish => 'Selesai';

  @override
  String get ctaSubtitle => 'BANGUN, MAINKAN, DAN PERINTAHKAN';

  @override
  String get btnCreateAdventure => 'BUAT PETUALANGAN';

  @override
  String get btnContinueJourney => 'LANJUTKAN';

  @override
  String get btnMissionControl => 'KONTROL MISI';

  @override
  String get settingsTitle => 'Pengaturan';

  @override
  String get settingsMusicVolume => 'Volume Musik';

  @override
  String get settingsSoundVolume => 'Volume Efek Suara';

  @override
  String get settingsTutorial => 'Tampilkan Tutorial';

  @override
  String get settingsAbout => 'Tentang';

  @override
  String get aboutAppName => 'Astroid Code Craft';

  @override
  String get aboutVersion => '1.0.0';

  @override
  String get aboutLegalese => '© 2025 Asteria Academy';

  @override
  String get aboutDescription =>
      'Lingkungan pemrograman visual untuk belajar robotika dan coding.';

  @override
  String get settingsLanguage => 'Bahasa';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageIndonesian => 'Bahasa Indonesia';

  @override
  String get challengeModeTitle => 'Mode Tantangan';

  @override
  String get levelFirstSteps => 'Langkah Pertama';

  @override
  String get levelFirstStepsDesc => 'Belajar bergerak maju';

  @override
  String get levelMakingTurn => 'Berbelok';

  @override
  String get levelMakingTurnDesc => 'Navigasi di sudut';

  @override
  String get levelSquareDance => 'Tarian Kotak';

  @override
  String get levelSquareDanceDesc => 'Gunakan loop untuk membuat kotak';

  @override
  String get levelShuttleRun => 'Lari Bolak-Balik';

  @override
  String get levelShuttleRunDesc => 'Pergi dan kembali ke awal';

  @override
  String get levelDontHitWall => 'Jangan Tabrak Dinding!';

  @override
  String get levelDontHitWallDesc => 'Gunakan sensor untuk hindari rintangan';

  @override
  String get levelTheMaze => 'Labirin';

  @override
  String get levelTheMazeDesc => 'Navigasi labirin yang kompleks';

  @override
  String get difficultyEasy => 'Mudah';

  @override
  String get difficultyMedium => 'Sedang';

  @override
  String get difficultyHard => 'Sulit';

  @override
  String get missionControlTitle => 'Kontrol Misi';

  @override
  String get noProjectsMessage =>
      'Belum ada petualangan yang dibuat.\nKembali dan Buat Petualangan!';

  @override
  String get dialogDeleteTitle => 'Hapus Proyek?';

  @override
  String get dialogDeleteMessage => 'Tindakan ini tidak dapat dibatalkan.';

  @override
  String get dialogRenameTitle => 'Ganti Nama Proyek';

  @override
  String get dialogRenameHint => 'Masukkan nama baru';

  @override
  String get btnCancel => 'Batal';

  @override
  String get btnDelete => 'Hapus';

  @override
  String get btnSave => 'Simpan';

  @override
  String get btnRename => 'Ganti Nama';

  @override
  String get btnLoad => 'Muat';

  @override
  String get lastModified => 'Terakhir diubah';

  @override
  String get settingsTutorialDesc => 'Mainkan ulang tutorial interaktif';

  @override
  String get connectTitle => 'Hubungkan ke Robot';

  @override
  String connectSuccessMessage(String deviceName) {
    return 'Berhasil terhubung ke $deviceName';
  }

  @override
  String get connectFailedMessage => 'Koneksi gagal. Silakan coba lagi.';

  @override
  String connectConnectedTo(String deviceName) {
    return 'Terhubung ke: $deviceName';
  }

  @override
  String connectBattery(int level) {
    return 'Baterai: $level%';
  }

  @override
  String get connectDisconnect => 'Putuskan';

  @override
  String get connectRobotReady => 'Robot Siap!';

  @override
  String get connectGoBack => 'Kembali dan mulai petualanganmu.';

  @override
  String get connectSearching => 'Mencari robot Astroid...';

  @override
  String get connectNoRobots => 'Tidak Ada Robot Ditemukan';

  @override
  String get connectMakeSure =>
      'Pastikan robotmu sudah menyala dan tekan Pindai.';

  @override
  String get connectScanning => 'Memindai...';

  @override
  String get connectScanButton => 'Pindai Robot';

  @override
  String connectSignalStrength(int rssi) {
    return '$rssi dBm';
  }

  @override
  String get connectingTitle => 'Menghubungkan...';

  @override
  String connectingTo(String deviceName) {
    return 'Membuat koneksi dengan $deviceName';
  }

  @override
  String get connectingSuccess => 'Berhasil Terhubung!';

  @override
  String connectingSuccessTo(String deviceName) {
    return 'Terhubung ke $deviceName';
  }

  @override
  String get connectingFailed => 'Koneksi Gagal';

  @override
  String get connectingFailedReason => 'Tidak dapat terhubung ke robot.';

  @override
  String get connectingGoBack => 'Kembali';

  @override
  String get connectingCancel => 'Batal';

  @override
  String get codeChatTitle => 'Astroid CodeCraft';

  @override
  String get codeChatBlocks => 'Blok 3D';

  @override
  String get codeChatAI => 'Chat AI';

  @override
  String get codeChatPlaceholder => '// Kode robotmu di sini...';

  @override
  String get codeChatInputHint => 'Chat dengan AstroidBot...';
}
