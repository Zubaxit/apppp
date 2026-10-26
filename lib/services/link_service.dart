import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/utils/url_safety.dart';

/// All external navigation goes through here so that URL validation and the
/// "open in the browser, keep the app in the back stack" behaviour are
/// consistent everywhere.
class LinkService {
  const LinkService._();

  /// Returns true when the platform accepted the link.
  static Future<bool> openExternal(String? rawUrl) async {
    final String? safe = UrlSafety.sanitize(rawUrl);
    if (safe == null) return false;
    try {
      return await launchUrl(
        Uri.parse(safe),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      return false;
    }
  }

  /// In-app browser (Custom Tab on Android) for reading original articles.
  static Future<bool> openInAppBrowser(String? rawUrl) async {
    final String? safe = UrlSafety.sanitize(rawUrl);
    if (safe == null) return false;
    try {
      final bool launched = await launchUrl(
        Uri.parse(safe),
        mode: LaunchMode.inAppBrowserView,
      );
      if (launched) return true;
    } catch (_) {
      // Fall through to the external browser.
    }
    return openExternal(safe);
  }

  static Future<void> share(String text, {String? subject}) async {
    await Share.share(text, subject: subject);
  }

  static Future<void> copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
  }
}
