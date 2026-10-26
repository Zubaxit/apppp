import 'package:bangladesh_newspaper_hub/data/models/app_preferences.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';
import '../support/test_app.dart';

void main() {
  test('equivalent concurrent refreshes share one network operation', () async {
    final FakeFeedGateway gateway = FakeFeedGateway(
      delay: const Duration(milliseconds: 30),
    );
    final TestHarness harness = TestHarness(gateway: gateway);

    final Future<void> first = harness.feed.refresh(force: true);
    final Future<void> second = harness.feed.refresh(force: true);
    await Future.wait(<Future<void>>[first, second]);

    expect(gateway.calls, harness.registry.feedSources.length);
    expect(harness.feed.isRefreshing, isFalse);
  });

  test('cold start refreshes once even when cached metadata is fresh', () async {
    final FakeFeedGateway gateway = FakeFeedGateway();
    final stores = fakeStores();
    await stores.meta.set(
      'last_refresh_at',
      DateTime.now().toUtc().toIso8601String(),
    );
    final TestHarness harness = TestHarness(stores: stores, gateway: gateway);
    await harness.feed.start();
    final int callsAfterColdStart = gateway.calls;
    await harness.feed.start();
    expect(callsAfterColdStart, harness.registry.feedSources.length);
    expect(gateway.calls, callsAfterColdStart);
  });

  test('failed first load never completes one-time welcome state', () async {
    final FakeFeedGateway gateway = FakeFeedGateway(
      failing: <String>{'prothomalo', 'daily_star'},
    );
    final TestHarness harness = TestHarness(
      gateway: gateway,
      prefs: const AppPreferences(),
    );

    await harness.feed.start();

    expect(harness.feed.articles, isEmpty);
    expect(harness.settings.prefs.onboardingComplete, isFalse);
  });
}
