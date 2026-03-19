import 'dart:io';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../features/tenants/models/tenant.dart';
import '../../features/billing/models/monthly_log.dart';

/// Generates an Excel workbook from a tenant's billing history and
/// triggers the native share sheet so the user can save or send it.
class ExportService {
  ExportService._();

  /// Export [logs] for [tenant] to an .xlsx file and open the share sheet.
  static Future<void> exportTenantHistory(
    Tenant tenant,
    List<MonthlyLog> logs,
  ) async {
    final excel = Excel.createExcel();

    // Rename the default sheet
    final sheetName = 'Room ${tenant.roomNumber}';
    final defaultSheet = excel.getDefaultSheet();
    if (defaultSheet != null) {
      excel.rename(defaultSheet, sheetName);
    }

    final sheet = excel[sheetName];

    // ── Header row ──────────────────────────────────
    final headers = [
      'Month',
      'Prev Reading',
      'Curr Reading',
      'Units',
      'Electricity (₹)',
      'Water (₹)',
      'Rent (₹)',
      'Adjustments (₹)',
      'Total Due (₹)',
      'Amount Paid (₹)',
      'Balance (₹)',
    ];

    for (var i = 0; i < headers.length; i++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0)).value =
          TextCellValue(headers[i]);
    }

    // ── Data rows ───────────────────────────────────
    for (var r = 0; r < logs.length; r++) {
      final log = logs[r];

      // Format month for display (e.g. "Mar 2026")
      String monthLabel = log.monthYear;
      if (log.monthYear == 'SETTLEMENT') {
        monthLabel = 'Settlement';
      } else {
        try {
          final d = DateFormat('yyyy-MM').parse(log.monthYear);
          monthLabel = DateFormat('MMM yyyy').format(d);
        } catch (_) {
          // keep raw
        }
      }

      final row = r + 1;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value =
          TextCellValue(monthLabel);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value =
          DoubleCellValue(log.prevMeterReading);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row)).value =
          DoubleCellValue(log.currMeterReading);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row)).value =
          DoubleCellValue(log.unitsConsumed);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row)).value =
          DoubleCellValue(log.totalElectricityBill);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row)).value =
          DoubleCellValue(log.waterBill);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row)).value =
          DoubleCellValue(log.rentAmount);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: row)).value =
          DoubleCellValue(log.adjustments);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: row)).value =
          DoubleCellValue(log.totalDue);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: row)).value =
          DoubleCellValue(log.amountPaid);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: row)).value =
          DoubleCellValue(log.balanceCarriedForward);
    }

    // ── Save to temp directory ──────────────────────
    final bytes = excel.save();
    if (bytes == null) return;

    final dir = await getTemporaryDirectory();
    final cleanName = tenant.name.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final fileName = 'Room${tenant.roomNumber}_${cleanName}_History.xlsx';
    final filePath = '${dir.path}/$fileName';

    final file = File(filePath);
    await file.writeAsBytes(bytes, flush: true);

    // ── Share via native sheet ──────────────────────
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(filePath)],
        subject: 'Billing History — ${tenant.name} (Room ${tenant.roomNumber})',
      ),
    );
  }

  /// Export a dedicated Settlement Invoice for a moving-out tenant.
  static Future<void> exportSettlementInvoice(
    Tenant tenant,
    MonthlyLog settlementLog,
  ) async {
    final excel = Excel.createExcel();
    final sheetName = 'Settlement_Room_${tenant.roomNumber}';
    final defaultSheet = excel.getDefaultSheet();
    if (defaultSheet != null) {
      excel.rename(defaultSheet, sheetName);
    }

    final sheet = excel[sheetName];

    void writeCell(int col, int row, dynamic val, {bool bold = false}) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row)).value =
          val is double ? DoubleCellValue(val) : TextCellValue(val.toString());
    }

    // ── Header ─────────────────────────────────────
    writeCell(0, 0, 'KOVE FINAL SETTLEMENT INVOICE');
    writeCell(0, 1, 'Tenant Name: ${tenant.name}');
    writeCell(0, 2, 'Room Number: ${tenant.roomNumber}');
    writeCell(0, 3, 'Vacating Date: ${settlementLog.recordedAt != null ? DateFormat('dd MMM yyyy').format(DateTime.parse(settlementLog.recordedAt!)) : 'N/A'}');

    // ── Breakdown ──────────────────────────────────
    writeCell(0, 5, 'Description');
    writeCell(1, 5, 'Amount (₹)');

    writeCell(0, 6, 'Pro-rata Rent');
    writeCell(1, 6, settlementLog.rentAmount);

    writeCell(0, 7, 'Spot Electricity (${settlementLog.unitsConsumed} Units)');
    writeCell(1, 7, settlementLog.totalElectricityBill);

    writeCell(0, 8, 'Unpaid Balances');
    // totalDue = unpaid + rent + elec. So unpaid = totalDue - rent - elec.
    final previousUnpaid = settlementLog.totalDue - settlementLog.rentAmount - settlementLog.totalElectricityBill;
    writeCell(1, 8, previousUnpaid);

    writeCell(0, 10, 'TOTAL DUES');
    writeCell(1, 10, settlementLog.totalDue);

    writeCell(0, 11, 'ADVANCE CREDIT (Paid at Move-in)');
    writeCell(1, 11, settlementLog.amountPaid);

    final net = settlementLog.totalDue - settlementLog.amountPaid;
    writeCell(0, 13, net > 0 ? 'NET PAYABLE BY TENANT' : 'NET REFUND TO TENANT');
    writeCell(1, 13, net.abs());

    // ── Save & Share ────────────────────────────────
    final bytes = excel.save();
    if (bytes == null) return;

    final dir = await getTemporaryDirectory();
    final cleanName = tenant.name.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final fileName = 'Settlement_Room${tenant.roomNumber}_$cleanName.xlsx';
    final filePath = '${dir.path}/$fileName';

    final file = File(filePath);
    await file.writeAsBytes(bytes, flush: true);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(filePath)],
        subject: 'Final Settlement Invoice — ${tenant.name} (Room ${tenant.roomNumber})',
      ),
    );
  }
}
