#!/usr/bin/env python3
"""Probe candidate feed URLs for the curated publisher set.

The shipped app only aggregates publishers whose feeds have been verified
against real responses. This tool tests a list of candidate URLs per
publication (several conventional paths, both feeds we already know about and
new ones) and reports which candidate qualifies, using exactly the same
evidence gate as `verify_sources.py`:

  * valid XML,
  * at least three items with links,
  * at least half the items carry a real timestamp,
  * at least half the item links point at the publisher's own host,
  * Bengali headlines for Bengali publications.

Usage:
    python3 scripts/probe_feeds.py                 # every curated publisher
    python3 scripts/probe_feeds.py --only prothomalo,tbs
    python3 scripts/probe_feeds.py --report probe.json

Requires only the Python standard library. It makes one request per candidate
URL with a polite delay, and never treats a 200 response as proof on its own.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional

sys.path.insert(0, str(Path(__file__).resolve().parent))

import verify_sources as verify  # noqa: E402  (shared fetch + evidence gate)

ROOT = Path(__file__).resolve().parent.parent
CANDIDATES = ROOT / "assets" / "data" / "feed_candidates.json"


def main(argv: Optional[List[str]] = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--only", default="", help="comma separated source ids")
    parser.add_argument("--report", default="feed_probe.json")
    parser.add_argument("--delay", type=float, default=0.8)
    parser.add_argument("--user-agent", default="", help="override the user agent")
    args = parser.parse_args(argv)

    spec: Dict[str, Any] = json.loads(CANDIDATES.read_text(encoding="utf-8"))
    only = {item.strip() for item in args.only.split(",") if item.strip()}
    if args.user_agent:
        verify.USER_AGENT = args.user_agent

    report: Dict[str, Any] = {"candidates": []}
    winners: List[str] = []
    for entry in spec["sources"]:
        if only and entry["id"] not in only:
            continue
        print(f"\n{entry['id']} ({entry.get('language', '?')})")
        best: Optional[Dict[str, Any]] = None
        for url in entry["urls"]:
            result = verify.check_feed(url)
            ok, reason = verify.qualifies(result, entry.get("language", ""))
            status = result.get("status")
            detail = (
                f"{result.get('itemCount', 0)} items, {result.get('datedItems', 0)} dated, "
                f"{result.get('onDomainLinks', 0)} on-domain, {result.get('bengaliItems', 0)} bn, "
                f"xml={result.get('wellFormedXml')}"
            )
            print(f"  {'OK ' if ok else 'x  '} {url}")
            print(f"      {detail if result.get('itemCount') else result.get('note')} -> {reason}")
            verify.time.sleep(args.delay)
            record = {
                "sourceId": entry["id"],
                "url": url,
                "status": status,
                "qualified": ok,
                "reason": reason,
                "itemCount": result.get("itemCount", 0),
                "datedItems": result.get("datedItems", 0),
                "onDomainLinks": result.get("onDomainLinks", 0),
                "bengaliItems": result.get("bengaliItems", 0),
                "wellFormedXml": result.get("wellFormedXml", False),
                "note": result.get("note"),
            }
            report["candidates"].append(record)
            if ok and best is None:
                best = record
        if best:
            winners.append(f"{entry['id']} -> {best['url']}")
            print(f"  => selected {best['url']}")

    report["selected"] = winners
    Path(args.report).write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(f"\n{len(winners)} selected:")
    for line in winners:
        print("  +", line)
    return 0


if __name__ == "__main__":
    sys.exit(main())
