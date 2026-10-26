import 'dart:convert';

import 'package:bangladesh_newspaper_hub/data/feeds/news_http_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// A Bengali headline as a publisher actually encodes it.
const String _bengali = 'বাংলাদেশে নতুন উদ্যোগ ঘোষণা করেছে সরকার';

NewsHttpClient client(
  Future<http.Response> Function(http.Request request) handler, {
  int attempts = 2,
}) {
  return NewsHttpClient(
    client: MockClient(handler),
    // No throttling in tests; a real device keeps the 1.5 s per-host gate.
    minHostInterval: Duration.zero,
    timeout: const Duration(seconds: 2),
  );
}

void main() {
  group('feed decoding', () {
    test('UTF-8 Bengali survives a feed that omits its charset', () async {
      // This is the shape Prothom Alo / Suprobhat / Sarabangla answer with:
      // a bare XML content type. Decoding that through `response.body` would
      // have used latin-1 and turned the headline into mojibake.
      final NewsHttpClient c = client((http.Request request) async {
        return http.Response.bytes(
          utf8.encode('<rss><channel><title>$_bengali</title></channel></rss>'),
          200,
          headers: <String, String>{'content-type': 'application/rss+xml'},
        );
      });
      final HttpFetchResult result =
          await c.get('https://www.prothomalo.com/stories.rss');
      expect(result.isSuccess, isTrue);
      expect(result.body, contains(_bengali));
      expect(result.body, isNot(contains('à¦')));
    });

    test('a declared latin-1 charset is still honoured', () async {
      final NewsHttpClient c = client((http.Request request) async {
        return http.Response.bytes(
          latin1.encode(
              '<rss><channel><title>café society</title></channel></rss>'),
          200,
          headers: <String, String>{
            'content-type': 'text/xml; charset=iso-8859-1'
          },
        );
      });
      final HttpFetchResult result = await c.get('https://example.com/feed');
      expect(result.body, contains('café society'));
    });

    test('a UTF-8 BOM is skipped rather than breaking the parser', () async {
      final NewsHttpClient c = client((http.Request request) async {
        return http.Response.bytes(
          <int>[
            0xEF,
            0xBB,
            0xBF,
            ...utf8.encode(
                '<rss><channel><title>$_bengali</title></channel></rss>')
          ],
          200,
          headers: <String, String>{'content-type': 'text/xml; charset=utf-8'},
        );
      });
      final HttpFetchResult result = await c.get('https://example.com/feed');
      expect(result.body, startsWith('<rss>'));
      expect(result.body, contains(_bengali));
    });
  });

  group('request policy', () {
    test('sends a descriptive user agent and an RSS accept header', () async {
      late http.Request seen;
      final NewsHttpClient c = client((http.Request request) async {
        seen = request;
        return http.Response('<rss/>', 200);
      });
      await c.get('https://www.tbsnews.net/rss.xml');
      expect(seen.headers['User-Agent'], NewsHttpClient.defaultUserAgent);
      expect(seen.headers['Accept'], contains('application/rss+xml'));
    });

    test('304 is reported as not-modified instead of an error', () async {
      final NewsHttpClient c = client((http.Request request) async {
        expect(request.headers['If-None-Match'], '"abc"');
        return http.Response('', 304);
      });
      final HttpFetchResult result = await c.get(
        'https://www.tbsnews.net/rss.xml',
        etag: '"abc"',
      );
      expect(result.notModified, isTrue);
      expect(result.isSuccess, isFalse);
      expect(result.statusCode, 304);
    });

    test('403 fails immediately and is never retried', () async {
      var calls = 0;
      final NewsHttpClient c = client((http.Request request) async {
        calls += 1;
        return http.Response('Forbidden', 403);
      });
      final HttpFetchResult result =
          await c.get('https://www.jugantor.com/rss');
      expect(result.statusCode, 403);
      expect(result.error, 'HTTP 403');
      expect(calls, 1, reason: 'a blocked source must not be hammered');
    });

    test('a server error is retried once, then reported honestly', () async {
      var calls = 0;
      final NewsHttpClient c = client((http.Request request) async {
        calls += 1;
        return http.Response('nope', 503);
      });
      final HttpFetchResult result = await c.get('https://www.samakal.com/rss');
      expect(calls, 2);
      expect(result.body, isNull);
      expect(result.error, 'HTTP 503');
    });

    test('recovers when the second attempt succeeds', () async {
      var calls = 0;
      final NewsHttpClient c = client((http.Request request) async {
        calls += 1;
        return calls == 1
            ? http.Response('busy', 500)
            : http.Response('<rss><channel/></rss>', 200);
      });
      final HttpFetchResult result =
          await c.get('https://www.kalerkantho.com/rss');
      expect(calls, 2);
      expect(result.isSuccess, isTrue);
    });

    test('oversized responses are rejected instead of parsed', () async {
      final NewsHttpClient c = NewsHttpClient(
        client: MockClient((http.Request request) async =>
            http.Response.bytes(List<int>.filled(64, 0x20), 200)),
        minHostInterval: Duration.zero,
        maxBytes: 32,
      );
      final HttpFetchResult result = await c.get('https://example.com/feed');
      expect(result.isSuccess, isFalse);
      expect(result.error, contains('larger than'));
    });

    test('an unsafe URL never leaves the device', () async {
      var calls = 0;
      final NewsHttpClient c = client((http.Request request) async {
        calls += 1;
        return http.Response('<rss/>', 200);
      });
      final HttpFetchResult result = await c.get('javascript:alert(1)');
      expect(result.isSuccess, isFalse);
      expect(calls, 0);
    });
  });
}
