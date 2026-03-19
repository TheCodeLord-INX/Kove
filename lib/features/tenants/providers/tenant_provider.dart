import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/tenant.dart';
import '../repositories/tenant_repository.dart';

// ── Repository singleton ─────────────────────────────
final tenantRepositoryProvider = Provider<TenantRepository>((ref) {
  return TenantRepository();
});

// ── Active tenants list ──────────────────────────────
final activeTenantsProvider =
    AsyncNotifierProvider<ActiveTenantsNotifier, List<Tenant>>(
  ActiveTenantsNotifier.new,
);

class ActiveTenantsNotifier extends AsyncNotifier<List<Tenant>> {
  @override
  FutureOr<List<Tenant>> build() {
    return ref.read(tenantRepositoryProvider).getActiveTenants();
  }

  /// Reload the list after any mutation.
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(tenantRepositoryProvider).getActiveTenants(),
    );
  }

  /// Add a new tenant and refresh.
  Future<void> addTenant(Tenant tenant) async {
    await ref.read(tenantRepositoryProvider).insertTenant(tenant);
    await refresh();
  }

  /// Update an existing tenant and refresh.
  Future<void> updateTenant(Tenant tenant) async {
    await ref.read(tenantRepositoryProvider).updateTenant(tenant);
    if (tenant.id != null) {
      ref.invalidate(tenantByIdProvider(tenant.id!));
    }
    await refresh();
  }

  /// Soft-archive a tenant and refresh.
  Future<void> archiveTenant(int id) async {
    await ref.read(tenantRepositoryProvider).archiveTenant(id);
    ref.invalidate(tenantByIdProvider(id));
    await refresh();
  }
}

// ── Single tenant by ID ──────────────────────────────
final tenantByIdProvider =
    FutureProvider.family<Tenant?, int>((ref, id) async {
  return ref.read(tenantRepositoryProvider).getTenantById(id);
});
