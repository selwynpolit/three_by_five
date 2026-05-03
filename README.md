# 3by5

A macOS desktop task manager inspired by physical 3x5 index cards. Cards live in stacks (projects), each card holds a Now column and a Later column, and a detail panel gives each task full rich-text notes, attachments, tags, and priority. The UI aims for the tactile feel of a physical corkboard.

---

## Tech Stack

| Layer | Package / Version |
|---|---|
| Framework | Flutter 3.41.8, Dart 3.11.5 |
| Database | Drift 2.28.2 (SQLite ORM, FTS5) |
| State | Riverpod 2.6.1 |
| Rich text | flutter_quill 11.5.0 |
| Window | window_manager |
| Drag-drop / files | desktop_drop, file_picker |

---

## Running the App

Requires Flutter with macOS desktop support enabled.

```
flutter run -d macos
```

---

## What's Been Built (Sessions 1–5)

### Card View
- Index cards displayed in three layout modes:
  - **Grid** — sorted by date
  - **Scattered** — rotated, corkboard-style
  - **Free Canvas** — drag cards to any position
- Each card shows a **Now** column and a **Later** column
- Double-click a card title to rename the project
- Card header right-click menu: Hide, Snooze (2 h / tonight / tomorrow / 1 week / custom date), Archive, Delete, Unhide, Restore
- Status badges on hidden, snoozed, and archived cards
- Eye toggle to show/hide hidden cards
- Snoozed cards resurface automatically (1-minute polling timer)

### Stacks (Projects)
- Create and delete stacks from the sidebar
- Each stack has its own set of cards

### Tasks
- Add tasks inline within a card (Enter for next task, Esc to close)
- Drag to reorder tasks within and between Now/Later columns
- Task right-click menu: Open, Duplicate, Move to Now/Later, Delete
- Undo toast for task complete and task delete

### Task Detail Panel
- Slides in from the right
- Title editing, priority selector, due date picker, tag editor
- Rich text description (Quill WYSIWYG)
- Attachments: inline images (drag-drop or file picker), links, email clips
- Rich text notes with inline image support; editable and deletable inline

### Archive View
- Lists all archived cards
- Restore or permanently delete from this view

### Undo
- Toast-based undo for: task complete, task delete, card hide, card snooze, card archive, card delete

### Data Model
- **Stacks → Cards → Tasks** (Now/Later columns)
- Tasks have: title, priority, due date, tags, description, notes, attachments
- All data stored in SQLite via Drift; FTS5 tables for future search

### Utilities
- Generate button (⊛) creates 3 sample cards with 5 tasks each
- Keyboard shortcuts: `⌘N` new card, `⌘↵` save note, `Esc` close panels

---

## Roadmap

| Session | Feature |
|---|---|
| Session 6 | Kanban view |
| Session 7 | Calendar view |
| Session 8 | Today dashboard, full-text search, complete keyboard shortcuts |
| Session 9 | Voice input, recurring tasks, onboarding, final polish |

---

## Session History

| Session | Date | Scope |
|---|---|---|
| 1 | — | Project scaffold, Drift schema, SQLite setup |
| 2 | — | Riverpod providers, domain layer |
| 3 | — | Stack switcher, Card View UI |
| 4 | — | Task Detail panel |
| 5 | 2026-04-29 | Card hiding, snooze, archive, undo |
