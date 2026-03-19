# Property & Tenant Management App

## Phase 1: Core Backend (Database, Models, Billing Engine)
- [ ] Create Flutter project with feature-first folder structure
- [ ] Add all required dependencies to pubspec.yaml
- [ ] Build SQLite database helper with `onCreate`/`onUpgrade` migration strategy
- [ ] Define Dart data models (Tenant, MonthlyLog, MainMeterAudit)
- [ ] Build the Billing Engine service class
- [ ] Create Riverpod providers (tenant, billing, audit)
- [ ] Pause for user review

## Phase 2: UI Screens
- [ ] Dashboard screen (collection overview, active tenants, balances)
- [ ] Tenant Profile screen (details, advance, log history)
- [ ] Monthly Billing Form (live preview of Total Due)
- [ ] "25th Day" Audit screen (line loss calculation)
- [ ] Add/Edit Tenant screen

## Phase 3: Data Export & Archiving
- [ ] Archive Tenant feature (query logs, export to .xlsx, share)
- [ ] Soft-delete/archive from active UI

## Phase 4: Background Automation
- [ ] Workmanager daily task (25th check)
- [ ] Local notifications (9 AM, 1 PM, 6 PM)
- [ ] Recurrence logic until all readings logged
