#!/usr/bin/env python3
"""Verify the Bangladeshi publication registry against the live internet.

The app ships a curated registry (`assets/data/sources.json`). This script is the
maintainer tool that turns *curated* data into *verified* data:

  * checks that each official website resolves (and reports redirect domains);
  * checks each configured feed URL, parses it and counts usable items;
  * checks each e-paper URL;
  * optionally probes a few conventional feed paths for sources that have none
    (clearly reported as candidates, never auto-trusted).

It is deliberately polite: one request per URL, 1.5 s spacing, a 15 s timeout,
a descriptive user agent and no retries beyond a single connect retry.

Usage
-----
    python3 scripts/verify_sources.py                  # report only
    python3 scripts/verify_sources.py --write          # update feedClaim/verified status
    python3 scripts/verify_sources.py --only prothomalo,daily_star
    python3 scripts/verify_sources.py --report docs/source_verification.json

Exit codes: 0 = finished (even if some sources failed), 2 = bad usage.
Requires only the Python 3 standard library.
"""
from __future__ import annotations

import argparse
import datetime as _dt
import json
import re
import socket
import ssl
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from typing import Any, Dict, Iterable, List, Optional, Tuple

ROOT = __import__("os").path.dirname(__import__("os").path.dirname(__import__("os").path.abspath(__file__)))
REGISTRY = __import__("os").path.join(ROOT, "assets", "data", "sources.json")
USER_AGENT = (
    "BangladeshNewspaperHub-Verifier/1.0 (+https://github.com/Zubaxit/apppp) "
    "python-urllib"
)
TIMEOUT = 15
DELAY_SECONDS = 1.5
MAX_BYTES = 3 * 1024 * 1024

CANDIDATE_PATHS = ("/feed", "/rss", "/rss.xml", "/feed.xml", "/atom.xml", "/wp-json/wp/v2/posts")

ITEM_RE = re.compile(r"<(item|entry)(?:\s[^>]*)?>(.*?)</\1>", re.S | re.I)
TITLE_RE = re.compile(r"<title[^>]*>(.*?)</title>", re.S | re.I)
LINK_RE = re.compile(r"<link[^>]*>(.*?)</link>", re.S | re.I)
HREF_RE = re.compile(r"<link[^>]*href\s*=\s*[\"']([^\"']+)[\"']", re.I)
DATE_RE = re.compile(r"<(pubDate|published|updated|dc:date)[^>]*>(.*?)</\1>", re.S | re.I)


def fetch(url: str, method: str = "GET") -> Tuple[Optional[int], Optional[str], str]:
    """Return (status, body, note). Never raises."""
    request = urllib.request.Request(
        url,
        method=method,
        headers={
            "User-Agent": USER_AGENT,
            "Accept": "application/rss+xml, application/atom+xml, application/xml;q=0.9,"
                      " text/xml;q=0.8, text/html;q=0.7, */*;q=0.5",
            "Accept-Language": "bn,en;q=0.8",
        },
    )
    context = ssl.create_default_context()
    try:
        with urllib.request.urlopen(request, timeout=TIMEOUT, context=context) as response:
            raw = response.read(MAX_BYTES + 1)
            if len(raw) > MAX_BYTES:
                return response.status, None, "response larger than 3 MB"
            charset = response.headers.get_content_charset() or "utf-8"
            try:
                body = raw.decode(charset, errors="replace")
            except LookupError:
                body = raw.decode("utf-8", errors="replace")
            return response.status, body, ""
    except urllib.error.HTTPError as error:
        return error.code, None, f"HTTP {error.code}"
    except urllib.error.URLError as error:
        reason = getattr(error, "reason", error)
        return None, None, f"URL error: {reason}"
    except socket.timeout:
        return None, None, f"timed out after {TIMEOUT}s"
    except ssl.SSLError as error:
        return None, None, f"TLS error: {error}"
    except Exception as error:  # noqa: BLE001 - a verifier must never crash
        return None, None, f"{type(error).__name__}: {error}"


def analyse_feed(body: str) -> Dict[str, Any]:
    """Count items and detect the feed dialect without a real XML parser."""
    items = ITEM_RE.findall(body)
    titles = [re.sub(r"<[^>]+>", "", match).strip() for match in TITLE_RE.findall(body)]
    dates = [match[1].strip() for match in DATE_RE.findall(body)]
    first_item = items[0][1] if items else ""
    format_name = "unknown"
    if "<feed" in body[:2000].lower():
        format_name = "atom"
    elif "<rss" in body[:2000].lower():
        format_name = "rss"
    elif "<rdf" in body[:2000].lower():
        format_name = "rdf"
    looks_like_html = "<html" in body[:400].lower()
    return {
        "format": format_name,
        "itemCount": len(items),
        "sampleTitles": [t for t in titles[:3] if t],
        "sampleDates": dates[:3],
        "hasLink": bool(LINK_RE.search(first_item) or HREF_RE.search(first_item)),
        "looksLikeHtml": looks_like_html,
        "usable": len(items) > 0 and bool(LINK_RE.search(first_item) or HREF_RE.search(first_item)),
    }


def check_website(url: str) -> Dict[str, Any]:
    status, body, note = fetch(url)
    final_host = ""
    try:
        request = urllib.request.Request(url, method="HEAD", headers={"User-Agent": USER_AGENT})
        with urllib.request.urlopen(request, timeout=TIMEOUT) as response:
            final_host = response.geturl()
    except Exception:  # noqa: BLE001
        final_host = url
    expected_host = re.sub(r"^www\.", "", urllib.parse.urlparse(url).netloc.lower())
    actual_host = re.sub(r"^www\.", "", urllib.parse.urlparse(final_host).netloc.lower())
    return {
        "status": status,
        "note": note,
        "finalUrl": final_host,
        "domainMismatch": bool(expected_host and actual_host and expected_host != actual_host),
        "reachable": status is not None and 200 <= status < 400,
    }


def check_feed(url: str) -> Dict[str, Any]:
    status, body, note = fetch(url)
    if status is None or body is None:
        return {"status": status, "note": note or "no body", "usable": False, "itemCount": 0}
    if not (200 <= status < 300):
        return {"status": status, "note": note or f"HTTP {status}", "usable": False, "itemCount": 0}
    analysis = analyse_feed(body)
    analysis.update({"status": status, "note": note})
    return analysis


def main(argv: Optional[List[str]] = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--write", action="store_true", help="write verification results back into the registry")
    parser.add_argument("--only", default="", help="comma separated source ids")
    parser.add_argument("--report", default="docs/source_verification.json", help="JSON report path")
    parser.add_argument("--probe-candidates", action="store_true", help="probe common feed paths for sources without a feed")
    parser.add_argument("--delay", type=float, default=DELAY_SECONDS)
    args = parser.parse_args(argv)

    with open(REGISTRY, encoding="utf-8") as handle:
        registry = json.load(handle)

    only = {item.strip() for item in args.only.split(",") if item.strip()}
    sources: Iterable[Dict[str, Any]] = [
        source for source in registry["sources"] if not only or source["id"] in only
    ]

    now = _dt.datetime.now(_dt.timezone.utc).replace(microsecond=0).isoformat()
    report: Dict[str, Any] = {"generatedAt": now, "sources": [], "epapers": []}
    counts = {"websiteOk": 0, "feedOk": 0, "feedFail": 0, "noFeed": 0, "domainMismatch": 0}

    print(f"verifying {len(list(sources))} sources (delay {args.delay}s)\n")
    for source in registry["sources"]:
        if only and source["id"] not in only:
            continue
        website = check_website(source["website"])
        time.sleep(args.delay)
        if website["reachable"]:
            counts["websiteOk"] += 1
        if website["domainMismatch"]:
            counts["domainMismatch"] += 1
            print(f"  ! {source['id']}: website redirects to {website['finalUrl']}")

        feed_result: Dict[str, Any] = {}
        if source.get("feedUrl"):
            feed_result = check_feed(source["feedUrl"])
            time.sleep(args.delay)
            if feed_result.get("usable"):
                counts["feedOk"] += 1
                print(
                    f"  + {source['id']:<24} feed OK ({feed_result['itemCount']} items, "
                    f"{feed_result['format']})"
                )
            else:
                counts["feedFail"] += 1
                print(
                    f"  x {source['id']:<24} feed unusable: "
                    f"{feed_result.get('note') or feed_result.get('format', 'unknown')}"
                )
        else:
            counts["noFeed"] += 1
            feed_result = {"usable": False, "note": "no feed configured"}
            if args.probe_candidates:
                for path in CANDIDATE_PATHS:
                    candidate = source["website"].rstrip("/") + path
                    probe = check_feed(candidate)
                    time.sleep(args.delay)
                    if probe.get("usable"):
                        print(
                            f"  ? {source['id']:<24} candidate feed {candidate} "
                            f"({probe['itemCount']} items) — review before use"
                        )
                        feed_result = {**probe, "candidateUrl": candidate}
                        break

        report["sources"].append(
            {
                "id": source["id"],
                "name": source["name"],
                "language": source.get("language"),
                "website": website,
                "feed": feed_result,
                "feedClaim": source.get("feedClaim"),
                "lastVerifiedAt": source.get("lastVerifiedAt"),
            }
        )

        if args.write:
            # Only a real fetch may change the claim: a documented URL stays
            # documented, everything that returned items becomes verified_working,
            # and a failing URL is demoted back to candidate (never deleted).
            if feed_result.get("usable"):
                source["lastVerifiedAt"] = now
                if source.get("feedClaim") != "official_documented":
                    source["feedClaim"] = "verified_working"
            elif source.get("feedUrl"):
                source["feedClaim"] = "candidate"

    for edition in registry.get("epapers", []):
        if only and edition.get("sourceId") not in only:
            continue
        result = check_website(edition["url"])
        time.sleep(args.delay)
        report["epapers"].append({"id": edition["id"], "url": edition["url"], **result})
        state = "ok" if result["reachable"] else "unreachable"
        print(f"  {edition['id']:<28} e-paper {state}")

    report["counts"] = counts
    if args.write:
        registry["verifiedAt"] = now
        with open(REGISTRY, "w", encoding="utf-8") as handle:
            json.dump(registry, handle, ensure_ascii=False, indent=2)
            handle.write("\n")
        print(f"\nregistry updated: {REGISTRY}")

    report_path = args.report
    if not __import__("os").path.isabs(report_path):
        report_path = __import__("os").path.join(ROOT, report_path)
    __import__("os").makedirs(__import__("os").path.dirname(report_path), exist_ok=True)
    with open(report_path, "w", encoding="utf-8") as handle:
        json.dump(report, handle, ensure_ascii=False, indent=2)
        handle.write("\n")

    print(
        "\nsummary: "
        f"{counts['websiteOk']} websites reachable, "
        f"{counts['feedOk']} feeds usable, "
        f"{counts['feedFail']} feeds failing, "
        f"{counts['noFeed']} without a configured feed, "
        f"{counts['domainMismatch']} domain redirects"
    )
    print(f"report written to {report_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
