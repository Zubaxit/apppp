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
   `scripts/verify_sources.py --write` is the only thing allowed to write `verified`.

## States

| `feedClaim` | Meaning | UI |
| --- | --- | --- |
| `none` | No feed known | "No feed — use the website" |
| `candidate` | Plausible URL, needs a live check | Health badge: not checked / working / failing |
| `official_documented` | Publisher documents the feed (e.g. BBC Bengali) | Same, checked at runtime |
| `verified` | Live check succeeded | "Feed working" once fetched |
| `unverified` | Last live check failed | "Feed currently unavailable" |

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
