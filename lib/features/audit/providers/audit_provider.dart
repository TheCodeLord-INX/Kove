import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../features/billing/repositories/billing_repository.dart';
import '../models/main_meter_audit.dart';
import '../repositories/audit_repository.dart';

// ── Repository singletons ────────────────────────────
final auditRepositoryProvider = Provider<AuditRepository>((ref) {
  return AuditRepository();
});

// ── All audits list ──────────────────────────────────
final allAuditsProvider = FutureProvider<List<MainMeterAudit>>((ref) async {
  return ref.read(auditRepositoryProvider).getAllAudits();
});

// ── Audit for a specific month ───────────────────────
final auditForMonthProvider =
    FutureProvider.family<MainMeterAudit?, String>((ref, monthYear) async {
  return ref.read(auditRepositoryProvider).getAuditForMonth(monthYear);
});

// ── Audit creation notifier ──────────────────────────

class AuditState {
  final double mainGridReading;
  final double totalSubmeterUnits;
  final double lineLossUnits;

  const AuditState({
    this.mainGridReading = 0,
    this.totalSubmeterUnits = 0,
    this.lineLossUnits = 0,
  });
}

final auditFormProvider = NotifierProvider<AuditFormNotifier, AuditState>(
  AuditFormNotifier.new,
);

class AuditFormNotifier extends Notifier<AuditState> {
  @override
  AuditState build() => const AuditState();

  /// Load the sum of all sub-meter current readings for the current month.
  Future<void> loadSubmeterTotal() async {
    final now = DateTime.now();
    final monthYear = DateFormat('yyyy-MM').format(now);

    final billingRepo = BillingRepository();
    final total = await billingRepo.sumUnitsConsumedForMonth(monthYear);

    state = AuditState(
      mainGridReading: state.mainGridReading,
      totalSubmeterUnits: total,
      lineLossUnits: state.mainGridReading - total,
    );
  }

  void updateMainGridReading(double value) {
    state = AuditState(
      mainGridReading: value,
      totalSubmeterUnits: state.totalSubmeterUnits,
      lineLossUnits: value - state.totalSubmeterUnits,
    );
  }

  /// Save the audit entry for the current month.
  Future<void> saveAudit() async {
    final now = DateTime.now();
    final monthYear = DateFormat('yyyy-MM').format(now);

    final audit = MainMeterAudit(
      monthYear: monthYear,
      mainGridReading: state.mainGridReading,
      totalSubmeterUnits: state.totalSubmeterUnits,
      lineLossUnits: state.lineLossUnits,
    );

    await ref.read(auditRepositoryProvider).insertAudit(audit);
    ref.invalidate(allAuditsProvider);
    ref.invalidate(auditForMonthProvider(monthYear));
  }
}
