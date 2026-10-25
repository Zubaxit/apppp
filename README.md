# আমার নিউজ · Amar News

A premium, offline-friendly **Android news reader** for Bangladesh, built with Flutter. It brings
verified Bangladeshi and international news feeds together into one calm, typographic reading
experience: a grayscale editorial design with one printed-red accent, iOS-style frosted chrome,
and motion that stays out of the way of reading.

*Amar News (আমার নিউজ, "my news") is the successor identity of Bangladesh Newspaper Hub. The
Android application ID is unchanged — `com.zubaxit.bdnewspaperhub` — so an update installs over the
existing app and keeps its bookmarks, follows and settings.*

The app is a **discovery and reading companion**, not a scraper: it stores only the headline,
excerpt and thumbnail each publisher exposes in its feed, always shows the publisher's name and
publication time, and sends readers to the original article on the publisher's site.

---

## Contents

- [What is implemented](#what-is-implemented)
- [Design system](#design-system)
- [Motion system](#motion-system)
- [Translation (offline glossary)](#translation-offline-glossary)
- [Source coverage (verified vs. listed)](#source-coverage-verified-vs-listed)
- [Quick start](#quick-start)
- [Project layout](#project-layout)
- [The source registry](#the-source-registry)
- [Verifying feeds against the live internet](#verifying-feeds-against-the-live-internet)
- [Testing](#testing)
- [Building the Android app](#building-the-android-app)
- [Privacy, publisher rights and the author profile](#privacy-publisher-rights-and-the-author-profile)
- [Known limitations](#known-limitations)
- [Roadmap](#roadmap)
- [Credits and licences](#credits-and-licences)

---

## What is implemented

### Identity
- Bengali display name **আমার নিউজ**, English metadata **Amar News**, used consistently in the
  launcher label, splash screen, masthead, settings and About screen.
- A custom launcher mark drawn from real vector/PNG geometry by `scripts/generate_icons.py`: a
  graphite tile carrying a white front page with a folded corner and a printed-red masthead rule.
  The Android splash drawable and the in-app `AmarNewsMark` widget use the same geometry, so the
  three never drift apart. No emoji is used as an icon anywhere in the interface.

### Front page
- Frosted, pinned masthead (real backdrop blur, translucent fill, one hairline) with the app name,
  today's Bengali date, filter and search actions.
- **Featured rail**: a swipeable set of the day's leading stories, taken only from real articles
  that actually carry a feed image. It appears only when at least three such articles exist;
  below that the plain lead story carries the page instead of a hollow carousel.
- **Unified latest-news feed** from every source with a working feed, sorted by real publication
  time (falling back to retrieval time *only* when a publisher supplies no date, and saying so).
- All / Following switch, live article count, manual refresh, and an honest freshness line (last
  successful update, cached, or offline).
- Compact topic rail (Bangladesh, politics, economy, international, sport, entertainment,
  technology, education, health, lifestyle) filtering the feed in place.
- Rule-separated river of headlines with publisher, relative time, thumbnail, and row-level
  bookmark and share.
- **Breaking news** appears only when a publisher labels the item `breaking`, `ব্রেকিং` or
  `Breaking News:` in its own feed; the banner can be switched off in Settings.
- Filter sheet to narrow the feed to specific publications and Bengali/English, with a badge while
  a filter is active.
- Skeleton placeholders shaped like the page while the first load runs; static by default, so an
  idle screen costs no animation frames.

### Newspaper directory
- **64 publications** in a JSON registry: national Bengali dailies, English dailies, online
  portals, business titles, regional titles, plus a clearly separated group of news agencies and
  broadcasters — of which **13 have a verified working feed** and **13 are website-only by design**.
- Search across Bengali and English names, including Bengali→Latin transliteration, with typo
  tolerance.
- Filters for type/category, language and (for regional titles) division.
- Publication detail with monogram, type, language, location, official website, live feed health,
  follow/unfollow, share, e-paper links and cached latest headlines.
- E-paper directory that opens the publisher's own e-paper destination; editions are never mirrored.
- Actions that cannot work are never shown: a publication with no feed shows *No feed — use the
  website* instead of a dead button.

### Reading
- Article detail with publisher identity, exact publication date/time in Bangladesh time, the
  permitted excerpt, a clear notice about why only the excerpt is shown, "Read in app", copy link
  and share.
- Bengali-first reading surface: **Noto Serif Bengali** headline and excerpt at generous line
  height, a hairline rule separating the standfirst, and a **reading-progress rule** pinned under
  the toolbar that is driven by scroll offset only (it never rebuilds the text).
- Toolbar actions: Bengali word meaning, bookmark (with fill animation), share, and a clear back
  path to the feed.
- **In-app browser.** "Read in app" opens the publisher's page in an embedded web view that always
  shows the real origin (e.g. `prothomalo.com`), with reload, page-history back, open-in-browser,
  an honest error state, and a save action that stores the headline and link only. Nothing is
  injected into the page; logins, paywalls and anti-bot measures are never bypassed.
- **Related coverage**: other publishers whose headlines describe the same story, listed as
  separate links with their own attribution — stories are never merged.
- Adjustable reading text size, light/dark themes, and reduced-motion support.

### Saved and search
- Bookmarks keep the headline, excerpt, image, time and original URL, so a save survives the
  publisher dropping the item from its feed.
- The Saved screen states the difference between **link only** and **with excerpt** on every item,
  and never calls either of them an offline copy of the article.
- Reading history (optional), cache cleanup that never deletes bookmarks.
- One search surface for publications *and* cached headlines, with separated result groups, recent
  searches and honest no-result states.

### Personalization & storage
- Follow/unfollow publications, preferred topics, default feed, automatic refresh interval,
  reading-history toggle, breaking-banner toggle, app language (Bengali/English), theme, text size
  and reduced motion — all persisted locally.
- **Editable author profile** in About (see [Privacy…](#privacy-publisher-rights-and-the-author-profile)).
- Everything is stored **on the device only**: `shared_preferences` for preferences and the profile,
  SQLite for the article cache, bookmarks and history. No account, no cloud sync, no analytics.

### Reliability
- Every feed is fetched independently: one failing publisher never breaks the feed or the app.
- Per-source health record (last success, last error, HTTP status, item count, latency) in
  *Settings → Source health*, with per-source retry.
- Polite networking: descriptive user agent, 12 s timeout, at most two attempts, 3 MB response cap,
  a minimum gap between requests to the same host, and an 8-minute per-source refresh floor.
- ETag / `If-Modified-Since` caching so unchanged feeds are not re-downloaded.
- Tolerant parser: RSS 2.0, RDF and Atom; broken XML is recovered; items with unsafe links, missing
  headlines or implausible dates are dropped rather than guessed at.

## Design system

| Element | Decision |
| --- | --- |
| Foundation | Grayscale. Warm newsprint paper `#F6F4F1`, graphite ink `#191A1B`, hairline borders at 0.8 px |
| Accent | One printed red `#AF1F2B` (dark mode `#FF6B73`) for the brand rule, kickers, links and saved state |
| Semantics | Separate success / warning / error colours, used only where they mean something |
| Type | Noto Serif Bengali for headlines and body copy, Noto Sans Bengali for UI chrome, all bundled |
| Glass | `GlassSurface` / `GlassBar`: real `BackdropFilter` blur + translucent fill + hairline, used **only** for chrome (masthead, navigation, browser bar, sheets), never on content |
| Shape | 8/12/18 px radii, full-bleed images, hairline rules instead of stacked cards |
| Icons | Material line icons and custom-drawn marks; no emoji, no raster UI icons, no publisher logos |
| Contrast | Ink on paper is ≥ 12:1; muted ink stays above 4.5:1; the accent is used for text only at label sizes and above |

All colours, sizes and durations live in `lib/theme/tokens.dart` and `lib/theme/app_theme.dart`.
Widgets resolve through those files, so a theme change is a token change, not a screen-by-screen
edit. Every duration and curve the interface uses is declared in `Tokens`.

## Motion system

`lib/theme/motion.dart` owns the vocabulary, and `Motion.of(context)` is the only way widgets read it:

| Token | Value | Used for |
| --- | --- | --- |
| `tap` | 120 ms | press feedback, bookmark fill, chip selection |
| `standard` | 220 ms | tab underlines, indicators, small state changes |
| `emphasized` | 320 ms | splash entrance, route transitions, page entrances |
| `slow` | 460 ms | at most one unhurried moment per screen |

- **Opening transition**: the splash mark rises and fades once, then hands over the instant bootstrap
  resolves; the wordmark is not animated on every launch beyond that.
- **Touch feedback**: one `Pressable` wrapper (scale 0.97, 120 ms) plus a selection haptic. Nothing
  bounces, nothing loops.
- **Bookmark**: outline → filled mark with a short overshoot, accent colour change and a light
  haptic; the state change is instant when motion is reduced.
- **Scrolling**: no animation on scroll; the reading-progress rule is the only scroll-driven paint.
- **Reduced motion**: the system "remove animations" setting and the in-app preference both collapse
  every duration to zero and skip the scale/slide wrappers. The app remains fully usable — nothing
  depends on an animation to become visible or reachable.
- **Loading**: static skeletons shaped like the content (opt-in slow pulse only where a single block
  represents a single pending region). No shimmering list of twenty rows.

## Translation (offline glossary)

- **What it is**: a bundled English→Bengali word glossary (`assets/data/bn_glossary.json`,
  269 entries as of this build) with a lookup sheet in the reader. `tool/check_glossary.py` guards
  it in CI: lowercase English keys, Bengali meanings, no placeholders, a stated honesty note.
- **What it is not**: not a translation engine, not a page translator, not a network service. The
  sheet says "word by word — this is not a full translation", unknown words are reported as *not in
  the dictionary* rather than approximated, and Bengali text is passed over.
- **Limits, stated plainly**: a glossary cannot translate a Bengali article into English, cannot
  handle inflection or idiom, and will miss most literary vocabulary. It is a reading aid for
  English words that appear in an otherwise Bengali feed.
- **Availability**: if the asset is missing or unreadable the sheet shows an unavailable state and
  the rest of the app is unaffected — the app is fully usable with no translation feature at all.
- **Why not more**: a real translator needs either a paid API or a large offline model. No paid
  service, no ToS-violating scraping and no invented meanings are acceptable, so the honest option
  is a small, verified word list.

## Source coverage (verified vs. listed)

| State | Meaning | Count |
| --- | --- | --- |
| Publications in the registry | Curated entries with an official website | **64** |
| Sources with a verified working feed | Fetched, parsed, timestamped, on-domain | **13** |
| Sources with a **feed URL** in the registry | The 13 above | **13** |
| Feed **candidates** tracked in the backlog | Plausible paths, never confirmed | **38** |
| Entries with **no feed** | Website-only, by design | **13** |
| E-paper destinations | Publisher-hosted links | **6** |

Verified on 2026-10-25 by the `Verify sources` workflow (run `40123781895`): 13 feeds returned valid,
on-domain, timestamped items, 0 failing. Per-feed numbers and the failures are in
[docs/SOURCES.md](docs/SOURCES.md).

### Verified feed set (what the front page actually shows)

| Publication | Language | Items in the last check |
| --- | --- | --- |
| Prothom Alo | bn | 50–63 |
| JagoNews24 | bn | 100 |
| Ajker Patrika | bn | 20 |
| Dhaka Post | bn | 20 |
| Suprobhat | bn | 10 |
| Sarabangla | bn | 10 |
| Dainik Azadi (Chattogram) | bn | 10 |
| The Daily Star | en | 10 (the feed carries no timestamps) |
| The Business Standard | en | 10 |
| BBC News Bengali | bn | 14 |
| Al Jazeera English | en | 25 |
| DW News | en | 131 |
| BBC News (World) | en | 30 |

> **Honest status.** Nine Bangladeshi feeds and four international feeds are confirmed. The brief
> asked for 10–11 Bangladeshi publishers; the live evidence supports nine, and the app says so
> instead of inventing feeds. The remaining publishers legitimately have directory entries and
> websites: Jugantor, Samakal, Kaler Kantho, Ittefaq, Bangladesh Pratidin, Bangla Tribune and Dhaka
> Tribune answer HTTP 403 to non-browser clients, bdnews24 returned HTML instead of a feed on sixteen
> paths, and Reuters no longer publishes public RSS. A GitHub runner's IP address is also blocked by
> most major Bangladeshi dailies, which is bot protection rather than proof of absence — re-run
> `Verify sources` from a normal connection to promote whatever works later.

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
./tool/verify.sh                  # registry, glossary and Dart structural checks (no SDK needed)
```

See [docs/RELEASE.md](docs/RELEASE.md) for signing and versioning notes, and
[docs/DESIGN.md](docs/DESIGN.md) for the visual and motion rules behind the current interface.

## Project layout

```
lib/
├── main.dart, app.dart, bootstrap.dart   # entry point, provider graph, DI seams
├── core/
│   ├── extensions.dart                   # BuildContext helpers (strings, theme, stores)
│   ├── l10n/app_strings.dart             # 188 typed strings, Bengali + English
│   ├── l10n/labels.dart                  # enum → label/icon mapping
│   └── utils/                            # text, Bengali, URL safety, stable ids
├── data/
│   ├── models/                           # NewsSource, Article, AuthorProfile, preferences…
│   ├── feeds/                            # HTTP client, RSS/Atom parser, feed service, classifier
│   └── services/                         # SQLite schema, stores, repository
├── services/                             # registry loader, links, connectivity, preferences,
│                                         # profile store, offline glossary lookup
├── state/                                # change notifiers: feed, saved, settings
├── theme/                                # tokens, theme, motion (durations/curves)
└── ui/
    ├── shell/app_shell.dart              # frosted bottom navigation + back handling
    ├── screens/                          # home, about, categories, directory, reader, browser…
    ├── widgets/                          # brand mark, featured rail, actions, sheets, cards
    ├── helpers/app_nav.dart              # routes
    └── services/link_launcher.dart       # testable external navigation
assets/data/sources.json                  # the registry (data, not code)
assets/data/bn_glossary.json              # offline English→Bengali word glossary
assets/data/source_candidates.json        # maintenance backlog (never shown in the app)
assets/fonts/                             # Noto Sans/Serif Bengali (OFL)
scripts/verify_sources.py                 # live feed/website verification
scripts/generate_icons.py                 # procedural launcher icon set
tool/check_glossary.py                    # glossary honesty/size checks
tool/dart_lint.py                         # dependency-free structural Dart checks
```

Architecture follows a one-way flow: **UI → controller (ChangeNotifier) → repository → feed service
/ stores**. Models are immutable, the registry is data, and every external URL passes through
`UrlSafety` before it is opened. See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## The source registry

`assets/data/sources.json` is the single source of truth for the directory. Adding a publication
never requires touching UI code.

Feed states are deliberately distinct and never conflated:

| Field | Values | Meaning |
| --- | --- | --- |
| `feedClaim` | `none` | No feed known — the app only offers the website |
| | `candidate` | A plausible feed URL exists in the backlog; not shipped as a live feed |
| | `official_documented` | Documented by the publisher |
| | `verified_working` | A live fetch returned parseable items — written by `scripts/verify_sources.py --write` |
| `lastVerifiedAt` | `yyyy-mm-dd` | Date of that check (feed **or** website for website-only entries) |
| `status` | `active`, `needs_review`, `inactive` | Publisher-level belief, never overwritten by runtime health |

Runtime health (working / failing / not checked, last success, last error) is stored separately in
SQLite and shown per source.

## Verifying feeds against the live internet

```bash
python3 scripts/verify_sources.py                     # report only, polite pacing
python3 scripts/verify_sources.py --write             # update feedClaim + lastVerifiedAt
python3 scripts/verify_sources.py --only prothomalo,daily_star
python3 scripts/verify_sources.py --probe-candidates  # probe /feed, /rss.xml … for sources without a feed
```

The script writes `docs/source_verification.json` with per-source results, counts and a timestamp,
using one request per URL, 1.5 s spacing and a 15 s timeout.

## Testing

```bash
dart format lib test
flutter analyze --fatal-warnings
flutter test --coverage
./tool/verify.sh            # registry + glossary + asset + Dart structural checks (no SDK required)
```

Test suites (see [docs/TESTING.md](docs/TESTING.md) for the full matrix):

| Suite | What it covers |
| --- | --- |
| `test/unit/feed_parser_test.dart` | RSS 2.0, Atom, malformed/HTML responses, unsafe links, missing dates, timezones, duplicate items, stable ids, breaking labels, media thumbnails |
| `test/unit/core_utils_test.dart` | HTML stripping, Bengali numerals/dates/relative time, transliteration, URL safety, id canonicalisation, story clustering |
| `test/unit/registry_test.dart` | Shipped registry integrity: unique ids, HTTPS-only, safe feed/e-paper URLs, enum mapping, verification claims always dated |
| `test/unit/repository_test.dart` | Refresh reporting, partial source failure, crashing gateway, throttling, filtering, sorting, bookmark persistence across store resets, history, related coverage, cache clearing |
| `test/unit/translation_test.dart` | Glossary load, case/punctuation tolerance, plural fallback, unknown-word honesty, missing-asset behaviour, tokenising |
| `test/unit/profile_test.dart` | Default profile contains only supplied facts, edit round-trip, blank/corrupt fallbacks, link validation |
| `test/unit/preferences_persistence_test.dart` | Theme, language, motion, text size and follows survive a restart; a failing store never loses the session value |
| `test/widget/screens_test.dart` | Home (live/empty/cached/breaking/topic filter), directory, publication detail, bookmarks, search, settings, About (registry counts, author profile, runtime editing, link rejection), e-paper list, shell navigation + Android back, dark theme, small-phone and tablet layouts |
| `test/widget/translation_sheet_test.dart` | Known word, unknown word, missing glossary, tapping a word chip |
| `test/widget/browser_test.dart`, `directory_filter_test.dart` | Reader chrome, error state, back handling; directory filters |

**Verified in this environment:** `./tool/verify.sh` passes — registry JSON validation (enum
resolution, verification claims, website-only entries), glossary validation, asset-existence checks
and the dependency-free Dart structural checks. **Not executable here:** `flutter analyze`,
`flutter test` and the Android build — this sandbox has no Dart/Flutter/JDK/Android SDK. Those run
in GitHub Actions on every push, and the results quoted in this repository are read from the run
logs, never assumed. **No physical device or emulator test has been performed.**

## Building the Android app

- `applicationId`: `com.zubaxit.bdnewspaperhub` (unchanged from the previous identity, so updates
  install over the existing app and keep local data)
- `minSdk 23`, `targetSdk 35`, `compileSdk 35`, Kotlin 1.9.25, AGP 8.7.0, Gradle 8.9
- Permissions: `INTERNET`, `ACCESS_NETWORK_STATE` only
- `usesCleartextTraffic=false`; `allowBackup=false`; no tracking SDK
- Launcher icon: graphite adaptive tile with the front-page mark (generated by
  `scripts/generate_icons.py`); light and dark splash themes on paper/graphite

Release signing reads `android/key.properties` (git-ignored, template at
`android/key.properties.example`). Without it, release builds fall back to debug signing so CI can
still produce an installable artifact. **APKs are build artifacts, not committed.**

## Privacy, publisher rights and the author profile

- No account, no analytics, no advertising, no personal data collection.
- Follows, bookmarks, history, settings and the author profile live in app-private storage on the
  device. Nothing is uploaded.
- The app fetches only the publishers' public feeds, one request per feed at a time, with caching and
  a refresh floor. It never scrapes article pages, never bypasses paywalls or logins, and never
  stores full article text.
- Every card names the publisher and links to the original story. The About screen states plainly
  that the app has **no affiliation with any newspaper** and that all content belongs to its
  publisher.
- Every external URL is validated (`https` only; no `javascript:`/`data:`/`file:`/`intent:`, no local
  hosts, no userinfo, no executable downloads) before it is opened.
- **The About screen has two separate parts.** The app part describes the app and its data sources.
  The *About the author* part is a profile of the developer that can be **edited at runtime**
  (name, one-line role, short and long biography, interests, optional links) and is stored only in
  local preferences. Its starting text contains only the facts the owner supplied — Md Emon
  (মোঃ ইমন); Bangla studies at Government Brojalal College (B. L. College), Khulna; interests in
  Bengali literature, poetry, criticism, philosophy and classics; writing of poetry, essays and
  research; a particular interest in Shamsur Rahman's poetry; and an interest in useful digital
  tools. The master's-level study is mentioned as **unconfirmed** rather than claimed, and the
  profile contains no awards, publications, titles, degrees, employers, dates, contact details or
  family/medical/financial information. Links are only accepted if they are plain web addresses.

## Known limitations

1. **Thirteen feeds are verified working against the live internet; everything else is
   website-only or an unconfirmed candidate.** See *Source coverage* above and `docs/SOURCES.md`
   for the measured table, including why each unintegrated publisher is unintegrated.
2. Only **nine** Bangladeshi feeds could be verified, not the ten or eleven the brief hoped for; the
   app does not invent the difference.
3. Bengali and English publication *names* are curated; logos are not shipped (licensing), so text
   monograms are used.
4. Regional coverage stays conservative: only publications whose official domain is known with
   confidence are listed. Remaining divisions are parked in `assets/data/source_candidates.json`.
5. Only 6 e-paper destinations are listed, all on the publisher's own domain; access terms are the
   publisher's and are not asserted by the app.
6. Automatic refresh runs in the foreground at the configured interval (15–240 min) and on resume.
   Android does not guarantee exact background refresh timing, and the app does not claim to.
7. Deduplication is heuristic: identical URLs are collapsed; cross-publisher coverage is grouped for
   display only.
8. There is no cloud sync, no full-text reading and no commenting — by design.
9. The in-app reader needs a live connection. Saving from it stores the headline and link, not the
   page, and the reader cannot render a PDF-only e-paper.
10. The Daily Star's feed publishes no item timestamps. Those stories are labelled "publication time
    unknown" and sort after dated ones; the registry carries an explicit `allowUndated` flag for that
    one entry rather than accepting undated feeds generally.
11. The translation feature is a 269-word offline glossary, not a translator. It cannot translate a
    page, and it will mark most literary vocabulary as unknown.
12. Analysis, the test suite (165 tests) and the debug/release APK builds run in GitHub Actions; this
    sandbox has no Flutter SDK, so `./tool/verify.sh` is the only local gate. **No physical device or
    emulator test has been performed** — install the APK artifact from the CI run for a hands-on
    check. For this build: CI run `40162182346` on head `89c7e4d`, `apk` artifact 118 774 948 B,
    `coverage` 13 830 B.
    (CI rebuilds the APK on every commit, so the newest run matching the branch head always has the
    current artifact.)

## Roadmap

- Promote feed candidates with the `Verify sources` workflow; the 403 publishers need a documented
  endpoint or a change in their bot policy.
- Extend regional coverage once each domain is confirmed.
- Grow the glossary with reviewed entries only (never machine-generated meanings).
- Optional per-publication "read later" digests, if licensing allows.

## Credits and licences

- Application code: MIT (see `LICENSE`).
- Noto Sans Bengali & Noto Serif Bengali: SIL Open Font License 1.1 (`assets/fonts/OFL.txt`).
- Headlines, excerpts and images: © their respective publishers; displayed only as published in
  their public feeds, always with attribution and a link to the original.
