import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_id.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('id'),
  ];

  /// The application title
  ///
  /// In en, this message translates to:
  /// **'Astroid Blockly'**
  String get appTitle;

  /// Home navigation label
  ///
  /// In en, this message translates to:
  /// **'HOME'**
  String get navHome;

  /// Code/AI assistant navigation label
  ///
  /// In en, this message translates to:
  /// **'CODE'**
  String get navCode;

  /// Challenges navigation label
  ///
  /// In en, this message translates to:
  /// **'CHALLENGES'**
  String get navChallenges;

  /// Connect robot navigation label
  ///
  /// In en, this message translates to:
  /// **'CONNECT'**
  String get navConnect;

  /// Play/challenges navigation label
  ///
  /// In en, this message translates to:
  /// **'PLAY'**
  String get navPlay;

  /// Title for home showcase
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get showcaseHomeTitle;

  /// Description for home showcase
  ///
  /// In en, this message translates to:
  /// **'Your command center. Return here anytime to access all features.'**
  String get showcaseHomeDesc;

  /// Title for code assistant showcase
  ///
  /// In en, this message translates to:
  /// **'AI Code Assistant'**
  String get showcaseCodeTitle;

  /// Description for code assistant showcase
  ///
  /// In en, this message translates to:
  /// **'Chat with AI to get coding help and learn programming concepts.'**
  String get showcaseCodeDesc;

  /// Title for challenges showcase
  ///
  /// In en, this message translates to:
  /// **'Challenges'**
  String get showcaseChallengesTitle;

  /// Description for challenges showcase
  ///
  /// In en, this message translates to:
  /// **'Test your skills with exciting coding challenges and puzzles.'**
  String get showcaseChallengesDesc;

  /// Title for connect robot showcase
  ///
  /// In en, this message translates to:
  /// **'Connect Robot'**
  String get showcaseConnectTitle;

  /// Description for connect robot showcase
  ///
  /// In en, this message translates to:
  /// **'Connect to your physical robot via Bluetooth to bring your code to life.'**
  String get showcaseConnectDesc;

  /// Title for create adventure showcase
  ///
  /// In en, this message translates to:
  /// **'Create Adventure'**
  String get showcaseCreateTitle;

  /// Description for create adventure showcase
  ///
  /// In en, this message translates to:
  /// **'Start a brand new coding project. Build and program your robot from scratch!'**
  String get showcaseCreateDesc;

  /// Title for continue journey showcase
  ///
  /// In en, this message translates to:
  /// **'Continue Journey'**
  String get showcaseContinueTitle;

  /// Description for continue journey showcase
  ///
  /// In en, this message translates to:
  /// **'Resume your last project and keep building your creation.'**
  String get showcaseContinueDesc;

  /// Title for mission control showcase
  ///
  /// In en, this message translates to:
  /// **'Mission Control'**
  String get showcaseMissionTitle;

  /// Description for mission control showcase
  ///
  /// In en, this message translates to:
  /// **'View and manage all your saved projects. Load, delete, or rename them here.'**
  String get showcaseMissionDesc;

  /// Skip button text
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get btnSkip;

  /// Next button text
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get btnNext;

  /// Previous button text
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get btnPrevious;

  /// Finish button text
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get btnFinish;

  /// Main subtitle on home screen
  ///
  /// In en, this message translates to:
  /// **'BUILD, PLAY, AND COMMAND'**
  String get ctaSubtitle;

  /// Create adventure button label
  ///
  /// In en, this message translates to:
  /// **'CREATE ADVENTURE'**
  String get btnCreateAdventure;

  /// Continue journey button label
  ///
  /// In en, this message translates to:
  /// **'CONTINUE JOURNEY'**
  String get btnContinueJourney;

  /// Mission control button label
  ///
  /// In en, this message translates to:
  /// **'MISSION CONTROL'**
  String get btnMissionControl;

  /// Settings screen title
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// Music volume setting label
  ///
  /// In en, this message translates to:
  /// **'Music Volume'**
  String get settingsMusicVolume;

  /// Sound effects volume setting label
  ///
  /// In en, this message translates to:
  /// **'Sound Effects Volume'**
  String get settingsSoundVolume;

  /// Show tutorial button label
  ///
  /// In en, this message translates to:
  /// **'Show Tutorial'**
  String get settingsTutorial;

  /// About button label
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// Application name in about dialog
  ///
  /// In en, this message translates to:
  /// **'Astroid Code Craft'**
  String get aboutAppName;

  /// Application version
  ///
  /// In en, this message translates to:
  /// **'1.0.0'**
  String get aboutVersion;

  /// Copyright notice
  ///
  /// In en, this message translates to:
  /// **'© 2025 Asteria Academy'**
  String get aboutLegalese;

  /// Application description in about dialog
  ///
  /// In en, this message translates to:
  /// **'A visual programming environment for learning robotics and coding.'**
  String get aboutDescription;

  /// Language setting label
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// English language option
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// Indonesian language option
  ///
  /// In en, this message translates to:
  /// **'Indonesian'**
  String get languageIndonesian;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'id'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'id':
      return AppLocalizationsId();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
