import '../../../core/database/database_constants.dart';

/// Immutable representation of a payment (rent or advance) logged for a tenant.
class Payment {
  final int? id;
  final int tenantId;
  final String monthYear; // Format: YYYY-MM
  final double amount;
  final String paymentDate; // ISO 8601 or YYYY-MM-DD string
  final String type; // 'RENT' or 'ADVANCE'
  final String? paymentMode; // 'CASH' or 'ONLINE', optional
  final String? paymentApp; // App name, optional

  const Payment({
    this.id,
    required this.tenantId,
    required this.monthYear,
    required this.amount,
    required this.paymentDate,
    required this.type,
    this.paymentMode,
    this.paymentApp,
  });

  factory Payment.fromMap(Map<String, dynamic> map) {
    return Payment(
      id: map[DbConstants.colId] as int?,
      tenantId: map[DbConstants.colTenantId] as int,
      monthYear: map[DbConstants.colMonthYear] as String,
      amount: (map[DbConstants.colAmount] as num).toDouble(),
      paymentDate: map[DbConstants.colPaymentDate] as String,
      type: map[DbConstants.colType] as String,
      paymentMode: map[DbConstants.colPaymentMode] as String?,
      paymentApp: map[DbConstants.colPaymentApp] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) DbConstants.colId: id,
      DbConstants.colTenantId: tenantId,
      DbConstants.colMonthYear: monthYear,
      DbConstants.colAmount: amount,
      DbConstants.colPaymentDate: paymentDate,
      DbConstants.colType: type,
      DbConstants.colPaymentMode: paymentMode,
      DbConstants.colPaymentApp: paymentApp,
    };
  }

  Payment copyWith({
    int? id,
    int? tenantId,
    String? monthYear,
    double? amount,
    String? paymentDate,
    String? type,
    String? paymentMode,
    String? paymentApp,
  }) {
    return Payment(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      monthYear: monthYear ?? this.monthYear,
      amount: amount ?? this.amount,
      paymentDate: paymentDate ?? this.paymentDate,
      type: type ?? this.type,
      paymentMode: paymentMode ?? this.paymentMode,
      paymentApp: paymentApp ?? this.paymentApp,
    );
  }

  @override
  String toString() =>
      'Payment(id: $id, tenant: $tenantId, amount: $amount, type: $type)';
}
