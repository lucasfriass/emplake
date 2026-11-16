import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/sound_service.dart';

class AppSettingsState {
  final ThemeMode themeMode;
  final double fontScale;
  final String fontFamily;
  final Color seedColor;
  final Locale locale;
  final bool isSoundEnabled;

  const AppSettingsState({
    this.themeMode = ThemeMode.system,
    this.fontScale = 1.0,
    this.fontFamily = 'Roboto',
    this.seedColor = const Color(0xFF1E56A0),
    this.locale = const Locale('pt'),
    this.isSoundEnabled = false, // Obrigatório iniciar sem som
  });

  AppSettingsState copyWith({
    ThemeMode? themeMode,
    double? fontScale,
    String? fontFamily,
    Color? seedColor,
    Locale? locale,
    bool? isSoundEnabled,
  }) {
    return AppSettingsState(
      themeMode: themeMode ?? this.themeMode,
      fontScale: fontScale ?? this.fontScale,
      fontFamily: fontFamily ?? this.fontFamily,
      seedColor: seedColor ?? this.seedColor,
      locale: locale ?? this.locale,
      isSoundEnabled: isSoundEnabled ?? this.isSoundEnabled,
    );
  }
}

class AppSettingsNotifier extends Notifier<AppSettingsState> {
  @override
  AppSettingsState build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final themeIndex = prefs.getInt('themeMode') ?? 0; // 0 = system
    final fontScale = prefs.getDouble('fontScale') ?? 1.0;
    final fontFamily = prefs.getString('fontFamily') ?? 'Roboto';
    final colorValue = prefs.getInt('seedColor') ?? 0xFF1E56A0;
    final langCode = prefs.getString('locale') ?? 'pt';
    // Som continua desligado por padrão; só liga se o usuário ativou antes
    final soundEnabled = prefs.getBool('soundEnabled') ?? false;

    return AppSettingsState(
      themeMode: ThemeMode.values[themeIndex],
      fontScale: fontScale,
      fontFamily: fontFamily,
      seedColor: Color(colorValue),
      locale: Locale(langCode),
      isSoundEnabled: soundEnabled,
    );
  }

  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  void setThemeMode(ThemeMode mode) {
    _prefs.setInt('themeMode', mode.index);
    state = state.copyWith(themeMode: mode);
  }

  void setFontScale(double scale) {
    _prefs.setDouble('fontScale', scale);
    state = state.copyWith(fontScale: scale);
  }

  void setFontFamily(String family) {
    _prefs.setString('fontFamily', family);
    state = state.copyWith(fontFamily: family);
  }

  void setSeedColor(Color color) {
    _prefs.setInt('seedColor', color.toARGB32());
    state = state.copyWith(seedColor: color);
  }

  void setLocale(Locale locale) {
    _prefs.setString('locale', locale.languageCode);
    state = state.copyWith(locale: locale);
  }

  void toggleSound() {
    final enabled = !state.isSoundEnabled;
    _prefs.setBool('soundEnabled', enabled);
    state = state.copyWith(isSoundEnabled: enabled);
  }

  /// Salva a última rota visitada (ex: '/game' ou '/settings')
  Future<void> saveLastRoute(String route) async {
    if (route != '/login') {
      await _prefs.setString('lastRoute', route);
    }
  }

  String getLastRoute() {
    return _prefs.getString('lastRoute') ?? '/game';
  }
}

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Inicializado no main.dart');
});

final appSettingsProvider =
    NotifierProvider<AppSettingsNotifier, AppSettingsState>(
  AppSettingsNotifier.new,
);

final soundServiceProvider = Provider<SoundService>((ref) {
  final service = SoundService();
  ref.onDispose(service.dispose);
  return service;
});
