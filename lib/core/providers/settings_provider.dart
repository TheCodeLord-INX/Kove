import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/settings_service.dart';

/// Provider for the shared preferences instance. Requires initialization in main().
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider must be overridden in main()');
});

/// Provider for the SettingsService.
final settingsServiceProvider = Provider<SettingsService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SettingsService(prefs);
});

// A state class to hold all current settings values synchronously.
class AppSettings {
  final bool isDarkMode;
  final double waterCharge;
  final double tier1Rate;
  final double tier2Rate;
  final double tierThreshold;
  final double meterCharge;
  final int auditDay;

  const AppSettings({
    required this.isDarkMode,
    required this.waterCharge,
    required this.tier1Rate,
    required this.tier2Rate,
    required this.tierThreshold,
    required this.meterCharge,
    required this.auditDay,
  });

  AppSettings copyWith({
    bool? isDarkMode,
    double? waterCharge,
    double? tier1Rate,
    double? tier2Rate,
    double? tierThreshold,
    double? meterCharge,
    int? auditDay,
  }) {
    return AppSettings(
      isDarkMode: isDarkMode ?? this.isDarkMode,
      waterCharge: waterCharge ?? this.waterCharge,
      tier1Rate: tier1Rate ?? this.tier1Rate,
      tier2Rate: tier2Rate ?? this.tier2Rate,
      tierThreshold: tierThreshold ?? this.tierThreshold,
      meterCharge: meterCharge ?? this.meterCharge,
      auditDay: auditDay ?? this.auditDay,
    );
  }
}

class SettingsNotifier extends Notifier<AppSettings> {
  late SettingsService _service;

  @override
  AppSettings build() {
    _service = ref.watch(settingsServiceProvider);
    return AppSettings(
      isDarkMode: _service.isDarkMode,
      waterCharge: _service.waterCharge,
      tier1Rate: _service.tier1Rate,
      tier2Rate: _service.tier2Rate,
      tierThreshold: _service.tierThreshold,
      meterCharge: _service.meterCharge,
      auditDay: _service.auditDay,
    );
  }

  Future<void> setDarkMode(bool value) async {
    await _service.setDarkMode(value);
    state = state.copyWith(isDarkMode: value);
  }

  Future<void> setWaterCharge(double value) async {
    await _service.setWaterCharge(value);
    state = state.copyWith(waterCharge: value);
  }

  Future<void> setTier1Rate(double value) async {
    await _service.setTier1Rate(value);
    state = state.copyWith(tier1Rate: value);
  }

  Future<void> setTier2Rate(double value) async {
    await _service.setTier2Rate(value);
    state = state.copyWith(tier2Rate: value);
  }

  Future<void> setTierThreshold(double value) async {
    await _service.setTierThreshold(value);
    state = state.copyWith(tierThreshold: value);
  }

  Future<void> setMeterCharge(double value) async {
    await _service.setMeterCharge(value);
    state = state.copyWith(meterCharge: value);
  }

  Future<void> setAuditDay(int value) async {
    await _service.setAuditDay(value);
    state = state.copyWith(auditDay: value);
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(() {
  return SettingsNotifier();
});
