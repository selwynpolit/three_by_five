# Backup and Restore

A backup is a safety net and a way to move your data between machines. It's a single file — a **.3by5backup** file — that contains everything: your complete database, every image you've attached, every email clip, every link. It's self-contained and portable. You can restore it on any Mac running 3by5, even years from now.

---

## Opening Settings

The backup controls below live in the **Settings** panel. Open it with the gear-icon **Settings** row at the bottom of the sidebar. The panel also holds a few other sections — **Card View** options, per-view **Zoom** levels (see views.md), and **Export** (see export.md) — but backups are what most people come here for. Press Escape or click outside the panel to close it.

---

## Creating a backup

You can create a backup manually in two ways:

1. Go to **Settings → Create Backup**, or
2. Use the File menu: **File → Create Backup** (⌘⇧B)

Once you choose, a progress sheet appears on screen. You'll see each step as it happens — gathering your cards, collecting attachments, assembling the file. This takes a few seconds depending on how many images you have.

When the backup is fully assembled, a standard save dialog appears. The default filename is **3by5-backup-YYYY-MM-DD-HHmm.3by5backup** — the date and time are baked in so you can keep many backups without accidentally overwriting one. Save it wherever makes sense to you: your Downloads folder, your Documents folder, iCloud Drive, an external drive, a flash stick. It's just a file, so you can organize it like anything else.

---

## Automatic backups

You don't have to create backups manually if you don't want to. 3by5 can do it for you.

Go to **Settings → Automatic Backups** and choose a frequency:

- **Off** — no automatic backups. (This is the default.)
- **Daily** — a new backup every 24 hours.
- **Weekly** — a new backup every seven days.

Automatic backups go to a folder inside 3by5's own application storage, so they're always accessible — no extra permissions needed. If you want them somewhere else (iCloud Drive, Dropbox, an external drive), click the **Change** button to pick a different folder.

3by5 is tidy about automatic backups: it keeps the seven most recent and deletes anything older than that. If you want to keep a backup forever, copy it to a different folder and 3by5 won't touch it.

---

## Restoring from a backup

When you restore, 3by5 replaces your current data with the data from the backup file. This is a big action, so the app makes sure you really want to do it.

To restore:

1. Go to **Settings → Restore from Backup**, or use the File menu: **File → Restore from Backup**
2. A file picker appears. Choose a **.3by5backup** file.
3. A preview sheet shows you what's in the backup:
   - The dates it contains
   - How many records (cards, tasks, etc.)
   - Which device it came from
4. Read it over. If it looks right, click **Replace My Data**. If you change your mind, click outside the sheet or press Escape to cancel.

Before anything changes, 3by5 creates a **safety backup** of your current data automatically. This protects you — if something goes wrong during the restore, your current data is still there. If the safety backup fails for any reason, the restore is aborted and your data stays untouched.

After the restore completes, a countdown appears on screen (three seconds) and the app restarts cleanly. Your new data is now loaded.

---

## Safety backups

Every time you restore from a backup, 3by5 automatically saves your current data as a safety backup. These are stored in the app's local storage and are yours to manage.

To see your safety backups or delete old ones:

1. Go to **Settings → Safety Backups**
2. You'll see a list of all safety backups with their dates.
3. Click any one to preview what's in it, or click the × to delete it.

Safety backups are never automatically deleted — you control them. This is different from automatic backups, which 3by5 prunes to keep only the seven newest.

---

## What's actually in a backup

A **.3by5backup** file contains:

- The complete SQLite database with all your cards, tasks, projects, stacks, tags, due dates, notes, and everything else.
- Every image attachment you've added to tasks.
- Every email clip you've saved. Email metadata (sender, date, subject, and the first 5 lines of the body) is stored in the database.
- Every link you've pasted into task descriptions.

It does **not** contain settings like your chosen color scheme or which views you prefer. Those stay on your Mac.

A backup is not the same as an export. Backups are for restoring your entire data state later. If you want a spreadsheet of your tasks (for Excel, Numbers, Google Sheets, etc.), that's the export feature — see **export.md** for details.

---

## If something goes wrong

If 3by5 quits unexpectedly during a restore — a power outage, a crash, anything — your original data is safe. The safety backup was created before the restore began, and you can restore from that safety backup if needed. Or just force-quit 3by5 and relaunch it; your original data is still there waiting.

Backups are designed to be forgiving. You can restore them, undo them (via a safety backup), and move them between machines without worrying about corruption. That's the whole point.

