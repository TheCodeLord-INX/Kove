import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../database/database_constants.dart';
import '../database/database_helper.dart';
import 'notification_service.dart';

/// Unique task name registered with Workmanager.
const kAuditCheckTask = 'com.tenantmanager.auditCheck';

/// Top-level callback required by Workmanager.
///
/// Runs in a **separate isolate** — no access to Riverpod or the main
/// app's DB instance. We must re-initialize everything from scratch.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    try {
      // ── 1. Bootstrap the isolate ──────────────────
      WidgetsFlutterBinding.ensureInitialized();

      // ── 2. Date check (use local device time) ─────
      final prefs = await SharedPreferences.getInstance();
      final auditDay = prefs.getInt('audit_day') ?? 25;
      
      final now = DateTime.now();
      if (now.day != auditDay) {
        // Not the audit day — nothing to do.
        return Future.value(true);
      }

      // ── 3. Re-initialize DB in this isolate ───────
      final db = await DatabaseHelper.instance.database;

      // ── 4. Count active tenants ───────────────────
      final activeResult = await db.rawQuery(
        'SELECT COUNT(*) as cnt FROM ${DbConstants.tableTenants} '
        'WHERE ${DbConstants.colActiveStatus} = 1',
      );
      final activeTenants = (activeResult.first['cnt'] as int?) ?? 0;

      if (activeTenants == 0) return Future.value(true);

      // ── 5. Count tenants with a log this month ────
      final monthYear = DateFormat('yyyy-MM').format(now);
      final loggedResult = await db.rawQuery(
        'SELECT COUNT(DISTINCT ${DbConstants.colTenantId}) as cnt '
        'FROM ${DbConstants.tableMonthlyLogs} '
        'WHERE ${DbConstants.colMonthYear} = ?',
        [monthYear],
      );
      final loggedTenants = (loggedResult.first['cnt'] as int?) ?? 0;

      // ── 6. Fire notification if rooms are missing ─
      final missing = activeTenants - loggedTenants;
      if (missing > 0) {
        await NotificationService.initialize();
        await NotificationService.showAuditReminder(missing);
      }

      return Future.value(true);
    } catch (_) {
      // Swallow errors — background tasks must not crash.
      return Future.value(true);
    }
  });
}
