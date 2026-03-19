import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/providers/settings_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/in_app_notification.dart';
import '../../billing/models/monthly_log.dart';
import '../../tenants/models/tenant.dart';
import '../../tenants/providers/tenant_provider.dart';
import '../../billing/repositories/billing_repository.dart';
import '../models/main_meter_audit.dart';
import '../repositories/audit_repository.dart';
import '../../../core/providers/navigation_provider.dart';
import '../providers/audit_provider.dart';

class AuditScreen extends ConsumerStatefulWidget {
  const AuditScreen({super.key});

  @override
  ConsumerState<AuditScreen> createState() => _AuditScreenState();
}

class _AuditScreenState extends ConsumerState<AuditScreen> {
  static const double _compactSheetSize = 0.22;
  static const double _defaultSheetSize = 0.42;
  static const double _maxSheetSize = 0.92;
  static const double _saveButtonHeight = 60;

  final _gridReadingCtrl = TextEditingController();
  final _baselineReadingCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  int _activeTab = 0; // 0: Rooms, 1: History

  double _submeterTotal = 0;
  double _lineLoss = 0;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _showBaselineInput = false;
  String _baselineLabel = 'Last Reading';

  Map<int, Map<String, double>> _roomStatus = {};

  @override
  void initState() {
    super.initState();
    _gridReadingCtrl.addListener(_recalculate);
    _baselineReadingCtrl.addListener(_recalculate);
    _loadSubmeterData();
  }

  Future<void> _loadSubmeterData() async {
    final now = DateTime.now();
    final monthYear = DateFormat('yyyy-MM').format(now);
    final billingRepo = BillingRepository();
    final auditRepo = AuditRepository();
    final settingsService = ref.read(settingsServiceProvider);

    final savedBaseline = settingsService.lastGridReading;
    final prevAudit = await auditRepo.getLatestAuditBefore(monthYear);
    final total = await billingRepo.sumUnitsConsumedForMonth(monthYear);
    final logs = await billingRepo.getLogsForMonth(monthYear);

    final Map<int, Map<String, double>> status = {};
    for (final log in logs) {
      status[log.tenantId] = {
        'curr': log.currMeterReading,
        'units': log.unitsConsumed,
      };
    }

    if (mounted) {
      setState(() {
        if (savedBaseline != null) {
          _baselineReadingCtrl.text = savedBaseline.toStringAsFixed(0);
          _baselineLabel = 'Last Saved Reading';
          _showBaselineInput = false;
        } else if (prevAudit != null) {
          _baselineReadingCtrl.text = prevAudit.mainGridReading.toStringAsFixed(0);
          _baselineLabel = 'Previous Audit Reading';
          _showBaselineInput = false;
        } else {
          _baselineLabel = 'Baseline Reading';
          _showBaselineInput = true;
        }
        _submeterTotal = total;
        _roomStatus = status;
        _isLoading = false;
      });
      _recalculate();
    }
  }

  void _recalculate() {
    final gridReading = double.tryParse(_gridReadingCtrl.text) ?? 0;
    final baseline = double.tryParse(_baselineReadingCtrl.text) ?? 0;
    final monthlyConsumption = gridReading > baseline ? gridReading - baseline : 0.0;
    setState(() {
      _lineLoss = monthlyConsumption - _submeterTotal;
    });
  }

  Future<void> _saveAudit() async {
    final gridReading = double.tryParse(_gridReadingCtrl.text);

    if (gridReading == null || gridReading <= 0) {
      InAppNotification.showError(context, 'Please enter a valid grid reading');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final monthYear = DateFormat('yyyy-MM').format(DateTime.now());
      final audit = MainMeterAudit(
        monthYear: monthYear,
        mainGridReading: gridReading,
        totalSubmeterUnits: _submeterTotal,
        lineLossUnits: _lineLoss,
        recordedAt: DateTime.now().toIso8601String(),
      );

      await AuditRepository().insertAudit(audit);
      await ref.read(settingsServiceProvider).setLastGridReading(gridReading);
      ref.invalidate(allAuditsProvider);
      ref.invalidate(auditForMonthProvider(monthYear));

      if (mounted) {
        InAppNotification.showSuccess(context, 'Audit record saved!');
        ref.read(navigationProvider.notifier).setIndex(0);
      }
    } catch (e) {
      if (mounted) {
        InAppNotification.showError(context, 'Error saving audit: $e');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _formatDisplayDate(String monthYear) {
    try {
      final dt = DateFormat('yyyy-MM').parse(monthYear);
      return DateFormat('MMMM yyyy').format(dt);
    } catch (_) {
      return monthYear;
    }
  }

  bool _matchesSearch(String monthYear, String query) {
    if (query.isEmpty) return true;
    final q = query.toLowerCase().replaceAll('/', '-');
    final displayDate = _formatDisplayDate(monthYear).toLowerCase();
    
    // Check for "March 2026" style
    if (displayDate.contains(q)) return true;
    
    // Check for "03-2026" or "2026-03" style
    final parts = monthYear.split('-');
    if (parts.length == 2) {
      final yyyy = parts[0].toLowerCase();
      final mm = parts[1].toLowerCase();
      
      if (q.contains(yyyy) && q.contains(mm)) return true;
      if ('$mm-$yyyy'.contains(q)) return true;
      if ('$yyyy-$mm'.contains(q)) return true;
    }
    
    return monthYear.toLowerCase().contains(q);
  }

  Future<_AuditHistoryDetails> _loadAuditHistoryDetails(MainMeterAudit audit) async {
    final billingRepo = BillingRepository();
    final auditRepo = AuditRepository();
    final tenantRepo = ref.read(tenantRepositoryProvider);

    final currentLogs = await billingRepo.getLogsForMonth(audit.monthYear);
    final previousAudit = await auditRepo.getLatestAuditBefore(audit.monthYear);
    final allTenants = await tenantRepo.getAllTenants();
    final tenantsById = {
      for (final tenant in allTenants)
        if (tenant.id != null) tenant.id!: tenant,
    };

    final tenantBreakdowns = <_AuditTenantBreakdown>[];
    for (final log in currentLogs) {
      final tenant = tenantsById[log.tenantId];
      if (tenant == null) continue;

      final previousLog =
          await billingRepo.getLatestLogForTenant(log.tenantId, beforeMonth: audit.monthYear);
      tenantBreakdowns.add(
        _AuditTenantBreakdown(
          tenant: tenant,
          currentLog: log,
          previousLog: previousLog,
        ),
      );
    }

    tenantBreakdowns.sort(
      (a, b) => a.tenant.roomNumber.compareTo(b.tenant.roomNumber),
    );

    final fallbackDelta = audit.totalSubmeterUnits + audit.lineLossUnits;
    final rawDelta = previousAudit != null
        ? audit.mainGridReading - previousAudit.mainGridReading
        : fallbackDelta;
    final mainGridDelta = rawDelta > 0 ? rawDelta : math.max(fallbackDelta, 0).toDouble();
    final previousMainReading = previousAudit?.mainGridReading ??
        math.max(audit.mainGridReading - mainGridDelta, 0).toDouble();

    return _AuditHistoryDetails(
      audit: audit,
      previousAudit: previousAudit,
      tenantBreakdowns: tenantBreakdowns,
      mainGridDelta: mainGridDelta,
      previousMainReading: previousMainReading,
    );
  }

  Future<void> _showAuditHistoryDetails(MainMeterAudit audit) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 0.9,
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? KoveColors.obsidianBlack : KoveColors.pureWhite,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border.all(
                color: isDark ? Colors.white12 : Colors.black12,
              ),
            ),
            child: FutureBuilder<_AuditHistoryDetails>(
              future: _loadAuditHistoryDetails(audit),
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('Unable to load breakdown: ${snapshot.error}'),
                    ),
                  );
                }

                final details = snapshot.data!;
                return _AuditHistoryDetailsSheet(
                  details: details,
                  displayDate: _formatDisplayDate(audit.monthYear),
                  formatDisplayDate: _formatDisplayDate,
                  formatRecordedLabel: _formatRecordedLabel,
                );
              },
            ),
          ),
        );
      },
    );
  }

  String _formatRecordedLabel(String? isoDate, String monthYear) {
    if (isoDate != null && isoDate.isNotEmpty) {
      try {
        return DateFormat('dd MMM yyyy').format(DateTime.parse(isoDate));
      } catch (_) {}
    }
    return '${_formatDisplayDate(monthYear)} (date unavailable)';
  }

  @override
  void dispose() {
    _gridReadingCtrl.dispose();
    _baselineReadingCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final auditsAsync = ref.watch(allAuditsProvider);
    final tenantsAsync = ref.watch(activeTenantsProvider);
    final screenHeight = MediaQuery.of(context).size.height;
    final defaultSheetHeight = screenHeight * _defaultSheetSize;
    final contentBottomPadding = defaultSheetHeight + 40;

    final gridReading = double.tryParse(_gridReadingCtrl.text) ?? 0;
    final baseline = double.tryParse(_baselineReadingCtrl.text) ?? 0;
    final consumption = gridReading > baseline ? gridReading - baseline : 0.0;

    return Scaffold(
      backgroundColor: isDark ? KoveColors.obsidianBlack : KoveColors.pureWhite,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                // Main Content
                Column(
                  children: [
                    _buildAppBar(),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(16, 16, 16, contentBottomPadding),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildInputCard(tt, baseline),
                            const SizedBox(height: 20),
                            Text(
                              'Consumption Breakdown',
                              style: tt.titleLarge?.copyWith(
                                color: isDark ? Colors.white : const Color(0xFF1E293B),
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 12),
                            consumption > 0 
                              ? _ConsumptionGauge(
                                  total: consumption,
                                  submeter: _submeterTotal,
                                  loss: _lineLoss,
                                )
                              : Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(32),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.02),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(Icons.electric_meter_outlined, size: 48, color: isDark ? Colors.white24 : Colors.black12),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Awaiting Meter Data',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontWeight: FontWeight.w800,
                                          color: isDark ? Colors.white38 : Colors.black38,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            const SizedBox(height: 28),
                            SizedBox(
                              width: double.infinity,
                              height: _saveButtonHeight,
                              child: ElevatedButton(
                                onPressed: _isSaving ? null : _saveAudit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: KoveColors.kiwiGreen,
                                  foregroundColor: KoveColors.obsidianBlack,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    side: const BorderSide(color: Colors.black, width: 1.5),
                                  ),
                                  elevation: 4,
                                  shadowColor: Colors.black,
                                ),
                                child: _isSaving
                                    ? const CircularProgressIndicator(color: KoveColors.obsidianBlack)
                                    : Text(
                                        'Save Audit Record',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 16,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                // Uber-style Draggable Sheet
                DraggableScrollableSheet(
                  initialChildSize: _defaultSheetSize,
                  minChildSize: _compactSheetSize,
                  maxChildSize: _maxSheetSize,
                  snap: true,
                  snapSizes: const [
                    _compactSheetSize,
                    _defaultSheetSize,
                    _maxSheetSize,
                  ],
                  builder: (context, scrollController) {
                    return Container(
                      decoration: KoveDecorations.glass(
                        isDark: isDark,
                        opacity: 0.95,
                        borderRadius: 32,
                      ).copyWith(
                        border: Border.all(color: isDark ? Colors.white24 : Colors.black, width: 2),
                      ),
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                        child: ListView(
                          controller: scrollController,
                          padding: EdgeInsets.zero,
                          children: [
                            // Drag Handle
                            Center(
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 16),
                                width: 48,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white24 : Colors.black26,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                            
                            // Tabs
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              child: Row(
                                children: [
                                  _buildTab(0, 'Current Status'),
                                  const SizedBox(width: 12),
                                  _buildTab(1, 'History Logs'),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),

                            if (_activeTab == 0)
                              _buildRoomStatusList(tenantsAsync)
                            else
                              _buildHistorySection(auditsAsync),
                            
                            const SizedBox(height: kFloatingIslandNavClearance),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
    );
  }

  Widget _buildAppBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            IconButton(
              onPressed: () => ref.read(navigationProvider.notifier).setIndex(0),
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              style: IconButton.styleFrom(
                backgroundColor: KoveColors.kiwiGreen.withValues(alpha: 0.1),
                padding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(width: 16),
            Text(
              'Grid Audit',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w900,
                fontSize: 24,
                color: Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputCard(TextTheme tt, double baseline) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: KoveDecorations.neobrutalist(
        color: KoveColors.kiwiGreen,
        shadowOffset: 4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Mahavitaran Main Grid',
            style: tt.labelLarge?.copyWith(
              color: KoveColors.obsidianBlack.withValues(alpha: 0.7),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _gridReadingCtrl,
            keyboardType: TextInputType.number,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: KoveColors.obsidianBlack,
            ),
            decoration: const InputDecoration(
              hintText: '00000',
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const Divider(color: Colors.black, thickness: 1.5),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_baselineLabel, style: tt.bodySmall?.copyWith(color: Colors.black54)),
                  Text(
                    '${baseline.toInt()} Units',
                    style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.w700, color: Colors.black),
                  ),
                ],
              ),
              IconButton(
                onPressed: () => setState(() => _showBaselineInput = !_showBaselineInput),
                icon: const Icon(Icons.edit_note_rounded, color: Colors.black),
              )
            ],
          ),
          if (_showBaselineInput) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _baselineReadingCtrl,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white24,
                labelText: 'Baseline Reading',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTab(int index, String label) {
    final isActive = _activeTab == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _activeTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? KoveColors.kiwiGreen : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isActive ? Colors.black : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: isActive ? FontWeight.w900 : FontWeight.w500,
              color: isActive ? KoveColors.obsidianBlack : null,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoomStatusList(AsyncValue<List<Tenant>> tenantsAsync) {
    return tenantsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (tenants) => Column(
        children: tenants.map((t) {
          final data = _roomStatus[t.id];
          final units = data?['units'];
          final isPending = units == null;
          
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            leading: Text(
              t.roomNumber,
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900, fontSize: 18),
            ),
            title: Text(t.name, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(isPending ? 'Log pending' : 'Reading recorded'),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isPending ? KoveColors.danger.withValues(alpha: 0.1) : KoveColors.kiwiGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                isPending ? 'PENDING' : '${units.toInt()} U',
                style: TextStyle(
                  color: isPending ? KoveColors.danger : KoveColors.kiwiGreen,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildHistorySection(AsyncValue<List<MainMeterAudit>> auditsAsync) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final searchTextColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final searchHintColor = isDark ? Colors.white60 : const Color(0xFF64748B);
    final searchIconColor = isDark ? Colors.white70 : const Color(0xFF475569);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (_) => setState(() {}),
            style: TextStyle(
              color: searchTextColor,
              fontWeight: FontWeight.w700,
            ),
            cursorColor: KoveColors.kiwiGreen,
            decoration: InputDecoration(
              hintText: 'Search (e.g. March 2026, 03/2026)',
              hintStyle: TextStyle(
                color: searchHintColor,
                fontWeight: FontWeight.w500,
              ),
              prefixIcon: Icon(Icons.search_rounded, color: searchIconColor),
              filled: true,
              fillColor: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: isDark ? Colors.white12 : const Color(0xFFD1D5DB),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: isDark ? Colors.white12 : const Color(0xFFD1D5DB),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: KoveColors.kiwiGreen,
                  width: 1.5,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        auditsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (audits) {
            final filtered = audits.where((a) => _matchesSearch(a.monthYear, _searchCtrl.text)).toList();
            return Column(
              children: filtered.map((audit) => _HistoryCard(
                audit: audit,
                displayDate: _formatDisplayDate(audit.monthYear),
                onTap: () => _showAuditHistoryDetails(audit),
              )).toList(),
            );
          },
        ),
        const SizedBox(height: 40),
      ],
    );
  }
}

class _ConsumptionGauge extends StatelessWidget {
  final double total;
  final double submeter;
  final double loss;

  const _ConsumptionGauge({
    required this.total,
    required this.submeter,
    required this.loss,
  });

  @override
  Widget build(BuildContext context) {
    if (total <= 0) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final visualLoss = math.max(loss, 0).toDouble();
    final visualTotal = math.max(total, submeter + visualLoss).toDouble();
    final usageRatio =
        visualTotal <= 0 ? 0.0 : (submeter / visualTotal).clamp(0.0, 1.0).toDouble();
    final lossRatio = visualTotal <= 0
        ? 0.0
        : (visualLoss / visualTotal).clamp(0.0, 1.0 - usageRatio).toDouble();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 184,
            width: 184,
            child: CustomPaint(
              painter: _ConsumptionGaugePainter(
                usageRatio: usageRatio,
                lossRatio: lossRatio,
                trackColor: isDark ? Colors.white12 : Colors.black12,
                usageColor: KoveColors.kiwiGreen,
                lossColor: Colors.amber,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${total.toInt()} U',
                      style: GoogleFonts.jetBrainsMono(
                        fontWeight: FontWeight.w900,
                        fontSize: 28,
                        color: isDark ? Colors.white : KoveColors.obsidianBlack,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Grid Delta',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white70 : const Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (loss < 0) ...[
            const SizedBox(height: 12),
            Text(
              'Submeter usage is above the current grid delta, so the gauge shows line loss as 0 U.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : const Color(0xFF475569),
              ),
            ),
          ],
          const SizedBox(height: 20),
          Wrap(
            spacing: 20,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              _LegendItem(
                color: KoveColors.kiwiGreen,
                label: 'Tenant Usage',
                val: '${submeter.toInt()} U',
                icon: Icons.power_rounded,
              ),
              _LegendItem(
                color: Colors.amber,
                label: 'Line Loss',
                val: '${loss.toInt()} U',
                icon: Icons.warning_amber_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ConsumptionGaugePainter extends CustomPainter {
  const _ConsumptionGaugePainter({
    required this.usageRatio,
    required this.lossRatio,
    required this.trackColor,
    required this.usageColor,
    required this.lossColor,
  });

  final double usageRatio;
  final double lossRatio;
  final Color trackColor;
  final Color usageColor;
  final Color lossColor;

  @override
  void paint(Canvas canvas, Size size) {
    final shortestSide = math.min(size.width, size.height);
    final strokeWidth = shortestSide * 0.12;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (shortestSide - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final usagePaint = Paint()
      ..color = usageColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final lossPaint = Paint()
      ..color = lossColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, 0, math.pi * 2, false, trackPaint);

    const gapRadians = 0.12;
    final hasLossSegment = lossRatio > 0;
    final availableSweep = (math.pi * 2) - (hasLossSegment ? gapRadians : 0);
    final usageSweep = availableSweep * usageRatio;
    final lossSweep = availableSweep * lossRatio;
    const startAngle = -math.pi / 2;

    if (usageSweep > 0) {
      canvas.drawArc(rect, startAngle, usageSweep, false, usagePaint);
    }

    if (hasLossSegment && lossSweep > 0) {
      canvas.drawArc(rect, startAngle + usageSweep + gapRadians, lossSweep, false, lossPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ConsumptionGaugePainter oldDelegate) {
    return oldDelegate.usageRatio != usageRatio ||
        oldDelegate.lossRatio != lossRatio ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.usageColor != usageColor ||
        oldDelegate.lossColor != lossColor;
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final String val;
  final IconData icon;

  const _LegendItem({
    required this.color, 
    required this.label, 
    required this.val,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white70 : const Color(0xFF192A3E),
              ),
            ),
            Text(
              val,
              style: GoogleFonts.jetBrainsMono(
                fontWeight: FontWeight.w900,
                fontSize: 13,
                color: color,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final MainMeterAudit audit;
  final String displayDate;
  final VoidCallback onTap;

  const _HistoryCard({
    required this.audit,
    required this.displayDate,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          margin: const EdgeInsets.fromLTRB(24, 0, 24, 12),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isDark ? Colors.white24 : Colors.black12, width: 1),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayDate,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Grid: ${audit.mainGridReading.toInt()} | Sub: ${audit.totalSubmeterUnits.toInt()}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white54 : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${audit.lineLossUnits.toInt()} U',
                    style: const TextStyle(
                      color: Colors.amber,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  const Text('Loss', style: TextStyle(fontSize: 10, color: Colors.amber)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AuditHistoryDetails {
  const _AuditHistoryDetails({
    required this.audit,
    required this.previousAudit,
    required this.tenantBreakdowns,
    required this.mainGridDelta,
    required this.previousMainReading,
  });

  final MainMeterAudit audit;
  final MainMeterAudit? previousAudit;
  final List<_AuditTenantBreakdown> tenantBreakdowns;
  final double mainGridDelta;
  final double previousMainReading;
}

class _AuditTenantBreakdown {
  const _AuditTenantBreakdown({
    required this.tenant,
    required this.currentLog,
    required this.previousLog,
  });

  final Tenant tenant;
  final MonthlyLog currentLog;
  final MonthlyLog? previousLog;
}

class _AuditHistoryDetailsSheet extends StatelessWidget {
  const _AuditHistoryDetailsSheet({
    required this.details,
    required this.displayDate,
    required this.formatDisplayDate,
    required this.formatRecordedLabel,
  });

  final _AuditHistoryDetails details;
  final String displayDate;
  final String Function(String monthYear) formatDisplayDate;
  final String Function(String? isoDate, String monthYear) formatRecordedLabel;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fmt =
        NumberFormat.currency(locale: 'en_IN', symbol: '\u20B9', decimalDigits: 0);
    final mainGridDelta = details.mainGridDelta;

    return Column(
      children: [
        Center(
          child: Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 48,
            height: 6,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.black26,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayDate,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w900,
                    fontSize: 26,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Main meter vs renter-wise electricity breakdown',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _AuditSummaryChip(
                      label: 'Main Grid Delta',
                      value: '${mainGridDelta.toInt()} U',
                      color: isDark ? Colors.white : KoveColors.obsidianBlack,
                    ),
                    _AuditSummaryChip(
                      label: 'Tenant Total',
                      value: '${details.audit.totalSubmeterUnits.toInt()} U',
                      color: KoveColors.kiwiGreen,
                    ),
                    _AuditSummaryChip(
                      label: 'Line Loss',
                      value: '${details.audit.lineLossUnits.toInt()} U',
                      color: Colors.amber,
                    ),
                    _AuditSummaryChip(
                      label: 'Tenant Share',
                      value: mainGridDelta > 0
                          ? '${((details.audit.totalSubmeterUnits / mainGridDelta) * 100).clamp(0, 999).toStringAsFixed(0)}%'
                          : '0%',
                      color: KoveColors.success,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _AuditSectionCard(
                  title: 'Main Meter Readings',
                  child: Column(
                    children: [
                      _AuditReadingTile(
                        label: 'Previous Main Meter',
                        reading: details.previousMainReading,
                        dateLabel: details.previousAudit != null
                            ? formatRecordedLabel(
                                details.previousAudit!.recordedAt,
                                details.previousAudit!.monthYear,
                              )
                            : '${formatDisplayDate(_previousMonth(details.audit.monthYear))} (derived)',
                      ),
                      const SizedBox(height: 12),
                      _AuditReadingTile(
                        label: 'Current Main Meter',
                        reading: details.audit.mainGridReading,
                        dateLabel: formatRecordedLabel(
                          details.audit.recordedAt,
                          details.audit.monthYear,
                        ),
                      ),
                      const Divider(height: 28),
                      _AuditMetricRow(
                        label: 'Main Grid Consumption',
                        value: '${mainGridDelta.toInt()} U',
                      ),
                      _AuditMetricRow(
                        label: 'Renter Total Consumption',
                        value: '${details.audit.totalSubmeterUnits.toInt()} U',
                      ),
                      _AuditMetricRow(
                        label: 'Estimated Loss / Difference',
                        value: '${details.audit.lineLossUnits.toInt()} U',
                        valueColor: Colors.amber,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _AuditSectionCard(
                  title: 'Renter-wise Breakdown',
                  child: details.tenantBreakdowns.isEmpty
                      ? Text(
                          'No renter billing logs were found for this month.',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white60 : const Color(0xFF64748B),
                          ),
                        )
                      : Column(
                          children: [
                            for (final item in details.tenantBreakdowns) ...[
                              _TenantAuditBreakdownCard(
                                item: item,
                                mainGridDelta: mainGridDelta,
                                formatRecordedLabel: formatRecordedLabel,
                                formatDisplayDate: formatDisplayDate,
                                currencyFormat: fmt,
                              ),
                              if (item != details.tenantBreakdowns.last)
                                const SizedBox(height: 12),
                            ],
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static String _previousMonth(String monthYear) {
    try {
      final parsed = DateFormat('yyyy-MM').parse(monthYear);
      return DateFormat('yyyy-MM').format(DateTime(parsed.year, parsed.month - 1));
    } catch (_) {
      return monthYear;
    }
  }
}

class _AuditSectionCard extends StatelessWidget {
  const _AuditSectionCard({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w900,
              fontSize: 18,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _AuditSummaryChip extends StatelessWidget {
  const _AuditSummaryChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white60 : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(
              fontWeight: FontWeight.w900,
              fontSize: 13,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _AuditReadingTile extends StatelessWidget {
  const _AuditReadingTile({
    required this.label,
    required this.reading,
    required this.dateLabel,
  });

  final String label;
  final double reading;
  final String dateLabel;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                dateLabel,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white60 : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
        Text(
          '${reading.toInt()} U',
          style: GoogleFonts.jetBrainsMono(
            fontWeight: FontWeight.w900,
            fontSize: 16,
            color: KoveColors.kiwiGreen,
          ),
        ),
      ],
    );
  }
}

class _AuditMetricRow extends StatelessWidget {
  const _AuditMetricRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white70 : const Color(0xFF475569),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(
              fontWeight: FontWeight.w900,
              color: valueColor ?? (isDark ? Colors.white : KoveColors.obsidianBlack),
            ),
          ),
        ],
      ),
    );
  }
}

class _TenantAuditBreakdownCard extends StatelessWidget {
  const _TenantAuditBreakdownCard({
    required this.item,
    required this.mainGridDelta,
    required this.formatRecordedLabel,
    required this.formatDisplayDate,
    required this.currencyFormat,
  });

  final _AuditTenantBreakdown item;
  final double mainGridDelta;
  final String Function(String? isoDate, String monthYear) formatRecordedLabel;
  final String Function(String monthYear) formatDisplayDate;
  final NumberFormat currencyFormat;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentLog = item.currentLog;
    final previousLog = item.previousLog;
    final share = mainGridDelta > 0
        ? ((currentLog.unitsConsumed / mainGridDelta) * 100).clamp(0, 999).toDouble()
        : 0.0;

    final previousDateLabel = previousLog != null
        ? formatRecordedLabel(previousLog.recordedAt, previousLog.monthYear)
        : _fallbackMoveInLabel(item.tenant.moveInDate);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: KoveDecorations.neobrutalist(
                  color: KoveColors.kiwiGreen,
                  borderRadius: 10,
                  shadowOffset: 2,
                ),
                child: Text(
                  item.tenant.roomNumber,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    color: KoveColors.obsidianBlack,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.tenant.name,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ),
              Text(
                '${currentLog.unitsConsumed.toInt()} U',
                style: GoogleFonts.jetBrainsMono(
                  fontWeight: FontWeight.w900,
                  color: KoveColors.kiwiGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${share.toStringAsFixed(0)}% of the main-grid consumption',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white60 : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 14),
          _AuditReadingTile(
            label: 'Previous Renter Meter',
            reading: currentLog.prevMeterReading,
            dateLabel: previousDateLabel,
          ),
          const SizedBox(height: 10),
          _AuditReadingTile(
            label: 'Current Renter Meter',
            reading: currentLog.currMeterReading,
            dateLabel: formatRecordedLabel(currentLog.recordedAt, currentLog.monthYear),
          ),
          const Divider(height: 24),
          _AuditMetricRow(
            label: 'Electricity Bill',
            value: currencyFormat.format(currentLog.totalElectricityBill),
          ),
          _AuditMetricRow(
            label: 'Month Covered',
            value: formatDisplayDate(currentLog.monthYear),
          ),
        ],
      ),
    );
  }

  static String _fallbackMoveInLabel(String moveInDate) {
    try {
      return DateFormat('dd MMM yyyy').format(DateTime.parse(moveInDate));
    } catch (_) {
      return moveInDate;
    }
  }
}
