# CLAUDE.md — 3by5 Task Manager

## What This Project Is

3by5 is a beautiful, native Mac task manager built in Flutter and Dart. It takes
its name and visual metaphor from physical 3×5 index cards. The app is designed
to be genuinely gorgeous — warm paper aesthetics, tactile animations, and a feel
that no other task manager has — while remaining fast, focused, and practical.

The primary platform is macOS desktop. The architecture is cross-platform from
day one (Flutter) so iOS, Android, Windows, and Linux are future targets. Every
architectural decision should avoid painting us into a corner on those platforms.

This is a personal productivity app for a single user (no multi-user features).
Local SQLite storage is the source of truth. Cloud sync is a future phase.

---

## Tech Stack

- **Framework:** Flutter 3.x / Dart 3.x (null safety throughout)
- **Database:** SQLite via the Drift package with FTS5 enabled
- **State management:** Riverpod
- **Local storage:** Drift + sqlite3_flutter_libs (bundled SQLite — do not use system SQLite)
- **Image storage:** Files on disk in the app's local support directory; paths stored in DB
- **Date parsing:** jiffy package for relative date expressions
- **Markdown rendering:** flutter_markdown (used in the help system)

---

## Project Structure

```
lib/
├── data/           # Drift database, tables, DAOs, repositories
│   ├── database/   # Drift schema, migrations, database class
│   ├── tables/     # Drift table definitions
│   ├── daos/       # Data Access Objects
│   └── repositories/ # One repository per entity (cards, tasks, notes etc)
├── domain/         # Business logic, use cases, service interfaces
│   ├── enums/      # AppView, TaskColumn, Priority, CardStatus etc
│   ├── services/   # Domain service implementations
│   │               # (VoiceService, CalendarService, RecurrenceService,
│   │               #  DateParsingService, UrlFetchService, WindowStateService,
│   │               #  EmailClipService)
│   └── undo/       # UndoManager and UndoAction sealed hierarchy
├── presentation/   # UI — views, widgets, providers
│   ├── views/      # Top-level screens (card_view, kanban_view etc)
│   ├── widgets/    # Reusable widgets
│   ├── providers/  # Riverpod providers
│   ├── shell/      # AppShell, Sidebar, AppView extensions
│   └── utils/      # Quill editor utilities
└── core/           # Constants, theme, utilities, extensions
    ├── constants/  # AppConstants
    ├── theme/      # AppColors, AppTheme, AppTypography, AppSpacing, AppShadows
    ├── extensions/ # Dart extension methods
    ├── router/     # Navigation / routing
    └── services/   # Platform service implementations
                    # BackupService, ExportService

macos/              # macOS platform code
docs/               # User documentation (markdown, bundled as Flutter assets)
```

---

## Data Model

Understand this fully before making any schema changes.

**Stack** — top-level organisational unit. Cards belong to a stack.
Fields: uuid, name, color (ARGB int), icon (nullable), sort_order,
created_at, deleted_at

**Card** — the primary unit. Belongs to a stack.
Fields: uuid, stack_id, date, project_title, status (active/archived/expanded),
is_hidden (bool — true = permanently hidden with no resurface date),
hidden_until (null=visible, future date=snoozed),
sort_order, created_at, updated_at, deleted_at

**Task** — belongs to a card.
Fields: uuid, card_id, column_name (now/later), title,
description (Quill Delta JSON, nullable),
is_completed (bool), completed_at (nullable),
due_date (nullable), reminder_at (nullable),
rrule (RFC 5545 recurrence rule, nullable),
priority (high/normal/low), kanban_stage_id (FK to BoardColumns, nullable),
sort_order, created_at, updated_at, deleted_at

**Note** — belongs to a task. Has: body text, created_at (auto-set on
creation), updated_at (null until first edit, then updated on every save),
deleted_at (soft delete). Notes are editable after creation. The UI shows
the created_at timestamp and a subtle edited indicator when updated_at is
set. Notes can be deleted via soft delete — deleted_at IS NULL is filtered
in all queries.
Fields: uuid, task_id, body, created_at, updated_at (nullable), deleted_at (nullable)

**Attachment** — belongs to a task only (not to notes).
Types: image (file path), link (url + link_title + favicon_url), email_clip
(subject, sender, body_snippet, source_client, original_date)
Fields: uuid, task_id, type, file_path, url, link_title, favicon_url,
email_sender, email_subject, email_body_snippet, email_source_client,
email_original_date, created_at, deleted_at

**Tag** — many-to-many with tasks via task_tags join table.
Fields: uuid, name (unique), color (nullable ARGB int), created_at

**Settings** — key-value store for app preferences and state persistence.
Hard-deleted by design (see Architecture Rules). No soft delete.
Fields: key (PK), value

**BoardColumn** — defines the stages in the Kanban and Board views.
Seeded with: To Do, In Progress, Pending, Done.
Hard-deleted by design (see Architecture Rules). No soft delete.
Fields: id (text PK), title, sort_order, color (nullable ARGB int)

**CalendarEvent** — read-only cache of Google Calendar events (Phase 2).
**Table does not exist in the schema yet** — this is the planned shape only.
Fields: uuid, external_id, title, start_datetime, end_datetime,
calendar_name, color, url, synced_at

All tables use UUID primary keys. Soft-delete tables have created_at and
deleted_at; tables with mutable fields also have updated_at. See Architecture
Rules for sanctioned hard-delete exceptions.

---

## Schema Migrations

Every schema change requires a Drift migration. This is critical.

- Increment the database schema version number
- Write a migration step for every change — addColumn, createTable, etc.
- Always provide a default value for new non-nullable columns
- Test that existing data survives the migration intact
- Never drop a column or table in a migration — mark as unused instead
- Always show me the migration code before applying it

Current schema version: 5

---

## Architecture Rules

**Separation of concerns — strictly enforced:**
- UI widgets never query the database directly — always via Riverpod providers
- Riverpod providers never contain business logic — delegate to repositories or services
- Repositories never contain UI logic
- Services (BackupService, ExportService, etc.) are injected via Riverpod — never instantiated directly in widgets
- Platform-specific code lives in core/services/ or domain/services/ and is always behind an interface — never inline in widgets or providers

**Riverpod patterns:**
- Use AsyncNotifierProvider for async state with loading/error states
- Use StreamProvider for reactive database queries (Drift watch() queries)
- Use StateNotifierProvider for complex UI state
- Always handle loading and error states in the UI — never assume data is available
- Invalidate providers explicitly after mutations — do not rely on automatic invalidation

**Drift patterns:**
- All database queries go through DAOs — never write raw SQL in repositories
- Use watch() for reactive queries that the UI subscribes to
- Use get() for one-shot queries in services and export/backup operations
- FTS5 search queries go through the dedicated search DAO
- Always filter out soft-deleted records (deleted_at IS NULL) in every query

**Sanctioned hard-delete exceptions** — the following tables are
hard-deleted by design and are exempt from the soft-delete rule:
Tags, TaskTags, BoardColumns, Settings. All other tables use soft
deletes via deleted_at.

**File operations:**
- Never modify original image files — copy only
- Always write to a temp file first, then rename on success (atomic writes)
- Always clean up temp directories in finally blocks — no temp files left on disk
- Always check available disk space before large operations (backup, export)

---

## UI and Visual Design

The visual identity of this app is its most important differentiator. Every UI
decision should serve the warm, paper-like card aesthetic.

**Color palette:** Cream/ivory card backgrounds, warm neutrals, subtle shadows.
Dark and sepia themes are defined but not yet fully styled — use the theme
system correctly so all three themes work when fully implemented.

**Typography:** Lato or Nunito for UI text. Caveat for handwritten accents.
Google Fonts package handles font loading.

**Animations:** Smooth and physical. Cards feel weighted. Transitions feel
motivated. Never use instant state changes where a brief animation would
communicate what happened. Target 60fps — profile before assuming performance
is acceptable.

**The card flip animation** is the signature interaction of the app:
- Two-zone horizontal layout: draw stack (right) and discard pile (left)
- Page-turn direction: right to left like a book
- Uses Matrix4.rotationY() — not rotationX()
- Cubic bezier arc travel path between zones — not a straight line
- Right zone anchor point is pixel-stable throughout all animations
- Flip queue handles rapid successive flips without interrupting in-flight cards
- Never intercept click events on the current card face

**Carry Forward** — right-click a card → "Carry Forward":
- Creates a new card dated today in the same stack with the card's project title
- Copies only incomplete tasks, preserving column (Now/Later), title, description,
  priority, due date, rrule, and tags
- Kanban stage IDs are NOT copied — carried tasks are plain tasks with no stage
- If any incomplete task has a kanbanStageId, a confirmation dialog is shown
- If all tasks are complete or the card has no tasks, a snack bar toast is shown
- After creation the app navigates to card view showing the new card's stack

**Spacing and sizing:** All proportions defined as named constants — never
magic numbers buried in widget code.

---

## Views

**Card View** — default view. Draw stack right, discard pile left. Page-turn
flip navigation. Current card shows two columns: Now (left) and Later (right).
Has four layout modes via `CardLayoutMode` (grid / scattered / canvas /
task-list grid with sortable columns — see `canvas_providers.dart`). Canvas
mode is excluded from the zoom system (it has its own InteractiveViewer).

**Kanban View** — cards as swimlane columns, tasks as cards within lanes.

**Board View** — ambitious cards expand into full Kanban boards with
customisable columns. Directory structure exists; implementation pending.

**Task Detail View** — title, priority, due date, tags, rich text description,
timestamped editable notes feed, attachments.

**Calendar View** — monthly grid. Tasks appear on due dates as pills (max 3
shown per day) with truncation-detected tooltips. **Drag-to-reschedule**: drag
a pill onto another day to change its due date (time-of-day preserved,
destination cell highlights + pulses on drop, undoable via `TaskRescheduled`).
Reschedule logic lives in `_CalendarViewState._reschedule` and writes through
`TaskRepository.updateDueDate`. Weekly mode is still **Coming Soon**. Google
Calendar overlay in Phase 2.

**Today Dashboard** — tasks due today grouped by card/project. Calendar
events in Phase 2.

**Archive View** — browsable, searchable archived cards. Restoring supported.

**Help Panel** — slide-in overlay, ⌘? to open. Renders docs/ markdown files
via flutter_markdown. Searchable. Remembers last section.

**Settings Panel** (`lib/presentation/widgets/settings_panel.dart`) — backup
settings UI: automatic backup frequency and destination folder. Built ahead of
the full Phase 2 Settings screen (which will absorb it). Note: currently
contains a known architecture violation — see Known issues.

---

## Keyboard Shortcuts

These are defined and must be maintained:

| Shortcut | Action |
|---|---|
| ⌘N | New card (quick-add) |
| ⌘K | Open search overlay |
| ⌘F | Not yet implemented (⌘K handles search) |
| ⌘Z | Undo last action |
| ⌘? | Open help panel |
| ⌘⇧E | Export data as CSV |
| ⌘⇧B | Create backup |
| ⌘1 | Card View |
| ⌘2 | Kanban View |
| ⌘3 | Calendar View |
| ⌘4 | Today Dashboard |
| ⌘5 | Archive View |
| ⌘6 | All Cards View |
| ⌘+ / ⌘= | Zoom in (Card View) |
| ⌘- | Zoom out (Card View) |
| ⌘0 | Reset zoom to 100% (Card View) |
| Pinch | Continuous zoom (Card View, trackpad) |
| ⌘+scroll | Step zoom (Card View, trackpad) |
| Tab / ⇧Tab | Not yet implemented |
| Space | Not yet implemented |
| Escape | Close modal or detail panel |
| → | Flip to next card (Card View) |
| ← | Flip to previous card (Card View) |
| ⌘H | Hide app (macOS menu) |
| ⌘Q | Quit app (macOS menu) |

Note on the Edit menu (`lib/app.dart`):
- **Undo (⌘Z)** reverses the last recorded *domain* action only (task
  complete/delete/reschedule, note delete, card hide/snooze/archive/delete). It is a
  single-level buffer — no history stack — surfaced via the undo toast. It does
  NOT undo typing, task/card creation, renaming, moving, or reordering. After any
  undo runs (via ⌘Z, the Edit menu, or the toast button) an "Undone" confirmation
  flashes briefly, driven by `undoConfirmationProvider` in `undo_toast.dart`.
- **Cut/Copy/Paste/Select All** act on the focused text field. Keyboard
  shortcuts are handled by Flutter directly; the menu-bar clicks are wired via
  `_invokeFocusedEditIntent` to the corresponding text-editing intents.
- **Redo is not implemented** — the menu item was removed. Verified (2026-07-14)
  that the empty menu handlers did NOT swallow keyboard shortcuts on the current
  Flutter version; keyboard editing works regardless.
- A full multi-level undo/redo covering more operations is a **planned future
  feature** — see Phase 2.

---

## Services

**BackupService** (`lib/core/services/backup_service.dart`) — creates and
restores `.3by5backup` files (zip archives containing database.sqlite +
images folder + manifest.json). The pre-restore safety backup is
non-negotiable — always created before any restore operation.
Never hard-delete during restore — rename to .old first, delete only after
verification succeeds. Automatic backup scheduling runs silently on startup.

**ExportService** (`lib/core/services/export_service.dart`) — exports all
data as a flattened task-list CSV plus summary CSV plus attachments subfolder,
delivered as a zip. UTF-8 with BOM. One row per task. Never modifies original
files.

**VoiceService** (`lib/domain/services/voice_service.dart`) — macOS speech
recognition for task creation. Currently a stub (isAvailable = false). Full
implementation is a future session. macOS platform only.

**FileOpenService** — handles macOS UTI file association for `.3by5backup`
files. Method channel between Swift AppDelegate and Flutter. **Not yet
implemented** — AppDelegate.swift has no file-open code, and the Flutter
method channel does not exist. Planned for a future session.

**EmailClipService** (`lib/domain/services/email_clip_service.dart`) — detects
and parses pasted raw email text (From/Subject/Date headers) into structured
EmailClip fields for email_clip attachments. Pure Dart, regex-based.

---

## File Type Registration

**Not yet implemented.** `.3by5backup` UTI registration is planned alongside
FileOpenService. Verified absent as of July 2026: `macos/Runner/Info.plist`
has no CFBundleDocumentTypes or UTExportedTypeDeclarations, there is no
document icon (.icns) in `macos/Runner/`, and no lsregister build phase exists
in the Xcode project. The planned shape when implemented:
- UTI: `com.threebyfive.backup`
- Conforms to: `public.zip-archive`
- Registered in: `macos/Runner/Info.plist`
- Icon: `backup_document_icon.icns` in `macos/Runner/`
- lsregister build phase script forces registration on every build during development

---

## Documentation

User documentation lives in `docs/` as markdown files bundled as Flutter assets
in `pubspec.yaml`. The in-app help panel renders these files directly via
flutter_markdown. Do not duplicate content between docs/ and the help panel —
they share the same source files.

When implementing new features, update the relevant docs/ file to reflect the
new functionality. Mark unimplemented planned features as "Coming Soon."

---

## Phases

**Phase 1 — Current (Mac only):**
Card View, Kanban View, Board View (not started), Task Detail, Calendar View
(tasks only; monthly grid built, weekly + drag-reschedule pending),
Today Dashboard (tasks only), Archive View, Stack management, Card hiding and
snooze, Tags, Priority, Due dates, Recurring tasks, FTS5 search, Keyboard
shortcuts, Undo, Voice input (stub), Backup and restore, CSV export, Help
system, Window state persistence, Onboarding (not started), UTI file
association (not started).

**Phase 2 — Planned:**
Google Calendar integration, Dark and sepia themes fully styled, Notifications
and reminders, Settings screen (a backup-focused settings panel already exists
— see Views; the full screen will absorb it), Due date filtering UI, Custom URL scheme
(3by5://add), Gmail API, macOS Mail Share Extension, Outlook add-in, Cloud sync
(Supabase or Firebase), iOS and Android apps, Voice dictation into notes,
Full multi-level undo/redo (today's undo is a single-action buffer covering 7
destructive/state actions; there is no redo — this expands it to a proper
history stack across more operations).

**Phase 3 — Future:**
Two-way Google Calendar sync, Apple Calendar, Web companion app (Next.js),
Alexa skill, Windows and Linux apps.

---

## Things Claude Code Must Always Do

- Read this file at the start of every session before doing anything
- Read the relevant source files before modifying them
- Follow the separation of concerns rules — never put database queries in widgets
- Use soft deletes — never hard-delete any record (see sanctioned exceptions in Architecture Rules)
- Write a migration for every schema change and show it to me before applying
- Update docs/ when implementing new features
- Write named constants for all magic numbers, durations, and proportions
- Handle loading and error states in every UI component
- Clean up temp directories in finally blocks
- Show the implementation plan and get approval before writing code for
  any significant feature
- Ask before making architectural decisions not covered by this file

---

## Things Claude Code Must Never Do

- Hard-delete records from the database — always soft delete (except sanctioned exceptions: Tags, TaskTags, BoardColumns, Settings)
- Put database queries directly in widgets or providers
- Use system SQLite — always use the bundled sqlite3_flutter_libs
- Modify original image files — copy only
- Leave temp directories uncleaned on success or failure
- Use magic numbers in UI code — always named constants
- Proceed to restore without first creating the pre-restore safety backup
- Intercept click events on the current card face for navigation purposes
- Use Matrix4.rotationX() for the card flip — must be rotationY()
- Write a straight-line animation for the card travel arc — must be cubic bezier
- Skip the plan approval step for significant features
- Implement Phase 2 or Phase 3 features without being explicitly asked

---

## Release Tooling

**`release_alpha.sh`** — builds a local release and installs to
`/Applications/3by5 Alpha.app`. Run this to test the release build locally.

**`release.sh`** — validates version tag format, bumps `pubspec.yaml` version,
commits, tags, and pushes. Triggers the GitHub Actions release workflow.

**`.github/workflows/release.yml`** — builds macOS (DMG), Windows (ZIP), and
Linux (tar.gz) on `push: tags: 'v*.*.*'`. Attaches all three artifacts to a
GitHub Release. Pre-release if tag contains `alpha` or `beta`. Tests run on
macOS only (Linux/Windows lack macOS plugin stubs). Injects `BUILD_VERSION`
and `BUILD_DATE` as compile-time constants via `--dart-define`.

**Bundle identifier isolation** — debug and release builds use separate macOS
sandbox containers and thus separate databases:
- Debug (`flutter run`): `com.example.threeByFive.debug`
  → `~/Library/Containers/com.example.threeByFive.debug/`
- Release (`./release_alpha.sh`): `com.example.threeByFive`
  → `~/Library/Containers/com.example.threeByFive/`

**Alpha app icon** — Release builds use `AppIcon-Alpha` (orange "A" badge,
top-right corner) so the alpha is visually distinct from any future production
build. Regenerate with `swift scripts/generate_alpha_icons.swift` from the
project root if the base icon changes.

**Alpha watermark** — `_AlphaWatermark` overlays "ALPHA RELEASE" in faded
white text across the entire app surface in release builds (`kReleaseMode`).

**Generate button** — the dev-only card generator (⊛) is hidden in release
builds via `kReleaseMode` in `card_view_settings_provider.dart`.

---

## Test Suite

Tests live in `test/`. Run with `flutter test`.

```
test/
├── helpers/test_database.dart   # TestFixture — in-memory DB + all repos
├── unit/
│   ├── date_parsing_service_test.dart  # 20 cases
│   ├── undo_manager_test.dart          # UndoManager lifecycle + all subtypes
│   └── enum_test.dart                 # TaskPriority/TaskColumn/CardStatus round-trips
└── db/
    ├── settings_dao_test.dart          # 6 tests
    ├── card_repository_test.dart       # 10 tests (CRUD + carryForward contract)
    ├── task_repository_test.dart       # 9 tests
    └── note_repository_test.dart       # 6 tests
```

All DB tests use `NativeDatabase.memory()` via `AppDatabase.forTesting(e)`.
Tests run on macOS only — CI skips Linux/Windows to avoid plugin stub failures.

---

## Current Status

Last updated: July 2026 (full CLAUDE.md ↔ codebase audit performed 2026-07-14;
see HANDOFF.md for the resulting work queue)

Recently completed:
- Card flip animation (two-zone, page-turn, Matrix4.rotationY)
- Drift schema v5 with all tables and FTS5
- Riverpod provider tree
- BackupService with pre-restore safety backup, automatic scheduling on startup
- ExportService with flattened CSV and attachments subfolder
- In-app help system with docs/ markdown rendering
- completed_at field added to Task schema (migration v4)
- Notes: soft delete, editability, updated_at timestamp (migration v5)
- settingsDaoProvider added for provider-layer settings access; all widget and
  provider SettingsDao usage now routes through it (auto-backup writes go via
  AutoBackupSettingsController — HANDOFF.md #1 done)
- BoardColumnsRepository added — direct DAO access removed from kanban view
- ⌘6 (All Cards View) keyboard shortcut bound
- Card zoom: pinch, ⌘+/⌘-/⌘0, ⌘+scroll, spring animation, floating pill
  indicator, persistence via Settings DAO. Scale flows via CardZoomData
  InheritedWidget. Canvas view excluded (has own InteractiveViewer).
  Per-display zoom memory deferred — requires native platform channel.
- Stack management: right-click context menus on stack rows (Add/Rename/Delete);
  delete confirmation dialog with Move-cards-to or Delete-all choice; last stack
  deletion prevented; drag card → drop onto sidebar stack to move between stacks;
  checkboxes replaced with colored left-border selection indicator.
- Carry Forward: right-click card → creates new card dated today with all
  incomplete tasks (column, title, description, priority, due date, rrule, tags
  all preserved; Kanban stage cleared). Toast shown when nothing to carry.
  Kanban warning dialog shown when source card has stage-assigned tasks.
  New card surfaces immediately by switching to card view. Business logic lives
  in `CardRepository.carryForward()` — widget is UI-only.
- Calendar task chip tooltips: truncation-detected tooltip on _TaskPill showing
  full title + priority/due date meta; only shown when text is actually clipped.
- Release tooling: release_alpha.sh, release.sh, GitHub Actions workflow
- Alpha visual markers: watermark overlay + AppIcon-Alpha (orange A badge)
- Generate button hidden in release builds (kReleaseMode)
- Test suite: 51+ tests across unit and DB layers
- Bundle ID isolation: debug and release builds use separate databases
- Production bug fix: CardsDao.getById was missing soft-delete filter
- Card layout modes: grid / scattered / canvas / task-list grid with sortable
  columns (CardLayoutMode, TaskSortConfig, canvas_providers.dart)
- Settings panel with automatic-backup frequency and folder configuration
- EmailClipService: parses pasted raw email text into email_clip attachment fields

In progress:
- [Update as work proceeds]

Next up:
- Board View (directory started, no implementation)
- Onboarding flow
- UTI file association / FileOpenService
- Voice input (currently a stub — isAvailable = false)
- ⌘F, Tab/⇧Tab, Space keyboard shortcuts

Known issues:
- Voice input is a stub (isAvailable = false, no speech recognition)
- FileOpenService / UTI file association not implemented (File Type
  Registration section describes the planned shape only — nothing is in
  Info.plist yet)
- Board View has directory structure but no implementation
- Onboarding not implemented
- ⌘F not bound (⌘K handles search)
- Tab/⇧Tab and Space shortcuts not implemented
- Per-display zoom memory not implemented (needs native platform channel for stable display ID)
- No redo, and app Undo is single-action only (limited to 7 destructive/state
  actions) — full multi-level undo/redo is a planned Phase 2 feature. The dead
  Redo menu item was removed and the Edit menu's Cut/Copy/Paste/Select All were
  wired to the focused field (HANDOFF.md #2 done)
- Calendar View: no weekly mode yet (drag-to-reschedule done — HANDOFF.md #3)
- Magic numbers: settings_panel.dart uses no AppSpacing constants;
  index_card_widget.dart repeats raw popup-menu dimensions (HANDOFF.md #4)
- lib/presentation/views/search/ is an empty scaffold directory (search lives
  in presentation/widgets/search_overlay.dart)
