// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Astroid Blockly';

  @override
  String get navHome => 'HOME';

  @override
  String get navCode => 'AI CHAT';

  @override
  String get navChallenges => 'CHALLENGES';

  @override
  String get navConnect => 'CONNECT';

  @override
  String get navPlay => 'PLAY';

  @override
  String get showcaseHomeTitle => 'Home';

  @override
  String get showcaseHomeDesc =>
      'Your command center. Return here anytime to access all features.';

  @override
  String get showcaseCodeTitle => 'AI Code Assistant';

  @override
  String get showcaseCodeDesc =>
      'Chat with AI to get coding help and learn programming concepts.';

  @override
  String get showcaseChallengesTitle => 'Challenges';

  @override
  String get showcaseChallengesDesc =>
      'Test your skills with exciting coding challenges and puzzles.';

  @override
  String get showcaseConnectTitle => 'Connect Robot';

  @override
  String get showcaseConnectDesc =>
      'Connect to your physical robot via Bluetooth to bring your code to life.';

  @override
  String get showcaseCreateTitle => 'Create Adventure';

  @override
  String get showcaseCreateDesc =>
      'Start a brand new coding project. Build and program your robot from scratch!';

  @override
  String get showcaseContinueTitle => 'Continue Journey';

  @override
  String get showcaseContinueDesc =>
      'Resume your last project and keep building your creation.';

  @override
  String get showcaseMissionTitle => 'Mission Control';

  @override
  String get showcaseMissionDesc =>
      'View and manage all your saved projects. Load, delete, or rename them here.';

  @override
  String get btnSkip => 'Skip';

  @override
  String get btnNext => 'Next';

  @override
  String get btnPrevious => 'Previous';

  @override
  String get btnFinish => 'Finish';

  @override
  String get ctaSubtitle => 'BUILD, PLAY, AND COMMAND';

  @override
  String get btnCreateAdventure => 'CREATE ADVENTURE';

  @override
  String get btnContinueJourney => 'CONTINUE JOURNEY';

  @override
  String get btnMissionControl => 'MISSION CONTROL';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsMusicVolume => 'Music Volume';

  @override
  String get settingsSoundVolume => 'Sound Effects Volume';

  @override
  String get settingsTutorial => 'Show Tutorial';

  @override
  String get settingsAbout => 'About';

  @override
  String get aboutAppName => 'Astroid Code Craft';

  @override
  String get aboutVersion => '1.0.0';

  @override
  String get aboutLegalese => '© 2025 Asteria Academy';

  @override
  String get aboutDescription =>
      'A visual programming environment for learning robotics and coding.';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageIndonesian => 'Indonesian';

  @override
  String get challengeModeTitle => 'Challenge Mode';

  @override
  String get levelFirstSteps => 'First Steps';

  @override
  String get levelFirstStepsDesc => 'Learn to move forward';

  @override
  String get levelMakingTurn => 'Making a Turn';

  @override
  String get levelMakingTurnDesc => 'Navigate a corner';

  @override
  String get levelSquareDance => 'The Square Dance';

  @override
  String get levelSquareDanceDesc => 'Use loops to trace a square';

  @override
  String get levelShuttleRun => 'Shuttle Run';

  @override
  String get levelShuttleRunDesc => 'Go and return to start';

  @override
  String get levelDontHitWall => 'Don\'t Hit The Wall!';

  @override
  String get levelDontHitWallDesc => 'Use sensors to avoid obstacles';

  @override
  String get levelTheMaze => 'The Maze';

  @override
  String get levelTheMazeDesc => 'Navigate a complex maze';

  @override
  String get difficultyEasy => 'Easy';

  @override
  String get difficultyMedium => 'Medium';

  @override
  String get difficultyHard => 'Hard';

  @override
  String get missionControlTitle => 'Mission Control';

  @override
  String get noProjectsMessage =>
      'No adventures created yet.\nGo back and Create Adventure!';

  @override
  String get dialogDeleteTitle => 'Delete Project?';

  @override
  String get dialogDeleteMessage => 'This action cannot be undone.';

  @override
  String get dialogRenameTitle => 'Rename Project';

  @override
  String get dialogRenameHint => 'Enter new name';

  @override
  String get btnCancel => 'Cancel';

  @override
  String get btnDelete => 'Delete';

  @override
  String get btnSave => 'Save';

  @override
  String get btnRename => 'Rename';

  @override
  String get btnLoad => 'Load';

  @override
  String get lastModified => 'Last modified';

  @override
  String get settingsTutorialDesc => 'Replay the interactive tutorial';

  @override
  String get connectTitle => 'Connect to Robot';

  @override
  String connectSuccessMessage(String deviceName) {
    return 'Successfully connected to $deviceName';
  }

  @override
  String get connectFailedMessage => 'Connection failed. Please try again.';

  @override
  String connectConnectedTo(String deviceName) {
    return 'Connected to: $deviceName';
  }

  @override
  String connectBattery(int level) {
    return 'Battery: $level%';
  }

  @override
  String get connectDisconnect => 'Disconnect';

  @override
  String get connectRobotReady => 'Robot is Ready!';

  @override
  String get connectGoBack => 'Go back and start your adventure.';

  @override
  String get connectSearching => 'Searching for Astroid robots...';

  @override
  String get connectNoRobots => 'No Robots Found';

  @override
  String get connectMakeSure =>
      'Make sure your robot is turned on and press Scan.';

  @override
  String get connectScanning => 'Scanning...';

  @override
  String get connectScanButton => 'Scan for Robots';

  @override
  String connectSignalStrength(int rssi) {
    return '$rssi dBm';
  }

  @override
  String get connectingTitle => 'Connecting...';

  @override
  String connectingTo(String deviceName) {
    return 'Establishing link with $deviceName';
  }

  @override
  String get connectingSuccess => 'Successfully Connected!';

  @override
  String connectingSuccessTo(String deviceName) {
    return 'Connected to $deviceName';
  }

  @override
  String get connectingFailed => 'Connection Failed';

  @override
  String get connectingFailedReason => 'Could not connect to the robot.';

  @override
  String get connectingGoBack => 'Go Back';

  @override
  String get connectingCancel => 'Cancel';

  @override
  String get codeChatTitle => 'AI Chatbot';

  @override
  String get codeChatBlocks => '3D Blocks';

  @override
  String get codeChatAI => 'Chat AI';

  @override
  String get codeChatInputHint => 'Chat with AstroidBot...';
}
