# Architecture

## Goals

1. **Data over code.** Publications live in `assets/data/sources.json`; adding one is a data edit.
2. **Honest state.** "Curated website", "feed candidate", "feed verified", "feed failing" and
   "cached content" are five different things and the app never conflates them.
3. **Isolation.** One unreachable publisher can never break the feed, the directory or the app.
4. **Testability without a device.** Every store, the feed gateway and connectivity sit behind
   interfaces so tests run with fakes (no sqflite, no plugins, no network).

## Layers

```
┌─────────────────────────────────────────────────────────────────────┐
│ ui/            screens, widgets, shell, route helpers               │
│                reads controllers through provider, never touches    │
│                HTTP, SQLite or the filesystem                       │
├─────────────────────────────────────────────────────────────────────┤
│ state/         FeedController · SavedController · SettingsController │
│                ChangeNotifier; owns UI state, caching policy, timers │
├─────────────────────────────────────────────────────────────────────┤
│ data/services  ArticleRepository   ← single entry point for data     │
│                AppDatabase + stores (SQLite)                        │
├─────────────────────────────────────────────────────────────────────┤
│ data/feeds     FeedService (FeedGateway) → NewsHttpClient →          │
│                FeedParser → TopicClassifier                         │
├─────────────────────────────────────────────────────────────────────┤
│ data/models    immutable NewsSource, Article, SourceHealth,          │
│                AppPreferences, FeedQuery, RefreshReport              │
├─────────────────────────────────────────────────────────────────────┤
│ core/          strings (bn/en), labels, text/Bengali/URL/id utils    │
└─────────────────────────────────────────────────────────────────────┘
```

Dependency rule: a layer may import the layer below it, never above. `ui` knows `state`, `state`
knows `data/services`, `data/services` knows `data/feeds` and `data/models`, and `core` is a leaf.

## Boot sequence

`main()` → `BootstrapGate` → `AppBootstrap.create()`:

1. `RegistryLoader.load()` parses `assets/data/sources.json` into an immutable `SourceRegistry`
   (fails loudly if the JSON is malformed — a data error, not a user error).
2. `AppDatabase.open()` creates the SQLite schema (`articles`, `saved_articles`,
   `reading_history`, `source_health`, `feed_meta`, `app_meta`).
3. `SharedPreferencesStore` is read into `AppPreferences` (JSON blob, forward compatible: unknown
   keys are ignored, missing keys fall back to defaults).
4. Controllers are constructed and exposed through `MultiProvider`.

A bootstrap failure shows a recoverable error screen with a retry, not a crash loop.

## Feed pipeline

```
registry entry ─┬─ feedUrl? ─ no ─→ SourceHealth(disabled) — directory still works
                └─ yes
                    ↓
        FeedService.fetch(source)
          · ETag / If-Modified-Since from feed_meta
          · NewsHttpClient: UA, 12 s timeout, ≤2 attempts, 3 MB cap, per-host gap
          · 304 → "not modified" (no re-parse, no new timestamps)
          · non-2xx/timeout/TLS → SourceHealth(failing, message) — never throws
                    ↓
        FeedParser.parse(body)
          · sanitize control chars, broken entities, CDATA
          · XmlDocument.parse → RSS 2.0 / RDF / Atom
          · on XmlException → tolerant regex recovery over <item>/<entry>
          · per item: title required, link required and URL-safe, date optional
          · RFC 822 / RFC 3339 / naive "yyyy-MM-dd HH:mm" with +06:00 assumption
          · implausible dates (> now+1 day, < 1995) → null, never invented
          · thumbnail from media:*, enclosure or first <img>
          · breaking only from publisher category or explicit prefix
                    ↓
        TopicClassifier (publisher category first, then bn/en keyword scoring)
                    ↓
        Article.create() → stable id (FNV-1a of sourceId + canonical URL)
                         → clusterKey (sorted headline tokens + UTC day)
                    ↓
        ArticleStore.upsertAll() + prune()  →  SourceHealth upsert + feed_meta
```

`RefreshReport` summarises each pass (attempted / succeeded / failed / not-modified / new articles,
per-source failure messages). `FeedController` merges the report, reloads the filtered feed from
SQLite and notifies the UI.

### Why sorted by publication time matters

`Article.sortKey = publishedAt ?? fetchedAt`, and the UI explicitly renders
"প্রকাশের সময় পাওয়া যায়নি" when `publishedAt` is null. Cache age is rendered separately and never
presented as a publication timestamp; `FeedController.isShowingCached` compares the newest cached
`fetchedAt` against the last successful refresh.

### De-duplication

- Within a feed: identical id (same canonical URL) or identical normalized title is dropped.
- Across feeds: stories are **not** merged. `clusterKey` only powers the "Also covered by" list,
  which shows each publisher separately with its own headline and link.

## Refresh policy

| Trigger | Behaviour |
| --- | --- |
| App start | Load cache immediately, then refresh if the cache is older than the configured interval |
| Resume from background | `refreshIfStale()` (also re-reads reading history) |
| Timer | Foreground periodic timer at the configured interval (15/30/60/120/240 min) |
| Pull-to-refresh / refresh button | Forced refresh |
| Per source | Minimum 8 minutes between fetches, enforced in the repository |

There is no `WorkManager`/background-isolate refresh: Android's scheduling guarantees would make any
"refreshes every N minutes in the background" claim dishonest, so the app only promises what it can
deliver — foreground refresh plus an on-screen "last updated" time.

## Storage schema (SQLite v1)

| Table | Purpose |
| --- | --- |
| `articles` | Cached feed metadata (no article bodies); indexed on published/fetched/source/cluster |
| `saved_articles` | JSON snapshot of the article + `saved_at` (survives feed removal) |
| `reading_history` | Last 200 opened stories (toggleable; cleared when disabled) |
| `source_health` | Last check, last success, error, HTTP status, item count, latency |
| `feed_meta` | ETag, Last-Modified, last fetch/success, item count |
| `app_meta` | Key/value metadata such as `last_refresh_at` |

Pruning keeps the newest 80 items per source, a 2 500-item overall cap and 45 days of history.

## Security decisions

- **URL allow-list:** `UrlSafety` accepts only `http(s)` with a dotted host, upgrades to `https`,
  rejects `javascript:`, `data:`, `file:`, `intent:`, `content:`, `blob:`, userinfo in the authority,
  loopback hosts and executable file extensions. Every external open and every feed/image URL goes
  through it.
- **No WebView.** Articles open in the platform browser / Custom Tab, so publisher content never
  runs inside the app's process.
- **Network:** HTTPS only (`usesCleartextTraffic="false"`), no certificates bypassed, no proxy.
- **No secrets in the app.** There is no API key, service account or token anywhere in the codebase;
  the static check scans for common credential patterns.
- **Backups disabled** (`allowBackup=false`) so bookmarks and history are not silently extracted.

## Extending the app

- **Add a publication:** append an entry to `assets/data/sources.json`. No code change. If the
  publisher has a WordPress-style feed, a `/feed` candidate is usually enough; run the verification
  script before marking it `verified`.
- **Add a feed dialect:** extend `FeedParser` (single file) or add a `FeedFormat` and a branch in
  `_parseDocument`.
- **Add a language:** add an `AppStrings` subclass and register it in `AppStrings.forLanguage`.
- **Add cloud sync:** implement `SavedStore`/`HistoryStore` against a remote backend and swap it in
  `AppDatabase.stores` — the rest of the app is unchanged.
