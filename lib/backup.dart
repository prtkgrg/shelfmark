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
  var restored = 0;
  var skipped = 0;
  for (final rawEntry in seriesList) {
    try {
      final entry = rawEntry as Map<String, dynamic>;
      final id = entry['id'] as String;
      final name = entry['name'] as String;
      final folderPath = entry['folderPath'] as String;

      await library.addOrReplaceSeries(Series(
        id: id,
        name: name,
        folderPath: folderPath,
      ));

      final store = ProgressStore(id);
      await store.restoreRaw(
        readAt: Map<String, String>.from(entry['readAt'] as Map? ?? {}),
        lastPage: Map<String, int>.from(entry['lastPage'] as Map? ?? {}),
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
