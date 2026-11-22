import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_pt.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
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
    Locale('pt'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In pt, this message translates to:
  /// **'Emplake'**
  String get appTitle;

  /// No description provided for @plateHeader.
  ///
  /// In pt, this message translates to:
  /// **'BRASIL • EMPLAKE'**
  String get plateHeader;

  /// No description provided for @developedBy.
  ///
  /// In pt, this message translates to:
  /// **'Desenvolvido por: {names}'**
  String developedBy(String names);

  /// No description provided for @selectLanguage.
  ///
  /// In pt, this message translates to:
  /// **'Idioma'**
  String get selectLanguage;

  /// No description provided for @navGame.
  ///
  /// In pt, this message translates to:
  /// **'Jogar'**
  String get navGame;

  /// No description provided for @navSettings.
  ///
  /// In pt, this message translates to:
  /// **'Configurações'**
  String get navSettings;

  /// No description provided for @navHelp.
  ///
  /// In pt, this message translates to:
  /// **'Ajuda'**
  String get navHelp;

  /// No description provided for @levelEasy.
  ///
  /// In pt, this message translates to:
  /// **'Fácil'**
  String get levelEasy;

  /// No description provided for @levelIntermediate.
  ///
  /// In pt, this message translates to:
  /// **'Intermediário'**
  String get levelIntermediate;

  /// No description provided for @levelAdvanced.
  ///
  /// In pt, this message translates to:
  /// **'Avançado'**
  String get levelAdvanced;

  /// No description provided for @levelHard.
  ///
  /// In pt, this message translates to:
  /// **'Difícil'**
  String get levelHard;

  /// No description provided for @scoreLabel.
  ///
  /// In pt, this message translates to:
  /// **'Pontuação: {score}'**
  String scoreLabel(int score);

  /// No description provided for @solvedCount.
  ///
  /// In pt, this message translates to:
  /// **'Resolvidos: {count}'**
  String solvedCount(int count);

  /// No description provided for @checkButton.
  ///
  /// In pt, this message translates to:
  /// **'Verificar'**
  String get checkButton;

  /// No description provided for @clearButton.
  ///
  /// In pt, this message translates to:
  /// **'Limpar'**
  String get clearButton;

  /// No description provided for @skipButton.
  ///
  /// In pt, this message translates to:
  /// **'Pular'**
  String get skipButton;

  /// No description provided for @logoutButton.
  ///
  /// In pt, this message translates to:
  /// **'Sair'**
  String get logoutButton;

  /// No description provided for @successMessage.
  ///
  /// In pt, this message translates to:
  /// **'Parabéns! Igualdade válida! +{points} pts'**
  String successMessage(int points);

  /// No description provided for @errorNotEqual.
  ///
  /// In pt, this message translates to:
  /// **'Os dois lados não são iguais ({left} ≠ {right}).'**
  String errorNotEqual(String left, String right);

  /// No description provided for @errorNonIntegerDivision.
  ///
  /// In pt, this message translates to:
  /// **'Neste nível não é permitida divisão não inteira!'**
  String get errorNonIntegerDivision;

  /// No description provided for @errorInvalidSyntax.
  ///
  /// In pt, this message translates to:
  /// **'Expressão matemática inválida ou parênteses desbalanceados.'**
  String get errorInvalidSyntax;

  /// No description provided for @errorOperatorNotAllowed.
  ///
  /// In pt, this message translates to:
  /// **'Operador não permitido neste nível.'**
  String get errorOperatorNotAllowed;

  /// No description provided for @settingsTitle.
  ///
  /// In pt, this message translates to:
  /// **'Configurações'**
  String get settingsTitle;

  /// No description provided for @darkModeLabel.
  ///
  /// In pt, this message translates to:
  /// **'Modo Escuro'**
  String get darkModeLabel;

  /// No description provided for @fontSizeLabel.
  ///
  /// In pt, this message translates to:
  /// **'Tamanho da Fonte'**
  String get fontSizeLabel;

  /// No description provided for @fontFamilyLabel.
  ///
  /// In pt, this message translates to:
  /// **'Tipo da Fonte'**
  String get fontFamilyLabel;

  /// No description provided for @themeColorLabel.
  ///
  /// In pt, this message translates to:
  /// **'Cor Semente do Tema'**
  String get themeColorLabel;

  /// No description provided for @presetThemesLabel.
  ///
  /// In pt, this message translates to:
  /// **'Temas Prontos'**
  String get presetThemesLabel;

  /// No description provided for @themeDefault.
  ///
  /// In pt, this message translates to:
  /// **'Padrão do Sistema'**
  String get themeDefault;

  /// No description provided for @themeOcean.
  ///
  /// In pt, this message translates to:
  /// **'Oceano'**
  String get themeOcean;

  /// No description provided for @themeForest.
  ///
  /// In pt, this message translates to:
  /// **'Floresta'**
  String get themeForest;

  /// No description provided for @themeSunset.
  ///
  /// In pt, this message translates to:
  /// **'Pôr do Sol'**
  String get themeSunset;

  /// No description provided for @helpTitle.
  ///
  /// In pt, this message translates to:
  /// **'Como Jogar Emplake'**
  String get helpTitle;

  /// No description provided for @helpBody.
  ///
  /// In pt, this message translates to:
  /// **'Insira operadores matemáticos entre os 4 dígitos da placa para formar uma equação verdadeira.\n\nRegras por Nível:\n• Fácil: Todos os operadores (+, -, *, /, √, ∛, !, ^, |x|, piso ⌊x⌋, teto ⌈x⌉) e aceita divisão decimal.\n• Intermediário: Sem piso/teto. Apenas divisões inteiras.\n• Avançado: Sem raiz cúbica e potência. Apenas divisões inteiras.\n• Difícil: Apenas +, -, *, /, ( ), e módulo |x|. Apenas divisões inteiras.'**
  String get helpBody;

  /// No description provided for @closeButton.
  ///
  /// In pt, this message translates to:
  /// **'Fechar'**
  String get closeButton;

  /// No description provided for @loadingData.
  ///
  /// In pt, this message translates to:
  /// **'Sincronizando progresso na nuvem...'**
  String get loadingData;

  /// No description provided for @errorLoadingData.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível carregar seu progresso.'**
  String get errorLoadingData;

  /// No description provided for @errorSavingProgress.
  ///
  /// In pt, this message translates to:
  /// **'Não foi possível salvar seu progresso. Tente novamente.'**
  String get errorSavingProgress;

  /// No description provided for @retryButton.
  ///
  /// In pt, this message translates to:
  /// **'Tentar novamente'**
  String get retryButton;

  /// No description provided for @soundOnTooltip.
  ///
  /// In pt, this message translates to:
  /// **'Desligar som'**
  String get soundOnTooltip;

  /// No description provided for @soundOffTooltip.
  ///
  /// In pt, this message translates to:
  /// **'Ligar som'**
  String get soundOffTooltip;

  /// No description provided for @historyTitle.
  ///
  /// In pt, this message translates to:
  /// **'Histórico'**
  String get historyTitle;

  /// No description provided for @historyEmpty.
  ///
  /// In pt, this message translates to:
  /// **'Você ainda não resolveu nenhum número.'**
  String get historyEmpty;

  /// No description provided for @historyNoSolution.
  ///
  /// In pt, this message translates to:
  /// **'Solução não registrada'**
  String get historyNoSolution;

  /// No description provided for @historyPoints.
  ///
  /// In pt, this message translates to:
  /// **'+{points} pts'**
  String historyPoints(int points);

  /// No description provided for @eraseButton.
  ///
  /// In pt, this message translates to:
  /// **'Apagar'**
  String get eraseButton;

  /// No description provided for @solvedHint.
  ///
  /// In pt, this message translates to:
  /// **'Toque em Limpar ou Pular para continuar.'**
  String get solvedHint;

  /// No description provided for @retryHint.
  ///
  /// In pt, this message translates to:
  /// **'Você pode editar a expressão e verificar de novo.'**
  String get retryHint;
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
      <String>['en', 'pt'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'pt':
      return AppLocalizationsPt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
