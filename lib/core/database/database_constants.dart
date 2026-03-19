/// Centralized constants for all table and column names.
/// Prevents typos and makes refactoring trivial.
class DbConstants {
  DbConstants._();

  // ── Database ──────────────────────────────────────
  static const String databaseName = 'tenant_manager.db';
  static const int databaseVersion = 8;

  // ── Tenants table ─────────────────────────────────
  static const String tableTenants = 'tenants';
  static const String colId = 'id';
  static const String colName = 'name';
  static const String colRoomNumber = 'room_number';
  static const String colMoveInDate = 'move_in_date';
  static const String colAdvancePaid = 'advance_paid';
  static const String colInitialMeterReading = 'initial_meter_reading';
  static const String colMonthlyRent = 'monthly_rent';
  static const String colActiveStatus = 'active_status';

  // ── MonthlyLogs table ─────────────────────────────
  static const String tableMonthlyLogs = 'monthly_logs';
  static const String colTenantId = 'tenant_id';
  static const String colMonthYear = 'month_year'; // Format: YYYY-MM
  static const String colPrevMeterReading = 'prev_meter_reading';
  static const String colCurrMeterReading = 'curr_meter_reading';
  static const String colUnitsConsumed = 'units_consumed';
  static const String colTotalElectricityBill = 'total_electricity_bill';
  static const String colWaterBill = 'water_bill';
  static const String colRentAmount = 'rent_amount';
  static const String colAdjustments = 'adjustments';
  static const String colTotalDue = 'total_due';
  static const String colAmountPaid = 'amount_paid';
  static const String colBalanceCarriedForward = 'balance_carried_forward';
  static const String colIsCleared = 'is_cleared';
  static const String colRecordedAt = 'recorded_at';

  // ── MainMeterAudit table ──────────────────────────
  static const String tableMainMeterAudit = 'main_meter_audit';
  static const String colMainGridReading = 'main_grid_reading';
  static const String colTotalSubmeterUnits = 'total_submeter_units';
  static const String colLineLossUnits = 'line_loss_units';

  // ── Payments table ────────────────────────────────
  static const String tablePayments = 'payments';
  static const String colAmount = 'amount';
  static const String colPaymentDate = 'payment_date';
  static const String colType = 'type'; // 'RENT' or 'ADVANCE'
  static const String colPaymentMode = 'payment_mode'; // 'CASH' or 'ONLINE'
  static const String colPaymentApp = 'payment_app'; // e.g. GPay, PhonePe
}
