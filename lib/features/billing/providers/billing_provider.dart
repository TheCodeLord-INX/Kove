import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/services/billing_engine.dart';
import '../../../core/providers/settings_provider.dart';
import '../models/monthly_log.dart';
import '../repositories/billing_repository.dart';

// ── Repository singleton ─────────────────────────────
final billingRepositoryProvider = Provider<BillingRepository>((ref) {
  return BillingRepository();
});

// ── Tenant log history (family) ──────────────────────
final tenantLogsProvider =
    FutureProvider.family<List<MonthlyLog>, int>((ref, tenantId) async {
  return ref.read(billingRepositoryProvider).getLogsForTenant(tenantId);
});

// ── Monthly logs for a specific month ────────────────
final monthLogsProvider =
    FutureProvider.family<List<MonthlyLog>, String>((ref, monthYear) async {
  return ref.read(billingRepositoryProvider).getLogsForMonth(monthYear);
});

final allMonthlyLogsProvider = FutureProvider<List<MonthlyLog>>((ref) async {
  return ref.read(billingRepositoryProvider).getAllLogs();
});

// ── Billing form state ───────────────────────────────

/// Holds the live-preview state while the user fills in the billing form.
class BillingFormState {
  final double prevReading;
  final double currReading;
  final double rent;
  final double adjustments;
  final double previousBalance;
  final double amountPaid;

  // Computed fields
  final double unitsConsumed;
  final double electricityBill;
  final double waterBill;
  final double totalDue;
  final double balanceCarriedForward;

  const BillingFormState({
    this.prevReading = 0,
    this.currReading = 0,
    this.rent = 0,
    this.adjustments = 0,
    this.previousBalance = 0,
    this.amountPaid = 0,
    this.unitsConsumed = 0,
    this.electricityBill = 0,
    this.waterBill = 100.0,
    this.totalDue = 0,
    this.balanceCarriedForward = 0,
  });

  BillingFormState recompute(AppSettings settings) {
    final computed = BillingEngine.computeFullBill(
      prevReading: prevReading,
      currReading: currReading,
      rent: rent,
      waterCharge: settings.waterCharge,
      tier1Rate: settings.tier1Rate,
      tier2Rate: settings.tier2Rate,
      tierThreshold: settings.tierThreshold,
      meterCharge: settings.meterCharge,
      adjustments: adjustments,
      previousBalance: previousBalance,
      amountPaid: amountPaid,
    );

    return BillingFormState(
      prevReading: prevReading,
      currReading: currReading,
      rent: rent,
      adjustments: adjustments,
      previousBalance: previousBalance,
      amountPaid: amountPaid,
      unitsConsumed: computed['units_consumed']!,
      electricityBill: computed['electricity_bill']!,
      waterBill: computed['water_bill']!,
      totalDue: computed['total_due']!,
      balanceCarriedForward: computed['balance_carried_forward']!,
    );
  }
}

final billingFormProvider =
    NotifierProvider<BillingFormNotifier, BillingFormState>(
  BillingFormNotifier.new,
);

class BillingFormNotifier extends Notifier<BillingFormState> {
  @override
  BillingFormState build() => const BillingFormState();

  /// Initialize from the latest log for a tenant.
  /// Auto-fills prev_meter_reading and previous balance.
  Future<void> initForTenant(int tenantId, double rent) async {
    final repo = ref.read(billingRepositoryProvider);
    final latestLog = await repo.getLatestLogForTenant(tenantId);

    final settings = ref.read(settingsProvider);

    state = BillingFormState(
      prevReading: latestLog?.currMeterReading ?? 0,
      previousBalance: latestLog?.balanceCarriedForward ?? 0,
      rent: rent,
    ).recompute(settings);
  }

  void setFullState({
    required double prevReading,
    required double currReading,
    required double rent,
    required double adjustments,
    required double previousBalance,
    required double amountPaid,
  }) {
    final settings = ref.read(settingsProvider);
    state = BillingFormState(
      prevReading: prevReading,
      currReading: currReading,
      rent: rent,
      adjustments: adjustments,
      previousBalance: previousBalance,
      amountPaid: amountPaid,
    ).recompute(settings);
  }

  void updateCurrReading(double value) {
    final settings = ref.read(settingsProvider);
    state = BillingFormState(
      prevReading: state.prevReading,
      currReading: value,
      rent: state.rent,
      adjustments: state.adjustments,
      previousBalance: state.previousBalance,
      amountPaid: state.amountPaid,
    ).recompute(settings);
  }

  void updateAdjustments(double value) {
    final settings = ref.read(settingsProvider);
    state = BillingFormState(
      prevReading: state.prevReading,
      currReading: state.currReading,
      rent: state.rent,
      adjustments: value,
      previousBalance: state.previousBalance,
      amountPaid: state.amountPaid,
    ).recompute(settings);
  }

  void updateAmountPaid(double value) {
    final settings = ref.read(settingsProvider);
    state = BillingFormState(
      prevReading: state.prevReading,
      currReading: state.currReading,
      rent: state.rent,
      adjustments: state.adjustments,
      previousBalance: state.previousBalance,
      amountPaid: value,
    ).recompute(settings);
  }

  void updateRent(double value) {
    final settings = ref.read(settingsProvider);
    state = BillingFormState(
      prevReading: state.prevReading,
      currReading: state.currReading,
      rent: value,
      adjustments: state.adjustments,
      previousBalance: state.previousBalance,
      amountPaid: state.amountPaid,
    ).recompute(settings);
  }

  /// Save the current form state as a MonthlyLog row.
  Future<void> saveLog(int tenantId, {String? monthYearOverride}) async {
    final now = DateTime.now();
    final monthYear = monthYearOverride ?? DateFormat('yyyy-MM').format(now);

    final repo = ref.read(billingRepositoryProvider);
    final logsThisMonth = await repo.getLogsForTenant(tenantId);
    final existingLog = logsThisMonth.where((e) => e.monthYear == monthYear).firstOrNull;

    final log = MonthlyLog(
      id: existingLog?.id,
      tenantId: tenantId,
      monthYear: monthYear,
      prevMeterReading: state.prevReading,
      currMeterReading: state.currReading,
      unitsConsumed: state.unitsConsumed,
      totalElectricityBill: state.electricityBill,
      waterBill: state.waterBill,
      rentAmount: state.rent,
      adjustments: state.adjustments,
      totalDue: state.totalDue,
      amountPaid: state.amountPaid,
      balanceCarriedForward: state.balanceCarriedForward,
      isCleared: state.balanceCarriedForward <= 0,
      recordedAt: DateTime.now().toIso8601String(),
    );

    if (existingLog != null) {
      await repo.updateLog(log);
    } else {
      await repo.insertLog(log);
    }

    // Invalidate the tenant logs cache so histories refresh.
    ref.invalidate(tenantLogsProvider(tenantId));
    ref.invalidate(allMonthlyLogsProvider);
    ref.invalidate(monthLogsProvider(monthYear));
  }
}

// ── Action provider for standalone repo access ───────────────────
final billingActionProvider = Provider((ref) {
  final repo = ref.read(billingRepositoryProvider);
  return BillingActionHandler(repo, ref);
});

class BillingActionHandler {
  final BillingRepository _repo;
  final Ref _ref;
  BillingActionHandler(this._repo, this._ref);

  Future<void> saveMonthlyLog(MonthlyLog log) async {
    final logsThisMonth = await _repo.getLogsForTenant(log.tenantId);
    final existingLog = logsThisMonth.where((e) => e.monthYear == log.monthYear).firstOrNull;

    if (existingLog != null) {
      await _repo.updateLog(log.copyWith(id: existingLog.id));
    } else {
      await _repo.insertLog(log);
    }
    _ref.invalidate(tenantLogsProvider(log.tenantId));
    _ref.invalidate(allMonthlyLogsProvider);
    _ref.invalidate(monthLogsProvider(log.monthYear));
  }
}
