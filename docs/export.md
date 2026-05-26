# Export Data

An export is a snapshot of all your tasks as a spreadsheet-ready file — perfect for Excel, Numbers, Google Sheets, or any spreadsheet app. It's a one-way trip: an export can't be restored back into 3by5 the way a backup can. Think of it as a report, not a sync.

---

## How to export

You can trigger an export in two ways:

1. Go to **Settings → Export to CSV**, or
2. Use the File menu: **File → Export Data** (⌘⇧E)

A progress sheet appears showing each step as it happens. Once the ZIP file is fully assembled (this takes a few seconds depending on how many tasks and attachments you have), a standard save dialog appears. The default filename is **3by5-export-YYYY-MM-DD.zip** — the date is baked in so you can keep dated snapshots without overwriting them.

---

## What's inside the ZIP

The exported ZIP contains everything you need to open and work with your tasks in a spreadsheet:

**Main CSV: 3by5-export-YYYY-MM-DD.csv**

One row per task. Every column you need is here, and no cross-referencing is required — the whole thing is self-contained:

- **Stack** — which stack the task belongs to
- **Project** — the project title from the card
- **Card Date** — when the card was created
- **Card Status** — whether the card is active, hidden, snoozed, or archived
- **Column** — Now or Later
- **Task** — the task title
- **Description** — plain text (rich formatting like bold or links is stripped)
- **Priority** — High, Normal, or Low
- **Due Date** — the due date, if one exists
- **Due Status** — Overdue, Due Today, Due This Week, Upcoming, or blank
- **Recurring** — whether the task repeats
- **Tags** — semicolon-separated and @-prefixed (e.g., @home;@urgent)
- **Completed** — Yes or No
- **Completed Date** — when it was marked done (blank if never completed, or if completed before app version 1.0.0)
- **Kanban Stage** — which column it's in on the Kanban board, if applicable
- **Notes** — all notes with timestamps, one note per line within the cell
- **Image Files** — relative paths to images (e.g., attachments/my-task-a3f9-photo.jpg)
- **Links** — all URLs from the task
- **Email Clips** — relative paths to saved email clips (e.g., attachments/my-task-clip.txt)

**Summary CSV: 3by5-export-YYYY-MM-DD-summary.csv**

One row per stack, plus a totals row at the bottom. Shows:

- Stack name
- Total tasks
- Tasks in Now column
- Tasks in Later column
- Completed tasks
- Overdue tasks
- Tasks due this week
- Tasks with no due date

This is handy for a high-level view or reporting.

**Attachments folder**

All your image files and email clip text files sit in an **attachments/** subfolder. Paths in the CSV are relative to the ZIP root, so when you extract the ZIP, the CSV and attachments folder sit right next to each other.

**README.txt**

A quick explanation of the structure.

**attachments/manifest.json**

A JSON list of every file in the export, for completeness.

---

## Opening in Excel or Numbers

The CSV uses UTF-8 with BOM (Byte Order Mark) encoding, so most spreadsheet apps recognize it automatically. Just double-click the CSV file:

- **macOS Numbers** — opens the file directly, ready to read.
- **Microsoft Excel** — opens the file directly, ready to read.
- **Google Sheets** — use File → Import and pick the CSV.

No import wizard needed in most cases. Once it's open, you can filter by Stack, Column, Due Status, or any other column. You can sort, pivot, or export to other formats — it's a standard spreadsheet now.

---

## Email clips

When you save an email clip in 3by5, the app captures the sender, date, subject, and the first 5 lines of the email body. That's what gets stored in the database and included in the export.

Email clip files are plain text (.txt), one per saved clip. You can open them in any text editor. Their relative paths appear in the **Email Clips** column of the CSV.

---

## A note about Completed Date

The **Completed Date** column shows when a task was marked done. However, if a task was completed before 3by5 version 1.0.0, that date might be blank — completion timestamps were added in v1.0.0. New tasks you complete now will have a date.

---

## Attachments in the spreadsheet

Images and email clips are referenced by relative path in the CSV (e.g., `attachments/my-task-a3f9-photo.jpg`). After you extract the ZIP:

1. The CSV sits in the root of the extracted folder.
2. The **attachments/** subfolder sits next to it.
3. If you're viewing the CSV in a spreadsheet app, the image paths won't automatically resolve in the app itself — you'll just see the text path. To see the images, open them manually or write a script that follows the paths.

If you want to include actual images embedded in your spreadsheet, you'll need to do that in your spreadsheet app after import — it's outside the scope of the export. But all the data is there waiting for you.

