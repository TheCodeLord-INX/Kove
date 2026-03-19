# Phase 1: Core Backend — Property & Tenant Management App

Offline-first Flutter app for managing rental properties, tenants, monthly billing with electricity metering, and main-grid audit. No cloud backend; all data stays local via SQLite.

## Proposed Changes

### Project Setup

#### [NEW] Flutter project `t_app`
- Create at `c:\Users\adity\OneDrive\Desktop\t_app`
- Feature-first folder structure:

```
lib/
├── main.dart
├── core/
│   ├── database/
│   │   ├── database_helper.dart      # SQLite init, migrations
│   │   └── database_constants.dart   # Table/column name constants
│   └── services/
│       └── billing_engine.dart       # Pure calculation logic
├── features/
│   ├── tenants/
│   │   ├── models/tenant.dart
│   │   ├── providers/tenant_provider.dart
│   │   └── repositories/tenant_repository.dart
│   ├── billing/
│   │   ├── models/monthly_log.dart
│   │   ├── providers/billing_provider.dart
│   │   └── repositories/billing_repository.dart
│   └── audit/
│       ├── models/main_meter_audit.dart
│       ├── providers/audit_provider.dart
│       └── repositories/audit_repository.dart
```

#### Dependencies (`pubspec.yaml`)
| Package | Purpose |
|---|---|
| `flutter_riverpod` | State management |
| `sqflite` | Local SQLite database |
| `path` | DB file path resolution |
| `intl` | Date formatting |
| `workmanager` | Background tasks (Phase 4) |
| `flutter_local_notifications` | Notifications (Phase 4) |
| `excel` | .xlsx export (Phase 3) |
| `path_provider` | File system access (Phase 3) |
| `share_plus` | Native share sheet (Phase 3) |

---

### Database Layer

#### [NEW] [database_constants.dart](file:///c:/Users/adity/OneDrive/Desktop/t_app/lib/core/database/database_constants.dart)
- All table names, column names as `static const String` to prevent typos

#### [NEW] [database_helper.dart](file:///c:/Users/adity/OneDrive/Desktop/t_app/lib/core/database/database_helper.dart)
- Singleton pattern for single DB connection
- `onCreate` (v1): create `tenants`, `monthly_logs`, `main_meter_audit` tables
- `onUpgrade`: version-based `switch` for incremental migrations
- Schema v1:

```sql
-- Tenants
CREATE TABLE tenants (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  room_number TEXT NOT NULL,
  move_in_date TEXT NOT NULL,
  advance_paid REAL NOT NULL DEFAULT 0.0,
  active_status INTEGER NOT NULL DEFAULT 1
);

-- MonthlyLogs
CREATE TABLE monthly_logs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  tenant_id INTEGER NOT NULL,
  month_year TEXT NOT NULL,
  prev_meter_reading REAL NOT NULL,
  curr_meter_reading REAL NOT NULL,
  units_consumed REAL NOT NULL,
  total_electricity_bill REAL NOT NULL,
  water_bill REAL NOT NULL DEFAULT 100.0,
  rent_amount REAL NOT NULL,
  adjustments REAL NOT NULL DEFAULT 0.0,
  total_due REAL NOT NULL,
  amount_paid REAL NOT NULL DEFAULT 0.0,
  balance_carried_forward REAL NOT NULL DEFAULT 0.0,
  is_cleared INTEGER NOT NULL DEFAULT 0,
  FOREIGN KEY (tenant_id) REFERENCES tenants(id)
);

-- MainMeterAudit
CREATE TABLE main_meter_audit (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  month_year TEXT NOT NULL UNIQUE,
  main_grid_reading REAL NOT NULL,
  total_submeter_units REAL NOT NULL,
  line_loss_units REAL NOT NULL
);
```

---

### Data Models

#### [NEW] [tenant.dart](file:///c:/Users/adity/OneDrive/Desktop/t_app/lib/features/tenants/models/tenant.dart)
- Immutable Dart class with `fromMap()`, `toMap()`, `copyWith()`

#### [NEW] [monthly_log.dart](file:///c:/Users/adity/OneDrive/Desktop/t_app/lib/features/billing/models/monthly_log.dart)
- Immutable Dart class with `fromMap()`, `toMap()`, `copyWith()`

#### [NEW] [main_meter_audit.dart](file:///c:/Users/adity/OneDrive/Desktop/t_app/lib/features/audit/models/main_meter_audit.dart)
- Immutable Dart class with `fromMap()`, `toMap()`, `copyWith()`

---

### Billing Engine

#### [NEW] [billing_engine.dart](file:///c:/Users/adity/OneDrive/Desktop/t_app/lib/core/services/billing_engine.dart)
Pure, stateless calculation class:

| Method | Logic |
|---|---|
| `calculateUnitsConsumed(prev, curr)` | `curr - prev` |
| `calculateElectricityBill(units)` | `150 + (units < 60 ? units * 10 : units * 12)` |
| `calculateTotalDue(rent, electricityBill, waterBill, adjustments, previousBalance)` | Sum of all |
| `calculateBalanceCarriedForward(totalDue, amountPaid)` | `totalDue - amountPaid` |

---

### Repositories (CRUD)

#### [NEW] [tenant_repository.dart](file:///c:/Users/adity/OneDrive/Desktop/t_app/lib/features/tenants/repositories/tenant_repository.dart)
- `insertTenant()`, `getActiveTenants()`, `getTenantById()`, `updateTenant()`, `archiveTenant()`

#### [NEW] [billing_repository.dart](file:///c:/Users/adity/OneDrive/Desktop/t_app/lib/features/billing/repositories/billing_repository.dart)
- `insertLog()`, `getLogsForTenant()`, `getLogsForMonth()`, `getLatestLogForTenant()`, `updateLog()`

#### [NEW] [audit_repository.dart](file:///c:/Users/adity/OneDrive/Desktop/t_app/lib/features/audit/repositories/audit_repository.dart)
- `insertAudit()`, `getAuditForMonth()`, `getAllAudits()`

---

### Riverpod Providers

#### [NEW] [tenant_provider.dart](file:///c:/Users/adity/OneDrive/Desktop/t_app/lib/features/tenants/providers/tenant_provider.dart)
- `activeTenantsProvider` — `AsyncNotifier` for the list of active tenants

#### [NEW] [billing_provider.dart](file:///c:/Users/adity/OneDrive/Desktop/t_app/lib/features/billing/providers/billing_provider.dart)
- `billingFormProvider` — manages form state with live calculation preview
- `tenantLogsProvider(tenantId)` — family provider for a tenant's history

#### [NEW] [audit_provider.dart](file:///c:/Users/adity/OneDrive/Desktop/t_app/lib/features/audit/providers/audit_provider.dart)
- `auditProvider` — manages audit creation and line-loss calculation

---

### Audit Screen Polishing (Phase 8.1)
- [x] **Fix DraggableScrollableSheet**: Use `CustomScrollView` with `SliverToBoxAdapter` for the header (handle + tabs) to ensure the sheet is draggable from the header.
- [x] **Accurate Submeter Total**: Update `BillingRepository.sumUnitsConsumedForMonth` to JOIN with `tenants` and only sum units for `active = 1` tenants.
- [x] **Smart Date Formatting**:
    - [x] Create a utility to format `YYYY-MM` to `MMMM yyyy` (e.g., "March 2026").
    - [x] Implement a `matchesQuery` helper that checks multiple formats (`MM/YYYY`, `MM-YYYY`, `Month YYYY`).
- [x] **Persistence for History**: Ensure `allAuditsProvider` is invalidated after saving to show the new log immediately in the history tab.
- [x] **UI Polish**: Use `currentMonth` correctly and ensure labels are "Units" as requested.

### Audit Screen Debugging (Phase 8.2)
- [x] **Data Transparency**: Update Room Status list to show both `Current Reading` and `Units Consumed` to clear confusion.
- [x] **SQL Query Robustness**: Simplify `SUM(MAX(units, 0))` to `SUM(CASE WHEN units > 0 THEN units ELSE 0 END)` to avoid any scalar/aggregate confusion in different SQLite versions.
- [x] **Logging**: Add trace logs to `sumUnitsConsumedForMonth` to verify the `monthYear` being passed and the raw results.

### Cumulative Grid Reading Audit (Phase 8.3)
- [ ] **Repository Update**: Add `getLatestAuditBefore(monthYear)` to fetch the most recent audit for baseline comparison.
- [ ] **Calculation Adjustment**: Monthly Loss = (Current Grid Reading - Previous Grid Reading) - Submeter Total.
- [ ] **UI Reference**: Display the "Previous Month's Reading" in the Audit Screen for user context.
- [ ] **Data Validation**: Ensure consumption is non-negative (curr >= prev).

## Verification Plan

### Automated Tests
- Run `flutter analyze` to confirm no static analysis issues
- Run the app on a connected device or emulator to verify database initialization

### Manual Verification
- User review of all generated files before proceeding to Phase 2 (UI)
