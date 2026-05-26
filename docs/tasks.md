# Tasks

Tasks are where the actual work lives. Every card has two columns of them — **Now** and **Later** — and each task can carry as much or as little detail as you need: a plain title, a due date, a priority level, tags, rich notes, and file attachments. You can keep it as simple as a sticky note or as detailed as a mini project brief. Your call.


## Adding and editing tasks

To add a task, click the **+** button below the task list in either column. A new task appears at the bottom, ready to type. Give it a title, then press **Enter** or click away to confirm. That's the whole flow.

To edit a task's title later, just click on it. Type, press Enter, done.

Tasks can be reordered by dragging them up or down within a column. You can also drag a task sideways to the other column — from **Now** to **Later** or vice versa — when your priorities shift. In Grid or Canvas view, you can even drag a task onto a completely different card.


## The task row at a glance

A lot of information fits into a small task row without feeling cluttered. Here's what the little indicators mean:

**Left side of the row:**
- A small colored dot indicates **priority**. Red means High, blue means Low, and no dot at all means Normal.

**Right side of the row:**
- A colored circle dot means the task has a **tag** with that color.
- A calendar icon means there's a **due date**. The icon is red if the task is overdue, amber if it's due today, and blue if it's in the future.
- A pencil icon means there are **notes or attachments**.

Tasks with notes or attachments are also shown in **bold** text (when not completed), so they stand out at a glance. Completed tasks get a strikethrough.

Right-clicking a task row opens a small context menu: **Open**, **Duplicate**, **Move to Now**, **Move to Later**, and **Delete**.


## Completing tasks

Click the checkbox on the left of any task row to mark it complete. There's a small spring animation when you do — one of those details that makes it feel like the task actually went somewhere rather than just changing color.

Completed tasks show strikethrough text. If you complete something by accident, a toast appears at the bottom of the screen with an **Undo** button. You have four seconds.


## The Task Detail panel

Click a task title (not the checkbox — that completes it) to open the **Task Detail panel**, which slides in from the right at 440px wide. This is where all the depth lives.

Close the panel by pressing **ESC**, clicking the **×** button, or clicking anywhere on the green background behind it.

Here's what you can do in the detail panel:


### Title

Click the title to edit it inline. Press **Enter** to save.


### Priority

Three pills at the top: **↑ High** (red), **— Normal** (gray), **↓ Low** (blue). Click one to set it. The priority dot on the task row updates immediately.


### Due date

Click the due date field to open a date picker. The date is shown in color once set: red for overdue, orange for today, blue for a future date.

The text field in the date picker understands natural language, so you can type things like:

- `today`, `tomorrow`
- A weekday name: `friday`
- `1 week`, `2 weeks`, `1 month`, `3 months`
- Shorthand: `2d` (2 days), `3w` (3 weeks), `1m` (1 month)

As you type, it shows you a preview — something like "3w → Mon 19 May" — so you always know what you're committing to before you click.


### Tags

Click **Add tag** to see a dropdown of your existing tags, plus a **New tag...** option at the bottom. Creating a new tag opens a small dialog where you can name it and optionally pick a color. Existing tags on the task are shown with an **×** to remove them.

Tags are shared across all tasks, so once you create "Waiting" or "Blocked" or "Errands", it's available everywhere.


### Description

A rich text editor (powered by Quill) sits below the tags. Write formatted notes, paste in content, make lists — whatever helps you capture the context for this task. Press **⌘↵** to save and close the panel.


### Notes

Below the description is a notes feed — a running log of shorter, timestamped notes you add over time. Use the composer at the bottom to add a note; it appears in the feed above. Each note can be edited after the fact.

Notes are great for tracking progress on a task without rewriting the description every time. "Talked to Sarah — she's handling the invoice" is the kind of thing that belongs in a note.


### Attachments

You can attach things to a task in a few ways:

- **Drag and drop** an image file onto the detail panel.
- **Paste a URL** to create a link clip — 3by5 automatically fetches the page title and favicon.
- **Paste email text** to create an email clip — the app extracts the From address, Subject line, and a snippet of the body.

Attachments live alongside your notes in the panel, so everything related to a task is in one place.


## Coming soon

> **Coming Soon** — Recurring tasks. The data structure is already in place, but the UI for setting up a recurring schedule hasn't been built yet. Once it's ready, you'll be able to set a task to repeat daily, weekly, or on a custom schedule.

> **Coming Soon** — Reminders and push notifications. You'll be able to get notified when a due date is approaching, even when 3by5 is in the background.
