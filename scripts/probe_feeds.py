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
            ok, reason = verify.qualifies(
                result, entry.get("language", ""), allow_undated=bool(entry.get("allowUndated"))
            )
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
                "undated": int(result.get("datedItems") or 0) == 0 and ok,
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

    # A compact, one-line-per-publisher result. The detailed log above is far too
    # long to republish as a CI annotation, and this is what a maintainer reads.
    summary: List[str] = []
    for entry in spec["sources"]:
        if only and entry["id"] not in only:
            continue
        records = [r for r in report["candidates"] if r["sourceId"] == entry["id"]]
        winner = next((r for r in records if r["qualified"]), None)
        if winner:
            dated = winner.get("datedItems") or 0
            detail = f"{winner.get('itemCount', 0)} items, {dated} dated"
            if not dated:
                detail += " (no timestamps: allowUndated)"
            summary.append(f"{entry['id']:<16} OK   {winner['url']} ({detail})")
        else:
            reasons = [r.get("note") or r.get("reason") or "no response" for r in records]
            signature = summarize_failures(reasons)
            summary.append(f"{entry['id']:<16} FAIL {signature}")
    Path("probe_summary.txt").write_text("\n".join(summary) + "\n", encoding="utf-8")
    print(f"\n{len(winners)} selected:")
    for line in winners:
        print("  +", line)
    print("\nSUMMARY")
    for line in summary:
        print(line)
    return 0


def summarize_failures(reasons: List[str]) -> str:
    """Collapse per-URL reasons into the one thing a reader needs to know."""
    counts: Dict[str, int] = {}
    for reason in reasons:
        key = str(reason).strip() or "no response"
        if key.startswith("HTTP "):
            key = key.split(" ")[0] + " " + key.split(" ")[1]
        counts[key] = counts.get(key, 0) + 1
    if not counts:
        return "no candidate URL"
    ordered = sorted(counts.items(), key=lambda item: (-item[1], item[0]))
    return ", ".join(f"{name} x{count}" for name, count in ordered)


if __name__ == "__main__":
    sys.exit(main())
