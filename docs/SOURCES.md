# Source catalogue: policy and maintenance

The directory is the product. It is therefore curated like editorial content, not scraped.

## Rules used when curating `assets/data/sources.json`

1. **Only publications with a confident official domain are shipped.** A doubtful candidate goes
   to `assets/data/source_candidates.json` (never shown in the UI) until the domain is confirmed.
2. **Newspapers are separated from other media.** `type` distinguishes `daily_newspaper`,
   `online_portal`, `weekly`, `news_agency` and `broadcaster`; the `broadcast` category groups
   agencies and international broadcasters so they are never presented as Bangladeshi newspapers.
3. **Geography is only claimed when known.** `division`/`district` are filled only for regional
   titles whose publication city is established; the UI derives its division list from the data,
   so an empty division simply does not appear.
4. **E-paper links point at the publisher.** The app never hosts, proxies or converts a PDF, and
   `access` is `unknown` unless the publisher states otherwise.
5. **Logo files are not shipped.** Branding assets require permission; the app renders a
   deterministic two-tone monogram instead of an unlicensed logo.
6. **Feed URLs are candidates until verified.** `feedClaim` records how a URL came to exist;
   `scripts/verify_sources.py --write` is the only thing allowed to write `verified_working`.

## States

| `feedClaim` | Meaning | UI |
| --- | --- | --- |
| `none` | No feed known | "No feed — use the website" |
| `candidate` | Plausible URL, never confirmed | "Unverified (candidate)" + health badge |
| `official_documented` | Publisher documents the feed (e.g. BBC Bengali) | "Documented by the publisher" |
| `verified_working` | A live fetch returned parseable items | "Verified working feed" + `lastVerifiedAt` date |

Only `scripts/verify_sources.py --write` may write `verified_working`, and only after a successful
fetch; it also writes `lastVerifiedAt`. A failing URL is demoted back to `candidate` — the entry is
never deleted, and a claim is never upgraded by guesswork.

**A 200 response is not enough.** The verifier only qualifies a feed when the body parses as real
XML, it yields at least three items with links, at least half the items carry a genuine timestamp,
at least half the links point at the publisher's own host, and a Bengali publication actually
contains Bengali headlines.

### Verification run — 2026-10-24

Run on a machine with normal internet access (GitHub Actions, `Verify sources` workflow).

| Source | Result | Items | Timestamped | On-domain | Bengali | Evidence for |
| --- | --- | --- | --- | --- | --- | --- |
| `prothomalo` | verified working | 88 | 88 | 76 | yes | `verified_working` |
| `bbc_bangla` | verified working | 14 | 14 | 14 | yes | stays `official_documented` |
| `suprobhat` | verified working | 10 | 10 | 10 | yes | `verified_working` |
| `sarabangla` | verified working | 10 | 10 | 10 | yes | `verified_working` |
| `dainik_azadi` | verified working | 10 | 10 | 10 | yes | `verified_working` |
| `tbs` | verified working | 10 | 10 | 10 | n/a (English) | `verified_working` |

Everything else stayed `candidate`: 51 configured feeds failed the check (mostly HTTP 403
bot-protection on conventional paths, several HTTP 404, DNS failures and one TLS hostname mismatch).
Those URLs are **not** removed — they remain honestly labelled as unverified, and the app reports the
live result per publication.

Other findings from the same run:

- `business_post`: `businesspostbd.com` redirects to an unrelated hosting page, so the entry is now
  `needs_review` with no feed claim. It stays in the directory until the current domain is confirmed.
- `bhorer_kagoj`: the `.com` host redirects to `bhorerkagoj.net`, so the registry now points at the
  canonical domain (feed path still unverified).
- Only 21 of 60 websites answered an automated GET. Most of the rest returned HTTP 403 (bot
  protection), which is **not** evidence that a newspaper has closed, so no entry was demoted for it.

Runtime health is stored separately (`source_health`) and never rewrites `status`. A publication
whose feed fails stays in the directory, keeps its "open website" action, and is listed first in
*Settings → Source health*.

## Adding a publication

1. Confirm the official HTTPS website (and that it is the publisher, not a directory/aggregator).
2. Determine the type and, for regional titles, the division/district.
3. Look for an official feed. Prefer the publisher's own feed page; a conventional
   `/feed`, `/rss`, `/rss.xml` or `/wp-json/wp/v2/posts` is a *candidate* until verified.
4. Add the entry with `feedClaim: "candidate"` or `"none"` and a short `notes` line explaining the
   evidence.
5. Run `python3 scripts/verify_sources.py --only <id> --write` and commit the updated registry plus
   `docs/source_verification.json`.
6. `flutter test test/unit/registry_test.dart` must stay green (it enforces unique ids, HTTPS-only
   URLs, valid divisions and agency typing).

## Coverage snapshot (this release)

| Group | Entries |
| --- | --- |
| National Bengali dailies | 20 |
| English-language dailies / weeklies | 14 |
| Online news portals | 13 |
| Business & finance | 6 |
| Regional (Chattogram, Sylhet) | 4 |
| News agencies & broadcasters (separate) | 9 |
| **Total registry entries** | **60** |
| E-paper destinations | 6 |

Regional coverage is deliberately incomplete: only divisions whose publications have a confirmed
domain are listed. Candidates for Barishal, Khulna, Rajshahi, Rangpur, Mymensingh and Dhaka that
still need domain verification are parked in `source_candidates.json`. **This is not complete
coverage of Bangladeshi newspapers** and the app does not claim to be.

## Copyright policy

- Only the headline, excerpt, thumbnail URL and publication time that the publisher includes in its
  public feed are stored. No article bodies are fetched, stored or displayed.
- Every card and detail page shows the publisher, the publication time and a link to the original.
- The app never bypasses a paywall, login, CAPTCHA or anti-bot measure, and never falls back to
  scraping when a feed is missing.
- The About screen states that the app is not affiliated with any newspaper and that all content
  belongs to its publisher.
# Verified sources — 2026-10-25

This file records what the app actually fetches and why. It is written from the
live evidence produced by the `Verify sources` workflow (run `40121635019`,
164 candidate URLs, 27 publishers) and is regenerated whenever the registry
changes.

## Feeds that answered (shipped as `verified_working`)

| # | Publication | Language | Feed | Items that run |
| - | --- | --- | --- | --- |
| 1 | Prothom Alo | bn | `https://www.prothomalo.com/stories.rss` | 60 (60 dated) |
| 2 | JagoNews24 | bn | `https://www.jagonews24.com/rss/rss.xml` | 100 (100 dated) |
| 3 | Ajker Patrika | bn | `https://www.ajkerpatrika.com/feed` | 20 (20 dated) |
| 4 | Dhaka Post | bn | `https://www.dhakapost.com/rss/rss.xml` | 20 (20 dated) |
| 5 | Suprobhat | bn | `https://www.suprobhat.com/rss` | 10 (10 dated) |
| 6 | Sarabangla | bn | `https://sarabangla.net/rss` | 10 (10 dated) |
| 7 | Dainik Azadi (Chattogram) | bn | `https://www.dainikazadi.net/rss` | 10 (10 dated) |
| 8 | The Daily Star | en | `https://www.thedailystar.net/frontpage/rss.xml` | 10 (**0 dated**) |
| 9 | The Business Standard | en | `https://www.tbsnews.net/rss.xml` | 10 (10 dated) |
| 10 | BBC News Bengali | bn | `https://feeds.bbci.co.uk/bengali/rss.xml` | 14 (14 dated) |
| 11 | Al Jazeera English | en | `https://www.aljazeera.com/xml/rss/all.xml` | 25 (25 dated) |
| 12 | DW News (English) | en | `https://rss.dw.com/rdf/rss-en-all` | 131 (131 dated) |
| 13 | BBC News (World) | en | `https://feeds.bbci.co.uk/news/world/rss.xml` | 30 (30 dated) |

The Daily Star publishes no item timestamps. Its stories are shown with
"publication time unknown" and are sorted after dated stories; the probe flags
this explicitly (`allowUndated`) rather than silently passing an undated feed.

## Requested publishers that could not be integrated

| Publication | What the network said on 2026-10-25 |
| --- | --- |
| bdnews24 (bn/en) | 16 paths probed on both hosts; the host answers but nothing returns RSS/Atom (HTML bodies only). |
| Jugantor | 11 paths, HTTP 403 on every one. |
| Samakal | 10 paths, HTTP 403 on every one. |
| Kaler Kantho | 11 paths, HTTP 403 on every one. |
| Ittefaq | 10 paths, HTTP 403 on every one. |
| Bangladesh Pratidin | 11 paths, HTTP 403 on every one. |
| Bangla Tribune | 10 paths, HTTP 403 on every one. |
| Dhaka Tribune | 10 paths, HTTP 403 on every one. |
| Reuters | `feeds.reuters.com` no longer resolves; `outboundfeeds` answers 404/401. No public RSS. |

None of these is presented as an active feed. Each keeps its directory entry,
e-paper link and metadata, and opens the publisher's own website in the in-app
reader. The app's per-source status says "no feed — use the website" instead of
showing an empty headline list.

## Other publishers

38 further registry entries are unverified hypotheses. They no longer ship a
feed URL at all: their candidate URLs live in `assets/data/feed_candidates.json`,
and a URL is only promoted into `assets/data/sources.json` after the probe
qualifies it. `test/unit/registry_test.dart` asserts that rule.

## Reproducing this

```bash
gh workflow run verify-sources.yml          # or push a change to the data files
gh run list --workflow=verify-sources.yml   # pick the newest run
# the run's check annotations carry the per-publisher summary
python3 scripts/probe_feeds.py --only prothomalo --delay 1.0
```
