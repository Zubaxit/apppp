import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/extensions.dart';
import '../../data/models/author_profile.dart';
import '../../services/profile_store.dart';
import '../../theme/materials.dart';
import '../../theme/motion.dart';
import '../../theme/tokens.dart';
import '../helpers/app_nav.dart';
import '../services/link_launcher.dart';
import '../widgets/actions.dart';
import '../widgets/brand.dart';
import '../widgets/editorial.dart';
import 'settings_screen.dart' show SettingsScreen;

/// About, split into two parts that never blur together.
///
/// The first part is the app: what it does, where the content comes from, what
/// it stores on the device, and the explicit statement that it is not affiliated
/// with any publisher. The second part is the person who made it — an editable,
/// local-only profile seeded with the facts the owner supplied.
class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key, this.store});

  /// Injected in tests; the real app uses the shared preferences store.
  final ProfileStore? store;

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  late final Future<ProfileStore> _storeFuture = widget.store != null
      ? Future<ProfileStore>.value(widget.store!)
      : SharedPreferencesProfileStore.create();

  ProfileStore? _store;
  AuthorProfile _profile = const AuthorProfile();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final ProfileStore store = await _storeFuture;
      final AuthorProfile profile = await store.load();
      if (!mounted) return;
      setState(() {
        _store = store;
        _profile = profile;
        _loading = false;
      });
    } catch (_) {
      // A preferences failure must not hide the About information itself.
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _edit() async {
    final AuthorProfile? edited = await Navigator.of(context).push<AuthorProfile>(
      editorialRoute<AuthorProfile>(
        ProfileEditScreen(profile: _profile),
        name: 'profile-edit',
      ),
    );
    if (edited == null || !mounted) return;
    setState(() => _profile = edited);
    try {
      await _store?.save(edited);
    } catch (_) {
      if (!mounted) return;
      context.showSnack(context.strings.errorBody);
      return;
    }
    if (mounted) context.showSnack(context.strings.profileSaved);
  }

  Future<void> _resetProfile() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(context.strings.profileReset),
        content: Text(context.strings.profileResetBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.strings.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.strings.clear),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _store?.clear();
    } catch (_) {
      // best effort
    }
    if (!mounted) return;
    setState(() => _profile = const AuthorProfile());
    context.showSnack(context.strings.profileSaved);
  }

  @override
  Widget build(BuildContext context) {
    final registry = context.registry;
    final int withFeed = registry.sources.where((s) => s.hasFeed).length;
    final int withEpaper = registry.sources.where((s) => s.hasEpaper).length;
    final bool bengali = context.isBengali;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AuroraBackdrop(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: <Widget>[
              _AboutHeader(),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    Tokens.gutter,
                    2,
                    Tokens.gutter,
                    48,
                  ),
                  children: <Widget>[
          // ------------------------------------------------------- the app
          Row(
            children: <Widget>[
              const AmarNewsMark(size: 62),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      context.strings.appName,
                      style: context.texts.titleLarge?.copyWith(
                        fontFamily: Tokens.serif,
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.strings.appTagline,
                      style: context.texts.labelSmall?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${context.strings.version} ${SettingsScreen.appVersion}',
                      style: context.texts.labelSmall?.copyWith(fontSize: 10.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            context.strings.aboutBody,
            style: context.texts.bodyMedium?.copyWith(height: 1.65),
          ),
          const SizedBox(height: 20),
          _AboutBlock(
            title: context.strings.registryTitle,
            body: context.strings.registryBody,
            stats: <Widget>[
              Expanded(
                child: _StatChip(
                  value: '${registry.sources.length}',
                  label: context.strings.sourcesListed,
                ),
              ),
              Expanded(
                child: _StatChip(
                  value: '${registry.sources.where((s) => s.website.isNotEmpty).length}',
                  label: context.strings.sourcesWithWebsite,
                ),
              ),
              Expanded(
                child: _StatChip(value: '$withFeed', label: context.strings.sourcesWithFeed),
              ),
              Expanded(
                child: _StatChip(value: '$withEpaper', label: context.strings.sourcesWithEpaper),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _AboutBlock(
            title: context.strings.publisherNotice.split('।').first,
            body: context.strings.publisherNotice,
          ),
          const SizedBox(height: 14),
          _AboutBlock(
            title: context.strings.privacyTitle,
            body: context.strings.privacyBody,
          ),
          const SizedBox(height: 14),
          _AboutBlock(
            title: context.strings.dataOnDevice,
            body: context.strings.dataOnDeviceBody,
          ),
          const SizedBox(height: 14),
          _AboutBlock(
            title: context.strings.licence.split(':').first,
            body: context.strings.licence,
          ),
          const SizedBox(height: 8),
          JellySurface(
            onTap: () => openSourceHealth(context),
            scale: 0.99,
            child: GlassPanel(
              radius: Tokens.radiusSm,
              blur: 0,
              elevation: 0.2,
              sheen: false,
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.monitor_heart_outlined,
                    size: 18,
                    color: context.colors.primary,
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          context.strings.sourceHealth,
                          style: context.texts.labelLarge?.copyWith(fontSize: 12.5),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          context.strings.sourceHealthBody,
                          style: context.texts.labelSmall?.copyWith(
                            fontSize: 10.2,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: context.colors.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          Text(
            bengali
                ? 'ডেটা: ${registry.updatedAt.year}-${registry.updatedAt.month.toString().padLeft(2, '0')}-${registry.updatedAt.day.toString().padLeft(2, '0')}'
                : 'Registry data: ${registry.updatedAt.toIso8601String().split('T').first}',
            style: context.texts.labelSmall?.copyWith(fontSize: 10.5),
          ),

          // ------------------------------------------------- the author
          const SizedBox(height: 30),
          const FadingRule(inset: 0),
          const SizedBox(height: 26),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            _AuthorSection(
              profile: _profile,
              onEdit: _edit,
              onReset: _resetProfile,
            ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The screen's own masthead: a back disc, the serif title and the build mark.
class _AboutHeader extends StatelessWidget {
  const _AboutHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Tokens.gutter, 8, Tokens.gutter, 10),
      child: Row(
        children: <Widget>[
          GlassIconButton(
            icon: Icons.arrow_back_rounded,
            tooltip: context.strings.back,
            onTap: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              context.strings.aboutTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.texts.titleLarge?.copyWith(
                fontFamily: Tokens.serif,
                fontSize: 21,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
          ),
          Text(
            'v${SettingsScreen.appVersion}',
            style: context.texts.labelSmall?.copyWith(
              fontSize: 10,
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// The author panel: a monogram, the name in both scripts, and the supplied
/// facts. It carries an explicit edit affordance because none of this should be
/// frozen into the build.
class _AuthorSection extends StatelessWidget {
  const _AuthorSection({
    required this.profile,
    required this.onEdit,
    required this.onReset,
  });

  final AuthorProfile profile;
  final VoidCallback onEdit;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final bool dark = context.isDark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    context.colors.primary.withValues(alpha: dark ? 0.26 : 0.14),
                    context.colors.primary.withValues(alpha: dark ? 0.08 : 0.03),
                  ],
                ),
                border: Border.all(
                  color: context.colors.primary.withValues(alpha: 0.28),
                  width: 0.9,
                ),
                boxShadow: Tokens.shadow(context, lift: 0.6),
              ),
              child: Text(
                profile.initial,
                style: context.texts.headlineSmall?.copyWith(
                  fontFamily: Tokens.serif,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: context.colors.primary,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Kicker(context.strings.aboutAuthorTitle),
                  const SizedBox(height: 6),
                  Text(
                    profile.name,
                    style: context.texts.titleLarge?.copyWith(
                      fontFamily: Tokens.serif,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '${profile.nameEn} · ${profile.role}',
                    style: context.texts.labelSmall?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: context.strings.editProfile,
              onPressed: onEdit,
              icon: Icon(
                Icons.edit_outlined,
                size: 19,
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          profile.bio,
          style: context.texts.bodyMedium?.copyWith(height: 1.7),
        ),
        const SizedBox(height: 12),
        Text(
          profile.longBio,
          style: context.texts.bodySmall?.copyWith(
            height: 1.75,
            color: context.colors.onSurfaceVariant,
          ),
        ),
        if (profile.interests.isNotEmpty) ...<Widget>[
          const SizedBox(height: 16),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: <Widget>[
              for (final String interest in profile.interests)
                GlassChip(label: interest, dense: true),
            ],
          ),
        ],
        if (profile.links.isNotEmpty) ...<Widget>[
          const SizedBox(height: 18),
          for (final String link in profile.links)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Pressable(
                onTap: () => LinkLauncher.open(link),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: <Widget>[
                      Icon(
                        Icons.link_rounded,
                        size: 15,
                        color: context.colors.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          link,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.texts.labelSmall?.copyWith(
                            fontSize: 11.5,
                            color: context.colors.primary,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.north_east_rounded,
                        size: 13,
                        color: context.colors.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
        const SizedBox(height: 14),
        Row(
          children: <Widget>[
            JellyButton(
              label: context.strings.editProfile,
              icon: Icons.edit_outlined,
              compact: true,
              onPressed: onEdit,
            ),
            const SizedBox(width: 10),
            JellySurface(
              onTap: onReset,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                child: Text(
                  context.strings.profileReset,
                  style: context.texts.labelSmall?.copyWith(
                    fontSize: 11.5,
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Editor for the local profile.
///
/// Every field is optional; blank values fall back to the starting profile so
/// the panel can never turn into an empty block. Links must be plain web
/// addresses, and the screen never asks for anything private.
class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key, required this.profile});

  final AuthorProfile profile;

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  late final TextEditingController _name = TextEditingController(text: widget.profile.name);
  late final TextEditingController _nameEn =
      TextEditingController(text: widget.profile.nameEn);
  late final TextEditingController _role = TextEditingController(text: widget.profile.role);
  late final TextEditingController _bio = TextEditingController(text: widget.profile.bio);
  late final TextEditingController _longBio =
      TextEditingController(text: widget.profile.longBio);
  late final TextEditingController _interests =
      TextEditingController(text: widget.profile.interests.join(', '));
  late final TextEditingController _links =
      TextEditingController(text: widget.profile.links.join('\n'));
  String? _linkError;

  @override
  void dispose() {
    _name.dispose();
    _nameEn.dispose();
    _role.dispose();
    _bio.dispose();
    _longBio.dispose();
    _interests.dispose();
    _links.dispose();
    super.dispose();
  }

  List<String> _lines(String raw) => raw
      .split(RegExp(r'[\n,]'))
      .map((String e) => e.trim())
      .where((String e) => e.isNotEmpty)
      .toList();

  void _save() {
    final List<String> links = _lines(_links.text);
    final String? badLink = links
        .cast<String?>()
        .firstWhere((String? l) => !AuthorProfile.isSupportedLink(l!), orElse: () => null);
    if (badLink != null) {
      setState(() => _linkError = badLink);
      return;
    }
    setState(() => _linkError = null);

    const AuthorProfile fallback = AuthorProfile();
    String keep(String value, String original) {
      final String trimmed = value.trim();
      return trimmed.isEmpty ? original : trimmed;
    }

    final AuthorProfile next = AuthorProfile(
      name: keep(_name.text, fallback.name),
      nameEn: keep(_nameEn.text, fallback.nameEn),
      role: keep(_role.text, fallback.role),
      bio: keep(_bio.text, fallback.bio),
      longBio: keep(_longBio.text, fallback.longBio),
      interests: _lines(_interests.text),
      links: links,
    );
    Navigator.of(context).pop(next);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AuroraBackdrop(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Tokens.gutter,
                  8,
                  Tokens.gutter,
                  8,
                ),
                child: Row(
                  children: <Widget>[
                    GlassIconButton(
                      icon: Icons.close_rounded,
                      tooltip: context.strings.cancel,
                      onTap: () => Navigator.of(context).maybePop(),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        context.strings.editProfile,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.texts.titleLarge?.copyWith(
                          fontFamily: Tokens.serif,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    JellyButton(
                      label: context.strings.done,
                      compact: true,
                      filled: true,
                      onPressed: _save,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    Tokens.gutter,
                    8,
                    Tokens.gutter,
                    48,
                  ),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  children: <Widget>[
          _ProfileField(
            label: context.strings.profileName,
            controller: _name,
            hint: const AuthorProfile().name,
          ),
          _ProfileField(
            label: 'English name',
            controller: _nameEn,
            hint: const AuthorProfile().nameEn,
          ),
          _ProfileField(
            label: context.strings.profileRole,
            controller: _role,
            hint: const AuthorProfile().role,
          ),
          _ProfileField(
            label: context.strings.profileBio,
            controller: _bio,
            lines: 3,
          ),
          _ProfileField(
            label: context.strings.profileLongBio,
            controller: _longBio,
            lines: 7,
          ),
          _ProfileField(
            label: context.strings.profileInterests,
            controller: _interests,
            hint: 'বাংলা সাহিত্য, কবিতা',
          ),
          _ProfileField(
            label: context.strings.profileLinks,
            controller: _links,
            lines: 3,
            hint: 'https://',
            error: _linkError == null
                ? null
                : '${context.strings.openFailed}: ${_linkError!}',
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 8),
          Text(
            context.strings.dataOnDeviceBody,
            style: context.texts.labelSmall?.copyWith(
              fontSize: 10.5,
              height: 1.5,
              color: context.colors.onSurfaceVariant,
            ),
          ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileField extends StatelessWidget {
  const _ProfileField({
    required this.label,
    required this.controller,
    this.lines = 1,
    this.hint,
    this.error,
    this.keyboardType,
  });

  final String label;
  final TextEditingController controller;
  final int lines;
  final String? hint;
  final String? error;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        minLines: lines,
        maxLines: lines,
        keyboardType: keyboardType,
        textInputAction: lines > 1 ? TextInputAction.newline : TextInputAction.next,
        style: context.texts.bodyMedium?.copyWith(height: 1.5),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          errorText: error,
          alignLabelWithHint: true,
          filled: true,
          fillColor: context.isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.white.withValues(alpha: 0.55),
          labelStyle: context.texts.labelSmall?.copyWith(
            fontSize: 11.5,
            color: context.colors.onSurfaceVariant,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(Tokens.radiusMd),
            borderSide: BorderSide(
              color: context.isDark ? Tokens.nightHairline : Tokens.hairline,
              width: 0.9,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(Tokens.radiusMd),
            borderSide: BorderSide(
              color: context.isDark ? Tokens.nightHairline : Tokens.hairline,
              width: 0.9,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(Tokens.radiusMd),
            borderSide: BorderSide(color: context.colors.primary, width: 1.2),
          ),
        ),
      ),
    );
  }
}

class _AboutBlock extends StatelessWidget {
  const _AboutBlock({required this.title, required this.body, this.stats});

  final String title;
  final String body;
  final List<Widget>? stats;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      radius: Tokens.radiusMd,
      blur: 0,
      elevation: 0.3,
      sheen: false,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: context.texts.titleSmall?.copyWith(
              fontFamily: Tokens.serif,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: context.texts.bodySmall?.copyWith(height: 1.65, fontSize: 12),
          ),
          if (stats != null) ...<Widget>[
            const SizedBox(height: 12),
            Row(children: stats!),
          ],
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          value,
          style: context.texts.headlineSmall?.copyWith(
            fontSize: 20,
            color: context.colors.primary,
          ),
        ),
        Text(
          label,
          style: context.texts.labelSmall?.copyWith(fontSize: 9.5, height: 1.3),
          maxLines: 2,
        ),
      ],
    );
  }
}
