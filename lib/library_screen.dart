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
import 'series_screen.dart';
import 'stats.dart';
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
  final File? cover;

  _SeriesEntry({
    required this.series,
    required this.totalChapters,
    required this.readCount,
    required this.cover,
  });
}

class _LibraryScreenState extends State<LibraryScreen> {
  final library = LibraryStore();
  List<_SeriesEntry> entries = [];
  bool loading = true;
  int streakDays = 0;
  int chaptersThisWeek = 0;

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

    for (final s in library.series) {
      final chapters = await compute(scanChapters, s.folderPath);
      final store = ProgressStore(s.id);
      await store.load();
      allTimestamps.addAll(store.allReadTimestamps);
      final cover = await getOrGenerateCoverThumbnail(s.id, chapters);
      newEntries.add(_SeriesEntry(
        series: s,
        totalChapters: chapters.length,
        readCount: store.readCount,
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
    final name = await _promptName(initial: defaultName, title: 'Name this series');
    if (name == null || name.trim().isEmpty) return;

    await library.addSeries(name: name.trim(), folderPath: path);
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
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
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
                        ...entries.map((e) => _SeriesCard(
                              entry: e,
                              onTap: () => _openSeries(e.series),
                              onRename: () => _renameSeries(e.series),
                              onRemove: () => _removeSeries(e.series),
                            )),
                      ],
                    ),
            ),
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
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onRemove;

  const _SeriesCard({
    required this.entry,
    required this.onTap,
    required this.onRename,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final total = entry.totalChapters;
    final read = entry.readCount;
    final pct = total == 0 ? 0 : (read / total * 100).round();

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
                    Text(entry.series.name, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(value: total == 0 ? 0 : read / total),
                    const SizedBox(height: 4),
                    Text('$read / $total read ($pct%)'),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'rename') onRename();
                  if (v == 'remove') onRemove();
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'rename', child: Text('Rename')),
                  PopupMenuItem(value: 'remove', child: Text('Remove')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
