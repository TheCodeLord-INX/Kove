import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/in_app_notification.dart';
import '../models/tenant.dart';
import '../providers/tenant_provider.dart';

/// Add or Edit tenant form with date picker and ₹ prefix for advance.
class TenantFormScreen extends ConsumerStatefulWidget {
  const TenantFormScreen({super.key, this.existingTenant});

  /// Pass an existing tenant to switch to "Edit" mode.
  final Tenant? existingTenant;

  @override
  ConsumerState<TenantFormScreen> createState() => _TenantFormScreenState();
}

class _TenantFormScreenState extends ConsumerState<TenantFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _roomCtrl = TextEditingController();
  final _advanceCtrl = TextEditingController();
  final _initialMeterCtrl = TextEditingController();
  final _monthlyRentCtrl = TextEditingController();

  DateTime _moveInDate = DateTime.now();
  bool _isSaving = false;

  bool get _isEditing => widget.existingTenant != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final t = widget.existingTenant!;
      _nameCtrl.text = t.name;
      _roomCtrl.text = t.roomNumber;
      _advanceCtrl.text = t.advancePaid.toStringAsFixed(0);
      _initialMeterCtrl.text = t.initialMeterReading.toStringAsFixed(0);
      _monthlyRentCtrl.text = t.monthlyRent.toStringAsFixed(0);
      _moveInDate = DateFormat('yyyy-MM-dd').parse(t.moveInDate);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _moveInDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.navyPrimary,
                  onPrimary: Colors.white,
                ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _moveInDate = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final tenant = Tenant(
      id: widget.existingTenant?.id,
      name: _nameCtrl.text.trim(),
      roomNumber: _roomCtrl.text.trim(),
      moveInDate: DateFormat('yyyy-MM-dd').format(_moveInDate),
      advancePaid: double.tryParse(_advanceCtrl.text) ?? 0,
      initialMeterReading: double.tryParse(_initialMeterCtrl.text) ?? 0,
      monthlyRent: double.tryParse(_monthlyRentCtrl.text) ?? 0,
      activeStatus: true,
    );

    final notifier = ref.read(activeTenantsProvider.notifier);

    if (_isEditing) {
      await notifier.updateTenant(tenant);
      if (tenant.id != null) {
        ref.invalidate(tenantByIdProvider(tenant.id!));
      }
    } else {
      await notifier.addTenant(tenant);
    }

    if (mounted) {
      InAppNotification.showSuccess(
        context,
        _isEditing ? 'Tenant updated!' : 'Tenant added!',
      );
      Navigator.of(context).pop(true);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _roomCtrl.dispose();
    _advanceCtrl.dispose();
    _initialMeterCtrl.dispose();
    _monthlyRentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _isEditing ? 'Edit Tenant' : 'Add New Tenant',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w900,
            color: Theme.of(context).brightness == Brightness.dark ? Colors.white : KoveColors.obsidianBlack,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 40),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // ── Form card ───────────────────────────────
              Card(
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Full Name
                      _buildLabel('Full Name'),
                      const SizedBox(height: 8),
                        TextFormField(
                          controller: _nameCtrl,
                          textCapitalization: TextCapitalization.words,
                          style: TextStyle(
                            fontSize: 16,
                            color: Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1E293B),
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: _inputDecor(
                            hint: 'e.g. Ramesh Patil',
                            icon: Icons.person_rounded,
                          ),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                        ),

                      const SizedBox(height: 20),

                      // Room Number
                      _buildLabel('Room Number'),
                      const SizedBox(height: 8),
                        TextFormField(
                          controller: _roomCtrl,
                          style: TextStyle(
                            fontSize: 16,
                            color: Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1E293B),
                            fontWeight: FontWeight.w700,
                          ),
                          decoration: _inputDecor(
                            hint: 'e.g. 101',
                            icon: Icons.door_front_door_rounded,
                          ),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'Room number is required' : null,
                        ),

                      const SizedBox(height: 20),

                      // Move-in Date
                      _buildLabel('Move-in Date'),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: _pickDate,
                        borderRadius: BorderRadius.circular(12),
                        child: InputDecorator(
                          decoration: _inputDecor(
                            hint: '',
                            icon: Icons.calendar_month_rounded,
                          ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    DateFormat('dd MMMM yyyy').format(_moveInDate),
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Theme.of(context).brightness == Brightness.dark 
                                          ? Colors.white 
                                          : const Color(0xFF1E293B),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Icon(
                                    Icons.edit_calendar_rounded,
                                    size: 20, 
                                    color: Theme.of(context).brightness == Brightness.dark 
                                        ? Colors.white60 
                                        : Colors.black54,
                                  ),
                                ],
                              ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Monthly Rent
                      _buildLabel('Monthly Rent'),
                      const SizedBox(height: 8),
                        TextFormField(
                          controller: _monthlyRentCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 16,
                            color: Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1E293B),
                            fontWeight: FontWeight.w800,
                          ),
                          decoration: _inputDecor(
                            hint: 'e.g. 5000',
                            icon: Icons.currency_rupee_rounded,
                            prefixText: '₹ ',
                          ),
                        ),
                      const SizedBox(height: 4),
                      Text(
                        'Fixed rent amount due each month',
                        style: tt.bodyMedium?.copyWith(fontSize: 12),
                      ),

                      const SizedBox(height: 20),

                      // Advance Deposit
                      _buildLabel('Advance Deposit Paid'),
                      const SizedBox(height: 8),
                        TextFormField(
                          controller: _advanceCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 16,
                            color: Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1E293B),
                            fontWeight: FontWeight.w800,
                          ),
                          decoration: _inputDecor(
                            hint: '0',
                            icon: Icons.account_balance_wallet_rounded,
                            prefixText: '₹ ',
                          ),
                        ),
                      const SizedBox(height: 4),
                      Text(
                        'Security deposit or advance amount',
                        style: tt.bodyMedium?.copyWith(fontSize: 12),
                      ),

                      const SizedBox(height: 20),

                      // Initial Meter Reading
                      _buildLabel('Initial Meter Reading'),
                      const SizedBox(height: 8),
                        TextFormField(
                          controller: _initialMeterCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 16,
                            color: Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF1E293B),
                            fontWeight: FontWeight.w800,
                          ),
                          decoration: _inputDecor(
                            hint: '0',
                            icon: Icons.electric_meter_rounded,
                          ),
                        ),
                      const SizedBox(height: 4),
                      Text(
                        'Meter reading on move-in date',
                        style: tt.bodyMedium?.copyWith(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Save button ─────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: FilledButton(
                  onPressed: _isSaving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.navyPrimary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white),
                        )
                      : Text(
                          _isEditing ? 'Update Tenant' : 'Save Tenant',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleMedium,
    );
  }

  InputDecoration _inputDecor({
    required String hint,
    required IconData icon,
    String? prefixText,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InputDecoration(
      prefixIcon: Icon(icon, color: isDark ? Colors.white60 : KoveColors.obsidianBlack),
      prefixText: prefixText,
      prefixStyle: GoogleFonts.plusJakartaSans(
        color: isDark ? KoveColors.kiwiGreen : KoveColors.obsidianBlack,
        fontWeight: FontWeight.w900,
      ),
      hintText: hint,
      hintStyle: TextStyle(color: isDark ? Colors.white38 : const Color(0xFF64748B)),
      filled: true,
      fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.02),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.black12),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.black12),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: KoveColors.kiwiGreen, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: KoveColors.danger),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}
