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
    64 sources, 6 e-papers, 6 candidates
==> offline glossary is valid and honestly labelled
    269 english words with Bengali glosses
==> every asset declared in pubspec.yaml exists
    all 11 declared asset files present
==> Dart structural checks (no SDK required)
checked 81 Dart files: structure, imports and class visibility OK
```

Checks: JSON parses; ids unique; every website/feed/e-paper URL is `https`; enums
(`type`, `status`, `feedClaim`, `categories`) contain only values that resolve to a real Dart enum
member after key normalization — this catches the failure mode where `needs_review` silently becomes
`active`; a `verified_working` claim must carry a `lastVerifiedAt` date; regional entries must name a
division; e-papers must point at a known source; and every asset declared in `pubspec.yaml`
(JSON data, the glossary, the Noto Bengali families, the OFL text) must exist on disk and be
non-trivial. `tool/check_glossary.py` additionally requires the offline glossary to carry Bengali
meanings for at least 200 lowercase English keys, no placeholder meanings, and a note stating that
it is not a full translation.

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

All 188 `AppStrings` members are implemented by both `BanglaStrings` and `EnglishStrings`
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

Thirteen feeds pass the evidence gate and are recorded as `verified_working`; every other publisher
stays website-only or an unconfirmed candidate — see [SOURCES.md](SOURCES.md). The script cannot
reach publishers from the development sandbox (only GitHub/npm/PyPI are allow-listed), which is why
it runs in the `Verify sources` workflow. Latest run: **`40123781895`**, 13 usable feeds, 0 failing,
25 websites reachable, 51 without a feed.

```bash
# on any machine with normal internet access
python3 scripts/verify_sources.py --write            # promote qualified feeds
gh workflow run verify-sources.yml                   # or run the workflow
```

### 6. Launcher icons — generated and visually inspected

`scripts/generate_icons.py` produced the Amar News mark (graphite tile, white front page with a
folded corner, printed-red masthead rule) as all five PNG densities plus a 512 px store icon, and the
adaptive-icon foreground vector was rewritten from the same geometry. The generated images were
opened and reviewed at 512 px and at launcher size; the Flutter splash uses the same shapes through
`AmarNewsMark`.

### 7. Analyzer, unit/widget tests and the Android build — executed in GitHub Actions

This development sandbox has no Dart/Flutter/JDK/Android SDK, so the SDK gates run on GitHub Actions
(`.github/workflows/ci.yml`) on every push to the feature branch and on the pull request:

| Gate | Command | Latest result |
| --- | --- | --- |
| Formatting | not gated (kept out of CI on purpose; `dart format lib test` locally) | — |
| Static analysis | `flutter analyze --fatal-warnings` | **success**, 0 issues |
| Unit + widget tests | `flutter test --reporter expanded --concurrency=1 --coverage` | **success**, 168 tests (165 existing + 3 new interaction/policy cases) |
| Debug APK | `flutter build apk --debug` | **success** |
| Release APK | `flutter build apk --release` | **success** (artifact `apk`, 118 774 948 B; `coverage` 13 830 B) |
| `flutter build appbundle` | not run | documented in `docs/RELEASE.md` |
| On-device / emulator smoke test | not run | manual, see checklist below |

Green runs for the Amar News build: CI run **`40171457794`** is the first run of the reference-aligned
redesign — Analyze & test passed (0 analyzer issues, 168 tests) and Build Android APK produced the
`apk` artifact; Verify sources **`40123781895`** verified all 13 shipped feeds live with 0 failing.
Earlier green run: `40162182346` (the pre-redesign reader). Earlier green runs while
building the reader and transport fixes: `40125397570`, `40123785564`, `40117972337`,
`40107367502`, `40108517164`. Failures found and fixed in this phase (recorded because they were
real): `40159786431`/`40159899609` (analyzer errors from the token rewrite and import hygiene) and
`40160092910`/`40160343379` lineage (a 320 dp overflow in the All/Following row, a wrong glossary
fixture count, and About tests reaching lazily built content).

The APK is rebuilt by CI on **every** commit, so the run that matches the branch head is always the
newest one under *Actions → CI*: its `Build Android APK` job attaches the artifact named `apk`
(debug + release). This wording is deliberate — a hard-coded run id would point at the previous
commit as soon as the next commit lands. Because runner logs are not reachable from this sandbox, the workflows republish
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

**`test/unit/http_client_test.dart`**
The transport policy: Bengali survives a feed that omits its charset (the old `response.body`
default of latin-1 is exactly why headlines could arrive as mojibake), a declared latin-1 charset is
still honoured, a UTF-8 BOM is skipped, a descriptive user agent and RSS `Accept` header are sent,
304 is reported as not-modified, 403 fails once without retrying, 5xx retries once and then reports
honestly, an oversized body is rejected, and an unsafe URL never leaves the device.

**`test/unit/refresh_pipeline_test.dart`**
The path that produced the empty app, end to end: real `NewsHttpClient` (MockClient transport) →
real parser → real `FeedService` → real `ArticleRepository` → an `ArticleStore` that rejects any key
the real DDL does not declare, exactly like SQLite. Asserts six articles persisted with Bengali
titles, tracking parameters stripped, `+0600` converted to UTC, topics assigned, and category
queries reaching the same rows; that one publisher answering 403 never blocks the other two; that
the per-source refresh floor holds and `force` overrides it; and that a broken store is reported as
`storageError` rather than looking like a successful refresh.

**`test/unit/storage_contract_test.dart`**
Reads the real `CREATE TABLE` DDL out of `app_database.dart` and asserts `Article.toRow()` /
`SourceHealth.toRow()` keys equal the column names, round-trips a Bengali breaking article (tags,
excerpt, image, both timestamps, guid, cluster key), keeps Bengali bytes intact, survives a missing
date and a corrupt tag blob, and checks the camelCase JSON payload used by saved items still maps.

**`test/unit/translation_test.dart`**
Glossary loads from an injected bundle; size/availability reporting; a missing asset leaves the
feature unavailable instead of throwing; lookups tolerate case and punctuation; unknown words come
back as `found: false` with no meaning (never approximated); a trailing plural falls back to the
singular while `news` is untouched; `gloss()` keeps reading order, drops duplicates and skips Bengali
tokens; tokenising finds Latin words only.

**`test/unit/profile_test.dart`**
The starting author profile contains only supplied facts and states that the master's-level study is
unconfirmed; an edited profile survives an encode/decode round trip; blank and corrupt stored values
fall back to the defaults instead of throwing; only plain `http(s)` addresses are accepted as links;
the monogram falls back to a Bengali letter; the in-memory store starts at the default, saves and
clears.

**`test/unit/preferences_persistence_test.dart`**
A theme change is written through the store and re-read by a fresh controller (the app after a
restart); language, reduced motion, text scale and followed sources all persist; a store that throws
on write never loses the in-session preference.

**`test/widget/translation_sheet_test.dart`**
A known word shows its glossary meaning; an unknown word says so instead of inventing one; a missing
glossary asset shows the unavailable state with no input field; tapping a word chip looks it up. In
the About suite, the author profile is edited at runtime and the change reaches the store, and a link
that is not a web address is rejected without saving.

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
results, recent searches, no results. Settings: theme, text size, language switch. About: registry counts, the author profile rendered
separately from the app description, runtime editing persisted to the profile store, and rejection of
a malformed profile link.
E-paper directory. AppShell: tab switching, Android back behaviour, detail push/pop. Dark theme.
Layouts at 360×640 dp and 800×1280 dp without overflow.

## What the redesign pass could and could not verify

- **Verified in CI**: analyzer clean, 168 tests green, release APK builds. The new cases cover the
  jelly surface's tap and disabled states, the reduced-motion duration policy, the category strip's
  selection callbacks and the news card's bookmark round-trip.
- **Not verified anywhere**: frame-level spring timing, the visual result of the glass layers, and how
  the layouts look on a real screen. This sandbox has no emulator and no Flutter SDK, so no screenshot,
  recording or animation measurement was produced, and none is claimed. The composition was built
  against the supplied three-device reference; the manual checklist below is how to confirm it.
- One honest limitation of the headless harness: pressing a `JellySurface` and reading the compressed
  transform back during the hold did not reproduce reliably under `flutter test`, so the suites assert
  the tap contract, the disabled state and the motion policy rather than the spring's intermediate
  frames.

## Manual QA checklist for a real device

1. Fresh install → Home shows the skeleton, then headlines (or the honest empty state).
2. Airplane mode → relaunch → cached headlines with the "cached/offline" notice; directory still
   browsable; publication websites still open.
3. `Settings → Source health` → failing sources listed first with their error; retry one.
4. Open a publication with no feed → only website/e-paper actions are offered.
5. Bookmark three stories → force-stop → relaunch → Saved intact.
6. Home → the counter reads the number of cached articles and the freshness line names the last
   refresh; the featured rail should appear only when at least three real articles carry images.
   A publisher that fails must show in `Source health` with its HTTP status while the other
   publishers' headlines stay on screen.
7. Open a story → "Read in app" → the publisher page loads with its real domain in the bar; follow a
   link inside it → back returns through page history before leaving the reader; "open in browser"
   hands the same URL to the system browser; bookmarking from the reader warns that only the
   headline and link are kept.
8. Search in Bengali and in English → both find publications and headlines.
9. Toggle dark theme, 140 % text size, reduce motion → no clipped Bengali headlines, and the
   bookmark fill animation is skipped while the saved state still changes.
10. About → the author profile edits and persists across a force-stop; a non-URL link is rejected.
11. Reader → the progress rule advances with scrolling; the translation sheet reports unknown words
    as unknown and states that it is word-by-word.
12. Android back: detail → list → Home tab → app exits (no navigation loop).
13. Rotate and use split-screen → no overflow stripes.
14. Let the app idle for the configured interval → "last updated" advances; no request storm in
    a proxy trace.
