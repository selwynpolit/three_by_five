# HANDOFF.md — Work Queue from 2026-07-14 Audit

This file is the prioritized work queue produced by a full CLAUDE.md ↔ codebase
audit. Each task is self-contained: read CLAUDE.md first (always), then the
files listed in the task. Tasks are ordered by priority — do them top to bottom
unless told otherwise. Do ONE task per session unless they are trivial.

Rules that apply to every task (from CLAUDE.md, repeated here for emphasis):
- Widgets never touch the database or DAOs — always via Riverpod providers
- No magic numbers in UI code — named constants (AppSpacing/AppConstants)
- Soft deletes only (exceptions: Tags, TaskTags, BoardColumns, Settings)
- Show a plan and get approval before writing code for any significant feature
  (tasks 3 is significant; tasks 1, 2, 4, 5 are small enough to just do)
- Update docs/ when user-visible behavior changes
- Run `flutter test` before declaring a task done

---

## Task 1 — Fix SettingsDao-in-widget architecture violation  🔴 HIGH

**Problem:** `lib/presentation/widgets/settings_panel.dart`, in
`_AutoBackupSection.build` (around line 320):

```dart
final dao = SettingsDao(ref.watch(appDatabaseProvider));
...
onChange: (v) => dao.set('backupAutoFrequency', v),
```

A widget constructs a DAO and writes to the database directly. This violates
the "UI widgets never query the database directly" rule.

**Fix:**
1. `settingsDaoProvider` already exists (generated in
   `lib/presentation/providers/database_provider.dart` / `.g.dart`). Do NOT
   create a new one.
2. Preferred shape: the auto-backup settings already have read providers
   (`autoBackupFrequencyProvider`, `autoBackupFolderProvider` in
   `lib/presentation/providers/backup_providers.dart`). Add mutation methods
   at the provider layer (e.g. a small Notifier or functions in
   backup_providers.dart) that write via `ref.read(settingsDaoProvider)`,
   then invalidate the corresponding read providers explicitly (CLAUDE.md:
   never rely on automatic invalidation).
3. Replace every `dao.set(...)` / `dao.get(...)` call inside
   settings_panel.dart with calls to those provider-layer mutations.
4. Remove the `SettingsDao(...)` construction and any now-unused imports from
   settings_panel.dart.
5. While in backup_providers.dart: it constructs `SettingsDao(ref.watch(appDatabaseProvider))`
   directly 5 times — replace each with `ref.watch(settingsDaoProvider)`.

**Acceptance:** `grep -rn "SettingsDao(" lib/presentation` returns only
provider-layer construction in database_provider.dart (and generated files) —
nothing in widgets. Settings panel still reads and writes auto-backup
frequency/folder correctly. `flutter test` passes.

**When done:** update CLAUDE.md Known issues (remove the ARCHITECTURE
VIOLATION bullet and the backup_providers inconsistency bullet).

---

## Task 2 — Fix no-op Edit menu items in lib/app.dart  🔴 HIGH

**Problem:** `lib/app.dart` (~lines 94–129) declares PlatformMenuItems for
Redo (⌘⇧Z), Cut (⌘X), Copy (⌘C), Paste (⌘V), Select All (⌘A) with
`onSelected: () {}` — empty handlers. Because PlatformMenuBar registers these
as menu key equivalents, they may swallow the shortcuts before Flutter text
fields receive them. Redo has no UndoManager support at all
(`lib/domain/undo/undo_manager.dart` has no redo).

**Fix:**
1. First VERIFY the swallowing behavior: run the app (`flutter run -d macos`),
   focus any text field (e.g. task title), test ⌘C/⌘V/⌘X/⌘A. Report findings.
2. If shortcuts are broken in text fields: replace the empty-handler items with
   `PlatformProvidedMenuItem` where available, or remove the items entirely so
   the system/Flutter default handling applies. Keep Undo (it works via
   `executeUndo(ref)`).
3. Remove the Redo menu item entirely (do NOT implement redo — that is a
   separate, unapproved feature). If a disabled greyed-out item is desired
   instead, ask the user first.

**Acceptance:** ⌘C/⌘V/⌘X/⌘A work in text fields in a debug run; no menu item
exists that silently does nothing. Update CLAUDE.md Keyboard Shortcuts note +
Known issues bullet when done.

---

## Task 3 — Calendar View: drag-to-reschedule  ⚠️ MEDIUM (significant feature — plan approval required)

**Problem:** CLAUDE.md's Views section promised "drag to reschedule" and a
weekly mode; neither exists. `lib/presentation/views/calendar_view/calendar_view.dart`
(716 lines) is a monthly grid with `_TaskPill` widgets (max 3 per day,
truncation tooltips). `calendar_view/widgets/` is empty. No Draggable/DragTarget
anywhere in the file.

**Scope decision made 2026-07-14:** implement drag-to-reschedule first; weekly
mode stays "Coming Soon" unless the user asks.

**Plan sketch (present this as a plan and get approval before coding):**
1. Wrap `_TaskPill` in `Draggable<TaskId-or-Task>` (long-press or immediate
   drag — match feel of existing card drag in sidebar, see
   `lib/presentation/shell/sidebar.dart` for the established pattern).
2. Make each day cell a `DragTarget` with a hover highlight consistent with
   the warm paper aesthetic (use AppColors, named constants for highlight
   opacity/inset).
3. On drop: update the task's dueDate via `TaskRepository` (through the
   existing task providers — no DB access in the widget), preserving the
   time-of-day component if the task had one.
4. Register an UndoAction so ⌘Z reverts the reschedule (see
   `lib/domain/undo/undo_action.dart` sealed hierarchy and how other actions
   are registered; add a subtype if none fits).
5. Invalidate the calendar's providers explicitly after the mutation.
6. Animate the pill settling into the new day (brief, physical — no instant
   jump; see Animations rules in CLAUDE.md).
7. Update `docs/views.md` (calendar section) and remove "Coming Soon" for
   drag-reschedule; keep weekly mode as Coming Soon.
8. Add a repository-level test in `test/db/task_repository_test.dart` for the
   due-date update if not already covered.

**Acceptance:** dragging a pill to another day updates the due date, survives
restart, is undoable with ⌘Z, and `flutter test` passes. Update CLAUDE.md
Views section + Known issues when done.

---

## Task 4 — Magic-number cleanup  ⚠️ MEDIUM

**Problem:** two files violate the named-constants rule:
- `lib/presentation/widgets/settings_panel.dart` — zero `AppSpacing.*` usages;
  raw values throughout (`EdgeInsets.all(14)`, `BorderRadius.circular(10)`,
  `width: 0.5`, `SizedBox(height: 12)`, etc.)
- `lib/presentation/views/card_view/widgets/index_card_widget.dart` — the
  right-click PopupMenuItems repeat `height: 32, padding:
  EdgeInsets.symmetric(horizontal: 14)` 8+ times (lines ~76–92).

**Fix:**
1. Read `lib/core/theme/` (AppSpacing etc.) and `lib/core/constants/`
   (AppConstants) first — reuse existing constants where values match; add new
   named constants only for values that don't exist yet (e.g.
   `AppSpacing.contextMenuItemHeight = 32`,
   `AppSpacing.contextMenuItemHPad = 14` — follow the existing naming style in
   that file, don't invent a new convention).
2. For index_card_widget.dart, prefer extracting a small private helper
   (e.g. `PopupMenuItem<String> _menuItem(String value, String label)`) so the
   dimensions live in exactly one place.
3. Purely mechanical — no behavior change. No screenshots needed, but do a
   quick `flutter analyze` and `flutter test`.

**Acceptance:** no raw dimension literals in the touched sections; visual
output unchanged. Update CLAUDE.md Known issues bullet when done.

---

## Task 5 — Small cleanups  📝 LOW (batch these together)

1. **Delete empty scaffold dir** `lib/presentation/views/search/` (contains
   only an empty `widgets/` dir; real search UI is
   `lib/presentation/widgets/search_overlay.dart`). Verify nothing imports
   from it first: `grep -rn "views/search" lib test`.
2. **docs/ additions:** document the card layout modes (grid / scattered /
   canvas / task list) — likely belongs in `docs/views.md`; document the
   settings panel (auto-backup frequency/folder) — likely `docs/backup-and-restore.md`.
   Match the tone and structure of existing docs files.
3. Update CLAUDE.md Known issues (remove the empty-scaffold bullet) when done.

---

## Explicitly OUT of scope (do not do without the user asking)

- Redo support in UndoManager (Task 2 removes the menu item only)
- Weekly calendar mode
- Board View implementation
- Onboarding flow
- UTI file association / FileOpenService (CLAUDE.md File Type Registration
  section describes the PLANNED shape — nothing exists yet)
- Voice input implementation (stub stays a stub)
- Anything in Phase 2/3 (Settings screen expansion, themes, notifications…)

## Audit facts a future session can rely on (verified 2026-07-14)

- Drift schema version 5 matches CLAUDE.md; all 9 tables match field-for-field
- CalendarEvents table does NOT exist (Phase 2 planned shape only)
- Hard deletes confined to sanctioned tables; soft-delete filters present in
  all DAOs including FTS search (raw SQL `deleted_at IS NULL`)
- Temp-dir operations in BackupService/ExportService all wrapped in finally
- All documented keyboard shortcuts exist except those marked "Not yet
  implemented" (⌘F, Tab/⇧Tab, Space)
