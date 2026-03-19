import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/payment.dart';
import '../repositories/payment_repository.dart';

final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  return PaymentRepository();
});

/// Fetches all payments for a specific tenant and month.
final monthPaymentsProvider = FutureProvider.family<List<Payment>, PaymentRequest>((ref, req) async {
  return ref.read(paymentRepositoryProvider).getPaymentsForMonth(req.tenantId, req.monthYear);
});

/// Fetches all payments across all time for a specific tenant (used in Move-Out settlement).
final tenantPaymentsProvider = FutureProvider.family<List<Payment>, int>((ref, tenantId) async {
  return ref.read(paymentRepositoryProvider).getAllPaymentsForTenant(tenantId);
});

class PaymentRequest {
  final int tenantId;
  final String monthYear;

  const PaymentRequest(this.tenantId, this.monthYear);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaymentRequest &&
          runtimeType == other.runtimeType &&
          tenantId == other.tenantId &&
          monthYear == other.monthYear;

  @override
  int get hashCode => tenantId.hashCode ^ monthYear.hashCode;
}

final paymentActionProvider = Provider<_PaymentAction>((ref) {
  return _PaymentAction(ref);
});

class _PaymentAction {
  final Ref ref;

  _PaymentAction(this.ref);

  Future<void> addPayment(Payment payment) async {
    await ref.read(paymentRepositoryProvider).insertPayment(payment);
    // Invalidate caches
    ref.invalidate(monthPaymentsProvider(PaymentRequest(payment.tenantId, payment.monthYear)));
    ref.invalidate(tenantPaymentsProvider(payment.tenantId));
  }
}
