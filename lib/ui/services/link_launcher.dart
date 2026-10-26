import 'package:share_plus/share_plus.dart';

import '../../core/utils/url_safety.dart';
import '../../services/link_service.dart';

/// UI-facing wrapper so widget tests can exercise screens without hitting the
/// platform plugin channels.
class LinkLauncher {
  const LinkLauncher._();

  static Future<bool> open(String? url, {bool inApp = false}) {
    if (UrlSafety.sanitize(url) == null) return Future<bool>.value(false);
    return inApp
        ? LinkService.openInAppBrowser(url)
        : LinkService.openExternal(url);
  }

  static Future<void> share(String text, {String? subject}) async {
    await Share.share(text, subject: subject);
  }
}
