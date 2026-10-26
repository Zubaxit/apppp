import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/models/news_source.dart';
import '../state/feed_controller.dart';
import '../state/saved_controller.dart';
import '../state/settings_controller.dart';
import 'l10n/app_strings.dart';

extension BuildContextX on BuildContext {
  AppStrings get strings => AppStrings.of(this);
  bool get isBengali => strings.languageCode == 'bn';

  SettingsController get settings => read<SettingsController>();
  FeedController get feed => read<FeedController>();
  SavedController get saved => read<SavedController>();

  SourceRegistry get registry => read<SourceRegistry>();

  ThemeData get theme => Theme.of(this);
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get texts => Theme.of(this).textTheme;

  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  void showSnack(String message, {SnackBarAction? action}) {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(this);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), action: action));
  }
}

/// Convenience for reading the localized name of a source from anywhere.
extension SourceNaming on NewsSource {
  String nameFor(BuildContext context) =>
      localizedName(bengali: context.isBengali);
}
