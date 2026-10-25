import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/extensions.dart';
import '../../core/utils/url_safety.dart';
import '../../data/models/article.dart';
import '../../data/models/news_source.dart';
import '../../state/saved_controller.dart';
import '../../theme/materials.dart';
import '../../theme/motion.dart';
import '../../theme/tokens.dart';
import '../helpers/app_nav.dart';
import '../services/browser_engine.dart';

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

  /// Mirrors the only two engine facts that the surrounding route needs: the
  /// system back gesture depends on page history, and the bookmark state
  /// changes when the user saves. Everything else — progress, loading, domain —
  /// is drawn by a [ListenableBuilder] inside the chrome, so the platform view
  /// is not rebuilt a hundred times while a page loads.
  bool _canGoBack = false;

  @override
  void initState() {
    super.initState();
    _ownsEngine = widget.engine == null;
    _engine = widget.engine ?? WebViewBrowserEngine(url: widget.url);
    _canGoBack = _engine.canGoBack;
    _engine.addListener(_onEngine);
  }

  void _onEngine() {
    if (!mounted) return;
    if (_engine.canGoBack == _canGoBack) return;
    setState(() => _canGoBack = _engine.canGoBack);
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
            ListenableBuilder(
              listenable: _engine,
              builder: (BuildContext context, Widget? child) => BrowserToolbar(
                domain: _engine.domain.isNotEmpty ? _engine.domain : domain,
                title: widget.title,
                loading: _engine.loading,
                progress: _engine.progress,
                canGoBack: _engine.canGoBack,
                onClose: () => Navigator.of(context).maybePop(),
                onBack: () => _engine.goBack(),
                onReload: () => _engine.reload(),
                onExternal: () => openUrlFeedback(context, _engine.url),
                onSave: _savedLink ? null : _explainOfflineSave,
                saved: _savedLink,
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

/// The browser's controls, in one row: close, the address pill, then page
/// history, reload, hand-off to the system browser and save.
///
/// The pill takes whatever width the discs leave, so the layout never pushes a
/// control off screen; below [compactBreakpoint] the discs and the type step
/// down one size instead of clipping anything. The row is deliberately one
/// line tall — the page below it is the content, the chrome is a tool.
class BrowserToolbar extends StatelessWidget {
  const BrowserToolbar({
    super.key,
    required this.domain,
    required this.title,
    required this.loading,
    required this.progress,
    required this.canGoBack,
    required this.onClose,
    required this.onBack,
    required this.onReload,
    required this.onExternal,
    required this.onSave,
    required this.saved,
  });

  /// Below this width the toolbar switches to its compact metric.
  static const double compactBreakpoint = 360;

  final String domain;
  final String? title;
  final bool loading;
  final double progress;
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
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            GlassBar(
              radius: Tokens.radiusLg,
              padding: const EdgeInsets.all(4),
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final bool compact =
                      constraints.maxWidth < compactBreakpoint;
                  final double tap = compact ? 32 : 36;
                  final double glyph = compact ? 17 : 18.5;
                  return Row(
                    children: <Widget>[
                      BrowserToolButton(
                        tool: BrowserTool.close,
                        icon: Icons.close_rounded,
                        tooltip:
                            MaterialLocalizations.of(context).closeButtonTooltip,
                        size: glyph,
                        tap: tap,
                        onTap: onClose,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: _AddressPill(
                          domain: domain,
                          title: title,
                          compact: compact,
                        ),
                      ),
                      BrowserToolButton(
                        tool: BrowserTool.back,
                        icon: Icons.arrow_back_rounded,
                        tooltip:
                            MaterialLocalizations.of(context).backButtonTooltip,
                        size: glyph,
                        tap: tap,
                        onTap: canGoBack ? onBack : null,
                      ),
                      BrowserToolButton(
                        tool: BrowserTool.reload,
                        icon: Icons.refresh_rounded,
                        tooltip: context.strings.refresh,
                        size: glyph,
                        tap: tap,
                        onTap: loading ? null : onReload,
                      ),
                      BrowserToolButton(
                        tool: BrowserTool.external,
                        icon: Icons.open_in_new_rounded,
                        tooltip: context.strings.openWebsite,
                        size: glyph,
                        tap: tap,
                        onTap: onExternal,
                      ),
                      BrowserToolButton(
                        tool: BrowserTool.bookmark,
                        icon: saved
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_border_rounded,
                        tooltip: context.strings.save,
                        size: glyph,
                        tap: tap,
                        active: saved,
                        onTap: onSave,
                      ),
                    ],
                  );
                },
              ),
            ),
            // A 2 px rule states loading without adding a second chrome row.
            // It is determinate when the engine reports a fraction and a thin
            // sweep when it does not; it disappears entirely once the page is
            // in, so a failed page is never left spinning.
            if (loading)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: progress <= 0 ? null : progress,
                    minHeight: 2,
                    backgroundColor:
                        context.colors.onSurface.withValues(alpha: 0.05),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The controls the toolbar owns. The enum exists so tests can address one
/// control by name instead of by icon or by position.
enum BrowserTool { close, back, reload, external, bookmark }

/// One toolbar disc.
///
/// A disabled disc stays in place and keeps its size — removing it would make
/// the remaining controls jump around mid-page-load — and only drops to a
/// quieter ink. The press compression comes from the shared jelly surface.
class BrowserToolButton extends StatelessWidget {
  const BrowserToolButton({
    super.key,
    required this.tool,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.size = 18.5,
    this.tap = 36,
    this.active = false,
  });

  final BrowserTool tool;
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final double size;
  final double tap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onTap != null;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: tooltip,
        child: JellySurface(
          key: ValueKey<String>('browser-${tool.name}'),
          onTap: onTap,
          scale: 0.9,
          enabled: enabled,
          boundary: false,
          child: SizedBox(
            width: tap,
            height: tap,
            child: Center(
              child: Icon(
                icon,
                size: size,
                color: active
                    ? context.colors.primary
                    : (enabled
                        ? context.colors.onSurface
                        : context.colors.onSurfaceVariant
                            .withValues(alpha: 0.38)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The address pill: the real origin on the first line, the article's own
/// headline as a quieter second line when there is room for it.
class _AddressPill extends StatelessWidget {
  const _AddressPill({
    required this.domain,
    required this.title,
    required this.compact,
  });

  final String domain;
  final String? title;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final bool dark = context.isDark;
    final String? subtitle = (title ?? '').trim().isEmpty ? null : title;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 9 : 11,
        vertical: compact ? 5 : 6,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Tokens.radiusPill),
        color: dark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.035),
        border: Border.all(
          color: dark ? Tokens.nightHairline : Tokens.hairline,
          width: 0.8,
        ),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.public_rounded,
            size: compact ? 11 : 12,
            color: context.colors.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  domain,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: context.texts.labelSmall?.copyWith(
                    fontSize: compact ? 10.5 : 11.5,
                    height: 1.25,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.1,
                    color: context.colors.onSurface,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    style: context.texts.labelSmall?.copyWith(
                      fontSize: compact ? 9 : 9.5,
                      height: 1.3,
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
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
