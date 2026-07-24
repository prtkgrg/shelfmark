import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shelfmark/release_source.dart';

void main() {
  group('MangaDexSource.extractId', () {
    const id = 'a1c7c817-4e59-43b7-9365-09675a149a6f';

    test('extracts id from a title URL', () {
      expect(
        MangaDexSource.extractId('https://mangadex.org/title/$id/one-piece'),
        id,
      );
    });

    test('accepts a bare id', () {
      expect(MangaDexSource.extractId(id), id);
    });

    test('returns null when no uuid present', () {
      expect(MangaDexSource.extractId('https://example.com/one-piece'), isNull);
    });
  });

  group('MangaDexSource.parseAggregate', () {
    test('picks the highest chapter across volumes', () {
      // Shape mirrors the real /aggregate response (chapter numbers as keys).
      final body = jsonDecode('''
        {"result":"ok","volumes":{
          "none":{"chapters":{"1186":{"chapter":"1186"},"1185":{"chapter":"1185"}}},
          "1":{"chapters":{"1":{"chapter":"1"},"3":{"chapter":"3"}}}
        }}''');
      expect(MangaDexSource.parseAggregate(body), 1186);
    });

    test('handles fractional chapter numbers', () {
      final body = jsonDecode(
          '{"volumes":{"x":{"chapters":{"10":{},"10.5":{}}}}}');
      expect(MangaDexSource.parseAggregate(body), 10.5);
    });

    test('returns null for empty / malformed shapes', () {
      expect(MangaDexSource.parseAggregate({'volumes': {}}), isNull);
      expect(MangaDexSource.parseAggregate({}), isNull);
      expect(MangaDexSource.parseAggregate('nope'), isNull);
    });
  });

  group('ReleaseSource.validateConfig', () {
    const opId = 'a1c7c817-4e59-43b7-9365-09675a149a6f';

    test('type none is always valid', () {
      expect(ReleaseSource.validateConfig('none', ''), isNull);
    });

    test('empty ref for a real source is rejected', () {
      expect(ReleaseSource.validateConfig('mangadex', '  '), isNotNull);
      expect(ReleaseSource.validateConfig('scrape', ''), isNotNull);
    });

    test('mangadex needs a uuid, scrape needs an http url', () {
      expect(ReleaseSource.validateConfig('mangadex', 'not-a-uuid'), isNotNull);
      expect(
        ReleaseSource.validateConfig('mangadex', 'https://mangadex.org/title/$opId'),
        isNull,
      );
      expect(ReleaseSource.validateConfig('scrape', 'example.com'), isNotNull);
      expect(ReleaseSource.validateConfig('scrape', 'https://example.com/op'), isNull);
    });
  });

  group('ScrapeSource.parseHtml', () {
    test('extracts the highest chapter number from page text', () {
      const html = '''
        <a>Chapter 1189</a><a>Chapter 1188</a><a>Chapter 1187</a>
      ''';
      expect(ScrapeSource.parseHtml(html), 1189);
    });

    test('tolerates naming junk and fractional chapters', () {
      const html = 'chapter_1186_[SCANS] ... Chapter 1186.5 (extra)';
      expect(ScrapeSource.parseHtml(html), 1186.5);
    });

    test('returns null when no chapter mentioned', () {
      expect(ScrapeSource.parseHtml('<html>no chapters here</html>'), isNull);
    });
  });
}
