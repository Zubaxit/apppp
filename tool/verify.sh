#!/usr/bin/env bash
# Everything that can be checked on this machine, in one command.
#   ./tool/verify.sh            # static checks + source registry sanity
#   ./tool/verify.sh --dart     # also run dart format/analyze/test if Flutter exists
set -euo pipefail
cd "$(dirname "$0")/.."

echo "==> source registry JSON is valid"
python3 - <<'PY'
import json
with open('assets/data/sources.json', encoding='utf-8') as f:
    data = json.load(f)
ids = [s['id'] for s in data['sources']]
assert len(ids) == len(set(ids)), 'duplicate source ids'
for s in data['sources']:
    assert s['website'].startswith('https://'), s['id']
    for key in ('feedUrl', 'epaperUrl'):
        if s.get(key):
            assert s[key].startswith('https://'), (s['id'], key)
print(f"    {len(ids)} sources, {len(data.get('epapers', []))} e-papers")
PY

echo "==> Dart static checks (tree-sitter based)"
if [ -d node_modules/tree-sitter ] || [ -d /tmp/tsdart/node_modules/tree-sitter ]; then
  NODE_PATH="${NODE_PATH:-}:/tmp/tsdart/node_modules" node tool/dart_static_check.js
else
  echo "    skipped (install with: npm i tree-sitter@0.20.6 tree-sitter-dart@1.0.0)"
fi

if [ "${1:-}" = "--dart" ]; then
  if command -v flutter >/dev/null 2>&1; then
    echo "==> dart format"
    dart format --output=none --set-exit-if-changed lib test
    echo "==> flutter analyze"
    flutter analyze --fatal-infos
    echo "==> flutter test"
    flutter test
  else
    echo "flutter not found on PATH; skipping analyzer and tests" >&2
    exit 1
  fi
fi

echo "==> done"
