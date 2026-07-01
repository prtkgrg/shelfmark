import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';

import 'chapter_scanner.dart';
import 'models/chapter.dart';
import 'models/series.dart';
import 'progress_store.dart';
import 'reader_screen.dart';

enum ChapterFilter { all, unread, read }

enum SortOrder { numberAsc, numberDesc, recentlyRead }

class SeriesScreen extends StatefulWidget {
  final Series series;
  const SeriesScreen({super.key, required this.series});

  @override
  State<SeriesScreen> createState() => _SeriesScreenState();
}

class _SeriesScreenState extends State<SeriesScreen> {
  late final store = ProgressStore(widget.series.id);
  List<Chapter> chapters = [];
  ChapterFilter filter = ChapterFilter.all;
  SortOrder sortOrder = SortOrder.numberAsc;
  bool loading = true;
  String? error;
  final jumpController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await store.load();
    await _rescan();
  }

  Future<void> _rescan() async {
    setState(() => loading = true);
    final found = await compute(scanChapters, widget.series.folderPath);
    if (!mounted) return;
    setState(() {
      chapters = found;
      loading = false;
      error = found.isEmpty ? 'No chapter PDFs found in this folder.' : null;
    });
  }

  List<Chapter> get _filtered {
    Iterable<Chapter> list = chapters;
    switch (filter) {
      case ChapterFilter.all:
        break;
      case ChapterFilter.unread:
        list = list.where((c) => !store.isRead(c.number));
        break;
      case ChapterFilter.read:
        list = list.where((c) => store.isRead(c.number));
        break;
    }
    final result = list.toList();
    switch (sortOrder) {
      case SortOrder.numberAsc:
        result.sort((a, b) => a.number.compareTo(b.number));
        break;
      case SortOrder.numberDesc:
        result.sort((a, b) => b.number.compareTo(a.number));
        break;
      case SortOrder.recentlyRead:
        result.sort((a, b) {
          final ta = store.readAt(a.number);
          final tb = store.readAt(b.number);
          if (ta == null && tb == null) return a.number.compareTo(b.number);
          if (ta == null) return 1;
          if (tb == null) return -1;
          return tb.compareTo(ta);
        });
        break;
    }
    return result;
  }

  Future<void> _openChapter(Chapter c) async {
    final index = chapters.indexOf(c);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReaderScreen(
          seriesName: widget.series.name,
          chapters: chapters,
          startIndex: index,
          store: store,
        ),
      ),
    );
    setState(() {});
  }

  void _jumpTo() {
    final n = int.tryParse(jumpController.text);
    if (n == null) return;
    final match = chapters.where((c) => c.number == n);
    if (match.isEmpty) return;
    _openChapter(match.first);
  }

  String _sortLabel(SortOrder o) {
    switch (o) {
      case SortOrder.numberAsc:
        return 'Ch # ↑';
      case SortOrder.numberDesc:
        return 'Ch # ↓';
      case SortOrder.recentlyRead:
        return 'Recent';
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = chapters.length;
    final readCount = chapters.where((c) => store.isRead(c.number)).length;
    final pct = total == 0 ? 0 : (readCount / total * 100).round();

    return Scaffold(
      appBar: AppBar(title: Text(widget.series.name)),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  child: Column(
                    children: [
                      LinearProgressIndicator(value: total == 0 ? 0 : readCount / total),
                      const SizedBox(height: 6),
                      Text('$readCount / $total read ($pct%)'),
                    ],
                  ),
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Text(error!, style: const TextStyle(color: Colors.red)),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: jumpController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(hintText: 'Jump to chapter #'),
                          onSubmitted: (_) => _jumpTo(),
                        ),
                      ),
                      IconButton(icon: const Icon(Icons.search), onPressed: _jumpTo),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      ChoiceChip(
                        label: const Text('All'),
                        selected: filter == ChapterFilter.all,
                        onSelected: (_) => setState(() => filter = ChapterFilter.all),
                      ),
                      ChoiceChip(
                        label: const Text('Unread'),
                        selected: filter == ChapterFilter.unread,
                        onSelected: (_) => setState(() => filter = ChapterFilter.unread),
                      ),
                      ChoiceChip(
                        label: const Text('Read'),
                        selected: filter == ChapterFilter.read,
                        onSelected: (_) => setState(() => filter = ChapterFilter.read),
                      ),
                      ActionChip(label: const Text('Rescan folder'), onPressed: _rescan),
                      PopupMenuButton<SortOrder>(
                        initialValue: sortOrder,
                        onSelected: (v) => setState(() => sortOrder = v),
                        itemBuilder: (context) => const [
                          PopupMenuItem(value: SortOrder.numberAsc, child: Text('Chapter # (asc)')),
                          PopupMenuItem(value: SortOrder.numberDesc, child: Text('Chapter # (desc)')),
                          PopupMenuItem(value: SortOrder.recentlyRead, child: Text('Recently read first')),
                        ],
                        child: Chip(
                          avatar: const Icon(Icons.sort, size: 18),
                          label: Text(_sortLabel(sortOrder)),
                        ),
                      ),
                    ],
                  ),
                ),
                if (store.lastChapter != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        icon: const Icon(Icons.play_arrow),
                        label: Text('Continue: Chapter ${store.lastChapter}'),
                        onPressed: () {
                          final match = chapters.where((c) => c.number == store.lastChapter);
                          if (match.isNotEmpty) _openChapter(match.first);
                        },
                      ),
                    ),
                  ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    itemCount: _filtered.length,
                    itemBuilder: (context, i) {
                      final c = _filtered[i];
                      final read = store.isRead(c.number);
                      return ListTile(
                        title: Text('Chapter ${c.number}'),
                        leading: Icon(
                          read ? Icons.check_circle : Icons.radio_button_unchecked,
                          color: read ? Colors.green : null,
                        ),
                        onTap: () => _openChapter(c),
                        trailing: Checkbox(
                          value: read,
                          onChanged: (v) async {
                            await store.setRead(c.number, v ?? false);
                            setState(() {});
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
