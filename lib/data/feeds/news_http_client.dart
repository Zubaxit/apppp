import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../core/utils/url_safety.dart';

class HttpFetchResult {
  const HttpFetchResult({
    this.statusCode,
    this.body,
    this.error,
    this.latencyMs = 0,
    this.etag,
    this.lastModified,
    this.notModified = false,
  });

  final int? statusCode;
  final String? body;
  final String? error;
  final int latencyMs;
  final String? etag;
  final String? lastModified;
  final bool notModified;

  bool get isSuccess =>
      !notModified && body != null && statusCode != null && statusCode! >= 200 && statusCode! < 300;

  static HttpFetchResult failure(String error, {int? statusCode, int latencyMs = 0}) =>
      HttpFetchResult(error: error, statusCode: statusCode, latencyMs: latencyMs);
}

/// Wraps `package:http` with the policies the app promises publishers:
/// a descriptive user agent, short timeouts, at most two attempts, a small
/// response size cap and a per-host throttling gate so the app can never
/// hammer a newspaper server.
class NewsHttpClient {
  NewsHttpClient({
    http.Client? client,
    this.timeout = const Duration(seconds: 12),
    this.userAgent = defaultUserAgent,
    this.minHostInterval = const Duration(milliseconds: 1500),
    this.maxBytes = 3 * 1024 * 1024,
  }) : _client = client ?? http.Client();

  static const String defaultUserAgent =
      'BangladeshNewspaperHub/1.0 (Android; +https://github.com/Zubaxit/apppp)';

  final http.Client _client;
  final Duration timeout;
  final String userAgent;
  final Duration minHostInterval;
  final int maxBytes;

  final Map<String, DateTime> _lastRequestByHost = <String, DateTime>{};

  Future<void> _throttle(String host) async {
    final DateTime? last = _lastRequestByHost[host];
    if (last != null) {
      final Duration elapsed = DateTime.now().difference(last);
      if (elapsed < minHostInterval) {
        await Future<void>.delayed(minHostInterval - elapsed);
      }
    }
    _lastRequestByHost[host] = DateTime.now();
  }

  Future<HttpFetchResult> get(
    String url, {
    String? etag,
    String? lastModified,
    int attempts = 2,
  }) async {
    final String? safeUrl = UrlSafety.sanitize(url);
    if (safeUrl == null) return HttpFetchResult.failure('Unsafe or invalid URL');
    final Uri uri = Uri.parse(safeUrl);
    String? lastError;
    for (var attempt = 1; attempt <= attempts; attempt++) {
      final Stopwatch stopwatch = Stopwatch()..start();
      try {
        await _throttle(uri.host);
        final Map<String, String> headers = <String, String>{
          'User-Agent': userAgent,
          'Accept': 'application/rss+xml, application/atom+xml, application/xml;q=0.9, '
              'text/xml;q=0.8, */*;q=0.5',
          'Accept-Language': 'bn,en;q=0.8',
          'Cache-Control': 'max-age=0',
          if (etag != null && etag.isNotEmpty) 'If-None-Match': etag,
          if (lastModified != null && lastModified.isNotEmpty)
            'If-Modified-Since': lastModified,
        };
        final http.Response response =
            await _client.get(uri, headers: headers).timeout(timeout);
        stopwatch.stop();
        final int status = response.statusCode;
        if (status == 304) {
          return HttpFetchResult(
            statusCode: status,
            notModified: true,
            latencyMs: stopwatch.elapsedMilliseconds,
            etag: etag,
            lastModified: lastModified,
          );
        }
        if (status >= 200 && status < 300) {
          final int length = response.bodyBytes.length;
          if (length > maxBytes) {
            return HttpFetchResult.failure(
              'Feed larger than 3 MB',
              statusCode: status,
              latencyMs: stopwatch.elapsedMilliseconds,
            );
          }
          return HttpFetchResult(
            statusCode: status,
            body: response.body,
            latencyMs: stopwatch.elapsedMilliseconds,
            etag: response.headers['etag'],
            lastModified: response.headers['last-modified'],
          );
        }
        lastError = 'HTTP $status';
        // 4xx other than 408/429 will not succeed on retry.
        if (status >= 400 && status < 500 && status != 408 && status != 429) {
          return HttpFetchResult.failure(
            lastError,
            statusCode: status,
            latencyMs: stopwatch.elapsedMilliseconds,
          );
        }
      } on TimeoutException {
        stopwatch.stop();
        lastError = 'Timed out after ${timeout.inSeconds}s';
      } on SocketException {
        stopwatch.stop();
        lastError = 'Network unreachable';
      } on http.ClientException {
        stopwatch.stop();
        lastError = 'Connection failed';
      } on HandshakeException {
        stopwatch.stop();
        lastError = 'Secure connection failed';
      } catch (_) {
        stopwatch.stop();
        lastError = 'Unexpected network error';
      }
      if (attempt < attempts) {
        await Future<void>.delayed(Duration(milliseconds: 500 * attempt));
      }
    }
    return HttpFetchResult.failure(lastError ?? 'Unknown error');
  }

  void dispose() => _client.close();
}
