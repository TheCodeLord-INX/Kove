import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/providers/settings_provider.dart';
import '../../../core/providers/navigation_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/in_app_notification.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _waterCtrl = TextEditingController();
  final _tier1Ctrl = TextEditingController();
  final _tier2Ctrl = TextEditingController();
  final _thresholdCtrl = TextEditingController();
  final _meterCtrl = TextEditingController();
  final _auditDayCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    _waterCtrl.text = settings.waterCharge.toStringAsFixed(0);
    _tier1Ctrl.text = settings.tier1Rate.toStringAsFixed(0);
    _tier2Ctrl.text = settings.tier2Rate.toStringAsFixed(0);
    _thresholdCtrl.text = settings.tierThreshold.toStringAsFixed(0);
    _meterCtrl.text = settings.meterCharge.toStringAsFixed(0);
    _auditDayCtrl.text = settings.auditDay.toString();
  }

  @override
  void dispose() {
    _waterCtrl.dispose();
    _tier1Ctrl.dispose();
    _tier2Ctrl.dispose();
    _thresholdCtrl.dispose();
    _meterCtrl.dispose();
    _auditDayCtrl.dispose();
    super.dispose();
  }

  void _saveSettings() {
    final notifier = ref.read(settingsProvider.notifier);

    final water = double.tryParse(_waterCtrl.text);
    if (water != null) notifier.setWaterCharge(water);

    final t1 = double.tryParse(_tier1Ctrl.text);
    if (t1 != null) notifier.setTier1Rate(t1);

    final t2 = double.tryParse(_tier2Ctrl.text);
    if (t2 != null) notifier.setTier2Rate(t2);

    final th = double.tryParse(_thresholdCtrl.text);
    if (th != null) notifier.setTierThreshold(th);

    final mc = double.tryParse(_meterCtrl.text);
    if (mc != null) notifier.setMeterCharge(mc);

    final ad = int.tryParse(_auditDayCtrl.text);
    if (ad != null && ad >= 1 && ad <= 28) {
      notifier.setAuditDay(ad);
    } else if (ad != null) {
      InAppNotification.showError(context, 'Audit day must be between 1 and 28.');
      return;
    }

    InAppNotification.showSuccess(context, 'Settings saved');
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              ref.read(navigationProvider.notifier).setIndex(0);
            }
          },
          style: IconButton.styleFrom(
            backgroundColor: KoveColors.kiwiGreen.withValues(alpha: 0.1),
            padding: const EdgeInsets.all(12),
          ),
        ),
        toolbarHeight: 80,
        title: Text(
          'Settings', 
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w900,
            color: Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1E293B),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        children: [
          // ── App Preferences ──────────────────────────
          _sectionHeader('App Preferences'),
          const SizedBox(height: 8),
          Container(
            decoration: KoveDecorations.glass(
              isDark: isDark,
              opacity: isDark ? 0.08 : 0.5,
              borderRadius: 20,
            ).copyWith(
              border: Border.all(color: isDark ? Colors.white24 : Colors.black, width: 1.5),
            ),
            child: Column(
              children: [
                _KoveToggleTile(
                  icon: Icons.dark_mode_rounded,
                  title: 'Dark Mode',
                  subtitle: 'Toggle application theme',
                  value: settings.isDarkMode,
                  onChanged: (val) => ref.read(settingsProvider.notifier).setDarkMode(val),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // ── Billing Rates ───────────────────────────
          Row(
            children: [
              Expanded(child: _sectionHeader('Billing Rates')),
              GestureDetector(
                onTap: _saveSettings,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: KoveDecorations.neobrutalist(
                    color: KoveColors.kiwiGreen,
                    borderRadius: 10,
                    shadowOffset: 2,
                  ),
                  child: Text('Save', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900, fontSize: 13, color: KoveColors.obsidianBlack)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: KoveDecorations.glass(
              isDark: isDark,
              opacity: isDark ? 0.08 : 0.5,
              borderRadius: 20,
            ).copyWith(
              border: Border.all(color: isDark ? Colors.white24 : Colors.black, width: 1.5),
            ),
            child: Column(
              children: [
                _koveRateField('Water Charge', '₹', _waterCtrl, isDark),
                _divider(isDark),
                _koveRateField('Tier 1 Rate / Unit', '₹', _tier1Ctrl, isDark),
                _divider(isDark),
                _koveRateField('Tier 2 Rate / Unit', '₹', _tier2Ctrl, isDark),
                _divider(isDark),
                _koveRateField('Tier Threshold', 'Units', _thresholdCtrl, isDark),
                _divider(isDark),
                _koveRateField('Meter Charge', '₹', _meterCtrl, isDark),
                _divider(isDark),
                _koveRateField('Audit Day', 'Day', _auditDayCtrl, isDark, isInteger: true),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // ── About ──────────────────────────────────
          _sectionHeader('About'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: KoveDecorations.glass(
              isDark: isDark,
              opacity: isDark ? 0.08 : 0.5,
              borderRadius: 20,
            ).copyWith(
              border: Border.all(color: isDark ? Colors.white12 : Colors.black12, width: 1),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: KoveDecorations.neobrutalist(
                        color: KoveColors.kiwiGreen,
                        borderRadius: 10,
                        shadowOffset: 2,
                      ),
                      child: const Icon(Icons.home_work_rounded, size: 20, color: KoveColors.obsidianBlack),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('KOVE', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w900, fontSize: 18)),
                        Text('v1.5.0 • Modern Tenant Management', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: kFloatingIslandNavClearance),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.plusJakartaSans(
        fontWeight: FontWeight.w900, 
        fontSize: 18,
        color: Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1E293B),
      ),
    );
  }

  Widget _divider(bool isDark) {
    return Divider(height: 28, color: isDark ? Colors.white12 : Colors.black12);
  }

  Widget _koveRateField(String label, String unit, TextEditingController controller, bool isDark, {bool isInteger = false}) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Text(label, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 14)),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? Colors.white24 : const Color(0xFF1E293B).withValues(alpha: 0.2), 
                width: 1,
              ),
            ),
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.numberWithOptions(decimal: !isInteger),
              textAlign: TextAlign.end,
              style: GoogleFonts.jetBrainsMono(
                fontWeight: FontWeight.w800, 
                fontSize: 15,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                prefixText: '$unit ',
                prefixStyle: GoogleFonts.plusJakartaSans(
                  fontSize: 10, 
                  fontWeight: FontWeight.w800, 
                  color: isDark ? KoveColors.kiwiGreen.withValues(alpha: 0.7) : KoveColors.kiwiGreen.withValues(alpha: 0.9),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Toggle Tile ──────────────────────────────────────────────────

class _KoveToggleTile extends StatelessWidget {
  const _KoveToggleTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 22, color: KoveColors.kiwiGreen),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title, 
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700, 
                    fontSize: 15,
                    color: Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
                Text(subtitle, style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: KoveColors.kiwiGreen,
            activeTrackColor: KoveColors.kiwiGreen.withValues(alpha: 0.3),
          ),
        ],
      ),
    );
  }
}
