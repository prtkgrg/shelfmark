import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';

import 'backup.dart';
import 'chapter_scanner.dart';
import 'library_store.dart';
import 'models/series.dart';
import 'permissions.dart';
import 'progress_store.dart';
import 'release_source.dart';
import 'release_tracker.dart';
import 'series_screen.dart';
import 'stats.dart';
import 'theme_controller.dart';
import 'thumbnail.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _SeriesEntry {
  final Series series;
  final int totalChapters;
  final int readCount;
  final int highestLocal; // highest chapter number present on disk
  final File? cover;

  _SeriesEntry({
    required this.series,
    required this.totalChapters,
    required this.readCount,
    required this.highestLocal,
    required this.cover,
  });

  /// Chapters released beyond the highest local PDF. Reads the (live,
  /// mutable) [Series.latestChapter] so it reflects the latest fetch.
  int get newChapters {
    final latest = series.latestChapter;
    if (latest == null) return 0;
    final diff = latest.floor() - highestLocal;
    return diff > 0 ? diff : 0;
  }
}

class _LibraryScreenState extends State<LibraryScreen> {
  final library = LibraryStore();
  List<_SeriesEntry> entries = [];
  bool loading = true;
  int streakDays = 0;
  int chaptersThisWeek = 0;
  final Set<String> refreshingIds = {}; // series currently checking releases

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    await library.load();

    final newEntries = <_SeriesEntry>[];
    final allTimestamps = <DateTime>[];
    final highestLocalById = <String, int>{};

    for (final s in library.series) {
      final chapters = await compute(scanChapters, s.folderPath);
      final store = ProgressStore(s.id);
      await store.load();
      allTimestamps.addAll(store.allReadTimestamps);
      highestLocalById[s.id] = chapters.isEmpty ? 0 : chapters.last.number;
      final cover = await getOrGenerateCoverThumbnail(s.id, chapters);
      newEntries.add(_SeriesEntry(
        series: s,
        totalChapters: chapters.length,
        readCount: store.readCount,
        highestLocal: highestLocalById[s.id]!,
        cover: cover,
      ));
    }

    if (!mounted) return;
    setState(() {
      entries = newEntries;
      streakDays = computeStreakDays(allTimestamps);
      chaptersThisWeek = countInLastDays(allTimestamps, 7);
      loading = false;
    });

    // Auto-refresh release numbers in the background once the grid is shown.
    _refreshReleases(highestLocalById);
  }

  /// Fetches latest chapters for tracked series, then rebuilds so badges
  /// update. Notifications are fired inside the tracker. Best-effort.
  Future<void> _refreshReleases(Map<String, int> highestLocalById) async {
    final tracked = library.series.any((s) => s.sourceType != null);
    if (!tracked) return;
    await ReleaseTracker.refreshAll(library, highestLocalById);
    if (!mounted) return;
    setState(() {}); // Series.latestChapter mutated in place; refresh badges.
  }

  Future<void> _addSeries() async {
    final granted = await ensureStoragePermission();
    if (!granted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Storage permission needed to add a folder.')),
        );
      }
      return;
    }
    final path = await FilePicker.getDirectoryPath();
    if (path == null) return;

    final existing = library.series.where((s) => s.folderPath == path);
    if (existing.isNotEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('This folder is already in your library as "${existing.first.name}".')),
        );
      }
      return;
    }

    final defaultName = path.split('/').where((p) => p.isNotEmpty).last;
    if (!mounted) return;
    final config = await showDialog<_AddSeriesConfig>(
      context: context,
      builder: (context) => _AddSeriesDialog(initialName: defaultName),
    );
    if (config == null || config.name.trim().isEmpty) return;

    await library.addSeries(
      name: config.name.trim(),
      folderPath: path,
      sourceType: config.sourceType,
      sourceRef: config.sourceRef,
    );
    await _load();
  }

  Future<String?> _promptName({required String initial, required String title}) async {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _renameSeries(Series s) async {
    final name = await _promptName(initial: s.name, title: 'Rename series');
    if (name == null || name.trim().isEmpty) return;
    await library.renameSeries(s.id, name.trim());
    await _load();
  }

  /// Manually re-checks one series' latest release. [entry] carries the
  /// highest local chapter needed to compute the new-count.
  Future<void> _refreshOne(_SeriesEntry entry) async {
    final s = entry.series;
    if (s.sourceType == null || refreshingIds.contains(s.id)) return;
    setState(() => refreshingIds.add(s.id));

    final result = await ReleaseTracker.refreshSeries(library, s, entry.highestLocal);

    if (!mounted) return;
    setState(() => refreshingIds.remove(s.id));
    final msg = switch (result) {
      null => 'Not tracked.',
      TrackResult(fetched: false) => "Couldn't reach the source. Try again later.",
      TrackResult(newCount: 0) => 'Up to date (latest ${_fmtNum(s.latestChapter!)}).',
      TrackResult(:final newCount) =>
        '$newCount new (latest ${_fmtNum(s.latestChapter!)}).',
    };
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _configureTracking(Series s) async {
    final result = await showDialog<_TrackingConfig>(
      context: context,
      builder: (context) => _TrackingDialog(
        initialType: s.sourceType,
        initialRef: s.sourceRef,
      ),
    );
    if (result == null) return; // dialog cancelled
    await library.setSource(
      s.id,
      sourceType: result.type,
      sourceRef: result.ref,
    );
    await _load();
  }

  Future<void> _removeSeries(Series s) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove series?'),
        content: Text(
          'This removes "${s.name}" and its reading progress from Shelfmark. '
          'The PDF files themselves are not deleted.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove')),
        ],
      ),
    );
    if (confirmed != true) return;
    await invalidateCoverThumbnail(s.id);
    await library.removeSeries(s.id);
    await _load();
  }

  Future<void> _openSeries(Series s) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SeriesScreen(series: s)),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shelfmark'),
        actions: [
          ValueListenableBuilder<ThemeMode>(
            valueListenable: ThemeController.mode,
            builder: (context, mode, _) => PopupMenuButton<ThemeMode>(
              icon: Icon(switch (mode) {
                ThemeMode.light => Icons.light_mode,
                ThemeMode.dark => Icons.dark_mode,
                ThemeMode.system => Icons.brightness_auto,
              }),
              tooltip: 'Theme',
              initialValue: mode,
              onSelected: ThemeController.setMode,
              itemBuilder: (context) => const [
                PopupMenuItem(value: ThemeMode.system, child: Text('System')),
                PopupMenuItem(value: ThemeMode.light, child: Text('Light')),
                PopupMenuItem(value: ThemeMode.dark, child: Text('Dark')),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.upload_file),
            tooltip: 'Export backup',
            onPressed: () => exportBackup(context, library),
          ),
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Import backup',
            onPressed: () async {
              await importBackup(context, library);
              await _load();
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addSeries,
        icon: const Icon(Icons.add),
        label: const Text('Add series'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: entries.isEmpty
                  ? ListView(
                      children: const [
                        Padding(
                          padding: EdgeInsets.all(32),
                          child: Text(
                            'No series yet. Tap "Add series" and pick a folder full of chapter PDFs.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    )
                  : ReorderableListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
                      header: Column(
                        children: [
                          if (streakDays > 0 || chaptersThisWeek > 0)
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    _StatChip(
                                      icon: Icons.local_fire_department,
                                      label: '$streakDays day streak',
                                    ),
                                    _StatChip(
                                      icon: Icons.menu_book,
                                      label: '$chaptersThisWeek this week',
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          const SizedBox(height: 8),
                        ],
                      ),
                      itemCount: entries.length,
                      itemBuilder: (context, i) {
                        final e = entries[i];
                        return _SeriesCard(
                          key: ValueKey(e.series.id),
                          entry: e,
                          refreshing: refreshingIds.contains(e.series.id),
                          onTap: () => _openSeries(e.series),
                          onRename: () => _renameSeries(e.series),
                          onTrack: () => _configureTracking(e.series),
                          onRefresh: () => _refreshOne(e),
                          onRemove: () => _removeSeries(e.series),
                        );
                      },
                      onReorderItem: (oldIndex, newIndex) async {
                        await library.reorder(oldIndex, newIndex);
                        if (!mounted) return;
                        setState(() {
                          final item = entries.removeAt(oldIndex);
                          entries.insert(newIndex, item);
                        });
                      },
                    ),
            ),
    );
  }
}

class _TrackingConfig {
  final String? type; // null clears tracking
  final String? ref;
  _TrackingConfig(this.type, this.ref);
}

/// Lets the user pick a release source (MangaDex id/URL or a scrape URL) or
/// turn tracking off. Returns null on cancel, a [_TrackingConfig] on save.
class _TrackingDialog extends StatefulWidget {
  final String? initialType;
  final String? initialRef;
  const _TrackingDialog({this.initialType, this.initialRef});

  @override
  State<_TrackingDialog> createState() => _TrackingDialogState();
}

class _TrackingDialogState extends State<_TrackingDialog> {
  late String type = widget.initialType ?? 'none';
  late final refController = TextEditingController(text: widget.initialRef ?? '');
  String? error;

  @override
  void dispose() {
    refController.dispose();
    super.dispose();
  }

  String get _hint => switch (type) {
        'mangadex' => 'MangaDex URL or series id',
        'scrape' => 'Page URL to scan for chapter numbers',
        _ => '',
      };

  void _save() {
    if (type == 'none') {
      Navigator.pop(context, _TrackingConfig(null, null));
      return;
    }
    final ref = refController.text.trim();
    final err = ReleaseSource.validateConfig(type, ref);
    if (err != null) {
      setState(() => error = err);
      return;
    }
    Navigator.pop(context, _TrackingConfig(type, ref));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Track releases'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButton<String>(
            value: type,
            isExpanded: true,
            onChanged: (v) => setState(() {
              type = v ?? 'none';
              error = null;
            }),
            items: const [
              DropdownMenuItem(value: 'none', child: Text('Off')),
              DropdownMenuItem(value: 'mangadex', child: Text('MangaDex (official, English)')),
              DropdownMenuItem(value: 'scrape', child: Text('Web page (any site)')),
            ],
          ),
          if (type != 'none') ...[
            const SizedBox(height: 8),
            TextField(
              controller: refController,
              autofocus: true,
              decoration: InputDecoration(hintText: _hint, errorText: error),
            ),
          ],
          if (type == 'mangadex')
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Only official English chapters; may lag a few chapters behind '
                'scanlation releases.',
                style: TextStyle(fontSize: 12),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}

class _AddSeriesConfig {
  final String name;
  final String? sourceType;
  final String? sourceRef;
  _AddSeriesConfig(this.name, this.sourceType, this.sourceRef);
}

/// New-series dialog: name plus an optional release-tracking source, so a
/// series can be tracked the moment it's added (not only via the ⋮ menu).
class _AddSeriesDialog extends StatefulWidget {
  final String initialName;
  const _AddSeriesDialog({required this.initialName});

  @override
  State<_AddSeriesDialog> createState() => _AddSeriesDialogState();
}

class _AddSeriesDialogState extends State<_AddSeriesDialog> {
  late final nameController = TextEditingController(text: widget.initialName);
  final refController = TextEditingController();
  String type = 'none';
  String? refError;

  @override
  void dispose() {
    nameController.dispose();
    refController.dispose();
    super.dispose();
  }

  String get _hint => switch (type) {
        'mangadex' => 'MangaDex URL or series id',
        'scrape' => 'Page URL to scan for chapter numbers',
        _ => '',
      };

  void _save() {
    final name = nameController.text.trim();
    if (name.isEmpty) return; // name is required; keep the dialog open
    if (type == 'none') {
      Navigator.pop(context, _AddSeriesConfig(name, null, null));
      return;
    }
    final ref = refController.text.trim();
    final err = ReleaseSource.validateConfig(type, ref);
    if (err != null) {
      setState(() => refError = err);
      return;
    }
    Navigator.pop(context, _AddSeriesConfig(name, type, ref));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add series'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: nameController,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          const SizedBox(height: 16),
          Text('Track releases (optional)',
              style: Theme.of(context).textTheme.labelLarge),
          DropdownButton<String>(
            value: type,
            isExpanded: true,
            onChanged: (v) => setState(() {
              type = v ?? 'none';
              refError = null;
            }),
            items: const [
              DropdownMenuItem(value: 'none', child: Text('Off')),
              DropdownMenuItem(value: 'mangadex', child: Text('MangaDex (official, English)')),
              DropdownMenuItem(value: 'scrape', child: Text('Web page (any site)')),
            ],
          ),
          if (type != 'none')
            TextField(
              controller: refController,
              decoration: InputDecoration(hintText: _hint, errorText: refError),
            ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _save, child: const Text('Add')),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _StatChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}

class _SeriesCard extends StatelessWidget {
  final _SeriesEntry entry;
  final bool refreshing;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onTrack;
  final VoidCallback onRefresh;
  final VoidCallback onRemove;

  const _SeriesCard({
    super.key,
    required this.entry,
    required this.refreshing,
    required this.onTap,
    required this.onRename,
    required this.onTrack,
    required this.onRefresh,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final total = entry.totalChapters;
    final read = entry.readCount;
    final pct = total == 0 ? 0 : (read / total * 100).round();
    final newCount = entry.newChapters;
    final tracked = entry.series.sourceType != null;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: entry.cover != null
                    ? Image.file(entry.cover!, width: 56, height: 78, fit: BoxFit.cover)
                    : Container(
                        width: 56,
                        height: 78,
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        child: const Icon(Icons.menu_book),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(entry.series.name,
                              style: Theme.of(context).textTheme.titleMedium),
                        ),
                        if (newCount > 0) _NewBadge(count: newCount),
                      ],
                    ),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(value: total == 0 ? 0 : read / total),
                    const SizedBox(height: 4),
                    Text('$read / $total read ($pct%)'),
                    if (tracked && entry.series.latestChapter != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          'Latest released: ${_fmtNum(entry.series.latestChapter!)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                  ],
                ),
              ),
              if (tracked)
                IconButton(
                  tooltip: 'Check for new chapters',
                  onPressed: refreshing ? null : onRefresh,
                  icon: refreshing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                ),
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'rename') onRename();
                  if (v == 'track') onTrack();
                  if (v == 'remove') onRemove();
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'rename', child: Text('Rename')),
                  PopupMenuItem(
                    value: 'track',
                    child: Text(tracked ? 'Edit tracking…' : 'Track releases…'),
                  ),
                  const PopupMenuItem(value: 'remove', child: Text('Remove')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _fmtNum(num n) =>
    n == n.roundToDouble() ? n.toInt().toString() : n.toString();

class _NewBadge extends StatelessWidget {
  final int count;
  const _NewBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count new',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onPrimary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
