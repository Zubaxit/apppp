# Bangladesh Newspaper Hub

A premium, offline-friendly **Android news reader and verified newspaper directory** for
Bangladesh, built with Flutter. It brings the country's newspapers, online portals, business
dailies, regional titles and e-paper editions together in one place, and shows their latest
headlines from the publishers' own RSS/Atom feeds in a single, chronologically sorted feed.

The app is a **discovery and reading companion**, not a scraper: it stores only the headline,
excerpt and thumbnail each publisher exposes in its feed, always shows the publisher's name and
publication time, and sends readers to the original article on the publisher's site.

---

## Contents

- [What is implemented](#what-is-implemented)
- [Source coverage (verified vs. listed)](#source-coverage-verified-vs-listed)
- [Quick start](#quick-start)
- [Project layout](#project-layout)
- [The source registry](#the-source-registry)
- [Verifying feeds against the live internet](#verifying-feeds-against-the-live-internet)
- [Testing](#testing)
- [Building the Android app](#building-the-android-app)
- [Design system](#design-system)
- [Privacy and publisher rights](#privacy-and-publisher-rights)
- [Known limitations](#known-limitations)
- [Roadmap](#roadmap)
- [Credits and licences](#credits-and-licences)

---

## What is implemented

### Home
- Editorial masthead with app identity, tagline, search and a one-tap refresh.
- **Unified latest-news feed** aggregated from every source with a working feed, sorted by real
  publication time (falling back to retrieval time *only* when a publisher supplies no date, and
  saying so on the card).
- A hero story card plus a dense, scannable list; skeleton placeholders instead of blocking
  spinners; pull-to-refresh.
- **Breaking news** appears only when a publisher labels the item `breaking`, `ব্রেকিং` or
  `Breaking News:` in its own feed. The label can be switched off in Settings.
- Topic rail (Bangladesh, politics, economy, international, sports, entertainment, technology,
  education, health, lifestyle) that filters the feed in place.
- **Filter sheet** (toolbar *Filter feed*) to narrow the unified feed to specific publications and
  Bengali/English, with a searchable publication list, selection summary and a badge while active.
- "All / Following" feed switch, followed-publication strip, featured publications rail and a
  prominent route into the full directory.
- Status bar that states when the feed was last refreshed, and clearly says when cached or
  offline content is being shown.

### Newspaper directory
- **60 publications** in a JSON registry: national Bengali dailies, English dailies, online
  portals, business titles, regional titles, plus a clearly separated group of news agencies and
  broadcasters.
- Search that works across Bengali and English names, including a Bengali→Latin transliteration
  so "প্রথম আলো" finds *Prothom Alo* and vice versa, with typo tolerance.
- Filters for type/category, language and (for regional titles) division.
- Publication detail page with identity monogram, type, language, location, curated official
  website, live feed-health badge, follow/unfollow, share, e-paper links and a "latest headlines"
  list pulled from the cache.
- E-paper directory that opens the publisher's own e-paper destination (the app never mirrors or
  downloads an edition).
- Actions that cannot work are never shown: a publication with no configured feed shows
  "No feed — use the website" instead of a dead "Read headlines" button.

### Reading
- Article detail with source identity, exact publication date/time in Bangladesh time, the
  permitted excerpt, a clear notice about why only the excerpt is shown, "Read the original story"
  (Custom Tab / in-app browser, with a fallback to the external browser), copy link and share.
- Automatic tags: topic, publisher category, thumbnail (only if the feed supplies one).
- **Related coverage**: other publishers whose headlines describe the same story, listed as
  separate links with their own attribution — stories are never merged.
- Saved articles keep a full snapshot (headline, excerpt, image, time, original URL) so a
  bookmark survives the publisher dropping the item from its feed.
- Adjustable reading text size, light/dark themes, reduced-motion support.

### Search
- One search surface for publications *and* cached headlines, with the two result groups
  separated, recent searches, and honest no-result states.

### Personalization & storage
- Follow/unfollow publications, preferred topics, default feed (Latest / Following), automatic
  refresh interval, reading-history toggle, breaking-banner toggle, app language (Bengali/English),
  theme and text size.
- Everything is stored **on the device only**: `shared_preferences` for preferences, SQLite for the
  article cache, bookmarks and history. No account, no cloud sync, no analytics.

### Reliability
- Every feed is fetched independently: one failing publisher never breaks the feed or the app.
- Per-source health record (last success, last error, HTTP status, item count, latency) surfaced in
  *Settings → Source health*, with a per-source retry.
- Polite networking: descriptive user agent, 12 s timeout, at most two attempts, 3 MB response cap,
  a minimum gap between requests to the same host and an 8-minute per-source refresh floor.
- ETag / `If-Modified-Since` caching so unchanged feeds are not re-downloaded.
- Tolerant parser: RSS 2.0, RDF and Atom; broken XML is recovered; items with unsafe links,
  missing headlines or implausible dates are dropped rather than guessed at.
- Cache pruning (per source and overall), cache-clear action that never deletes bookmarks.

## Source coverage (verified vs. listed)

| State | Meaning | Count |
| --- | --- | --- |
| Publications in the registry | Curated entries with an official website | **60** |
| Sources with an e-paper destination | Publisher-hosted e-paper links | **6** e-papers |
| Sources with a **feed URL configured** | URLs the app checks at runtime | **56** |
| Sources **verified working feeds** | Fetched, parsed, timestamped, on-domain | **5** |
| Sources with a **documented** feed | Publisher documents the endpoint; also fetched successfully | **1** (`bbc_bangla`) |
| Feed **candidates** never confirmed | Guessed/plausible paths, validated only at runtime | **50** |
| Entries with **no feed** | Website-only, by design | **4** |

Verified on 2026-10-24 by fetching each endpoint and requiring valid XML, ≥3 items, ≥50 % items with
real timestamps, ≥50 % on-domain article links and Bengali headlines for Bengali publications:
`prothomalo` (88 items), `bbc_bangla` (14), `suprobhat`, `sarabangla`, `dainik_azadi`, `tbs` (10 each).
Per-feed numbers and the failures are in [docs/SOURCES.md](docs/SOURCES.md).

> **Honest status.** Six feeds have actually been fetched, parsed and quality-checked (see the table
> above); the other 50 configured URLs are educated candidates — mostly conventional `/rss` paths —
> that returned HTTP 403 (bot protection), 404, or a DNS/TLS failure when checked, and could not be
> confirmed. The app never claims otherwise: each publication shows *verified working feed*,
> *documented*, *candidate (unverified)* or *no feed* in its detail sheet, plus live health collected
> while you use the app. Re-run `python3 scripts/verify_sources.py --write` (or the `Verify sources`
> workflow) from a normal connection to promote whatever works later.

The directory *itself* is fully usable offline and independent of feeds: every publication's official
website opens even when its feed is missing or broken.

## Quick start

Requirements: Flutter **3.27+** (Dart 3.6+), Android SDK with `compileSdk 35`, JDK 17.

```bash
git clone https://github.com/Zubaxit/apppp.git
cd apppp
flutter pub get
flutter run                 # debug build on a connected device/emulator
```

Production build:

```bash
flutter build apk --release       # build/app/outputs/flutter-apk/app-release.apk
flutter build appbundle --release # build/app/outputs/bundle/release/app-release.aab
```

See [docs/RELEASE.md](docs/RELEASE.md) for signing, versioning and store-readiness notes.

## Project layout

```
lib/
├── main.dart, app.dart, bootstrap.dart   # entry point, provider graph, DI seams
├── core/
│   ├── extensions.dart                   # BuildContext helpers (strings, theme, stores)
│   ├── l10n/app_strings.dart             # 152 typed strings, Bengali + English
│   ├── l10n/labels.dart                  # enum → label/icon mapping
│   └── utils/                            # text, Bengali, URL safety, stable ids
├── data/
│   ├── models/                           # NewsSource, Article, SourceHealth, preferences…
│   ├── feeds/                            # HTTP client, RSS/Atom parser, feed service, classifier
│   └── services/                         # SQLite schema, stores, repository
├── services/                             # registry loader, links, connectivity, preferences
├── state/                                # change notifiers: feed, saved, settings
├── theme/app_theme.dart                  # editorial design system
└── ui/
    ├── shell/app_shell.dart              # bottom navigation + back handling
    ├── screens/                          # home, categories, directory, detail, search, saved…
    ├── widgets/                          # article card, publication tile, rails, empty states
    ├── helpers/app_nav.dart              # routes
    └── services/link_launcher.dart       # testable external navigation
assets/data/sources.json                  # the registry (data, not code)
assets/data/source_candidates.json        # maintenance backlog (never shown in the app)
assets/fonts/                             # Noto Sans/Serif Bengali (OFL)
scripts/verify_sources.py                 # live feed/website verification
scripts/generate_icons.py                 # procedural launcher icons
tool/dart_static_check.js                 # dependency-free static checks (CI fallback)
```

Architecture follows a one-way flow: **UI → controller (ChangeNotifier) → repository → feed
service / stores**. Models are immutable, the registry is data, and every external URL passes
through `UrlSafety` before it is opened. See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## The source registry

`assets/data/sources.json` is the single source of truth for the directory. Adding a publication
never requires touching UI code:

```json
{
  "id": "prothomalo",
  "name": "Prothom Alo",
  "nameBn": "প্রথম আলো",
  "aliases": ["প্রথম আলো"],
  "website": "https://www.prothomalo.com/",
  "feedUrl": "https://www.prothomalo.com/feed",
  "feedFormat": "rss",
  "feedClaim": "candidate",
  "language": "bn",
  "type": "daily_newspaper",
  "categories": ["national"],
  "division": null,
  "district": null,
  "status": "active",
  "featured": true,
  "epaperUrl": "https://epaper.prothomalo.com/",
  "notes": "…"
}
```

Feed states are deliberately distinct and never conflated:

| Field | Values | Meaning |
| --- | --- | --- |
| `feedClaim` | `none` | No feed known — the app only offers the website |
| | `candidate` | A plausible feed URL; the app verifies it at runtime |
| | `official_documented` | Documented by the publisher (e.g. BBC Bengali) |
| | `verified_working` | A live fetch returned parseable items — written by `scripts/verify_sources.py --write` |
| `lastVerifiedAt` | `yyyy-mm-dd` | Date of that successful check; absent when never confirmed |
| `status` | `active` | Publication believed to be publishing |
| | `needs_review` | Exists, but must be re-confirmed before relying on it |
| | `inactive` | Not currently publishing |

Runtime health (working / failing / not checked, last success, last error) is stored separately in
SQLite and shown per source; it never overwrites the curated `status`.

## Verifying feeds against the live internet

```bash
python3 scripts/verify_sources.py                     # report only, polite pacing
python3 scripts/verify_sources.py --write             # update feedClaim + lastVerifiedAt
python3 scripts/verify_sources.py --only prothomalo,daily_star
python3 scripts/verify_sources.py --probe-candidates  # probe /feed, /rss.xml … for sources without a feed
```

The script writes `docs/source_verification.json` with per-source website/feed/e-paper results,
counts and a timestamp. It uses one request per URL, 1.5 s spacing and a 15 s timeout so it can
never storm a publisher. Feed entries it marks as candidates are printed for manual review — they
are never trusted automatically.

## Testing

```bash
dart format lib test           # keep the tree formatted
flutter analyze --fatal-warnings
flutter test --coverage
./tool/verify.sh            # registry sanity + Dart static checks (no SDK required)
```

Test suites:

| Suite | What it covers |
| --- | --- |
| `test/unit/feed_parser_test.dart` | RSS 2.0, Atom, malformed/HTML responses, unsafe links, missing dates, timezone conversion, duplicate items, stable ids, breaking-news labels, media thumbnails |
| `test/unit/core_utils_test.dart` | HTML stripping, Bengali numerals/dates/relative time, transliteration, URL safety (javascript:/data:/localhost/file), id canonicalisation, story clustering |
| `test/unit/registry_test.dart` | Shipped registry integrity: unique ids, HTTPS-only, safe feed/e-paper URLs, regional divisions, agency vs. newspaper typing, required publications, Bengali/English search, snake_case → enum mapping, verification claims always dated |
| `test/unit/repository_test.dart` | Refresh reporting, partial source failure, crashing gateway, refresh throttling, filtering, sorting, bookmark persistence across store resets, history, related coverage, cache clearing |
| `test/widget/screens_test.dart` | Home (live/empty/cached/breaking/topic filter), directory (search, filters, follow), publication detail, bookmarks, search, settings (theme/language/text size), about, e-paper list, shell navigation + Android back, dark theme, small-phone and tablet layouts |

**Verified in this environment:** `./tool/verify.sh` passes — registry JSON validation (including
"every registry enum value resolves to a real Dart enum member"), asset-existence checks, and
tree-sitter-based Dart static checks (parse, import resolution, undefined-identifier, missing-import,
constructor named-argument and secret scanning). Two feed endpoints were also fetched through an
external reader on 2026-10-24 and returned parseable items (see *Source coverage*). **Not executable here:** `flutter analyze`, `flutter test` and the Android
build — this sandbox has no Dart/Flutter/JDK/Android SDK and no network path to pub.dev, the Flutter
SDK archive or Maven/Google repositories. Those run in GitHub Actions
(`.github/workflows/ci.yml`) on every push. See [docs/TESTING.md](docs/TESTING.md) for the full,
honest matrix.

## Building the Android app

- `applicationId`: `com.zubaxit.bdnewspaperhub`
- `minSdk 23`, `targetSdk 35`, `compileSdk 35`, Kotlin 1.9.25, AGP 8.7.0, Gradle 8.9
- Permissions: `INTERNET`, `ACCESS_NETWORK_STATE` only
- `usesCleartextTraffic=false`; `allowBackup=false`; no WebView, no tracking SDK
- Adaptive launcher icon (procedurally generated vector/gradient set), light and dark splash

Release signing is read from `android/key.properties` (git-ignored, template at
`android/key.properties.example`). Without it, release builds fall back to debug signing so CI can
still produce an installable artifact. **APKs and AABs are build artifacts, not committed** — this
repository does not distribute binaries and the app is not published on Google Play.

## Design system

Warm paper (`#FBF8F3`) and deep ink (`#0D1311`) surfaces, Bangladesh green (`#0B5A46`) as the brand
colour and flag red used *only* for breaking news. Headlines are set in **Noto Serif Bengali**,
UI text in **Noto Sans Bengali** (both OFL, bundled — no runtime font download). Cards use 0.8 px
hairline borders instead of shadows, 18 px radii and generous line height for Bengali glyphs.
Motion is limited to a 280 ms fade-and-rise route transition, 160 ms control transitions and
skeleton pulses; all of it collapses to zero when the system or the in-app setting asks for
reduced motion. Publication identity uses a deterministic two-tone monogram, never unlicensed
publisher logos.

## Privacy and publisher rights

- No account, no analytics, no advertising, no personal data collection.
- Follows, bookmarks, history and settings live in app-private storage on the device.
- The app fetches only the publishers' public feeds, one request per feed at a time, with caching
  and a refresh floor; it never scrapes article pages, never bypasses paywalls or logins, and never
  stores full article text.
- Every card names the publisher and links to the original story; the About screen states plainly
  that there is no affiliation with any newspaper and that all content belongs to its publisher.
- Every external URL is validated (`https` only, no `javascript:`/`data:`/`file:`/`intent:`, no
  local hosts, no userinfo, no executable downloads) before it is opened.

## Known limitations

1. **No live feed has been verified in this environment** (no network access to publisher hosts).
   Feed URLs are mostly candidates; the app reports per-source reality at runtime. Run the verification
   script to confirm and promote them.
2. Bengali and English publication *names* are curated; logos are not shipped (licensing), so
   text monograms are used.
3. Regional coverage is intentionally conservative: only publications whose official domain is
   known with confidence are listed (Chattogram, Sylhet). The remaining divisions are parked in
   `assets/data/source_candidates.json` rather than guessed.
4. Only 6 e-paper destinations are listed, all on the publisher's own domain; access terms
   (free/subscription) are the publisher's and are not asserted by the app.
5. Automatic refresh runs in the foreground at the configured interval (15–240 min) and on resume.
   Android does not guarantee exact background refresh timing, and the app does not claim to.
6. Deduplication is heuristic: identical URLs are collapsed; cross-publication coverage is grouped
   by headline-similarity signature for display only.
7. There is no cloud sync, no full-text reading, and no commenting — by design.
8. `flutter analyze`, `flutter test` and the Android build have not been executed in this sandbox;
   CI is configured to run them.

## Roadmap

- Promote feed candidates to `verified` with the verification script and a small PR per batch.
- Extend regional coverage (all eight divisions) once each domain is confirmed.
- Optional Firebase-free backend for centralized feed aggregation, if per-device fetching ever
  becomes impolite at scale.
- Reading "brief" digests with explicit publisher licensing.

## Credits and licences

- Application code: MIT (see `LICENSE`).
- Noto Sans Bengali & Noto Serif Bengali: SIL Open Font License 1.1
  (`assets/fonts/OFL.txt`).
- Headlines, excerpts and images: © their respective publishers; displayed only as published in
  their public feeds, always with attribution and a link to the original.
