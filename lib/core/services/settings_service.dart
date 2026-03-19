import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  final SharedPreferences _prefs;

  SettingsService(this._prefs);

  static const _keyIsDarkMode = 'isDarkMode';
  static const _keyWaterCharge = 'water_charge';
  static const _keyTier1Rate = 'tier1_rate';
  static const _keyTier2Rate = 'tier2_rate';
  static const _keyTierThreshold = 'tier_threshold';
  static const _keyMeterCharge = 'meter_charge';
  static const _keyAuditDay = 'audit_day';
  static const _keyLastGridReading = 'last_grid_reading';

  bool get isDarkMode => _prefs.getBool(_keyIsDarkMode) ?? false;
  Future<void> setDarkMode(bool value) => _prefs.setBool(_keyIsDarkMode, value);

  double get waterCharge => _prefs.getDouble(_keyWaterCharge) ?? 100.0;
  Future<void> setWaterCharge(double value) => _prefs.setDouble(_keyWaterCharge, value);

  double get tier1Rate => _prefs.getDouble(_keyTier1Rate) ?? 10.0;
  Future<void> setTier1Rate(double value) => _prefs.setDouble(_keyTier1Rate, value);

  double get tier2Rate => _prefs.getDouble(_keyTier2Rate) ?? 12.0;
  Future<void> setTier2Rate(double value) => _prefs.setDouble(_keyTier2Rate, value);

  double get tierThreshold => _prefs.getDouble(_keyTierThreshold) ?? 60.0;
  Future<void> setTierThreshold(double value) => _prefs.setDouble(_keyTierThreshold, value);

  double get meterCharge => _prefs.getDouble(_keyMeterCharge) ?? 150.0;
  Future<void> setMeterCharge(double value) => _prefs.setDouble(_keyMeterCharge, value);

  int get auditDay => _prefs.getInt(_keyAuditDay) ?? 25;
  Future<void> setAuditDay(int value) => _prefs.setInt(_keyAuditDay, value);

  double? get lastGridReading => _prefs.getDouble(_keyLastGridReading);
  Future<void> setLastGridReading(double value) =>
      _prefs.setDouble(_keyLastGridReading, value);
}
