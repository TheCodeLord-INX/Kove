import 'package:sqflite/sqflite.dart';

import '../../../core/database/database_constants.dart';
import '../../../core/database/database_helper.dart';
import '../models/tenant.dart';

/// CRUD operations for the [Tenant] table.
class TenantRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  /// Insert a new tenant. Returns the auto-generated id.
  Future<int> insertTenant(Tenant tenant) async {
    final db = await _dbHelper.database;
    return db.insert(
      DbConstants.tableTenants,
      tenant.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get all tenants where [active_status] == 1.
  Future<List<Tenant>> getActiveTenants() async {
    final db = await _dbHelper.database;
    final results = await db.query(
      DbConstants.tableTenants,
      where: '${DbConstants.colActiveStatus} = ?',
      whereArgs: [1],
      orderBy: '${DbConstants.colRoomNumber} ASC',
    );
    return results.map(Tenant.fromMap).toList();
  }

  /// Get all tenants (including archived).
  Future<List<Tenant>> getAllTenants() async {
    final db = await _dbHelper.database;
    final results = await db.query(
      DbConstants.tableTenants,
      orderBy: '${DbConstants.colRoomNumber} ASC',
    );
    return results.map(Tenant.fromMap).toList();
  }

  /// Get a single tenant by id.
  Future<Tenant?> getTenantById(int id) async {
    final db = await _dbHelper.database;
    final results = await db.query(
      DbConstants.tableTenants,
      where: '${DbConstants.colId} = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return Tenant.fromMap(results.first);
  }

  /// Update an existing tenant.
  Future<int> updateTenant(Tenant tenant) async {
    final db = await _dbHelper.database;
    return db.update(
      DbConstants.tableTenants,
      tenant.toMap(),
      where: '${DbConstants.colId} = ?',
      whereArgs: [tenant.id],
    );
  }

  /// Soft-delete: set [active_status] to 0.
  Future<int> archiveTenant(int id) async {
    final db = await _dbHelper.database;
    return db.update(
      DbConstants.tableTenants,
      {DbConstants.colActiveStatus: 0},
      where: '${DbConstants.colId} = ?',
      whereArgs: [id],
    );
  }
}
