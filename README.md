# 3by5

A beautiful, native macOS task manager inspired by physical 3×5 index cards.
Cards live in stacks, each card holds a **Now** column and a **Later** column,
and a detail panel gives every task rich-text notes, attachments, tags, and
priority. The UI aims for the tactile warmth of a physical corkboard.

---

## Tech Stack

| Layer | Package |
|---|---|
| Framework | Flutter 3.44 / Dart 3.12 |
| Database | Drift 2.22 (SQLite ORM, FTS5) |
| State | Riverpod 2.6 |
| Rich text | flutter_quill 11.5 |
| Window | window_manager 0.4 |
| Drag-drop / files | desktop_drop, file_picker |
| Date parsing | jiffy |
| Markdown | flutter_markdown (help system) |

---

## Running Locally

Requires Flutter with macOS desktop support enabled.

```bash
flutter run -d macos          # development (debug build)
./release_alpha.sh            # build release → /Applications/3by5 Alpha.app
flutter test                  # run the test suite
```

---

## Feature Summary

### Card View
- Draw stack (right) and discard pile (left) — page-turn flip navigation
- Each card: **Now** column (left) + **Later** column (right)
- Double-click card title to rename the project
- Right-click card header: Hide, Snooze, Archive, Delete, Carry Forward
- Zoom: pinch, ⌘+/⌘-/⌘0, ⌘+scroll — spring animation, floating pill indicator
- Snoozed cards resurface automatically

### Stacks (Projects)
- Right-click sidebar: Add / Rename / Delete stack
- Delete confirmation: move cards elsewhere or delete all
- Last stack deletion prevented
- Drag a card and drop onto a sidebar row to move it between stacks

### Carry Forward
- Right-click any card → **Carry Forward**
- Creates a new card dated today in the same stack
- Copies only incomplete tasks, preserving column, title, description, priority,
  due date, rrule, and tags; Kanban stage IDs are cleared
- Shows a warning dialog if any incomplete tasks carry a Kanban stage
- Navigates to the new card immediately

### Task Detail Panel
- Title, priority selector, due date, tags
- Rich text description (Quill WYSIWYG)
- Inline image attachments (drag-drop or file picker), link previews, email clips
- Timestamped editable notes feed with soft delete

### Kanban View
- Cards as swimlane columns, tasks as cards within lanes
- Customisable stages: To Do / In Progress / Pending / Done

### Calendar View
- Monthly layout; tasks appear on their due date as chips
- Truncation-aware tooltips on task chips showing full title + meta

### Today Dashboard
- Tasks due today grouped by card/project

### Archive View
- Browse and restore archived cards

### Full-text Search (⌘K)
- FTS5-powered search across task titles and descriptions

### Backup & Restore
- `.3by5backup` files (zip: database + images + manifest)
- Pre-restore safety backup is mandatory — always created before any restore
- Automatic backup on startup

### CSV Export (⌘⇧E)
- Flattened task-list CSV + summary CSV + attachments subfolder, delivered as zip

### Help System (⌘?)
- Slide-in overlay rendering `docs/` markdown files via flutter_markdown
- Searchable, remembers last section

---

## Keyboard Shortcuts

| Shortcut | Action |
|---|---|
| ⌘N | New card |
| ⌘K | Search |
| ⌘Z | Undo |
| ⌘? | Help |
| ⌘⇧E | Export CSV |
| ⌘⇧B | Backup |
| ⌘1 | Card View |
| ⌘2 | Kanban View |
| ⌘3 | Calendar View |
| ⌘4 | Today Dashboard |
| ⌘5 | Archive View |
| ⌘6 | All Cards View |
| ⌘+ / ⌘= | Zoom in |
| ⌘- | Zoom out |
| ⌘0 | Reset zoom |
| → / ← | Flip card |
| Esc | Close modal / panel |

---

## Release Tooling

**Local alpha build:**
```bash
./release_alpha.sh
```
Builds `flutter build macos --release`, renames to *3by5 Alpha*, and copies to
`/Applications`. The alpha uses a separate macOS sandbox container
(`com.example.threeByFive`) from the dev build (`com.example.threeByFive.debug`),
so they maintain independent databases.

The alpha is visually marked with:
- An **orange "A" badge** on the app icon (`AppIcon-Alpha` asset set)
- A faded **"ALPHA RELEASE" watermark** across the app surface

**Tagged GitHub release:**
```bash
./release.sh v1.0.0-alpha
```
Bumps `pubspec.yaml`, commits, tags, and pushes. GitHub Actions builds macOS
(DMG), Windows (ZIP), and Linux (tar.gz) and attaches them to a GitHub Release.

---

## Tests

```bash
flutter test
```

| File | Coverage |
|---|---|
| `test/unit/date_parsing_service_test.dart` | 20 cases |
| `test/unit/undo_manager_test.dart` | UndoManager + all 7 action subtypes |
| `test/unit/enum_test.dart` | Priority / Column / CardStatus round-trips |
| `test/db/settings_dao_test.dart` | 6 tests |
| `test/db/card_repository_test.dart` | 10 tests (CRUD + carryForward contract) |
| `test/db/task_repository_test.dart` | 9 tests |
| `test/db/note_repository_test.dart` | 6 tests |

All DB tests run against `NativeDatabase.memory()`.

---

## Project Structure

```
lib/
├── data/           # Drift DB, tables, DAOs, repositories
├── domain/         # Business logic, services, undo
├── presentation/   # Views, widgets, Riverpod providers, shell
└── core/           # Constants, theme, extensions, routing

macos/              # macOS platform code + Xcode project
docs/               # User documentation (markdown, bundled as assets)
test/               # Unit and DB tests
scripts/            # Dev utilities (generate_alpha_icons.swift, …)
```

---

## Known Limitations

- Voice input is a stub (`isAvailable = false`) — full implementation planned
- UTI file association (opening `.3by5backup` files from Finder) not yet wired
- Board View directory scaffolded, no implementation
- Onboarding flow not yet built
- ⌘F not bound (⌘K handles search); Tab/Space shortcuts not implemented
- Per-display zoom memory not implemented (needs native channel for stable display ID)
