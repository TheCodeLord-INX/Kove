import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

import 'database_constants.dart';

/// Singleton helper for managing the local SQLite database.
///
/// Uses a version-based migration strategy in [_onUpgrade] so that
/// future schema changes never cause data loss.
class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  Database? _database;

  /// Returns the singleton [Database] instance, initializing it on first call.
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, DbConstants.databaseName);

    return openDatabase(
      path,
      version: DbConstants.databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: (db) async {
        // Enable foreign-key enforcement.
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  // ── Schema creation (Version 1) ─────────────────────────────────────────

  Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();

    // Tenants
    batch.execute('''
      CREATE TABLE ${DbConstants.tableTenants} (
        ${DbConstants.colId}           INTEGER PRIMARY KEY AUTOINCREMENT,
        ${DbConstants.colName}         TEXT    NOT NULL,
        ${DbConstants.colRoomNumber}   TEXT    NOT NULL,
        ${DbConstants.colMoveInDate}   TEXT    NOT NULL,
        ${DbConstants.colAdvancePaid}  REAL    NOT NULL DEFAULT 0.0,
        ${DbConstants.colInitialMeterReading} REAL NOT NULL DEFAULT 0.0,
        ${DbConstants.colMonthlyRent}  REAL    NOT NULL DEFAULT 0.0,
        ${DbConstants.colActiveStatus} INTEGER NOT NULL DEFAULT 1
      )
    ''');

    // Monthly Logs
    batch.execute('''
      CREATE TABLE ${DbConstants.tableMonthlyLogs} (
        ${DbConstants.colId}                    INTEGER PRIMARY KEY AUTOINCREMENT,
        ${DbConstants.colTenantId}              INTEGER NOT NULL,
        ${DbConstants.colMonthYear}             TEXT    NOT NULL,
        ${DbConstants.colPrevMeterReading}      REAL    NOT NULL,
        ${DbConstants.colCurrMeterReading}      REAL    NOT NULL,
        ${DbConstants.colUnitsConsumed}         REAL    NOT NULL,
        ${DbConstants.colTotalElectricityBill}  REAL    NOT NULL,
        ${DbConstants.colWaterBill}             REAL    NOT NULL DEFAULT 100.0,
        ${DbConstants.colRentAmount}            REAL    NOT NULL,
        ${DbConstants.colAdjustments}           REAL    NOT NULL DEFAULT 0.0,
        ${DbConstants.colTotalDue}              REAL    NOT NULL,
        ${DbConstants.colAmountPaid}            REAL    NOT NULL DEFAULT 0.0,
        ${DbConstants.colBalanceCarriedForward} REAL    NOT NULL DEFAULT 0.0,
        ${DbConstants.colIsCleared}             INTEGER NOT NULL DEFAULT 0,
        ${DbConstants.colRecordedAt}            TEXT,
        FOREIGN KEY (${DbConstants.colTenantId})
          REFERENCES ${DbConstants.tableTenants}(${DbConstants.colId})
      )
    ''');

    // Main Meter Audit
    batch.execute('''
      CREATE TABLE ${DbConstants.tableMainMeterAudit} (
        ${DbConstants.colId}                 INTEGER PRIMARY KEY AUTOINCREMENT,
        ${DbConstants.colMonthYear}          TEXT    NOT NULL UNIQUE,
        ${DbConstants.colMainGridReading}    REAL    NOT NULL,
        ${DbConstants.colTotalSubmeterUnits} REAL    NOT NULL,
        ${DbConstants.colLineLossUnits}      REAL    NOT NULL,
        ${DbConstants.colRecordedAt}         TEXT
      )
    ''');

    // Payments
    batch.execute('''
      CREATE TABLE ${DbConstants.tablePayments} (
        ${DbConstants.colId}           INTEGER PRIMARY KEY AUTOINCREMENT,
        ${DbConstants.colTenantId}     INTEGER NOT NULL,
        ${DbConstants.colMonthYear}    TEXT    NOT NULL,
        ${DbConstants.colAmount}       REAL    NOT NULL,
        ${DbConstants.colPaymentDate}  TEXT    NOT NULL,
        ${DbConstants.colType}         TEXT    NOT NULL,
        ${DbConstants.colPaymentMode}  TEXT,
        ${DbConstants.colPaymentApp}   TEXT,
        FOREIGN KEY (${DbConstants.colTenantId})
          REFERENCES ${DbConstants.tableTenants}(${DbConstants.colId})
      )
    ''');

    await batch.commit(noResult: true);
  }

  // ── Incremental migrations ──────────────────────────────────────────────

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        'ALTER TABLE ${DbConstants.tableTenants} '
        'ADD COLUMN ${DbConstants.colInitialMeterReading} REAL NOT NULL DEFAULT 0.0',
      );
    }
    if (oldVersion < 3) {
      // Add monthly rent to tenants
      await db.execute(
        'ALTER TABLE ${DbConstants.tableTenants} '
        'ADD COLUMN ${DbConstants.colMonthlyRent} REAL NOT NULL DEFAULT 0.0',
      );

      // Create payments table
      await db.execute('''
        CREATE TABLE ${DbConstants.tablePayments} (
          ${DbConstants.colId}           INTEGER PRIMARY KEY AUTOINCREMENT,
          ${DbConstants.colTenantId}     INTEGER NOT NULL,
          ${DbConstants.colMonthYear}    TEXT    NOT NULL,
          ${DbConstants.colAmount}       REAL    NOT NULL,
          ${DbConstants.colPaymentDate}  TEXT    NOT NULL,
          ${DbConstants.colType}         TEXT    NOT NULL,
          FOREIGN KEY (${DbConstants.colTenantId})
            REFERENCES ${DbConstants.tableTenants}(${DbConstants.colId})
        )
      ''');
    }
    if (oldVersion < 5) {
      // Check if columns exist before adding to avoid "duplicate column" errors
      // if people somehow got them in a previous version 4 run.
      // But adding them normally is standard in Flutter sqflite migrations.
      try {
        await db.execute(
          'ALTER TABLE ${DbConstants.tablePayments} '
          'ADD COLUMN ${DbConstants.colPaymentMode} TEXT',
        );
      } catch (_) {}
      try {
        await db.execute(
          'ALTER TABLE ${DbConstants.tablePayments} '
          'ADD COLUMN ${DbConstants.colPaymentApp} TEXT',
        );
      } catch (_) {}
    }
    if (oldVersion < 6) {
      // 1. Deduplicate monthly_logs: Keep the newest (highest id) for each tenant/month
      await db.execute('''
        DELETE FROM ${DbConstants.tableMonthlyLogs}
        WHERE ${DbConstants.colId} NOT IN (
          SELECT MAX(${DbConstants.colId})
          FROM ${DbConstants.tableMonthlyLogs}
          GROUP BY ${DbConstants.colTenantId}, ${DbConstants.colMonthYear}
        )
      ''');

      // 2. Add Unique Index to prevent future duplicates
      await db.execute(
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_tenant_month '
        'ON ${DbConstants.tableMonthlyLogs} (${DbConstants.colTenantId}, ${DbConstants.colMonthYear})'
      );
    }
    if (oldVersion < 7) {
      await db.execute(
        'ALTER TABLE ${DbConstants.tableMonthlyLogs} '
        'ADD COLUMN ${DbConstants.colRecordedAt} TEXT',
      );
    }
    if (oldVersion < 8) {
      await db.execute(
        'ALTER TABLE ${DbConstants.tableMainMeterAudit} '
        'ADD COLUMN ${DbConstants.colRecordedAt} TEXT',
      );
    }
  }

  /// Convenience accessor for raw queries outside of repositories.
  Future<Database> getDb() => database;
}
