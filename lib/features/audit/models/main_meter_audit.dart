import '../../../core/database/database_constants.dart';

/// Immutable representation of a monthly main-meter audit.
///
/// [monthYear] is always in **YYYY-MM** format (e.g. `'2026-03'`).
class MainMeterAudit {
  final int? id;
  final String monthYear; // Strict format: YYYY-MM
  final double mainGridReading;
  final double totalSubmeterUnits;
  final double lineLossUnits;
  final String? recordedAt;

  const MainMeterAudit({
    this.id,
    required this.monthYear,
    required this.mainGridReading,
    required this.totalSubmeterUnits,
    required this.lineLossUnits,
    this.recordedAt,
  });

  factory MainMeterAudit.fromMap(Map<String, dynamic> map) {
    return MainMeterAudit(
      id: map[DbConstants.colId] as int?,
      monthYear: map[DbConstants.colMonthYear] as String,
      mainGridReading: (map[DbConstants.colMainGridReading] as num).toDouble(),
      totalSubmeterUnits:
          (map[DbConstants.colTotalSubmeterUnits] as num).toDouble(),
      lineLossUnits: (map[DbConstants.colLineLossUnits] as num).toDouble(),
      recordedAt: map[DbConstants.colRecordedAt] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) DbConstants.colId: id,
      DbConstants.colMonthYear: monthYear,
      DbConstants.colMainGridReading: mainGridReading,
      DbConstants.colTotalSubmeterUnits: totalSubmeterUnits,
      DbConstants.colLineLossUnits: lineLossUnits,
      DbConstants.colRecordedAt: recordedAt,
    };
  }

  MainMeterAudit copyWith({
    int? id,
    String? monthYear,
    double? mainGridReading,
    double? totalSubmeterUnits,
    double? lineLossUnits,
    String? recordedAt,
  }) {
    return MainMeterAudit(
      id: id ?? this.id,
      monthYear: monthYear ?? this.monthYear,
      mainGridReading: mainGridReading ?? this.mainGridReading,
      totalSubmeterUnits: totalSubmeterUnits ?? this.totalSubmeterUnits,
      lineLossUnits: lineLossUnits ?? this.lineLossUnits,
      recordedAt: recordedAt ?? this.recordedAt,
    );
  }

  @override
  String toString() =>
      'MainMeterAudit(id: $id, month: $monthYear, '
      'grid: $mainGridReading, loss: $lineLossUnits)';
}
