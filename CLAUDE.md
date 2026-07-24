# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Shelfmark is a Flutter app (Android-only in practice) for tracking reading
progress across local folders of numbered-chapter PDFs (manga/comics). No
backend, no accounts — all state lives on-device in `SharedPreferences` plus a
rendered-cover cache in app support storage.

## Commands

```bash
flutter pub get              # install deps
flutter run                  # run on a connected device/emulator
flutter build apk --release  # release APK
flutter analyze              # lint (flutter_lints via analysis_options.yaml)
flutter test                 # run all tests
flutter test test/widget_test.dart --name "some test"  # single test by name filter
dart run flutter_launcher_icons   # regenerate launcher icons after changing assets/icon/
dart run flutter_native_splash:create  # regenerate splash after icon change
```

Requires the Flutter stable SDK (Dart `^3.12.2`). No CI test workflow — verify
with `flutter analyze` and `flutter test` before finishing.

## Architecture

Three screens, navigated in sequence (`lib/main.dart` → `LibraryScreen`):

`library_screen.dart` (series grid) → `series_screen.dart` (chapter list) →
`reader_screen.dart` (PDF viewer). Each screen owns its data loading.

### Persistence — two stores, both `SharedPreferences`-backed

- **`LibraryStore`** (`library_store.dart`) — the ordered list of `Series`,
  under key `series_list`. Grid order is meaningful (`reorder`).
- **`ProgressStore`** (`progress_store.dart`) — per-series, keyed by series id.
  Uses **three** keys: `read_<id>` (chapter# → ISO read timestamp),
  `lastpage_<id>` (chapter# → last viewed page index), `lastchapter_<id>`.
  A store is instantiated with a `seriesId` and `load()`ed on demand; there is
  no shared singleton.

**Key-convention coupling:** the `read_<id>` / `lastchapter_<id>` /
`lastpage_<id>` string keys are hardcoded in *both* `progress_store.dart` and
`library_store.dart::removeSeries` (for cleanup). Change one, change the other.

JSON maps are stored with **string keys** (`chapter#.toString()`) because JSON
has no int keys; `ProgressStore._parseIntKeyedMap` re-parses them and silently
drops malformed entries — backups may be hand-edited or cross-version, so
loading must never throw.

### Chapters are derived, never stored

`chapter_scanner.dart::scanChapters` reads a series folder from the filesystem
every time and matches `.pdf` files against the regex `chapter\D{0,10}(\d+)`
(case-insensitive). Chapter numbers come from the filename, not an index.
Adding/removing PDFs in the folder + rescanning is the only way the chapter set
changes; there is no chapter DB to keep in sync.

### Two PDF libraries — do not conflate

- **`flutter_pdfview`** — the interactive reader (`reader_screen.dart`).
- **`pdfx`** — off-screen rendering of page 1 to a PNG cover thumbnail
  (`thumbnail.dart`).

Cover cache lives at `<appSupport>/covers/<id>.png` with a sibling
`<id>.source` marker holding `"<firstChapterNumber>:<filename>"`. If a rescan
changes the earliest chapter, the marker mismatches and the cover regenerates;
otherwise the cache is reused. On render failure it falls back to a stale cover
rather than showing nothing.

### Release tracking (latest-chapter, no downloading)

`release_source.dart` defines a `ReleaseSource` abstraction that fetches the
**latest released chapter number** (not the files). Two implementations:
`MangaDexSource` (official `/manga/{id}/aggregate?translatedLanguage[]=en` — API,
reliable, but only official English so it lags scanlation by a few chapters) and
`ScrapeSource` (max chapter number regex-scraped from any HTML page — fragile).
Both **never throw**: any failure returns null so the cached number is kept. The
network parse logic is split into pure static functions (`parseAggregate`,
`parseHtml`) which are unit-tested in `test/release_source_test.dart`.

`Series` carries `sourceType` / `sourceRef` / cached `latestChapter` /
`lastCheckedAt` (all nullable, backup-compatible). `ReleaseTracker.refreshAll`
(`release_tracker.dart`) is called from `LibraryScreen._load` after the grid
renders: it fetches each tracked series, persists the number via
`LibraryStore.updateLatest`, and fires a `Notifications` alert when the number
**grew since last check** and exceeds the highest local PDF (badge = `latest −
highestLocalPdf`). The "grew since last check" guard is what stops re-alerting on
every library open.

**Intentional scope limit:** the app tracks and notifies only — it never
downloads chapter files (would mean fetching copyrighted manga from scanlation
sources). Users download manually. Do not add an auto-downloader for such
sources.

### Home-screen widget (Android)

`widget_service.dart` (Dart, `home_widget` plugin) pushes "continue reading"
data (`series_name`, `chapter_number`, `total_chapters`, `read_count`) to the
native `ContinueReadingWidgetProvider.kt`. It is **fire-and-forget** — called on
every chapter open/navigate/read-toggle and swallows its own errors, so callers
must not await it for correctness. Registered in `AndroidManifest.xml` as a
`<receiver>`.

### Theme

`theme_controller.dart` — a static `ValueNotifier<ThemeMode>` loaded before
`runApp` and wrapped in a `ValueListenableBuilder` at the root. Default is
**dark**. Persisted under `theme_mode`.

### Backup / restore

`backup.dart` exports every series + its `ProgressStore` raw maps to a single
versioned JSON file via `file_picker`. Import is **two-pass**: parse first
(touching no storage) to detect id collisions with existing series, warn +
confirm overwrite, then commit. Overwrite is destructive and irreversible.

## Platform notes

- Needs `MANAGE_EXTERNAL_STORAGE` (Android 11+) to read arbitrary user folders,
  with a `storage`-permission fallback for older versions
  (`permissions.dart`). PDFs live outside app-private storage by design.
- `linux/`, `macos/`, `windows/`, `web/`, `ios/` platform folders exist from
  `flutter create` but the app targets Android.
