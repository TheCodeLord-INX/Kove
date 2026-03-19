import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../tenants/models/tenant.dart';
import '../../../tenants/providers/tenant_provider.dart';
import '../../models/monthly_log.dart';
import '../../providers/billing_provider.dart';
import '../monthly_billing_screen.dart';

class BillingListView extends ConsumerStatefulWidget {
  const BillingListView({super.key});

  @override
  ConsumerState<BillingListView> createState() => _BillingListViewState();
}

class _BillingListViewState extends ConsumerState<BillingListView> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<_BillingMonthSection> _buildSections(
    List<Tenant> tenants,
    List<MonthlyLog> logs,
  ) {
    final activeTenants = tenants.where((tenant) => tenant.id != null).toList()
      ..sort((a, b) => a.roomNumber.compareTo(b.roomNumber));
    final tenantsById = {
      for (final tenant in activeTenants) tenant.id!: tenant,
    };

    final relevantLogs = logs
        .where((log) => tenantsById.containsKey(log.tenantId) && _isSupportedMonth(log.monthYear))
        .toList();

    final logsByMonth = <String, List<MonthlyLog>>{};
    for (final log in relevantLogs) {
      logsByMonth.putIfAbsent(log.monthYear, () => []).add(log);
    }

    final currentMonth = DateFormat('yyyy-MM').format(DateTime.now());
    final sections = <_BillingMonthSection>[];
    final currentMonthLogs = logsByMonth[currentMonth] ?? const <MonthlyLog>[];
    final currentLogsByTenant = {
      for (final log in currentMonthLogs) log.tenantId: log,
    };

    sections.add(
      _BillingMonthSection(
        monthYear: currentMonth,
        displayMonth: _formatMonthLabel(currentMonth),
        subtitle: 'Current Rental Charges',
        isCurrentMonth: true,
        entries: [
          for (final tenant in activeTenants)
            _BillingMonthEntry(
              tenant: tenant,
              log: currentLogsByTenant[tenant.id],
            ),
        ],
      ),
    );

    final archivedMonths = logsByMonth.keys.where((month) => month != currentMonth).toList()
      ..sort((a, b) => b.compareTo(a));

    for (final month in archivedMonths) {
      final monthLogs = [...?logsByMonth[month]]
        ..sort((a, b) {
          final roomA = tenantsById[a.tenantId]?.roomNumber ?? '';
          final roomB = tenantsById[b.tenantId]?.roomNumber ?? '';
          return roomA.compareTo(roomB);
        });

      final entries = monthLogs
          .map(
            (log) => _BillingMonthEntry(
              tenant: tenantsById[log.tenantId]!,
              log: log,
            ),
          )
          .toList();

      sections.add(
        _BillingMonthSection(
          monthYear: month,
          displayMonth: _formatMonthLabel(month),
          subtitle: 'Monthly Billing Overview',
          isCurrentMonth: false,
          entries: entries,
        ),
      );
    }

    return sections;
  }

  List<_BillingMonthSection> _filterSections(List<_BillingMonthSection> sections) {
    final normalizedQuery = _normalizeQuery(_query);
    if (normalizedQuery.isEmpty) return sections;

    final filteredSections = <_BillingMonthSection>[];
    for (final section in sections) {
      final monthMatches = section.displayMonth.toLowerCase().contains(normalizedQuery) ||
          section.monthYear.toLowerCase().contains(normalizedQuery);

      final entries = monthMatches
          ? section.entries
          : section.entries.where((entry) {
              return entry.tenant.name.toLowerCase().contains(normalizedQuery) ||
                  entry.tenant.roomNumber.toLowerCase().contains(normalizedQuery);
            }).toList();

      if (entries.isNotEmpty) {
        filteredSections.add(section.copyWith(entries: entries));
      }
    }

    return filteredSections;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final searchTextColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final searchHintColor = isDark ? Colors.white60 : const Color(0xFF64748B);
    final searchIconColor = isDark ? Colors.white70 : const Color(0xFF475569);
    final tenantsAsync = ref.watch(activeTenantsProvider);
    final logsAsync = ref.watch(allMonthlyLogsProvider);

    final bodySliver = tenantsAsync.when(
      data: (tenants) => logsAsync.when(
        data: (logs) {
          final sections = _filterSections(_buildSections(tenants, logs));
          if (sections.isEmpty) {
            return SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.search_off_rounded,
                        size: 48,
                        color: isDark ? Colors.white24 : Colors.black26,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No month-wise billing cards match your search',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Try a renter name, room number, or month like March 2026.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          return SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _BillingMonthSectionCard(
                  section: sections[index],
                  onOpenEntry: (entry) async {
                    final result = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => MonthlyBillingScreen(
                          tenant: entry.tenant,
                          targetMonthYear: sections[index].monthYear,
                          existingLog: entry.log,
                        ),
                      ),
                    );

                    if (result == true && entry.tenant.id != null) {
                      ref.invalidate(tenantLogsProvider(entry.tenant.id!));
                      ref.invalidate(allMonthlyLogsProvider);
                    }
                  },
                ),
                childCount: sections.length,
              ),
            ),
          );
        },
        loading: () => const SliverFillRemaining(
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (error, _) => SliverFillRemaining(
          child: Center(child: Text('Error: $error')),
        ),
      ),
      loading: () => const SliverFillRemaining(
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => SliverFillRemaining(
        child: Center(child: Text('Error: $error')),
      ),
    );

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 64, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rental Charges',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w900,
                    fontSize: 28,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Search first, then browse each month\'s billing overview below.',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _searchCtrl,
                  onChanged: (value) => setState(() => _query = value),
                  style: TextStyle(
                    color: searchTextColor,
                    fontWeight: FontWeight.w700,
                  ),
                  cursorColor: KoveColors.kiwiGreen,
                  decoration: InputDecoration(
                    hintText: 'Search month, renter, or room',
                    hintStyle: TextStyle(
                      color: searchHintColor,
                      fontWeight: FontWeight.w500,
                    ),
                    prefixIcon: Icon(Icons.search_rounded, color: searchIconColor),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _query = '');
                            },
                            icon: Icon(Icons.close_rounded, color: searchIconColor),
                          ),
                    filled: true,
                    fillColor:
                        isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide(
                        color: isDark ? Colors.white12 : const Color(0xFFD1D5DB),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide(
                        color: isDark ? Colors.white12 : const Color(0xFFD1D5DB),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: const BorderSide(
                        color: KoveColors.kiwiGreen,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        bodySliver,
        const SliverToBoxAdapter(
          child: SizedBox(height: kFloatingIslandNavClearance),
        ),
      ],
    );
  }

  static String _normalizeQuery(String value) {
    return value.toLowerCase().trim().replaceAll('/', '-');
  }

  static bool _isSupportedMonth(String monthYear) {
    return RegExp(r'^\d{4}-\d{2}$').hasMatch(monthYear);
  }

  static String _formatMonthLabel(String monthYear) {
    try {
      return DateFormat('MMMM yyyy').format(DateFormat('yyyy-MM').parse(monthYear));
    } catch (_) {
      return monthYear;
    }
  }
}

class _BillingMonthSection {
  const _BillingMonthSection({
    required this.monthYear,
    required this.displayMonth,
    required this.subtitle,
    required this.isCurrentMonth,
    required this.entries,
  });

  final String monthYear;
  final String displayMonth;
  final String subtitle;
  final bool isCurrentMonth;
  final List<_BillingMonthEntry> entries;

  int get billedCount => entries.where((entry) => entry.log != null).length;
  int get pendingCount => entries.where((entry) => entry.log == null).length;
  double get totalDue =>
      entries.fold(0, (sum, entry) => sum + (entry.log?.totalDue ?? 0));
  double get amountPaid =>
      entries.fold(0, (sum, entry) => sum + (entry.log?.amountPaid ?? 0));

  _BillingMonthSection copyWith({
    List<_BillingMonthEntry>? entries,
  }) {
    return _BillingMonthSection(
      monthYear: monthYear,
      displayMonth: displayMonth,
      subtitle: subtitle,
      isCurrentMonth: isCurrentMonth,
      entries: entries ?? this.entries,
    );
  }
}

class _BillingMonthEntry {
  const _BillingMonthEntry({
    required this.tenant,
    required this.log,
  });

  final Tenant tenant;
  final MonthlyLog? log;
}

class _BillingMonthSectionCard extends StatelessWidget {
  const _BillingMonthSectionCard({
    required this.section,
    required this.onOpenEntry,
  });

  final _BillingMonthSection section;
  final ValueChanged<_BillingMonthEntry> onOpenEntry;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fmt =
        NumberFormat.currency(locale: 'en_IN', symbol: '\u20B9', decimalDigits: 0);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: KoveDecorations.glass(
        isDark: isDark,
        opacity: isDark ? 0.08 : 0.72,
        borderRadius: 24,
      ).copyWith(
        border: Border.all(
          color: isDark ? Colors.white24 : Colors.black,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      section.displayMonth,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w900,
                        fontSize: 24,
                        letterSpacing: -0.4,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      section.subtitle,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: isDark ? Colors.white60 : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              if (section.isCurrentMonth)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: KoveDecorations.neobrutalist(
                    color: KoveColors.kiwiGreen,
                    borderRadius: 12,
                    shadowOffset: 2,
                  ),
                  child: const Text(
                    'Current',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                      color: KoveColors.obsidianBlack,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _MonthStatPill(
                label: 'Billed',
                value: '${section.billedCount}',
                color: KoveColors.kiwiGreen,
              ),
              _MonthStatPill(
                label: 'Pending',
                value: '${section.pendingCount}',
                color: section.pendingCount == 0 ? KoveColors.success : KoveColors.danger,
              ),
              _MonthStatPill(
                label: 'Total Due',
                value: fmt.format(section.totalDue),
                color: isDark ? Colors.white : KoveColors.obsidianBlack,
              ),
              _MonthStatPill(
                label: 'Collected',
                value: fmt.format(section.amountPaid),
                color: KoveColors.success,
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (section.entries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text(
                'No rentees available in this month section.',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
            )
          else
            Column(
              children: [
                for (final entry in section.entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _TenantBillingStatusCard(
                      entry: entry,
                      monthYear: section.monthYear,
                      onTap: () => onOpenEntry(entry),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _MonthStatPill extends StatelessWidget {
  const _MonthStatPill({
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
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0xFFD1D5DB),
        ),
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
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _TenantBillingStatusCard extends StatelessWidget {
  const _TenantBillingStatusCard({
    required this.entry,
    required this.monthYear,
    required this.onTap,
  });

  final _BillingMonthEntry entry;
  final String monthYear;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final log = entry.log;
    final isBilled = log != null;
    final isPaid = isBilled && log.balanceCarriedForward <= 0;
    final hasPartial = isBilled && log.amountPaid > 0 && !isPaid;
    final fmt =
        NumberFormat.currency(locale: 'en_IN', symbol: '\u20B9', decimalDigits: 0);

    final statusColor = !isBilled
        ? KoveColors.danger
        : isPaid
            ? KoveColors.success
            : Colors.amber;

    final subtitle = !isBilled
        ? 'Log pending for ${_BillingListViewState._formatMonthLabel(monthYear)}'
        : isPaid
            ? 'Bill paid in full'
            : hasPartial
                ? 'Partial payment recorded'
                : 'Bill sent and awaiting payment';

    final summaryValue = !isBilled
        ? ''
        : isPaid
            ? fmt.format(log.amountPaid)
            : fmt.format(log.balanceCarriedForward.abs());

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark ? Colors.white12 : const Color(0xFFD1D5DB),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: isBilled
                      ? statusColor.withValues(alpha: 0.18)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? Colors.white24 : Colors.black,
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Text(
                    entry.tenant.roomNumber,
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      color: isBilled
                          ? (statusColor == Colors.amber
                              ? const Color(0xFF92400E)
                              : KoveColors.obsidianBlack)
                          : (isDark ? Colors.white : Colors.black),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.tenant.name,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                    if (isBilled) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Rent ${fmt.format(log.rentAmount)} • Total ${fmt.format(log.totalDue)}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white60 : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (summaryValue.isNotEmpty)
                    Text(
                      summaryValue,
                      style: GoogleFonts.jetBrainsMono(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        color: statusColor,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Icon(
                    isBilled
                        ? Icons.arrow_forward_ios_rounded
                        : Icons.add_circle_outline_rounded,
                    size: 18,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
