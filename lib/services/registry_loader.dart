import 'package:flutter/services.dart';

import '../data/models/news_source.dart';

/// Loads the source registry that ships with the app.
///
/// The registry is data, not code: adding a publication is a JSON edit.
class RegistryLoader {
  const RegistryLoader._();

  static const String assetPath = 'assets/data/sources.json';
  static SourceRegistry? _cached;

  static Future<SourceRegistry> load({AssetBundle? bundle, bool forceReload = false}) async {
    if (!forceReload && _cached != null) return _cached!;
    final String raw = await (bundle ?? rootBundle).loadString(assetPath);
    final SourceRegistry registry = SourceRegistry.fromJsonString(raw);
    _cached = registry;
    return registry;
  }
}
