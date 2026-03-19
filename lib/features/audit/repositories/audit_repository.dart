import 'package:sqflite/sqflite.dart';

import '../../../core/database/database_constants.dart';
import '../../../core/database/database_helper.dart';
import '../models/main_meter_audit.dart';

/// CRUD operations for the [MainMeterAudit] table.
class AuditRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  /// Insert or replace an audit entry (month_year is UNIQUE).
  Future<int> insertAudit(MainMeterAudit audit) async {
    final db = await _dbHelper.database;
    return db.insert(
      DbConstants.tableMainMeterAudit,
      audit.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get the audit record for a specific month (YYYY-MM).
  Future<MainMeterAudit?> getAuditForMonth(String monthYear) async {
    final db = await _dbHelper.database;
    final results = await db.query(
      DbConstants.tableMainMeterAudit,
      where: '${DbConstants.colMonthYear} = ?',
      whereArgs: [monthYear],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return MainMeterAudit.fromMap(results.first);
  }

  /// Get all audit records, newest-first.
  Future<List<MainMeterAudit>> getAllAudits() async {
    final db = await _dbHelper.database;
    final results = await db.query(
      DbConstants.tableMainMeterAudit,
      orderBy: '${DbConstants.colMonthYear} DESC',
    );
    return results.map(MainMeterAudit.fromMap).toList();
  }
  /// Get the latest audit record before a specific month (YYYY-MM).
  Future<MainMeterAudit?> getLatestAuditBefore(String monthYear) async {
    final db = await _dbHelper.database;
    final results = await db.query(
      DbConstants.tableMainMeterAudit,
      where: '${DbConstants.colMonthYear} < ?',
      whereArgs: [monthYear],
      orderBy: '${DbConstants.colMonthYear} DESC',
      limit: 1,
    );
    if (results.isEmpty) return null;
    return MainMeterAudit.fromMap(results.first);
  }
}
