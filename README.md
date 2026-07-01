# Shelfmark

Android app for tracking reading progress across local PDF chapter/series
folders (manga, comics, anything split into numbered-chapter PDFs).

## Features

- **Multi-series library** — point it at any folder of chapter PDFs, name it,
  track as many series as you want, each with independent progress.
- **Chapter list per series** — filter by all/unread/read, jump to a chapter
  number, sort by chapter # (asc/desc) or recently-read-first.
- **Resume mid-chapter** — reopening a chapter returns to the exact page you
  left off on, not page 1.
- **Cover thumbnails** — auto-generated from the first page of each series'
  earliest chapter.
- **Reading streak & stats** — day streak and chapters-read-this-week on the
  library screen.
- **Backup/restore** — export all series + progress to a JSON file, import it
  back later or on another device.

## How chapters are found

Point a series at a folder; any `.pdf` file whose name contains the word
"chapter" followed by a number is picked up (case-insensitive, tolerant of
naming variations like `Chapter 691`, `chapter_1186_[SCANS]`, etc. — see
`lib/chapter_scanner.dart`). Add more PDFs to the folder later and hit
"Rescan folder" to pick them up.

## Requirements

- Android 10+ (uses `MANAGE_EXTERNAL_STORAGE` for direct filesystem access to
  arbitrary folders, since the PDFs aren't in app-private storage).
- Flutter SDK (stable channel) to build.

## Running it

```
flutter pub get
flutter build apk --release
```

Install the APK, launch, tap "Add series", pick a folder, grant storage
access when prompted.

## Project layout

- `lib/models/` — `Series`, `Chapter` data classes
- `lib/library_store.dart` / `lib/progress_store.dart` — persistence
  (series list, per-series read/progress state)
- `lib/chapter_scanner.dart` — folder → chapter list
- `lib/thumbnail.dart` — cover image generation/caching
- `lib/backup.dart` — JSON export/import
- `lib/library_screen.dart` / `lib/series_screen.dart` / `lib/reader_screen.dart`
  — the three screens (library → chapter list → PDF reader)
