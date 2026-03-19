import 'package:sqflite/sqflite.dart';

import '../../../core/database/database_constants.dart';
import '../../../core/database/database_helper.dart';
import '../models/monthly_log.dart';

/// CRUD operations for the [MonthlyLog] table.
class BillingRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  /// Insert a new monthly log. Returns the auto-generated id.
  Future<int> insertLog(MonthlyLog log) async {
    final db = await _dbHelper.database;
    return db.insert(
      DbConstants.tableMonthlyLogs,
      log.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get all logs for a specific tenant, ordered newest-first.
  Future<List<MonthlyLog>> getLogsForTenant(int tenantId) async {
    final db = await _dbHelper.database;
    final results = await db.query(
      DbConstants.tableMonthlyLogs,
      where: '${DbConstants.colTenantId} = ?',
      whereArgs: [tenantId],
      orderBy: '${DbConstants.colMonthYear} DESC',
    );
    return results.map(MonthlyLog.fromMap).toList();
  }

  /// Get all logs for a given month (YYYY-MM), across all tenants.
  Future<List<MonthlyLog>> getLogsForMonth(String monthYear) async {
    final db = await _dbHelper.database;
    final results = await db.query(
      DbConstants.tableMonthlyLogs,
      where: '${DbConstants.colMonthYear} = ?',
      whereArgs: [monthYear],
    );
    return results.map(MonthlyLog.fromMap).toList();
  }

  /// Get all monthly logs across tenants, newest month first.
  Future<List<MonthlyLog>> getAllLogs() async {
    final db = await _dbHelper.database;
    final results = await db.query(
      DbConstants.tableMonthlyLogs,
      orderBy: '${DbConstants.colMonthYear} DESC, ${DbConstants.colRecordedAt} DESC',
    );
    return results.map(MonthlyLog.fromMap).toList();
  }

  /// Get the most recent log for a tenant (to auto-fill prev_meter_reading).
  Future<MonthlyLog?> getLatestLogForTenant(int tenantId, {String? beforeMonth}) async {
    final db = await _dbHelper.database;
    
    String where = '${DbConstants.colTenantId} = ?';
    List<dynamic> whereArgs = [tenantId];
    
    if (beforeMonth != null) {
      where += ' AND ${DbConstants.colMonthYear} < ?';
      whereArgs.add(beforeMonth);
    }

    final results = await db.query(
      DbConstants.tableMonthlyLogs,
      where: where,
      whereArgs: whereArgs,
      orderBy: '${DbConstants.colMonthYear} DESC',
      limit: 1,
    );
    if (results.isEmpty) return null;
    return MonthlyLog.fromMap(results.first);
  }

  /// Update an existing log.
  Future<int> updateLog(MonthlyLog log) async {
    final db = await _dbHelper.database;
    return db.update(
      DbConstants.tableMonthlyLogs,
      log.toMap(),
      where: '${DbConstants.colId} = ?',
      whereArgs: [log.id],
    );
  }

  /// Get tenant IDs that have a log for the given month.
  Future<List<int>> getTenantIdsWithLogForMonth(String monthYear) async {
    final db = await _dbHelper.database;
    final results = await db.query(
      DbConstants.tableMonthlyLogs,
      columns: [DbConstants.colTenantId],
      where: '${DbConstants.colMonthYear} = ?',
      whereArgs: [monthYear],
    );
    return results
        .map((row) => row[DbConstants.colTenantId] as int)
        .toList();
  }

  /// Sum of [units_consumed] for all logs in a given month.
  /// Used for the 25th-day audit line-loss calculation.
  Future<double> sumUnitsConsumedForMonth(String monthYear) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(CASE WHEN l.${DbConstants.colUnitsConsumed} > 0 THEN l.${DbConstants.colUnitsConsumed} ELSE 0 END), 0) as total '
      'FROM ${DbConstants.tableMonthlyLogs} l '
      'INNER JOIN ${DbConstants.tableTenants} t '
      'ON l.${DbConstants.colTenantId} = t.${DbConstants.colId} '
      'WHERE l.${DbConstants.colMonthYear} = ? '
      'AND t.${DbConstants.colActiveStatus} = 1',
      [monthYear],
    );
    final total = (result.first['total'] as num).toDouble();
    // ignore: avoid_print
    print('AUDIT: Month $monthYear, Active Submeter Total = $total');
    return total;
  }
}
