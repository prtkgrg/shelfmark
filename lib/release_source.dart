import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'models/series.dart';

/// Fetches the latest *released* chapter number for a series from some
/// external source. Implementations must never throw — a failed fetch
/// (network down, layout changed, rate limited) returns null so the cached
/// value is kept instead.
abstract class ReleaseSource {
  Future<num?> fetchLatest();

  /// Builds the source configured on [s], or null if the series isn't
  /// tracked / is misconfigured.
  static ReleaseSource? forSeries(Series s) {
    final ref = s.sourceRef?.trim();
    if (ref == null || ref.isEmpty) return null;
    switch (s.sourceType) {
      case 'mangadex':
        final id = MangaDexSource.extractId(ref);
        return id == null ? null : MangaDexSource(id);
      case 'scrape':
        return ScrapeSource(ref);
      default:
        return null;
    }
  }
}

const _userAgent = 'Shelfmark/1.1 (personal reading tracker)';

/// Reads the highest English chapter number from MangaDex's aggregate
/// endpoint. Reliable but only official/MangaPlus chapters, so it can lag
/// behind scanlation releases by a few chapters.
class MangaDexSource implements ReleaseSource {
  final String mangaId;
  MangaDexSource(this.mangaId);

  static final _uuidRe = RegExp(
    r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}',
    caseSensitive: false,
  );

  /// Accepts a bare UUID or any `mangadex.org/title/<uuid>/...` URL.
  static String? extractId(String ref) => _uuidRe.firstMatch(ref)?.group(0);

  @override
  Future<num?> fetchLatest() async {
    try {
      final uri = Uri.parse(
        'https://api.mangadex.org/manga/$mangaId/aggregate'
        '?translatedLanguage[]=en',
      );
      final resp = await http
          .get(uri, headers: {'User-Agent': _userAgent})
          .timeout(const Duration(seconds: 20));
      if (resp.statusCode != 200) return null;

      return parseAggregate(jsonDecode(resp.body));
    } catch (e) {
      debugPrint('MangaDexSource.fetchLatest failed: $e');
      return null;
    }
  }

  /// Extracts the highest chapter number from a MangaDex `/aggregate`
  /// response body (`{volumes: {vol: {chapters: {"num": {...}}}}}`).
  /// Returns null for an unexpected shape or no numeric chapters.
  static num? parseAggregate(dynamic body) {
    if (body is! Map) return null;
    final volumes = body['volumes'];
    if (volumes is! Map) return null;

    num? best;
    for (final vol in volumes.values) {
      if (vol is! Map) continue;
      final chapters = vol['chapters'];
      if (chapters is! Map) continue;
      for (final key in chapters.keys) {
        final n = num.tryParse(key.toString());
        if (n != null && (best == null || n > best)) best = n;
      }
    }
    return best;
  }
}

/// Fetches an arbitrary HTML page and extracts the highest chapter number
/// mentioned. Covers sources without an API (e.g. scanlation index pages).
/// Inherently fragile: any layout change can break it, hence the tolerant
/// regex and null-on-failure contract.
class ScrapeSource implements ReleaseSource {
  final String url;

  /// Matches "chapter" optionally followed by junk, then a (possibly
  /// fractional) number. Same spirit as the local filename scanner.
  static final _chapterRe =
      RegExp(r'chapter\D{0,10}(\d+(?:\.\d+)?)', caseSensitive: false);

  ScrapeSource(this.url);

  @override
  Future<num?> fetchLatest() async {
    try {
      final resp = await http
          .get(Uri.parse(url), headers: {'User-Agent': _userAgent})
          .timeout(const Duration(seconds: 20));
      if (resp.statusCode != 200) return null;
      return parseHtml(resp.body);
    } catch (e) {
      debugPrint('ScrapeSource.fetchLatest failed: $e');
      return null;
    }
  }

  /// Highest chapter number mentioned anywhere in [html]. Null if none.
  static num? parseHtml(String html) {
    num? best;
    for (final m in _chapterRe.allMatches(html)) {
      final n = num.tryParse(m.group(1)!);
      if (n != null && (best == null || n > best)) best = n;
    }
    return best;
  }
}
