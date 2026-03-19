import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/floating_island_nav.dart';
import '../models/tenant.dart';
import '../providers/tenant_provider.dart';
import '../../billing/presentation/widgets/billing_list_view.dart';
import '../../billing/providers/billing_provider.dart';
import '../../audit/presentation/audit_screen.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../../core/providers/navigation_provider.dart';
import 'tenant_form_screen.dart';
import 'tenant_profile_screen.dart';

/// Main dashboard showing collection overview and active tenant list.
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  Widget build(BuildContext context) {
    final tenantsAsync = ref.watch(activeTenantsProvider);
    final currentNavIndex = ref.watch(navigationProvider);

    return Scaffold(
      extendBody: true, // For transparency under bottom nav
      body: Stack(
        children: [
          _buildBody(tenantsAsync, currentNavIndex),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: FloatingIslandNav(
              currentIndex: currentNavIndex,
              onTap: (i) => ref.read(navigationProvider.notifier).setIndex(i),
            ),
          ),
        ],
      ),
      floatingActionButton: currentNavIndex == 0
          ? Padding(
              padding: const EdgeInsets.only(bottom: 80), // Offset from FloatingNav
              child: FloatingActionButton(
                backgroundColor: KoveColors.kiwiGreen,
                foregroundColor: KoveColors.obsidianBlack,
                onPressed: () async {
                  final result = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(builder: (_) => const TenantFormScreen()),
                  );
                  if (result == true) {
                    ref.read(activeTenantsProvider.notifier).refresh();
                  }
                },
                child: const Icon(Icons.add_rounded, size: 28),
              ),
            )
          : null,
    );
  }

  Widget _buildBody(AsyncValue<List<Tenant>> tenantsAsync, int index) {
    switch (index) {
      case 1:
        return const _BillingListBody();
      case 2:
        return const AuditScreen();
      case 3:
        return const SettingsScreen();
      default:
        return _DashboardHomeShell(tenantsAsync: tenantsAsync);
    }
  }
}

class _DashboardHomeShell extends ConsumerWidget {
  const _DashboardHomeShell({required this.tenantsAsync});

  final AsyncValue<List<Tenant>> tenantsAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topInset = MediaQuery.of(context).padding.top;
    final surfaceColor = isDark ? const Color(0xFF111827) : KoveColors.offWhite;

    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  KoveColors.obsidianBlack,
                  const Color(0xFF1E293B),
                  KoveColors.kiwiGreen.withValues(alpha: isDark ? 0.18 : 0.24),
                ],
              ),
            ),
          ),
        ),
        Positioned.fill(
          top: topInset + 48,
          child: Container(
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.12),
                  blurRadius: 32,
                  offset: const Offset(0, -6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              child: ColoredBox(
                color: surfaceColor,
                child: tenantsAsync.when(
                  data: (tenants) => _DashboardBody(tenants: tenants),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, stack) => Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline_rounded, color: Colors.red, size: 48),
                          const SizedBox(height: 16),
                          Text(
                            'Error: $err',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: () => ref.read(activeTenantsProvider.notifier).refresh(),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DashboardBody extends ConsumerWidget {
  const _DashboardBody({required this.tenants});
  final List<Tenant> tenants;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CustomScrollView(
      slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: 12)),
        const SliverToBoxAdapter(child: _DashboardGreetingHeader()),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
        SliverToBoxAdapter(
          child: _CollectionOverviewCard(tenants: tenants),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: [
                Text(
                  'Active Tenants',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1E293B),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: KoveDecorations.neobrutalist(
                    color: KoveColors.kiwiGreen, 
                    borderRadius: 8,
                    shadowOffset: 2,
                  ),
                  child: Text(
                    '${tenants.length}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      color: KoveColors.obsidianBlack,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (tenants.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(
                  'No active tenants found',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.1, // Denser cards
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => _TenantGridCard(tenant: tenants[index]),
                childCount: tenants.length,
              ),
            ),
          ),
        const SliverToBoxAdapter(
          child: SizedBox(height: kFloatingIslandNavClearance),
        ),
      ],
    );
  }
}

class _DashboardGreetingHeader extends StatelessWidget {
  const _DashboardGreetingHeader();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final highContrastText = isDark ? Colors.white : const Color(0xFF0F172A);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: KoveDecorations.neobrutalist(
              color: KoveColors.kiwiGreen,
              borderRadius: 999,
              shadowOffset: 2,
            ),
            child: const Text(
              'KOVE Dashboard',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 11,
                color: KoveColors.obsidianBlack,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _getGreeting(),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: highContrastText,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Here is the latest view of collections, tenants, and pending rooms.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: isDark ? Colors.white70 : const Color(0xFF475569),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  static String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return 'Good Morning, Aditya';
    if (hour >= 12 && hour < 17) return 'Good Afternoon, Aditya';
    return 'Good Evening, Aditya';
  }
}

class _CollectionOverviewCard extends ConsumerWidget {
  const _CollectionOverviewCard({required this.tenants});
  final List<Tenant> tenants;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tt = Theme.of(context).textTheme;
    final monthYear = DateFormat('yyyy-MM').format(DateTime.now());
    final logsAsync = ref.watch(monthLogsProvider(monthYear));

    double expected = 0;
    double collected = 0;

    logsAsync.whenData((logs) {
      final activeTenantIds = tenants.map((t) => t.id).toSet();
      final relevantLogs = logs.where((l) => activeTenantIds.contains(l.tenantId));
      for (final log in relevantLogs) {
        expected += log.totalDue;
        collected += log.amountPaid;
      }
    });

    final fmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      padding: const EdgeInsets.all(24),
      decoration: isDark 
        ? KoveDecorations.neobrutalist(
            color: KoveColors.obsidianBlack,
            shadowOffset: 6,
          )
        : KoveDecorations.glass(
            isDark: false,
            opacity: 0.9,
            borderRadius: 16,
          ).copyWith(
            border: Border.all(color: KoveColors.obsidianBlack, width: 2),
          ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Monthly Collection',
            style: tt.bodyMedium?.copyWith(
              color: isDark ? Colors.white70 : const Color(0xFF475569),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                fmt.format(collected),
                style: tt.displayLarge?.copyWith(
                  color: KoveColors.kiwiGreen,
                  fontSize: 32,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '/ ${fmt.format(expected)} expected',
                style: tt.bodyMedium?.copyWith(
                  color: isDark ? Colors.white38 : const Color(0xFF64748B),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Simple custom progress bar
          Container(
            height: 8,
            width: double.infinity,
            decoration: BoxDecoration(
              color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(4),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: expected > 0 ? (collected / expected).clamp(0.0, 1.0) : 0,
              child: Container(
                decoration: BoxDecoration(
                  color: KoveColors.kiwiGreen,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TenantGridCard extends ConsumerWidget {
  const _TenantGridCard({required this.tenant});
  final Tenant tenant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tt = Theme.of(context).textTheme;
    if (tenant.id == null) return const SizedBox.shrink();
    
    final logsAsync = ref.watch(tenantLogsProvider(tenant.id!));
    
    double balance = 0;
    String lastPayment = 'No history';
    
    logsAsync.whenData((logs) {
      if (logs.isNotEmpty) {
        balance = logs.first.balanceCarriedForward;
        final lastLog = logs.first;
        if (lastLog.recordedAt != null) {
          try {
            final date = DateTime.parse(lastLog.recordedAt!);
            lastPayment = DateFormat('dd MMM').format(date);
          } catch (_) {}
        }
      }
    });

    final isPaid = balance <= 0;

    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => TenantProfileScreen(tenant: tenant)),
      ),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: KoveDecorations.glass(
          isDark: isDark,
          opacity: isDark ? 0.08 : 0.4,
        ).copyWith(
          border: Border.all(
            color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: KoveDecorations.neobrutalist(
                    color: KoveColors.kiwiGreen,
                    borderRadius: 6,
                    shadowOffset: 1,
                  ),
                  child: Text(
                    tenant.roomNumber,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 10,
                      color: Colors.black,
                    ),
                  ),
                ),
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isPaid ? KoveColors.success : KoveColors.danger,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              tenant.name,
              style: tt.titleMedium?.copyWith(
                fontSize: 14, 
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : KoveColors.obsidianBlack,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              isPaid ? 'Cleared' : '₹${balance.abs().toInt()} Due',
              style: tt.bodySmall?.copyWith(
                color: isPaid ? KoveColors.success : KoveColors.danger,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
            const Divider(height: 12, thickness: 0.5, color: Colors.white10),
            Text(
              'Last: $lastPayment',
              style: tt.bodySmall?.copyWith(
                fontSize: 9,
                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BillingListBody extends StatelessWidget {
  const _BillingListBody();

  @override
  Widget build(BuildContext context) {
    return const BillingListView();
  }
}
