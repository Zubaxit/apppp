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
    60 sources, 6 e-papers
```

Checks: JSON parses, ids unique, every website/feed/e-paper URL is `https`.

### 2. Dart static checks (tree-sitter, no SDK) — passed

```
$ node tool/dart_static_check.js        # NODE_PATH points at tree-sitter + tree-sitter-dart
checked 54 Dart files, 176 top-level symbols
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

All 152 `AppStrings` getters are implemented by both `BanglaStrings` and `EnglishStrings`
(verified by a script; a missing override would be a compile error).

### 4. Store-interface completeness — passed

Every method declared on `ArticleStore`, `SavedStore`, `HistoryStore`, `HealthStore`,
`FeedMetaStore`, `MetaStore`, `PreferencesStore` and `FeedGateway` is implemented by both the
SQLite and the fake implementation, so the fakes exercise the same contract as production.

### 5. Source verification script — executed, network-blocked

```
$ python3 scripts/verify_sources.py --only prothomalo --delay 0.1
  x prothomalo               feed unusable: URL error: TLS/SSL connection has been closed
summary: 0 websites reachable, 0 feeds usable, ...
```

The script itself runs correctly end to end (it produced a report file); it cannot reach
publishers from this sandbox. **Therefore no feed is claimed as verified.** Run it from a normal
connection and commit `docs/source_verification.json`:

```bash
python3 scripts/verify_sources.py --write --probe-candidates
```

### 6. Launcher icons — generated and visually inspected

`scripts/generate_icons.py` produced the adaptive-icon layers and all five PNG densities plus a
512 px store icon; the output was opened and reviewed.

## What was NOT executed here (and where it does run)

| Command | Status | Where it runs |
| --- | --- | --- |
| `dart format` | not executed (nothing to compare against without the SDK) | local, documented in README |
| `flutter analyze --fatal-warnings` | not executed | CI |
| `flutter test` (unit + widget) | not executed | CI |
| `flutter build apk --debug/--release` | not executed | CI (`build-android` job) |
| `flutter build appbundle` | not executed | documented in `docs/RELEASE.md` |
| On-device / emulator smoke test | not executed | manual, see checklist below |

The test suites are written to run in CI without network access: all stores are in-memory fakes,
the feed gateway is a fake, connectivity is faked, and no test performs an HTTP request.

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
6. Search in Bengali and in English → both find publications and headlines.
7. Toggle dark theme, 140 % text size, reduce motion → no clipped Bengali headlines.
8. Android back: detail → list → Home tab → app exits (no navigation loop).
9. Rotate and use split-screen → no overflow stripes.
10. Let the app idle for the configured interval → "last updated" advances; no request storm in
    a proxy trace.
