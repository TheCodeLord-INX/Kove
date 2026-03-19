import 'package:sqflite/sqflite.dart';
import '../../../core/database/database_constants.dart';
import '../../../core/database/database_helper.dart';
import '../models/payment.dart';

class PaymentRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<int> insertPayment(Payment payment) async {
    final db = await _dbHelper.database;
    return await db.insert(DbConstants.tablePayments, payment.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Payment>> getPaymentsForMonth(int tenantId, String monthYear) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      DbConstants.tablePayments,
      where: '${DbConstants.colTenantId} = ? AND ${DbConstants.colMonthYear} = ?',
      whereArgs: [tenantId, monthYear],
      orderBy: '${DbConstants.colPaymentDate} ASC',
    );
    return maps.map((e) => Payment.fromMap(e)).toList();
  }

  Future<List<Payment>> getAllPaymentsForTenant(int tenantId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      DbConstants.tablePayments,
      where: '${DbConstants.colTenantId} = ?',
      whereArgs: [tenantId],
      orderBy: '${DbConstants.colPaymentDate} ASC',
    );
    return maps.map((e) => Payment.fromMap(e)).toList();
  }
}
