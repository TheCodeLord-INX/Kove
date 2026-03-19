import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/services/export_service.dart';
import '../models/tenant.dart';
import '../providers/tenant_provider.dart';
import '../../billing/models/monthly_log.dart';
import '../../billing/models/payment.dart';
import '../../billing/providers/billing_provider.dart';
import '../../billing/providers/payment_provider.dart';
import '../../billing/presentation/monthly_billing_screen.dart';
import '../../../core/services/billing_engine.dart';
import '../../../core/providers/settings_provider.dart';
import 'tenant_form_screen.dart';

/// KOVE Tenant Profile — Neobrutalist-Lite x Glassmorphism
class TenantProfileScreen extends ConsumerWidget {
  const TenantProfileScreen({super.key, required this.tenant});
  final Tenant tenant;

  void _showSettleAndMoveOutDialog(BuildContext context, WidgetRef ref) async {
    if (tenant.id == null) return;
    final logs = await ref.read(tenantLogsProvider(tenant.id!).future);
    final settings = ref.read(settingsProvider);

    double lastReading = tenant.initialMeterReading;
    String lastReadingDateStr = tenant.moveInDate;
    double unpaidBalances = 0;
    double paymentsThisCycle = 0;
    
    // Logic to separate "Current Month Rent" from "Existing Unpaid Dues"
    DateTime lastBilledDate;
    
    if (logs.isNotEmpty) {
      final lastLog = logs.first;
      lastReading = lastLog.currMeterReading;
      lastReadingDateStr = lastLog.recordedAt ?? tenant.moveInDate;
      
      // Determine if the last log is for the "Current Cycle" we are vacating in
      final vacatingMonthYear = DateFormat('yyyy-MM').format(DateTime.now());
      if (lastLog.monthYear == vacatingMonthYear) {
        // Find how much has been paid in this specific log entry
        paymentsThisCycle = lastLog.totalDue - lastLog.balanceCarriedForward;
        // Legacy dues are any balances carried into this log from the PAST
        unpaidBalances = lastLog.totalDue - lastLog.rentAmount - lastLog.totalElectricityBill - lastLog.waterBill - lastLog.adjustments;
        
        // Set lastBilledDate to the anniversary BEFORE this log
        final moveInDay = DateTime.parse(tenant.moveInDate).day;
        final parts = lastLog.monthYear.split('-');
        final year = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        lastBilledDate = DateTime(year, month - 1, moveInDay);
      } else {
        unpaidBalances = lastLog.balanceCarriedForward;
        lastBilledDate = _getLastBilledDate(logs, tenant);
      }
    } else {
      lastBilledDate = DateTime.parse(tenant.moveInDate);
    }
    
    final formattedLastDate = DateFormat('dd MMM yyyy').format(DateTime.parse(lastReadingDateStr));

    if (!context.mounted) return;

    final fmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final highContrastText = isDark ? Colors.white : const Color(0xFF1E293B);
    showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) {
        DateTime vacatingDate = DateTime.now();
        double moveOutReading = lastReading;
        final readingController = TextEditingController(text: lastReading.toString());

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: isDark ? KoveColors.obsidianBlack : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(color: isDark ? Colors.white12 : Colors.black, width: 2),
              ),
              title: Text(
                'Final Settlement',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w900,
                  color: highContrastText,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Vacating Date Picker
                    Text(
                      'Vacating Date',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: vacatingDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setState(() => vacatingDate = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(color: isDark ? Colors.white24 : Colors.black12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              DateFormat('dd MMMM yyyy').format(vacatingDate),
                              style: TextStyle(color: highContrastText, fontWeight: FontWeight.w600),
                            ),
                            const Icon(Icons.edit_calendar_rounded, size: 20),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 2. Final Meter Reading
                    Text(
                      'Final Meter Reading',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: readingController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (val) {
                        setState(() {
                          moveOutReading = double.tryParse(val) ?? lastReading;
                        });
                      },
                      style: TextStyle(color: highContrastText, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.electric_meter_rounded),
                        filled: true,
                        fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.02),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.black12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Last: $lastReading ($formattedLastDate)',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                      ),
                    ),
                    const Divider(height: 48),

                    // 3. Live Breakdown
                    _buildLiveBreakdown(
                      vacatingDate,
                      moveOutReading,
                      lastReading,
                      unpaidBalances,
                      tenant.advancePaid,
                      settings.copyWith(meterCharge: 150), // Force 150 minimum as requested
                      fmt,
                      isDark,
                      highContrastText,
                      lastBilledDate,
                      paymentsThisCycle,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text('Cancel', style: TextStyle(color: isDark ? Colors.white70 : Colors.black54)),
                ),
                FilledButton(
                  onPressed: () {
                    final result = BillingEngine.calculateSettlement(
                      moveInDateStr: tenant.moveInDate,
                      lastBilledDate: lastBilledDate,
                      monthlyRent: tenant.monthlyRent,
                      lastReading: lastReading,
                      moveOutReading: moveOutReading,
                      moveOutDate: vacatingDate,
                      tier1Rate: settings.tier1Rate,
                      tier2Rate: settings.tier2Rate,
                      tierThreshold: settings.tierThreshold,
                      meterCharge: 150, // Force 150 minimum
                    );

                    final rentCharge = result['monthly_rent_charge'] as double;
                    final extraRent = result['pro_rata_extra'] as double;
                    final elecBill = result['electricity_bill'] as double;
                    
                    // Total Due = Legacy + Current Rent + Pro-rata + Electricity
                    final totalDue = unpaidBalances + rentCharge + extraRent + elecBill;
                    // Final = Total Due - Payments Already Made - Advance
                    final finalSettlement = totalDue - paymentsThisCycle - tenant.advancePaid;

                    // Create final SETTLEMENT log
                    final settlementLog = MonthlyLog(
                      tenantId: tenant.id!,
                      monthYear: 'SETTLEMENT',
                      prevMeterReading: lastReading,
                      currMeterReading: moveOutReading,
                      unitsConsumed: result['electricity_units'],
                      totalElectricityBill: elecBill,
                      rentAmount: rentCharge + extraRent,
                      adjustments: 0,
                      totalDue: totalDue - paymentsThisCycle, // Net due past payments
                      amountPaid: tenant.advancePaid,
                      balanceCarriedForward: finalSettlement,
                      isCleared: true,
                      recordedAt: DateTime.now().toIso8601String(),
                    );

                    Navigator.of(ctx).pop({
                      'log': settlementLog,
                      'result': result,
                    });
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: KoveColors.danger,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Confirm Settlement'),
                ),
              ],
            );
          },
        );
      },
    ).then((data) async {
      if (data == null) return;
      
      final settlementLog = data['log'] as MonthlyLog;
      
      // 1. Save Log
      await ref.read(billingActionProvider).saveMonthlyLog(settlementLog);
      
      // 2. Export one history workbook including the settlement row
      await ExportService.exportTenantHistory(tenant, [...logs, settlementLog]);

      // 3. Archive
      await ref.read(activeTenantsProvider.notifier).archiveTenant(tenant.id!);
      
      if (context.mounted) Navigator.of(context).pop(true);
    });
  }

  Widget _buildLiveBreakdown(
    DateTime vacatingDate,
    double moveOutReading,
    double lastReading,
    double unpaidBalances,
    double advance,
    AppSettings settings,
    NumberFormat fmt,
    bool isDark,
    Color highContrastText,
    DateTime lastBilledDate,
    double paymentsThisCycle,
  ) {
    final result = BillingEngine.calculateSettlement(
      moveInDateStr: tenant.moveInDate,
      lastBilledDate: lastBilledDate,
      monthlyRent: tenant.monthlyRent,
      lastReading: lastReading,
      moveOutReading: moveOutReading,
      moveOutDate: vacatingDate,
      tier1Rate: settings.tier1Rate,
      tier2Rate: settings.tier2Rate,
      tierThreshold: settings.tierThreshold,
      meterCharge: 150, // Force 150 minimum
    );

    final monthlyRentCharge = result['monthly_rent_charge'] as double;
    final proRataExtra = result['pro_rata_extra'] as double;
    final elecBill = result['electricity_bill'] as double;
    final extraDays = result['extra_days'] as int;
    final totalMonths = result['total_months'] as int;

    // Strict Sequence: Total Due = (Final Month Rent) + Extras + Electricity + Unpaid
    final totalDueBeforeCredits = monthlyRentCharge + proRataExtra + elecBill + unpaidBalances;
    final finalSettlement = totalDueBeforeCredits - paymentsThisCycle - advance;

    const labelStyle = TextStyle(fontSize: 13, color: Colors.grey);
    final valueStyle = GoogleFonts.jetBrainsMono(fontWeight: FontWeight.w700, fontSize: 13);

    return Column(
      children: [
        // Show Full Month Rent if it's the cycle end (totalMonths > 0) or if explicitly anniversary
        if (monthlyRentCharge > 0)
          _row(
            totalMonths > 0 ? 'Monthly Rent ($totalMonths mo)' : 'Monthly Rent', 
            fmt.format(monthlyRentCharge), 
            labelStyle, 
            valueStyle
          ),
        if (extraDays > 0)
          _row('Pro-rata Extra ($extraDays days)', fmt.format(proRataExtra), labelStyle, valueStyle),
          
        const SizedBox(height: 8),
        _row('Spot Electricity (Min. ₹150)', fmt.format(elecBill), labelStyle, valueStyle),
        
        const SizedBox(height: 8),
        if (unpaidBalances != 0)
          _row(unpaidBalances > 0 ? 'Existing Unpaid Dues' : 'Previous Overpayments', fmt.format(unpaidBalances.abs()), labelStyle, valueStyle),
        
        const Divider(height: 24),
        _row('TOTAL DUE', fmt.format(totalDueBeforeCredits), labelStyle.copyWith(fontWeight: FontWeight.bold, color: highContrastText), valueStyle.copyWith(fontSize: 14)),
        
        const SizedBox(height: 12),
        if (paymentsThisCycle > 0)
          _row('Payments Received', '-${fmt.format(paymentsThisCycle)}', labelStyle.copyWith(color: KoveColors.kiwiGreen), valueStyle.copyWith(color: KoveColors.kiwiGreen)),
        _row('Advance Adjusted', '-${fmt.format(advance)}', labelStyle.copyWith(color: KoveColors.kiwiGreen), valueStyle.copyWith(color: KoveColors.kiwiGreen)),
        
        const Divider(height: 24),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: finalSettlement > 0 ? KoveColors.danger.withValues(alpha: 0.1) : KoveColors.success.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: _row(
            finalSettlement > 0 ? 'Collect' : 'Refund',
            fmt.format(finalSettlement.abs()),
            TextStyle(fontWeight: FontWeight.w900, color: finalSettlement > 0 ? KoveColors.danger : KoveColors.success),
            GoogleFonts.jetBrainsMono(fontWeight: FontWeight.w900, fontSize: 18, color: finalSettlement > 0 ? KoveColors.danger : KoveColors.success),
          ),
        ),
      ],
    );
  }

  DateTime _getLastBilledDate(List<MonthlyLog> logs, Tenant tenant) {
    if (logs.isEmpty) return DateTime.parse(tenant.moveInDate);
    
    // Most recent log record usually covers the month in its monthYear field
    final lastLog = logs.first;
    try {
      final anniversaryDay = DateTime.parse(tenant.moveInDate).day;
      final parts = lastLog.monthYear.split('-');
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      
      // Calculate the anniversary date for that month
      DateTime lastBilled = DateTime(year, month, anniversaryDay);
      
      // Handle the case where the log covers the full month ending on the anniversary
      // e.g. Log "2026-02" with anniversary 18 means Feb 18 is the start or end?
      // In our model, a log "YYYY-MM" covers the month ending around the 18th of that month.
      // So the period covered is [Prev Month 18, This Month 17]
      // Thus, the "Last Billed Date" is 18th March if the log is for March?
      // Wait, if last log is Feb, lastBilledDate is Feb 18.
      return lastBilled;
    } catch (e) {
      return DateTime.parse(tenant.moveInDate);
    }
  }

  Widget _row(String l, String v, TextStyle ls, TextStyle vs) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(l, style: ls),
        Text(v, style: vs),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (tenant.id == null) return const Scaffold(body: Center(child: Text('Invalid Tenant ID')));
    final tenantAsync = ref.watch(tenantByIdProvider(tenant.id!));
    final displayTenant = tenantAsync.value ?? tenant;
    final logsAsync = ref.watch(tenantLogsProvider(displayTenant.id ?? 0));

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── KOVE App Bar ─────────────────────────────────
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            leading: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              style: IconButton.styleFrom(
                backgroundColor: KoveColors.kiwiGreen.withValues(alpha: 0.1),
                padding: const EdgeInsets.all(12),
              ),
            ),
            actions: [
              IconButton(
                onPressed: () async {
                  final result = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => TenantFormScreen(existingTenant: displayTenant),
                    ),
                  );
                  if (result == true && displayTenant.id != null) {
                    ref.invalidate(tenantByIdProvider(displayTenant.id!));
                  }
                },
                icon: const Icon(Icons.edit_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: KoveColors.kiwiGreen.withValues(alpha: 0.1),
                  padding: const EdgeInsets.all(12),
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'move_out') _showSettleAndMoveOutDialog(context, ref);
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'move_out',
                    child: Row(
                      children: [
                        const Icon(Icons.output_rounded, color: KoveColors.danger, size: 20),
                        const SizedBox(width: 10),
                        Text('Settle & Move Out', style: TextStyle(color: KoveColors.danger)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      KoveColors.kiwiGreen.withValues(alpha: 0.3),
                      isDark ? KoveColors.obsidianBlack : KoveColors.pureWhite,
                    ],
                  ),
                ),
                child: SafeArea(
                  child: _KoveProfileHeader(tenant: displayTenant),
                ),
              ),
            ),
          ),

          // ── Quick Stats Row ──────────────────────────────
          SliverToBoxAdapter(child: _KoveQuickStats(tenant: displayTenant, logsAsync: logsAsync, ref: ref, context: context)),

          // ── Billing History ──────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              child: Text('Billing History', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900, fontSize: 20)),
            ),
          ),

          logsAsync.when(
            data: (logs) {
              if (logs.isEmpty) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.receipt_long_rounded, size: 56, color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.2)),
                        const SizedBox(height: 12),
                        Text('No billing records yet', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 16)),
                        const SizedBox(height: 4),
                        Text('Tap + to log the first bill', style: GoogleFonts.plusJakartaSans(color: Colors.grey)),
                      ],
                    ),
                  ),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _KoveHistoryTile(log: logs[index], tenant: displayTenant),
                    childCount: logs.length,
                  ),
                ),
              );
            },
            loading: () => const SliverFillRemaining(child: Center(child: CircularProgressIndicator())),
            error: (e, s) => SliverFillRemaining(child: Center(child: Text('Error: $e'))),
          ),

          const SliverPadding(padding: EdgeInsets.only(bottom: kFloatingIslandNavClearance)),
        ],
      ),

      // ── FAB ─────────────────────────────────────────
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => MonthlyBillingScreen(tenant: displayTenant)),
          );
          if (result == true) ref.invalidate(tenantLogsProvider(displayTenant.id!));
        },
        backgroundColor: KoveColors.kiwiGreen,
        foregroundColor: KoveColors.obsidianBlack,
        icon: const Icon(Icons.receipt_long_rounded),
        label: Text('New Bill', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: KoveColors.neobrutalistBorder, width: 1.5),
        ),
      ),
    );
  }
}

// ── Profile Header (inside SliverAppBar) ──────────────────────────

class _KoveProfileHeader extends StatelessWidget {
  const _KoveProfileHeader({required this.tenant});
  final Tenant tenant;

  @override
  Widget build(BuildContext context) {
    String sinceLabel = '';
    try {
      final d = DateFormat('yyyy-MM-dd').parse(tenant.moveInDate);
      sinceLabel = 'Since ${DateFormat('MMMM yyyy').format(d)}';
    } catch (e) {
      sinceLabel = tenant.moveInDate;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: KoveDecorations.neobrutalist(
              color: KoveColors.kiwiGreen,
              borderRadius: 12,
              shadowOffset: 3,
            ),
            child: Text(
              tenant.roomNumber,
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w900,
                fontSize: 20,
                color: KoveColors.obsidianBlack,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            tenant.name,
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900, fontSize: 26, letterSpacing: -0.5),
          ),
          Text(
            sinceLabel,
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w500, fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

// ── Quick Stats (Advance + Balance) ───────────────────────────────

class _KoveQuickStats extends StatelessWidget {
  const _KoveQuickStats({required this.tenant, required this.logsAsync, required this.ref, required this.context});
  final Tenant tenant;
  final AsyncValue<List<MonthlyLog>> logsAsync;
  final WidgetRef ref;
  final BuildContext context;

  @override
  Widget build(BuildContext buildCtx) {
    final isDark = Theme.of(buildCtx).brightness == Brightness.dark;
    final fmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    final balance = logsAsync.when(
      data: (logs) => logs.isNotEmpty ? logs.first.balanceCarriedForward : 0.0,
      loading: () => 0.0,
      error: (e, s) => 0.0,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          // Advance Card
          Expanded(
            child: _statCard(
              isDark: isDark,
              icon: Icons.savings_rounded,
              label: 'Advance',
              value: fmt.format(tenant.advancePaid),
              color: KoveColors.kiwiGreen,
              onTap: () => _showAddAdvanceDialog(buildCtx),
            ),
          ),
          const SizedBox(width: 12),
          // Balance Card
          Expanded(
            child: _statCard(
              isDark: isDark,
              icon: balance <= 0 ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
              label: 'Balance',
              value: fmt.format(balance.abs()),
              color: balance <= 0 ? KoveColors.success : KoveColors.danger,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard({
    required bool isDark,
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: KoveDecorations.glass(
          isDark: isDark,
          opacity: isDark ? 0.08 : 0.5,
          borderRadius: 16,
        ).copyWith(
          border: Border.all(color: isDark ? Colors.white24 : Colors.black, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: color),
                const Spacer(),
                if (onTap != null) Icon(Icons.add_circle_outline, size: 18, color: color),
              ],
            ),
            const SizedBox(height: 10),
            Text(label, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 2),
            Text(value, style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.w800, fontSize: 18, color: color)),
          ],
        ),
      ),
    );
  }

  void _showAddAdvanceDialog(BuildContext ctx) {
    final ctrl = TextEditingController();
    final appCtrl = TextEditingController();
    String? paymentMode;

    showDialog(
      context: ctx,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final fieldTextColor = isDark ? Colors.white : const Color(0xFF1E293B);
          final fieldLabelColor = isDark ? Colors.white70 : const Color(0xFF475569);
          final fieldHintColor = isDark ? Colors.white38 : const Color(0xFF64748B);

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: KoveColors.neobrutalistBorder, width: 1.5),
            ),
            title: Text('Add to Advance', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: ctrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    cursorColor: KoveColors.kiwiGreen,
                    style: TextStyle(
                      color: fieldTextColor,
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: InputDecoration(
                      labelStyle: TextStyle(color: fieldLabelColor),
                      hintText: 'e.g. 2500',
                      hintStyle: TextStyle(color: fieldHintColor),
                      labelText: 'Amount (₹)',
                      prefixIcon: Icon(Icons.currency_rupee),
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    // ignore: deprecated_member_use
                    value: paymentMode,
                    decoration: const InputDecoration(
                      labelText: 'Payment Mode (Optional)',
                      prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'CASH', child: Text('Cash')),
                      DropdownMenuItem(value: 'ONLINE', child: Text('Online')),
                    ],
                    onChanged: (val) => setState(() => paymentMode = val),
                  ),
                  if (paymentMode == 'ONLINE') ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: appCtrl,
                      cursorColor: KoveColors.kiwiGreen,
                      style: TextStyle(
                        color: fieldTextColor,
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: InputDecoration(
                        labelStyle: TextStyle(color: fieldLabelColor),
                        hintText: 'e.g. GPay',
                        hintStyle: TextStyle(color: fieldHintColor),
                        labelText: 'Payment App (e.g. GPay)',
                        prefixIcon: Icon(Icons.phone_android),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  final amt = double.tryParse(ctrl.text);
                  if (amt != null && amt > 0) {
                    final payment = Payment(
                      tenantId: tenant.id!,
                      monthYear: DateFormat('yyyy-MM').format(DateTime.now()),
                      amount: amt,
                      paymentDate: DateTime.now().toIso8601String(),
                      type: 'ADVANCE',
                      paymentMode: paymentMode,
                      paymentApp: paymentMode == 'ONLINE' ? appCtrl.text.trim() : null,
                    );
                    await ref.read(paymentActionProvider).addPayment(payment);
                    final updatedTenant = tenant.copyWith(advancePaid: tenant.advancePaid + amt);
                    await ref.read(activeTenantsProvider.notifier).updateTenant(updatedTenant);
                    ref.invalidate(tenantByIdProvider(tenant.id!));
                    if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
                  }
                },
                child: const Text('Add'),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── History Tile ─────────────────────────────────────────────────

class _KoveHistoryTile extends ConsumerWidget {
  const _KoveHistoryTile({required this.log, required this.tenant});
  final MonthlyLog log;
  final Tenant tenant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    final balance = log.balanceCarriedForward;
    final isCleared = balance <= 0;
    final statusColor = isCleared ? KoveColors.success : KoveColors.danger;

    String monthLabel = log.monthYear;
    try {
      final d = DateFormat('yyyy-MM').parse(log.monthYear);
      monthLabel = DateFormat('MMMM yyyy').format(d);
    } catch (e) {
      // keep raw string
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () async {
          final result = await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (_) => MonthlyBillingScreen(
                tenant: tenant,
                targetMonthYear: log.monthYear,
                existingLog: log,
              ),
            ),
          );
          if (result == true) ref.invalidate(tenantLogsProvider(tenant.id!));
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: KoveDecorations.glass(
              isDark: isDark,
              opacity: isDark ? 0.06 : 0.6,
              borderRadius: 16,
            ),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  // Status color strip
                  Container(width: 4, color: statusColor),
                  // Content
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          // Month + Details
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(monthLabel, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 15)),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Text('Billed ', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.grey)),
                                    Text(fmt.format(log.totalDue), style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.w700)),
                                    const SizedBox(width: 12),
                                    Text('Paid ', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.grey)),
                                    Text(fmt.format(log.amountPaid), style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.w700, color: KoveColors.success)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          // Balance + Badge
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                fmt.format(balance.abs()),
                                style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.w800, fontSize: 16, color: statusColor),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  isCleared ? 'Cleared' : 'Due',
                                  style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700, color: statusColor),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
