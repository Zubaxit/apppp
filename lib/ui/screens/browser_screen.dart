import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/extensions.dart';
import '../../core/utils/url_safety.dart';
import '../../data/models/article.dart';
import '../../data/models/news_source.dart';
import '../../state/saved_controller.dart';
import '../../theme/app_theme.dart';
import '../../theme/motion.dart';
import '../../theme/tokens.dart';
import '../helpers/app_nav.dart';
import '../services/browser_engine.dart';
import '../widgets/editorial.dart';

/// In-app reader for a publisher's own page.
///
/// The app never renders publisher content as its own: the origin stays visible
/// in the chrome, "open in browser" hands off to the real site, and saving keeps
/// only what the app legitimately holds (headline, excerpt, link).
class BrowserScreen extends StatefulWidget {
  const BrowserScreen({
    super.key,
    required this.url,
    this.title,
    this.source,
    this.engine,
    this.article,
  });

  final String url;
  final String? title;
  final NewsSource? source;
  final Article? article;

  /// Injected by tests; the app builds a WebView engine.
  final BrowserEngine? engine;

  @override
  State<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends State<BrowserScreen> {
  late final BrowserEngine _engine;
  late final bool _ownsEngine;
  bool _savedLink = false;

  @override
  void initState() {
    super.initState();
    _ownsEngine = widget.engine == null;
    _engine = widget.engine ?? WebViewBrowserEngine(url: widget.url);
    _engine.addListener(_onEngine);
  }

  void _onEngine() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _engine.removeListener(_onEngine);
    if (_ownsEngine) _engine.dispose();
    super.dispose();
  }

  Future<void> _saveCurrentUrl() async {
    final String current = _engine.url;
    final String safe = UrlSafety.sanitize(current) ?? widget.url;
    final SavedController saved = context.read<SavedController>();
    final Article link = Article.create(
      sourceId: widget.source?.id ?? widget.article?.sourceId ?? 'web',
      title: widget.title ?? _engine.domain,
      link: safe,
    );
    await saved.toggle(link);
    if (!mounted) return;
    setState(() => _savedLink = true);
    context.showSnack(
      saved.isSaved(link.id) ? context.strings.savedLabel : context.strings.removeSaved,
    );
  }

  void _explainOfflineSave() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(Tokens.gutter, 0, Tokens.gutter, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              context.strings.save,
              style: context.texts.headlineSmall?.copyWith(fontSize: 19),
            ),
            const SizedBox(height: 10),
            Text(
              context.strings.saveLinkOnlyNotice,
              style: context.texts.bodyMedium?.copyWith(height: 1.6),
            ),
            const SizedBox(height: 18),
            Row(
              children: <Widget>[
                FilledButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _saveCurrentUrl();
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: context.colors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(Tokens.radiusMd),
                    ),
                  ),
                  child: Text(context.strings.savedLabel),
                ),
                const SizedBox(width: 10),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(context.strings.cancel),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String domain = _engine.domain.isNotEmpty ? _engine.domain : widget.url;
    return PopScope(
      // Back walks the page history before it leaves the reader.
      canPop: !_engine.canGoBack,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        if (_engine.canGoBack) _engine.goBack();
      },
      child: Scaffold(
        backgroundColor: context.theme.scaffoldBackgroundColor,
        body: Column(
          children: <Widget>[
            _BrowserChrome(
              domain: domain,
              title: widget.title,
              loading: _engine.loading,
              canGoBack: _engine.canGoBack,
              onClose: () => Navigator.of(context).maybePop(),
              onBack: () => _engine.goBack(),
              onReload: () => _engine.reload(),
              onExternal: () => openUrlFeedback(context, _engine.url),
              onSave: _savedLink ? null : _explainOfflineSave,
              saved: _savedLink,
            ),
            if (_engine.loading)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Tokens.gutter),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: _engine.progress == 0 ? null : _engine.progress,
                    minHeight: 2,
                    backgroundColor:
                        context.colors.onSurface.withValues(alpha: 0.06),
                  ),
                ),
              ),
            Expanded(
              child: _engine.error != null
                  ? _BrowserError(
                      message: _engine.error!,
                      onRetry: () => _engine.reload(),
                      onExternal: () => openUrlFeedback(context, _engine.url),
                    )
                  : _engine.buildView(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrowserChrome extends StatelessWidget {
  const _BrowserChrome({
    required this.domain,
    required this.title,
    required this.loading,
    required this.canGoBack,
    required this.onClose,
    required this.onBack,
    required this.onReload,
    required this.onExternal,
    required this.onSave,
    required this.saved,
  });

  final String domain;
  final String? title;
  final bool loading;
  final bool canGoBack;
  final VoidCallback onClose;
  final VoidCallback onBack;
  final VoidCallback onReload;
  final VoidCallback onExternal;
  final VoidCallback? onSave;
  final bool saved;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: GlassBar(
        padding: const EdgeInsets.fromLTRB(6, 6, 6, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                IconButton(
                  onPressed: onClose,
                  iconSize: 20,
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  icon: const Icon(Icons.close_rounded),
                ),
                IconButton(
                  onPressed: canGoBack ? onBack : null,
                  iconSize: 20,
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        domain,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.texts.labelSmall?.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                      if (title != null)
                        Text(
                          title!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.texts.labelSmall?.copyWith(fontSize: 9.5),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: loading ? null : onReload,
                  iconSize: 19,
                  tooltip: context.strings.refresh,
                  icon: const Icon(Icons.refresh_rounded),
                ),
                IconButton(
                  onPressed: onExternal,
                  iconSize: 19,
                  tooltip: context.strings.openWebsite,
                  icon: const Icon(Icons.open_in_new_rounded),
                ),
                IconButton(
                  onPressed: onSave,
                  iconSize: 19,
                  tooltip: context.strings.save,
                  icon: Icon(
                    saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                    color: saved ? context.colors.primary : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BrowserError extends StatelessWidget {
  const _BrowserError({
    required this.message,
    required this.onRetry,
    required this.onExternal,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onExternal;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Tokens.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.wifi_off_rounded, size: 26, color: context.colors.primary),
            const SizedBox(height: 12),
            Text(
              context.strings.openFailed,
              textAlign: TextAlign.center,
              style: context.texts.headlineSmall?.copyWith(fontSize: 18),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: context.texts.bodySmall?.copyWith(fontSize: 11.5),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                FilledButton(
                  onPressed: onRetry,
                  style: FilledButton.styleFrom(
                    backgroundColor: context.colors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(Tokens.radiusMd),
                    ),
                  ),
                  child: Text(context.strings.retry),
                ),
                const SizedBox(width: 10),
                TextButton(onPressed: onExternal, child: Text(context.strings.openWebsite)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Opens the in-app browser for a URL, keeping the publisher identity visible.
Future<void> openInBrowser(
  BuildContext context, {
  required String url,
  String? title,
  NewsSource? source,
  Article? article,
}) {
  final String? safe = UrlSafety.sanitize(url);
  if (safe == null) {
    context.showSnack(context.strings.openFailed);
    HapticFeedback.lightImpact();
    return Future<void>.value();
  }
  return Navigator.of(context).push<void>(
    PageRouteBuilder<void>(
      settings: const RouteSettings(name: 'browser'),
      transitionDuration: const Duration(milliseconds: 260),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (BuildContext context, Animation<double> animation, Animation<double> secondary) =>
          BrowserScreen(url: safe, title: title, source: source, article: article),
      transitionsBuilder: (BuildContext context, Animation<double> animation,
          Animation<double> secondary, Widget child) {
        if (Motion.of(context).reduce) return child;
        final CurvedAnimation curved =
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
              .animate(curved),
          child: FadeTransition(opacity: curved, child: child),
        );
      },
    ),
  );
}
