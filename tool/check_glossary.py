"""Sanity checks for the bundled offline word glossary.

The glossary is a word list, not a translation engine. These checks keep it
honest and usable: English keys, Bengali meanings, no placeholders, and a size
that justifies shipping the feature at all.
"""

import json
import re
import sys
from pathlib import Path

BENGALI = re.compile(r"[\u0980-\u09FF]")


def main() -> int:
    path = Path("assets/data/bn_glossary.json")
    data = json.loads(path.read_text(encoding="utf-8"))
    words = data.get("words")
    if not isinstance(words, dict):
        print("glossary has no words map")
        return 1
    if len(words) < 200:
        print(f"glossary is too small to be useful ({len(words)} words)")
        return 1
    note = data.get("_note") or ""
    if "not full translation" not in note:
        print("glossary must state that it is not a full translation")
        return 1
    if data.get("version") != 1:
        print("unexpected glossary version")
        return 1
    for key, value in words.items():
        if not re.fullmatch(r"[a-z][a-z'\-]*", key):
            print(f"non-lowercase english key: {key!r}")
            return 1
        if not isinstance(value, str) or not value.strip():
            print(f"{key}: empty meaning")
            return 1
        if not BENGALI.search(value):
            print(f"{key}: meaning is not Bengali ({value!r})")
            return 1
        if "?" in value:
            print(f"{key}: uncertain meaning ({value!r})")
            return 1
    print(f"    {len(words)} english words with Bengali glosses")
    return 0


if __name__ == "__main__":
    sys.exit(main())
