# Testing and verification status

This document states exactly what was executed and what could not be executed. Nothing here is
claimed unless it actually ran.

## Environment used for this build

| Tool | Available? |
| --- | --- |
| Flutter SDK / Dart SDK | **No** (not installed, and `storage.googleapis.com` / `pub.dev` are unreachable from the build sandbox) |
| JDK / Android SDK / Gradle | **No** (`java: command not found`) |
| Python 3.11 | Yes (stdlib only) |
| Node.js 22 | Yes (npm registry reachable) |
| Network to publisher sites | **No** (only github.com, codeload/api.github.com, registry.npmjs.org, pypi.org, files.pythonhosted.org) |

## What actually ran here

### 1. Registry validation — passed

```
$ ./tool/verify.sh
==> source registry JSON is valid
    60 sources, 6 e-papers, 6 candidates
==> every asset declared in pubspec.yaml exists
    all 10 declared asset files present
```

Checks: JSON parses; ids unique; every website/feed/e-paper URL is `https`; enums
(`type`, `status`, `feedClaim`, `categories`) contain only values that resolve to a real Dart enum
member after key normalization — this catches the failure mode where `needs_review` silently becomes
`active`; a `verified_working` claim must carry a `lastVerifiedAt` date; regional entries must name a
division; e-papers must point at a known source; and every asset declared in `pubspec.yaml`
(JSON data, three Noto Bengali families, the OFL text) must exist on disk and be non-trivial.

### 2. Dart static checks (tree-sitter, no SDK) — passed

```
$ node tool/dart_static_check.js        # NODE_PATH points at tree-sitter + tree-sitter-dart
checked 55 Dart files, 180 top-level symbols
all static checks passed
```

`tool/dart_static_check.js` verifies, for every `.dart` file in `lib/`, `test/`:

- the file parses as Dart (tree-sitter-dart grammar);
- every relative/`package:` import resolves to a file that exists;
- every capitalised type used in a type position, constructor, mixin/extends clause or member
  receiver is declared in the project or is a known SDK symbol (catches typos and undefined
  classes);
- every project type used in a file is **imported** by that file (catches the most common
  missing-import compile error);
- every named argument passed to a project constructor corresponds to a declared constructor
  parameter (catches misspelled `required` arguments);
- no credential-looking strings (Google/OpenAI/GitHub tokens, private keys, cloud service keys).

This is a lint, not a type checker: it does not validate argument types, generics or const-ness.
It found and fixed three real defects during development (`SectionHeader` and
`EpaperDirectoryScreen` imports in `categories_screen.dart`, `AppStores` import in
`repository_test.dart`).

### 3. App-string completeness — passed

All 153 `AppStrings` getters are implemented by both `BanglaStrings` and `EnglishStrings`
(verified by a script; a missing override would be a compile error).

### 4. Store-interface completeness — passed

Every method declared on `ArticleStore`, `SavedStore`, `HistoryStore`, `HealthStore`,
`FeedMetaStore`, `MetaStore`, `PreferencesStore` and `FeedGateway` is implemented by both the
SQLite and the fake implementation, so the fakes exercise the same contract as production.

### 5. Source verification — executed on a networked runner

```
$ gh run list --workflow verify-sources.yml
Check live feeds   success   (run 40107364030)

  + prothomalo      feed ok: 88 items, 88 dated, 76 on-domain, 88 bn, xml=True
  + bbc_bangla      feed ok: 14 items, 14 dated, 14 on-domain, 14 bn, xml=True
  + suprobhat       feed ok: 10 items, 10 dated, 10 on-domain, 10 bn, xml=True
  + sarabangla      feed ok: 10 items, 10 dated, 10 on-domain, 10 bn, xml=True
  + dainik_azadi    feed ok: 10 items, 10 dated, 10 on-domain, 10 bn, xml=True
  + tbs             feed ok: 10 items, 10 dated, 10 on-domain,  0 bn, xml=True
summary: 22 websites reachable, 6 feeds usable, 50 feeds failing, 4 without a configured feed
```

Six feeds passed the evidence gate and are recorded as `verified_working` (five) or
`official_documented` (BBC). The other 50 configured candidates failed on HTTP 403/404, DNS or TLS and
stay clearly labelled as unverified — see [SOURCES.md](SOURCES.md). The script cannot reach
publishers from the development sandbox (only GitHub/npm/PyPI are allow-listed), which is why it runs
in the `Verify sources` workflow.

```bash
# on any machine with normal internet access
python3 scripts/verify_sources.py --write            # promote qualified feeds
gh workflow run verify-sources.yml                   # or run the workflow
```

### 6. Launcher icons — generated and visually inspected

`scripts/generate_icons.py` produced the adaptive-icon layers and all five PNG densities plus a
512 px store icon; the output was opened and reviewed.

### 7. Analyzer, unit/widget tests and the Android build — executed in GitHub Actions

This development sandbox has no Dart/Flutter/JDK/Android SDK, so the SDK gates run on GitHub Actions
(`.github/workflows/ci.yml`) on every push to the feature branch and on the pull request:

| Gate | Command | Latest result |
| --- | --- | --- |
| Formatting | not gated (kept out of CI on purpose; `dart format lib test` locally) | — |
| Static analysis | `flutter analyze --fatal-warnings` | **success**, 0 issues |
| Unit + widget tests | `flutter test --reporter expanded --concurrency=1 --coverage` | **success**, 124 tests |
| Debug APK | `flutter build apk --debug` | **success** |
| Release APK | `flutter build apk --release` | **success** (artifact `apk`, ~118 MB combined) |
| `flutter build appbundle` | not run | documented in `docs/RELEASE.md` |
| On-device / emulator smoke test | not run | manual, see checklist below |

Run IDs for the latest green build: CI run `40117972337` (analyze & test + APK, commit `d8261ad`, which
includes the in-app reader) and Verify sources run `40107364030`. Earlier green runs:
`40107367502` (pre-reader) and `40108517164`. Because runner logs are not reachable from this sandbox, the workflows republish
analyzer and test diagnostics as check annotations — that is also how each failure below was
diagnosed and fixed.

The test suites run without network access: all stores are in-memory fakes, the feed gateway is a
fake, connectivity is faked, and no test performs an HTTP request.

## Test inventory (what the suites assert)

**`test/unit/feed_parser_test.dart`**
RSS 2.0 detection; CDATA headlines; HTML-stripped excerpts; tracking-parameter removal; `+0600`
→ UTC conversion; naive dates parsed with the +06:00 assumption; missing dates stay `null`;
publisher-labelled breaking news detected and its prefix stripped; `media:content` thumbnails;
topic classification; deterministic ids across re-parses; duplicate items collapsed; Atom
`rel="alternate"` links and `<updated>`; entries without links skipped; malformed XML recovered;
HTML error page yields zero items; empty input does not throw; far-future dates rejected;
broken UTF-8 decoding tolerated.

**`test/unit/core_utils_test.dart`**
HTML/entity handling; whitespace normalization; search normalization; truncation; edit distance;
Bengali↔ASCII numerals; Bengali script detection; relative time in both languages; Bangladesh-time
absolute formatting; transliteration; URL safety across `javascript:`, `data:`, `file:`, `intent:`,
localhost, userinfo and `.exe`; host comparison; canonical URL/id stability; story clustering by
day.

**`test/unit/registry_test.dart`**
Shipped JSON integrity (60 entries, unique ids, HTTPS-only, safe URLs, e-papers pointing at known
sources, no `verified` claim without a URL); regional entries carry a real division and district;
agencies/broadcasters are never typed as newspapers; the publications named in the brief exist;
Bengali↔English search, typo tolerance, filtering; localization and monogram helpers.

**`test/unit/repository_test.dart`**
Refresh report counts; only sources with feeds are fetched; a failing source does not stop others;
a gateway that throws is recorded as a failure; the 8-minute per-source floor and its `force`
override; source/topic/language/text filters; followed-only semantics; publication-time sorting
with undated items last; bookmark persistence across a cache wipe; history write/clear; related
coverage excludes the same publisher and the article itself; cache clearing keeps bookmarks.

**`test/unit/storage_contract_test.dart`**
Reads the real `CREATE TABLE` DDL out of `app_database.dart` and asserts `Article.toRow()` /
`SourceHealth.toRow()` keys equal the column names, round-trips a Bengali breaking article (tags,
excerpt, image, both timestamps, guid, cluster key), keeps Bengali bytes intact, survives a missing
date and a corrupt tag blob, and checks the camelCase JSON payload used by saved items still maps.

**`test/widget/browser_test.dart`**
Reader chrome shows the publisher's real domain (not just a title); page-history back is disabled
until the engine reports history and then calls it; a load failure renders retry rather than a blank
platform view; saving asks for consent first, explains it stores a headline + link, and then stores
exactly one bookmark.

**`test/widget/directory_filter_test.dart`**
Division chips narrow the directory (Bengali division labels), the district row only lists districts
inside the chosen division, a division passed in from the categories screen is preselected, clearing
it restores the curated front page, and a division with no publication shows the honest empty note.

**`test/widget/screens_test.dart`**
Home: live render with source + relative time, empty state, cached notice, topic filtering,
breaking banner. Directory: list, search (`daily`, `বণিক`), no-results, language filter, follow.
Publication detail: action availability, no-feed state, follow toggle. Saved: bookmark round-trip
including a simulated restart, unbookmark. Article card: missing-date note. Search: headline
results, recent searches, no results. Settings: theme, text size, language switch, About counts.
E-paper directory. AppShell: tab switching, Android back behaviour, detail push/pop. Dark theme.
Layouts at 360×640 dp and 800×1280 dp without overflow.

## Manual QA checklist for a real device

1. Fresh install → Home shows the skeleton, then headlines (or the honest empty state).
2. Airplane mode → relaunch → cached headlines with the "cached/offline" notice; directory still
   browsable; publication websites still open.
3. `Settings → Source health` → failing sources listed first with their error; retry one.
4. Open a publication with no feed → only website/e-paper actions are offered.
5. Bookmark three stories → force-stop → relaunch → Saved intact.
6. Open a story → "Read in app" → the publisher page loads with its real domain in the bar; follow a
   link inside it → back returns through page history before leaving the reader; "open in browser"
   hands the same URL to the system browser; bookmarking from the reader warns that only the
   headline and link are kept.
6. Search in Bengali and in English → both find publications and headlines.
7. Toggle dark theme, 140 % text size, reduce motion → no clipped Bengali headlines.
8. Android back: detail → list → Home tab → app exits (no navigation loop).
9. Rotate and use split-screen → no overflow stripes.
10. Let the app idle for the configured interval → "last updated" advances; no request storm in
    a proxy trace.
