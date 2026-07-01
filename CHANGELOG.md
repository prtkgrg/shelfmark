# Changelog

## v1.1.0

### Added
- Custom app icon (stacked books with a bookmark ribbon) and matching native splash screen.
- Home screen widget — shows the current series, chapter, and read progress; updates live as you read; tap to open the app.
- Light/dark/system theme toggle (AppBar icon).
- Drag-to-reorder series in the library.
- Page number indicator in the reader — translucent floating badge (e.g. "7/19") over the bottom-right corner of the page.
- Backup import now warns which series' progress will be overwritten before proceeding.

### Fixed
- Reorder could crash with "setState() called after dispose()" if the library screen was closed mid-drag.
- Home screen widget's chapter label read confusingly (e.g. "Chapter 102 of 5"); now reads "Chapter 102 · 1/5 read".
- Widget update calls could throw unhandled errors on every chapter open/read-toggle; now fail silently and log instead.

## v1.0.0

Initial release.
- Multi-series library: point at any folder of chapter PDFs, track progress per series.
- Chapter list with filter (all/unread/read), sort (chapter #, recently read), and jump-to-chapter.
- Resume mid-chapter — reopening a chapter returns to the last page read.
- Auto-generated cover thumbnails from each series' first chapter.
- Reading streak and chapters-this-week stats.
- Backup/restore all series and progress to/from a JSON file.
