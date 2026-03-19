import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/providers/settings_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/in_app_notification.dart';
import '../../../core/services/billing_engine.dart';
import '../../tenants/models/tenant.dart';
import '../models/monthly_log.dart';
import '../models/payment.dart';
import '../providers/billing_provider.dart';
import '../providers/payment_provider.dart';
import '../repositories/billing_repository.dart';

class MonthlyBillingScreen extends ConsumerStatefulWidget {
  const MonthlyBillingScreen({
    super.key, 
    required this.tenant,
    this.targetMonthYear,
    this.existingLog,
  });
  
  final Tenant tenant;
  final String? targetMonthYear;
  final MonthlyLog? existingLog;

  @override
  ConsumerState<MonthlyBillingScreen> createState() =>
      _MonthlyBillingScreenState();
}

class _MonthlyBillingScreenState extends ConsumerState<MonthlyBillingScreen> {
  final _currReadingCtrl = TextEditingController();
  final _adjustmentsCtrl = TextEditingController();
  final _rentCtrl = TextEditingController();

  double _prevReading = 0;
  String? _prevReadingDate;
  double _previousBalance = 0;
  double _amountPaid = 0;
  bool _isLoading = true;
  bool _isSaving = false;

  late String _monthYear;

  // Computed values
  double _units = 0;
  double _electricityBill = 0;
  double _totalDue = 0;
  double _balance = 0;

  @override
  void initState() {
    super.initState();
    _monthYear = widget.targetMonthYear ?? widget.existingLog?.monthYear ?? DateFormat('yyyy-MM').format(DateTime.now());
    _loadPreviousData();
    _currReadingCtrl.addListener(_recalculate);
    _adjustmentsCtrl.addListener(_recalculate);
    _rentCtrl.addListener(_recalculate);
  }

  Future<void> _loadPreviousData() async {
    final repo = BillingRepository();
    
    final log = widget.existingLog;
    if (log != null) {
      _prevReading = log.prevMeterReading;
      _currReadingCtrl.text = log.currMeterReading.toStringAsFixed(0);
      _adjustmentsCtrl.text = log.adjustments.toStringAsFixed(0);
      _rentCtrl.text = log.rentAmount.toStringAsFixed(0);
      
      _previousBalance = log.totalDue - log.rentAmount - log.totalElectricityBill - log.waterBill - log.adjustments;
      
      final tenantId = widget.tenant.id;
      if (tenantId == null) return;
      
      final previousLog = await repo.getLatestLogForTenant(tenantId, beforeMonth: log.monthYear);
      _prevReadingDate = previousLog?.recordedAt ?? widget.tenant.moveInDate;
    } else {
      final tenantId = widget.tenant.id;
      if (tenantId == null) return;
      
      final latestLog = await repo.getLatestLogForTenant(tenantId);
      _prevReading = latestLog?.currMeterReading ?? widget.tenant.initialMeterReading;
      _prevReadingDate = latestLog?.recordedAt ?? widget.tenant.moveInDate;
      _previousBalance = latestLog?.balanceCarriedForward ?? 0;
      _rentCtrl.text = latestLog?.rentAmount.toStringAsFixed(0) ?? widget.tenant.monthlyRent.toStringAsFixed(0);
    }

    setState(() {
      _isLoading = false;
    });
    _recalculate();
  }

  void _recalculate() {
    final settings = ref.read(settingsProvider);
    final currReading = double.tryParse(_currReadingCtrl.text) ?? _prevReading;
    final adjustments = double.tryParse(_adjustmentsCtrl.text) ?? 0;
    final rent = double.tryParse(_rentCtrl.text) ?? 0;

    final units = BillingEngine.calculateUnitsConsumed(_prevReading, currReading);
    final elecBill = BillingEngine.calculateElectricityBill(
      units,
      tier1Rate: settings.tier1Rate,
      tier2Rate: settings.tier2Rate,
      tierThreshold: settings.tierThreshold,
      meterCharge: settings.meterCharge,
    );
    final totalDue = BillingEngine.calculateTotalDue(
      rent: rent,
      electricityBill: elecBill,
      waterBill: settings.waterCharge,
      adjustments: adjustments,
      previousBalance: _previousBalance,
    );
    final balance = BillingEngine.calculateBalanceCarriedForward(totalDue, _amountPaid);

    setState(() {
      _units = units;
      _electricityBill = elecBill;
      _totalDue = totalDue;
      _balance = balance;
    });
  }

  Future<void> _saveLog() async {
    setState(() => _isSaving = true);

    final notifier = ref.read(billingFormProvider.notifier);
    final currReading = double.tryParse(_currReadingCtrl.text) ?? _prevReading;
    final adjustments = double.tryParse(_adjustmentsCtrl.text) ?? 0;
    final rent = double.tryParse(_rentCtrl.text) ?? 0;

    notifier.setFullState(
      prevReading: _prevReading,
      currReading: currReading,
      rent: rent,
      adjustments: adjustments,
      previousBalance: _previousBalance,
      amountPaid: _amountPaid,
    );

    final tenantId = widget.tenant.id;
    if (tenantId == null) return;

    notifier.saveLog(tenantId, monthYearOverride: _monthYear).then((_) {
      ref.invalidate(tenantLogsProvider(tenantId));
      if (mounted) {
        InAppNotification.showSuccess(context, 'Invoice finalized and saved!');
        Navigator.of(context).pop(true);
      }
    });
  }

  @override
  void dispose() {
    _currReadingCtrl.dispose();
    _adjustmentsCtrl.dispose();
    _rentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tenantId = widget.tenant.id ?? 0;
    final paymentsAsync = ref.watch(monthPaymentsProvider(PaymentRequest(tenantId, _monthYear)));
    final payments = paymentsAsync.value ?? [];
    
    double sumPayments = 0;
    for (final p in payments) {
      if (p.type == 'RENT') sumPayments += p.amount;
    }
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _amountPaid != sumPayments) {
        setState(() => _amountPaid = sumPayments);
        _recalculate();
      }
    });

    final fmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return Scaffold(
      backgroundColor: isDark ? KoveColors.obsidianBlack : KoveColors.pureWhite,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                // Digital Invoice Background Pattern (Subtle)
                Positioned(
                  right: -50,
                  top: 100,
                  child: Opacity(
                    opacity: 0.03,
                    child: Icon(Icons.receipt_long_rounded, size: 300, color: isDark ? Colors.white : Colors.black),
                  ),
                ),

                CustomScrollView(
                  slivers: [
                    _buildSliverAppBar(context),
                    SliverPadding(
                      padding: const EdgeInsets.all(16),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          _buildTenantTopCard(context, fmt),
                          const SizedBox(height: 24),
                          _buildInputSection(context),
                          const SizedBox(height: 24),
                          _BillSummaryCard(
                            units: _units,
                            electricityBill: _electricityBill,
                            rent: double.tryParse(_rentCtrl.text) ?? 0,
                            adjustments: _adjustmentsCtrl.text.isEmpty ? 0 : double.tryParse(_adjustmentsCtrl.text) ?? 0,
                            previousBalance: _previousBalance,
                            totalDue: _totalDue,
                            amountPaid: _amountPaid,
                            balance: _balance,
                            settings: ref.watch(settingsProvider),
                          ),
                          const SizedBox(height: 32),
                          SizedBox(
                            width: double.infinity,
                            height: 60,
                            child: ElevatedButton(
                              onPressed: _isSaving ? null : _saveLog,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: KoveColors.obsidianBlack,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: const BorderSide(color: KoveColors.kiwiGreen, width: 1.5),
                                ),
                              ),
                              child: _isSaving
                                  ? const CircularProgressIndicator(color: Colors.white)
                                  : const Text(
                                      'FINALIZE & SAVE INVOICE',
                                      style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2),
                                    ),
                            ),
                          ),
                          const SizedBox(height: kFloatingIslandNavClearance), // Clearance
                        ]),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 120,
      backgroundColor: Colors.transparent,
      leading: IconButton(
        onPressed: () => Navigator.of(context).pop(),
        icon: const Icon(Icons.close_rounded),
        style: IconButton.styleFrom(backgroundColor: KoveColors.kiwiGreen.withValues(alpha: 0.1)),
      ),
      title: const Text('Digital Invoice'),
      titleTextStyle: GoogleFonts.plusJakartaSans(
        fontWeight: FontWeight.w900,
        fontSize: 20,
        color: Theme.of(context).brightness == Brightness.dark ? Colors.white : KoveColors.obsidianBlack,
      ),
      centerTitle: true,
    );
  }

  Widget _buildTenantTopCard(BuildContext context, NumberFormat fmt) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: KoveDecorations.glass(isDark: isDark),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: KoveDecorations.neobrutalist(color: KoveColors.kiwiGreen, borderRadius: 12, shadowOffset: 3),
            child: Text(
              widget.tenant.roomNumber,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.tenant.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
                Text(_monthYear, style: TextStyle(fontWeight: FontWeight.w500, color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.6))),
              ],
            ),
          ),
          if (_previousBalance > 0)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text('ARREARS', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 10, color: KoveColors.danger)),
                Text(fmt.format(_previousBalance), style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.w700, color: KoveColors.danger)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildInputSection(BuildContext context) {
    return Column(
      children: [
        _KoveInputField(
          label: 'Energy Consumption (kWh)',
          controller: _currReadingCtrl,
          hint: 'Current Reading',
          icon: Icons.electric_meter_rounded,
          helper: 'Prev: ${_prevReading.toInt()} recorded on $_prevReadingDate',
        ),
        const SizedBox(height: 16),
        _KoveInputField(
          label: 'Adjustments (₹)',
          controller: _adjustmentsCtrl,
          hint: 'Extra charges/credits',
          icon: Icons.tune_rounded,
          prefix: '₹',
        ),
        const SizedBox(height: 24),
        Align(
          alignment: Alignment.centerLeft,
          child: Text('Payment History', style: Theme.of(context).textTheme.titleMedium),
        ),
        const SizedBox(height: 12),
        _buildPaymentLedger(),
      ],
    );
  }

  Widget _buildPaymentLedger() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tenantId = widget.tenant.id ?? 0;
    final paymentsAsync = ref.watch(monthPaymentsProvider(PaymentRequest(tenantId, _monthYear)));
    
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white24 : const Color(0xFF1E293B).withValues(alpha: 0.1), 
          width: 1,
        ),
      ),
      child: Column(
        children: [
          paymentsAsync.when(
            data: (payments) {
              final rentPayments = payments.where((p) => p.type == 'RENT').toList();
              if (rentPayments.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('No partial payments recorded', style: TextStyle(color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.5))),
                );
              }
              return Column(
                children: rentPayments.map((p) {
                  DateTime? date;
                  try {
                    date = DateTime.parse(p.paymentDate);
                  } catch (_) {}
                  
                  return ListTile(
                    dense: true,
                    title: Text(
                      date != null ? DateFormat('dd MMM').format(date) : 'Recent',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                    subtitle: Text(
                      _paymentModeLabel(p),
                      style: TextStyle(
                        color: isDark ? Colors.white70 : const Color(0xFF475569),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    trailing: Text(
                      '₹${p.amount.toInt()}', 
                      style: GoogleFonts.jetBrainsMono(
                        fontWeight: FontWeight.w900,
                        color: KoveColors.kiwiGreen,
                      ),
                    ),
                  );
                }).toList(),
              );
            },
            loading: () => const LinearProgressIndicator(),
            error: (err, stack) => const Text('Error loading payments'),
          ),
          InkWell(
            onTap: () => _showAddPaymentDialogWithMode(context),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Colors.black12)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_rounded, size: 20, color: KoveColors.kiwiGreen),
                  SizedBox(width: 8),
                  Text('Add Payment', style: TextStyle(color: KoveColors.kiwiGreen, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  String _paymentModeLabel(Payment payment) {
    final mode = payment.paymentMode?.trim();
    final app = payment.paymentApp?.trim();

    if (mode == null || mode.isEmpty) {
      return 'Payment mode not added';
    }

    if (mode == 'ONLINE' && app != null && app.isNotEmpty) {
      return 'Online - $app';
    }

    if (mode == 'ONLINE') {
      return 'Online';
    }

    if (mode == 'CASH') {
      return 'Cash';
    }

    return mode;
  }

  void _showAddPaymentDialogWithMode(BuildContext context) {
    final ctrl = TextEditingController();
    final appCtrl = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String? paymentMode;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: isDark ? KoveColors.obsidianBlack : Colors.white,
          title: Text(
            'Record Partial Payment',
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF1E293B),
              fontWeight: FontWeight.w900,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    hintText: 'e.g. 1500',
                    prefixIcon: Icon(Icons.currency_rupee_rounded),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: paymentMode,
                  decoration: const InputDecoration(
                    labelText: 'Payment Mode (Optional)',
                    prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'CASH', child: Text('Cash')),
                    DropdownMenuItem(value: 'ONLINE', child: Text('Online')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      paymentMode = value;
                      if (paymentMode != 'ONLINE') {
                        appCtrl.clear();
                      }
                    });
                  },
                ),
                if (paymentMode == 'ONLINE') ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: appCtrl,
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Payment App (Optional)',
                      hintText: 'e.g. GPay',
                      prefixIcon: Icon(Icons.phone_android_rounded),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Cancel',
                style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: KoveColors.kiwiGreen,
                foregroundColor: KoveColors.obsidianBlack,
              ),
              onPressed: () async {
                final amt = double.tryParse(ctrl.text);
                final paymentApp = appCtrl.text.trim();
                if (amt != null && amt > 0) {
                  final payment = Payment(
                    tenantId: widget.tenant.id ?? 0,
                    monthYear: _monthYear,
                    amount: amt,
                    paymentDate: DateTime.now().toIso8601String(),
                    type: 'RENT',
                    paymentMode: paymentMode,
                    paymentApp: paymentMode == 'ONLINE' && paymentApp.isNotEmpty
                        ? paymentApp
                        : null,
                  );
                  await ref.read(paymentActionProvider).addPayment(payment);
                  if (ctx.mounted) Navigator.pop(ctx);
                }
              },
              child: const Text('Record'),
            ),
          ],
        ),
      ),
    );
  }
}

class _KoveInputField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final String? helper;
  final String? prefix;

  const _KoveInputField({
    required this.label,
    required this.controller,
    required this.hint,
    required this.icon,
    this.helper,
    this.prefix,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.02),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? Colors.white24 : Colors.black12, width: 1.5),
          ),
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            style: GoogleFonts.jetBrainsMono(
              fontWeight: FontWeight.w800, 
              fontSize: 18,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
            decoration: InputDecoration(
              icon: Icon(icon, size: 20, color: isDark ? Colors.white60 : KoveColors.obsidianBlack),
              hintText: hint,
              hintStyle: TextStyle(color: isDark ? Colors.white38 : const Color(0xFF64748B)),
              prefixText: prefix,
              prefixStyle: GoogleFonts.plusJakartaSans(
                color: isDark ? KoveColors.kiwiGreen : KoveColors.obsidianBlack,
                fontWeight: FontWeight.w900,
              ),
              border: InputBorder.none,
            ),
          ),
        ),
        if (helper != null) ...[
          const SizedBox(height: 4),
          Text(helper ?? '', style: TextStyle(fontSize: 10, color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.6))),
        ],
      ],
    );
  }
}

class _BillSummaryCard extends StatelessWidget {
  final double units;
  final double electricityBill;
  final double rent;
  final double adjustments;
  final double previousBalance;
  final double totalDue;
  final double amountPaid;
  final double balance;
  final AppSettings settings;

  const _BillSummaryCard({
    required this.units,
    required this.electricityBill,
    required this.rent,
    required this.adjustments,
    required this.previousBalance,
    required this.totalDue,
    required this.amountPaid,
    required this.balance,
    required this.settings,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    
    return Container(
      decoration: BoxDecoration(
        color: isDark ? KoveColors.obsidianBlack : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white : Colors.black, width: 2),
      ),
      child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: KoveColors.kiwiGreen,
                borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
              ),
              child: const Text('TOTAL INVOICE SUMMARY', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Colors.black)),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  _SummaryRow(label: 'Rent', value: fmt.format(rent)),
                  _SummaryRow(label: 'Electricity (${units.toInt()} U)', value: fmt.format(electricityBill)),
                  _SummaryRow(label: 'Water', value: fmt.format(settings.waterCharge)),
                  if (adjustments != 0) _SummaryRow(label: 'Adjustments', value: fmt.format(adjustments)),
                  if (previousBalance > 0) _SummaryRow(label: 'Arrears', value: fmt.format(previousBalance), isRed: true),
                  const Divider(color: Colors.black, thickness: 1.5, height: 32),
                  _SummaryRow(label: 'NET TOTAL', value: fmt.format(totalDue), isBold: true, fontSize: 24),
                  _SummaryRow(label: 'PAID SO FAR', value: fmt.format(amountPaid), isSuccess: true),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: balance <= 0 ? KoveColors.success.withValues(alpha: 0.1) : KoveColors.danger.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        balance <= 0 ? 'STATUS: PAID' : 'OUTSTANDING: ${fmt.format(balance)}',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: balance <= 0 ? KoveColors.success : KoveColors.danger,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;
  final bool isRed;
  final bool isSuccess;
  final double fontSize;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.isBold = false,
    this.isRed = false,
    this.isSuccess = false,
    this.fontSize = 14,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: isBold ? FontWeight.w900 : FontWeight.w500, fontSize: fontSize * 0.8)),
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(
              fontWeight: isBold ? FontWeight.w900 : FontWeight.w700,
              fontSize: fontSize,
              color: isRed ? KoveColors.danger : (isSuccess ? KoveColors.success : null),
            ),
          ),
        ],
      ),
    );
  }
}
