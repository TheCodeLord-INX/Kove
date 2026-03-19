import '../../../core/database/database_constants.dart';

/// Immutable representation of a single month's billing record.
///
/// [monthYear] is always in **YYYY-MM** format (e.g. `'2026-03'`).
class MonthlyLog {
  final int? id;
  final int tenantId;
  final String monthYear; // Strict format: YYYY-MM
  final double prevMeterReading;
  final double currMeterReading;
  final double unitsConsumed;
  final double totalElectricityBill;
  final double waterBill;
  final double rentAmount;
  final double adjustments;
  final double totalDue;
  final double amountPaid;
  final double balanceCarriedForward;
  final bool isCleared;
  final String? recordedAt;

  const MonthlyLog({
    this.id,
    required this.tenantId,
    required this.monthYear,
    required this.prevMeterReading,
    required this.currMeterReading,
    required this.unitsConsumed,
    required this.totalElectricityBill,
    this.waterBill = 100.0,
    required this.rentAmount,
    this.adjustments = 0.0,
    required this.totalDue,
    this.amountPaid = 0.0,
    this.balanceCarriedForward = 0.0,
    this.isCleared = false,
    this.recordedAt,
  });

  factory MonthlyLog.fromMap(Map<String, dynamic> map) {
    return MonthlyLog(
      id: map[DbConstants.colId] as int?,
      tenantId: map[DbConstants.colTenantId] as int,
      monthYear: map[DbConstants.colMonthYear] as String,
      prevMeterReading: (map[DbConstants.colPrevMeterReading] as num).toDouble(),
      currMeterReading: (map[DbConstants.colCurrMeterReading] as num).toDouble(),
      unitsConsumed: (map[DbConstants.colUnitsConsumed] as num).toDouble(),
      totalElectricityBill:
          (map[DbConstants.colTotalElectricityBill] as num).toDouble(),
      waterBill: (map[DbConstants.colWaterBill] as num).toDouble(),
      rentAmount: (map[DbConstants.colRentAmount] as num).toDouble(),
      adjustments: (map[DbConstants.colAdjustments] as num).toDouble(),
      totalDue: (map[DbConstants.colTotalDue] as num).toDouble(),
      amountPaid: (map[DbConstants.colAmountPaid] as num).toDouble(),
      balanceCarriedForward:
          (map[DbConstants.colBalanceCarriedForward] as num).toDouble(),
      isCleared: (map[DbConstants.colIsCleared] as int) == 1,
      recordedAt: map[DbConstants.colRecordedAt] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) DbConstants.colId: id,
      DbConstants.colTenantId: tenantId,
      DbConstants.colMonthYear: monthYear,
      DbConstants.colPrevMeterReading: prevMeterReading,
      DbConstants.colCurrMeterReading: currMeterReading,
      DbConstants.colUnitsConsumed: unitsConsumed,
      DbConstants.colTotalElectricityBill: totalElectricityBill,
      DbConstants.colWaterBill: waterBill,
      DbConstants.colRentAmount: rentAmount,
      DbConstants.colAdjustments: adjustments,
      DbConstants.colTotalDue: totalDue,
      DbConstants.colAmountPaid: amountPaid,
      DbConstants.colBalanceCarriedForward: balanceCarriedForward,
      DbConstants.colIsCleared: isCleared ? 1 : 0,
      DbConstants.colRecordedAt: recordedAt,
    };
  }

  MonthlyLog copyWith({
    int? id,
    int? tenantId,
    String? monthYear,
    double? prevMeterReading,
    double? currMeterReading,
    double? unitsConsumed,
    double? totalElectricityBill,
    double? waterBill,
    double? rentAmount,
    double? adjustments,
    double? totalDue,
    double? amountPaid,
    double? balanceCarriedForward,
    bool? isCleared,
    String? recordedAt,
  }) {
    return MonthlyLog(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      monthYear: monthYear ?? this.monthYear,
      prevMeterReading: prevMeterReading ?? this.prevMeterReading,
      currMeterReading: currMeterReading ?? this.currMeterReading,
      unitsConsumed: unitsConsumed ?? this.unitsConsumed,
      totalElectricityBill: totalElectricityBill ?? this.totalElectricityBill,
      waterBill: waterBill ?? this.waterBill,
      rentAmount: rentAmount ?? this.rentAmount,
      adjustments: adjustments ?? this.adjustments,
      totalDue: totalDue ?? this.totalDue,
      amountPaid: amountPaid ?? this.amountPaid,
      balanceCarriedForward:
          balanceCarriedForward ?? this.balanceCarriedForward,
      isCleared: isCleared ?? this.isCleared,
      recordedAt: recordedAt ?? this.recordedAt,
    );
  }

  @override
  String toString() =>
      'MonthlyLog(id: $id, tenant: $tenantId, month: $monthYear, '
      'due: $totalDue, paid: $amountPaid)';
}
