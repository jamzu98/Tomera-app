# Work Tracker – Project Specification

A modular, offline-first work tracking app built with Flutter. Personal side-project, single developer, targeting Android first, web later, possibly multi-user in the future.

---

## 1. Vision

One app to manage all types of professional work through configurable **Workspaces** (e.g. DEV, Teaching, Maintenance). Each workspace enables only the modules it needs, so the same app fits a teacher, a developer, or a freelancer. Everything must work fully offline; cloud sync (Supabase) is added later without architectural changes.

## 2. Tech stack

- **Flutter** (latest stable) + Dart, Material 3
- **State management:** Riverpod (with code generation, `riverpod_annotation`)
- **Local database:** Drift (SQLite). Chosen because it also runs on web via WASM, which keeps the offline-first architecture identical across platforms
- **Routing:** go_router
- **Notifications:** flutter_local_notifications + timezone (exact, offline-capable reminders)
- **Future sync:** Supabase (auth + Postgres). Evaluate PowerSync before writing a custom sync layer. Do NOT implement sync in early phases, but design for it (see §5)

## 3. Architecture

Feature-first structure with a clean separation between UI, business logic, and data:

```
lib/
  core/            # theme, utils, constants, router
  data/
    db/            # drift database, tables, DAOs
    repositories/  # repository classes, the only layer widgets talk to (via providers)
  features/
    workspaces/
    calendar/
    tasks/
    notes/
    contacts/
    finance/
    settings/
  sync/            # placeholder, empty until sync phase
```

Rules:
- No business logic in widgets. Widgets consume Riverpod providers; providers call repositories; repositories call DAOs.
- Repositories return `Stream`s from Drift so the UI is reactive to DB changes.
- All IDs are UUIDs (v4), generated client-side.

## 4. Data model

Every table includes these base columns:

| column | type | purpose |
|---|---|---|
| id | TEXT (UUID) | primary key |
| owner_id | TEXT, nullable | null for now; maps to Supabase auth UUID later |
| created_at | INTEGER (epoch ms, UTC) | |
| updated_at | INTEGER (epoch ms, UTC) | updated on every write |
| deleted_at | INTEGER, nullable | soft delete; never hard-delete rows |
| is_dirty | BOOLEAN, default true | pending sync flag, unused until sync phase |

### Entities

**Workspace**
- name, color (int ARGB), icon (string, Material icon name)
- enabled_modules: JSON array of module keys: `calendar`, `tasks`, `notes`, `contacts`, `finance`
- sort_order

**Contact** (generic person or organization)
- name, email, phone, organization, notes_text
- Many-to-many with Workspace via **WorkspaceContact** join table, which carries a `role_label` per workspace (e.g. "student" in Teaching, "client" in DEV). One contact record, different roles per workspace.

**Event**
- workspace_id, title, description, location
- starts_at, ends_at (epoch ms UTC), all_day flag
- Optional recurrence: RRULE string (implement only simple weekly/daily recurrence in early phases, or defer entirely; keep the column)
- Linked contacts via **EventContact** join table

**Task**
- workspace_id, title, description
- status: `open` | `in_progress` | `done`
- due_at (nullable), reminder_at (nullable)
- Optional links: event_id, contact_id (both nullable)
- priority: `low` | `normal` | `high`

**Note**
- workspace_id, title, body (Markdown)
- Optional polymorphic link: parent_type (`workspace` | `event` | `task` | `contact`) + parent_id

**BillableItem**
- workspace_id, contact_id (nullable), event_id (nullable)
- type: `hourly` | `fixed`
- title/description
- For hourly: rate (integer cents), duration_minutes
- For fixed: amount (integer cents)
- currency: string, default `EUR`
- status: `unbilled` | `invoiced` | `paid`
- Computed total: hourly → rate × duration / 60; fixed → amount
- **All money is stored as integer cents. Never floats.**

**TimerSession**
- workspace_id, contact_id (nullable), description
- started_at (epoch ms UTC), stopped_at (nullable, null = running)
- On stop, converts into an hourly BillableItem (user can edit duration/rate before saving)

**Reminder** (if not embedded directly in Task/Event)
- parent_type + parent_id, fire_at, delivered flag

## 5. Sync-readiness rules (apply from day one)

- UUID primary keys everywhere, generated on device
- Soft deletes only (`deleted_at`), queries always filter them out
- `updated_at` bumped on every write; `is_dirty` set true on every local write
- `owner_id` column present but unused
- No auto-increment integers, no server-generated values
- Timestamps stored as UTC epoch ms; convert to local time only in the UI layer

## 6. Feature requirements

### 6.1 Workspaces
- CRUD, color and icon selection, reorder
- Module toggles per workspace: disabling a module hides its UI but never deletes data
- A global "All workspaces" view for calendar and tasks

### 6.2 Calendar
- Week view and agenda (list) view; month view is nice-to-have
- Events colored by workspace
- **Conflict detection:** when creating or editing an event, check for time-range overlaps against ALL workspaces (not only the current one). Overlap logic: `newStart < existingEnd && newEnd > existingStart`, ignoring soft-deleted events. Show a non-blocking warning listing the conflicting events; the user may save anyway
- Back-to-back warning (nice-to-have): flag events in different locations with less than a configurable buffer (default 30 min) between them
- Deadlines from tasks (due_at) appear in agenda view

### 6.3 Tasks
- CRUD, status changes with one tap, group by status or due date
- Filter by workspace, contact, overdue
- Reminder scheduling via local notifications (exact alarms on Android; request the exact-alarm permission gracefully)

### 6.4 Notes
- Markdown editing with simple preview
- Attachable to workspace, event, task, or contact; also standalone
- Full-text search across notes (SQLite FTS5 via Drift)

### 6.5 Contacts
- CRUD, per-workspace role labels
- Contact detail screen shows linked events, tasks, notes, billables, and financial summary (unbilled / invoiced / paid totals)

### 6.6 Finance
- BillableItem CRUD, both hourly and fixed types
- Per-contact default hourly rate (nullable), used to pre-fill new items
- **Work timer:**
  - Start a timer with workspace + optional contact + description
  - Persistent Android notification showing elapsed time and a stop action
  - Must survive process death: persist `started_at` in the DB and compute elapsed time on resume. Never depend on a running Dart isolate or foreground service for correctness; the notification is a convenience layer
  - Only one running timer at a time (v1 constraint)
  - On stop: open an edit sheet (duration rounded per settings, rate pre-filled) and save as an hourly BillableItem
- Duration rounding setting: none / 5 / 15 / 30 min, round up
- Summary screens:
  - Per workspace and per contact: hours this month, unbilled total, invoiced-but-unpaid total, paid this month
  - Monthly overview across workspaces
- CSV export of billable items (share sheet / file save)

### 6.7 Settings
- Theme: system / light / dark. Default styling: clean, minimalist, Material 3 defaults with a restrained accent color
- First day of week, time format
- Duration rounding
- Localization-ready: English first, structure with `flutter_localizations` + ARB files so Finnish can be added without refactoring

## 7. Phasing

Implement in this order. Each phase must leave the app in a working, usable state.

**Phase 1 – MVP**
- Project scaffold, theme, routing, Drift setup with the full schema from §4 (create all tables now even if unused)
- Workspaces CRUD + module toggles
- Tasks CRUD
- Notes CRUD (basic, no FTS yet)
- Calendar week/agenda views, event CRUD, conflict detection

**Phase 2**
- Contacts + role labels + detail screen
- Reminders (tasks and events) with local notifications
- BillableItems CRUD (hourly + fixed), per-contact rates

**Phase 3**
- Work timer with persistent notification and process-death safety
- Finance summary screens
- CSV export
- Notes FTS search

**Phase 4**
- Supabase auth
- Sync (evaluate PowerSync vs custom push/pull with last-write-wins)
- Web build target, treating web as view/edit companion (no reminders/timer notification on web)

**Phase 5 (later)**
- Workspace sharing / multi-user
- Recurring events, home screen widgets, iCal import, templates, simple PDF invoices

## 8. Quality expectations

- Null-safe, lints enabled (`flutter_lints` or stricter)
- Unit tests for: conflict detection logic, billable total calculations, timer elapsed-time calculation, duration rounding
- Repository layer covered by tests against an in-memory Drift database
- No hardcoded strings in widgets; use the ARB localization files from the start
- Meaningful commit per feature; keep the app runnable at every commit

## 9. Out of scope (do not build)

- Payments, invoicing PDFs, VAT handling (maybe later)
- Push notifications (local only)
- Any sync/network code before Phase 4
- iOS-specific work (should not be broken, but not a target yet)
