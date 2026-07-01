import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';

import 'models/chapter.dart';
import 'progress_store.dart';
import 'widget_service.dart';

class ReaderScreen extends StatefulWidget {
  final String seriesName;
  final List<Chapter> chapters;
  final int startIndex;
  final ProgressStore store;

  const ReaderScreen({
    super.key,
    required this.seriesName,
    required this.chapters,
    required this.startIndex,
    required this.store,
  });

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  late int index;
  int? currentPage;
  int? totalPages;

  Chapter get chapter => widget.chapters[index];

  @override
  void initState() {
    super.initState();
    index = widget.startIndex;
    currentPage = widget.store.lastPage(chapter.number);
    widget.store.setLastChapter(chapter.number);
    _pushWidgetUpdate();
  }

  void _pushWidgetUpdate() {
    WidgetService.update(
      seriesName: widget.seriesName,
      chapterNumber: chapter.number,
      totalChapters: widget.chapters.length,
      readCount: widget.store.readCount,
    );
  }

  void _go(int delta) {
    final newIndex = index + delta;
    if (newIndex < 0 || newIndex >= widget.chapters.length) return;
    setState(() {
      index = newIndex;
      currentPage = widget.store.lastPage(chapter.number);
      totalPages = null;
    });
    widget.store.setLastChapter(chapter.number);
    _pushWidgetUpdate();
  }

  Future<void> _toggleRead() async {
    await widget.store.setRead(chapter.number, !widget.store.isRead(chapter.number));
    setState(() {});
    _pushWidgetUpdate();
  }

  Future<void> _markReadAndNext() async {
    await widget.store.setRead(chapter.number, true);
    _go(1);
  }

  @override
  Widget build(BuildContext context) {
    final isRead = widget.store.isRead(chapter.number);
    return Scaffold(
      appBar: AppBar(
        title: Text('Chapter ${chapter.number}'),
        actions: [
          IconButton(
            icon: Icon(isRead ? Icons.check_box : Icons.check_box_outline_blank),
            tooltip: 'Mark as read',
            onPressed: _toggleRead,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: PDFView(
              key: ValueKey(chapter.path),
              filePath: chapter.path,
              defaultPage: widget.store.lastPage(chapter.number),
              enableSwipe: true,
              swipeHorizontal: false,
              autoSpacing: true,
              pageFling: true,
              onRender: (pages) => setState(() => totalPages = pages),
              onPageChanged: (page, total) {
                if (page != null) widget.store.setLastPage(chapter.number, page);
                setState(() {
                  currentPage = page;
                  if (total != null) totalPages = total;
                });
              },
            ),
          ),
          if (totalPages != null && currentPage != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                'Page ${currentPage! + 1} of $totalPages',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          SafeArea(
            top: false,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: index > 0 ? () => _go(-1) : null,
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Prev'),
                ),
                TextButton.icon(
                  onPressed: index < widget.chapters.length - 1 ? _markReadAndNext : null,
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Next'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
