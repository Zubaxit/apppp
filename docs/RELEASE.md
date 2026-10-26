# Release preparation

The app is a standard Flutter Android project. Nothing in this repository publishes, hosts or
signs a binary: builds are produced locally or by CI.

## Toolchain

| Component | Version |
| --- | --- |
| Flutter | 3.27.4 (stable) — minimum 3.27 |
| Dart | 3.6 |
| JDK | 17 |
| Android Gradle Plugin | 8.7.0 |
| Gradle | 8.9 |
| Kotlin | 1.9.25 |
| compileSdk / targetSdk | 35 |
| minSdk | 23 (Android 6.0) |

## Build commands

```bash
flutter pub get

# Debug (fast install on a device)
flutter build apk --debug          # build/app/outputs/flutter-apk/app-debug.apk

# Release APK
flutter build apk --release --split-per-abi
#  -> build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk
#     app-arm64-v8a-release.apk
#     app-x86_64-release.apk

# App bundle for Google Play
flutter build appbundle --release  # build/app/outputs/bundle/release/app-release.aab
```

Artifacts live under `build/`, which is git-ignored.

## Signing (never commit keys)

1. Create an upload keystore **outside** the repository:

   ```bash
   keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA \
           -keysize 2048 -validity 10000 -alias upload
   ```

2. Copy `android/key.properties.example` to `android/key.properties` (git-ignored) and fill it in:

   ```
   storePassword=…
   keyPassword=…
   keyAlias=upload
   storeFile=/absolute/path/to/upload-keystore.jks
   ```

3. `android/app/build.gradle` picks the file up automatically. Without it, release builds are
   debug-signed so CI can still produce an installable APK — **never distribute such a build**.

## Versioning

Bump `version:` in `pubspec.yaml` (`1.0.0+1` → `1.1.0+2`). `flutter build` propagates it to
`android/local.properties`, which the Gradle script reads for `versionName`/`versionCode`.

## Pre-release checklist

- [ ] `flutter analyze --fatal-warnings` clean
- [ ] `flutter test` green
- [ ] `python3 scripts/verify_sources.py --write` run recently; report committed
- [ ] Registry review: every new source has a curated HTTPS website and a correct `feedClaim`
- [ ] Fresh-install smoke test on minSdk (23) and on a current Android release
- [ ] Offline test (airplane mode → relaunch → cached content and directory)
- [ ] `flutter build appbundle --release` with the real upload key
- [ ] Store listing: screenshots, Bengali + English description, privacy policy pointing at
      `docs/` in this repository
- [ ] Data safety form: no data collected, no data shared; network used only for publisher feeds

## What is intentionally absent

- No `google-services.json`, no Firebase, no analytics SDK, no ads SDK, no tracking.
- No `INTERNET`-adjacent permissions beyond `ACCESS_NETWORK_STATE`.
- No background service or `WorkManager` job claiming guaranteed refresh timing.
- No WebView, no JS bridge, no `usesCleartextTraffic`.
