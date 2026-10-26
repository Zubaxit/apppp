import 'dart:convert';

/// Decodes a feed body from its raw bytes.
///
/// The `http` package decodes a response body with the charset from the
/// `Content-Type` header and **falls back to latin-1** when the server sends no
/// charset. Bengali feeds routinely answer with a bare `application/rss+xml` or
/// `text/xml`, so using `response.body` turned every Bengali headline into
/// mojibake and could break parsing outright. The bytes are the source of
/// truth, so decoding happens here instead:
///
///  * an explicit `charset=latin1`/`iso-8859-1` is honoured;
///  * a UTF-8 BOM is skipped;
///  * everything else is decoded as UTF-8 with malformed sequences tolerated,
///    because one broken byte must never cost a whole publisher.
String decodeFeedBody(List<int> bytes, String? contentType) {
  final String? charset = contentType == null
      ? null
      : RegExp(r'charset=([\w-]+)', caseSensitive: false)
          .firstMatch(contentType)
          ?.group(1);
  final List<int> body = bytes.length >= 3 &&
          bytes[0] == 0xEF &&
          bytes[1] == 0xBB &&
          bytes[2] == 0xBF
      ? bytes.sublist(3)
      : bytes;
  try {
    if (charset != null) {
      switch (charset.toLowerCase()) {
        case 'iso-8859-1':
        case 'latin1':
        case 'latin-1':
        case 'windows-1252':
          return latin1.decode(body, allowInvalid: true);
        default:
          return utf8.decode(body, allowMalformed: true);
      }
    }
    return utf8.decode(body, allowMalformed: true);
  } catch (_) {
    return latin1.decode(body, allowInvalid: true);
  }
}
