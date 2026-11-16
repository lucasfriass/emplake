// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Emplake';

  @override
  String get plateHeader => 'MATH PLATE • EMPLAKE';

  @override
  String developedBy(String names) {
    return 'Developed by: $names';
  }

  @override
  String get selectLanguage => 'Language';

  @override
  String get navGame => 'Play';

  @override
  String get navSettings => 'Settings';

  @override
  String get navHelp => 'Help';

  @override
  String get levelEasy => 'Easy';

  @override
  String get levelIntermediate => 'Intermediate';

  @override
  String get levelAdvanced => 'Advanced';

  @override
  String get levelHard => 'Hard';

  @override
  String scoreLabel(int score) {
    return 'Score: $score';
  }

  @override
  String solvedCount(int count) {
    return 'Solved: $count';
  }

  @override
  String get checkButton => 'Check';

  @override
  String get clearButton => 'Clear';

  @override
  String get skipButton => 'Skip';

  @override
  String get logoutButton => 'Log out';

  @override
  String successMessage(int points) {
    return 'Congratulations! Valid equation! +$points pts';
  }

  @override
  String errorNotEqual(String left, String right) {
    return 'Both sides are not equal ($left ≠ $right).';
  }

  @override
  String get errorNonIntegerDivision =>
      'Non-integer division is not allowed in this level!';

  @override
  String get errorInvalidSyntax =>
      'Invalid mathematical expression or unbalanced parentheses.';

  @override
  String get errorOperatorNotAllowed =>
      'Operator not allowed in this difficulty level.';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get darkModeLabel => 'Dark Mode';

  @override
  String get fontSizeLabel => 'Font Size';

  @override
  String get fontFamilyLabel => 'Font Family';

  @override
  String get themeColorLabel => 'Theme Seed Color';

  @override
  String get presetThemesLabel => 'Preset Themes';

  @override
  String get themeDefault => 'System Default';

  @override
  String get themeOcean => 'Ocean';

  @override
  String get themeForest => 'Forest';

  @override
  String get themeSunset => 'Sunset';

  @override
  String get helpTitle => 'How to Play Emplake';

  @override
  String get helpBody =>
      'Insert mathematical operators between the 4 license plate digits to form a true equation.\n\nLevel Rules:\n• Easy: All operators (+, -, *, /, √, ∛, !, ^, |x|, floor ⌊x⌋, ceil ⌈x⌉) and allows decimal division.\n• Intermediate: No floor/ceil. Integer division only.\n• Advanced: No cube root or exponentiation. Integer division only.\n• Hard: Only +, -, *, /, ( ), and absolute value |x|. Integer division only.';

  @override
  String get closeButton => 'Close';

  @override
  String get loadingData => 'Syncing progress with cloud...';

  @override
  String get errorLoadingData => 'Could not load your progress.';

  @override
  String get errorSavingProgress =>
      'Could not save your progress. Please try again.';

  @override
  String get retryButton => 'Try again';

  @override
  String get soundOnTooltip => 'Turn sound off';

  @override
  String get soundOffTooltip => 'Turn sound on';
}
