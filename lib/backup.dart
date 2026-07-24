import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'library_store.dart';
import 'models/series.dart';
import 'progress_store.dart';

Future<void> exportBackup(BuildContext context, LibraryStore library) async {
  final seriesData = <Map<String, dynamic>>[];
  for (final s in library.series) {
    final store = ProgressStore(s.id);
    await store.load();
    seriesData.add({
      'id': s.id,
      'name': s.name,
      'folderPath': s.folderPath,
      'sourceType': s.sourceType,
      'sourceRef': s.sourceRef,
      'latestChapter': s.latestChapter,
      'lastCheckedAt': s.lastCheckedAt,
      'readAt': store.readAtRaw,
      'lastPage': store.lastPageRaw,
      'lastChapter': store.lastChapter,
    });
  }

  final payload = {
    'version': 1,
    'exportedAt': DateTime.now().toIso8601String(),
    'series': seriesData,
  };

  final bytes = Uint8List.fromList(utf8.encode(jsonEncode(payload)));
  final path = await FilePicker.saveFile(
    dialogTitle: 'Save Shelfmark backup',
    fileName: 'shelfmark_backup_${DateTime.now().millisecondsSinceEpoch}.json',
    bytes: bytes,
  );

  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(path == null ? 'Export cancelled.' : 'Backup saved.')),
  );
}

Future<void> importBackup(BuildContext context, LibraryStore library) async {
  final result = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['json'],
    withData: true,
  );
  if (result == null || result.files.isEmpty) return;

  final file = result.files.single;
  String raw;
  if (file.bytes != null) {
    raw = utf8.decode(file.bytes!);
  } else if (file.path != null) {
    raw = await File(file.path!).readAsString();
  } else {
    return;
  }

  Map<String, dynamic> payload;
  try {
    payload = jsonDecode(raw) as Map<String, dynamic>;
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('That file is not a valid Shelfmark backup.')),
    );
    return;
  }

  final seriesList = (payload['series'] as List?) ?? [];

  // First pass: parse entries without touching storage, so we can warn
  // about overwrites before committing anything.
  final parsed = <Map<String, dynamic>>[];
  var parseSkipped = 0;
  for (final rawEntry in seriesList) {
    try {
      final entry = rawEntry as Map<String, dynamic>;
      parsed.add({
        'id': entry['id'] as String,
        'name': entry['name'] as String,
        'folderPath': entry['folderPath'] as String,
        'sourceType': entry['sourceType'] as String?,
        'sourceRef': entry['sourceRef'] as String?,
        'latestChapter': entry['latestChapter'] as num?,
        'lastCheckedAt': entry['lastCheckedAt'] as String?,
        'readAt': Map<String, String>.from(entry['readAt'] as Map? ?? {}),
        'lastPage': Map<String, int>.from(entry['lastPage'] as Map? ?? {}),
        'lastChapter': entry['lastChapter'] as int?,
      });
    } catch (_) {
      parseSkipped++;
    }
  }

  final existingById = {for (final s in library.series) s.id: s};
  final conflicts = parsed
      .where((e) => existingById.containsKey(e['id']))
      .map((e) => existingById[e['id']]!.name)
      .toList();

  if (conflicts.isNotEmpty) {
    if (!context.mounted) return;
    final proceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Overwrite existing progress?'),
        content: Text(
          'This backup will overwrite reading progress for:\n\n'
          '${conflicts.map((n) => '• $n').join('\n')}\n\n'
          'This cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Overwrite')),
        ],
      ),
    );
    if (proceed != true) return;
  }

  var restored = 0;
  var skipped = parseSkipped;
  for (final entry in parsed) {
    try {
      final id = entry['id'] as String;
      await library.addOrReplaceSeries(Series(
        id: id,
        name: entry['name'] as String,
        folderPath: entry['folderPath'] as String,
        sourceType: entry['sourceType'] as String?,
        sourceRef: entry['sourceRef'] as String?,
        latestChapter: entry['latestChapter'] as num?,
        lastCheckedAt: entry['lastCheckedAt'] as String?,
      ));

      final store = ProgressStore(id);
      await store.restoreRaw(
        readAt: entry['readAt'] as Map<String, String>,
        lastPage: entry['lastPage'] as Map<String, int>,
        lastChapter: entry['lastChapter'] as int?,
      );
      restored++;
    } catch (_) {
      skipped++;
    }
  }

  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        skipped == 0
            ? 'Backup restored ($restored series).'
            : 'Backup restored ($restored series, $skipped skipped due to invalid data).',
      ),
    ),
  );
}
