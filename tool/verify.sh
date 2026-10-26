#!/usr/bin/env bash
# Everything that can be checked on this machine, in one command.
#   ./tool/verify.sh            # static checks + source registry sanity
#   ./tool/verify.sh --dart     # also run dart format/analyze/test if Flutter exists
set -euo pipefail
cd "$(dirname "$0")/.."

echo "==> source registry JSON is valid"
python3 - <<'PY'
import json, re, sys
from pathlib import Path

data = json.loads(Path('assets/data/sources.json').read_text(encoding='utf-8'))
sources = data['sources']
ids = [s['id'] for s in sources]
assert len(ids) == len(set(ids)), 'duplicate source ids'
DIVISIONS = {'Dhaka', 'Chattogram', 'Rajshahi', 'Khulna', 'Barishal', 'Sylhet', 'Rangpur', 'Mymensingh'}
LANGUAGES = {'bn', 'en'}
TYPES = {'daily_newspaper', 'online_portal', 'broadcaster', 'news_agency', 'weekly', 'magazine'}
CATEGORIES = {'national', 'english', 'online', 'business', 'regional', 'broadcast'}
FEED_CLAIMS = {'candidate', 'official_documented', 'verified_working', 'none'}
STATUSES = {'active', 'needs_review', 'inactive'}
for s in sources:
    assert s['website'].startswith('https://'), s['id']
    for key in ('feedUrl', 'epaperUrl'):
        if s.get(key):
            assert s[key].startswith('https://'), (s['id'], key)
    for key in ('id', 'name', 'nameBn', 'type', 'language', 'status', 'feedClaim'):
        assert s.get(key), (s['id'], 'missing', key)
    assert s['language'] in LANGUAGES, (s['id'], s['language'])
    assert s['type'] in TYPES, (s['id'], s['type'])
    assert s['status'] in STATUSES, (s['id'], s['status'])
    assert s['feedClaim'] in FEED_CLAIMS, (s['id'], s['feedClaim'])
    assert s.get('categories'), (s['id'], 'no categories')
    assert set(s['categories']) <= CATEGORIES, (s['id'], s['categories'])
    assert s.get('division') in (DIVISIONS | {None}), (s['id'], s.get('division'))
    # `candidate` means an unverified URL is recorded in the candidate backlog,
    # not that the registry ships a feed; only documented or verified claims
    # require a feed URL here.
    if s['feedClaim'] in ('official_documented', 'verified_working'):
        assert s.get('feedUrl'), (s['id'], 'documented feed claim without a url')
    if s.get('feedUrl'):
        assert s.get('feedFormat') in ('rss', 'atom', 'unknown'), (s['id'], s.get('feedFormat'))
    if s.get('district'):
        assert s.get('division'), (s['id'], 'district without a division')
    if 'regional' in s['categories']:
        assert s.get('division'), (s['id'], 'regional source without a division')
    if s.get('notes'):
        assert len(s['notes']) < 400, (s['id'], 'notes too long')
    if s.get('lastVerifiedAt'):
        assert re.fullmatch(r'\d{4}-\d{2}-\d{2}', s['lastVerifiedAt']), (s['id'], s['lastVerifiedAt'])
        # A verification date records either a feed check or a website check; a
        # website-only source legitimately has no feed URL and must say so.
        if not s.get('feedUrl'):
            assert s['feedClaim'] == 'none', (s['id'], 'feed claim without a url')
            assert s.get('notes'), (s['id'], 'website check without a note')
    if s['feedClaim'] == 'verified_working':
        assert s.get('lastVerifiedAt'), (s['id'], 'verified claim without a date')

epapers = data.get('epapers', [])
ep_ids = [e['id'] for e in epapers]
assert len(ep_ids) == len(set(ep_ids)), 'duplicate e-paper ids'
known = set(ids)
for e in epapers:
    for key in ('id', 'sourceId', 'name', 'nameBn', 'url'):
        assert e.get(key), (e.get('id'), 'missing', key)
    assert e['sourceId'] in known, (e['id'], 'unknown source', e['sourceId'])
    assert e['url'].startswith('https://'), e['id']

assert len(data.get('about', '').strip()) > 200, 'about text is missing or too thin'

backlog = json.loads(Path('assets/data/source_candidates.json').read_text(encoding='utf-8'))
assert backlog.get('purpose'), 'source_candidates.json has no purpose'
candidates = backlog['candidates']
assert candidates, 'no candidate publications recorded'
for c in candidates:
    assert c.get('name') and c.get('nameBn'), c
    assert c.get('division') in DIVISIONS, c
# Registry strings must resolve to the Dart enums after key normalization;
# a mismatch silently degrades a value (e.g. status -> active, type -> unknown).
model = Path('lib/data/models/news_source.dart').read_text(encoding='utf-8')
def dart_enum(name):
    body = re.search(r'enum %s \{([^}]*)\}' % name, model, re.S)
    assert body, f'missing enum {name}'
    return {v.strip().lower() for v in body.group(1).replace('\n', ' ').split(',') if v.strip()}

def norm(value):
    return re.sub(r'[_\-\s]', '', str(value)).lower()

checks = [
    ('PublicationType', 'type', TYPES),
    ('SourceStatus', 'status', STATUSES),
    ('FeedClaim', 'feedClaim', FEED_CLAIMS),
]
for enum_name, field, allowed in checks:
    members = dart_enum(enum_name)
    for value in allowed:
        assert norm(value) in members, (enum_name, value, 'not a Dart enum member')
    for s in sources:
        assert norm(s[field]) in members, (s['id'], field, s[field])
for s in sources:
    for category in s.get('categories', []):
        assert norm(category) in dart_enum('SourceCategory'), (s['id'], category)
print(f"    {len(sources)} sources, {len(epapers)} e-papers, {len(candidates)} candidates")
PY

echo "==> offline glossary is valid and honestly labelled"
python3 tool/check_glossary.py

echo "==> every asset declared in pubspec.yaml exists"
python3 - <<'PY'
import re, sys
from pathlib import Path

text = Path('pubspec.yaml').read_text(encoding='utf-8')
declared = re.findall(r'^\s+-\s*(?:asset:\s*)?(assets/\S+)\s*$', text, re.M)
assert declared, 'no assets declared in pubspec.yaml'
missing = [p for p in declared if not Path(p).exists()]
empty = [p for p in declared if Path(p).stat().st_size == 0] if not missing else []
if missing or empty:
    for p in missing:
        print('    missing:', p)
    for p in empty:
        print('    empty:', p)
    sys.exit(1)
for path in sorted(set(declared)):
    size = Path(path).stat().st_size
    assert size < 4 * 1024 * 1024, f'{path} is surprisingly large ({size} bytes)'
print(f'    all {len(set(declared))} declared asset files present')
PY

echo "==> bundled publisher marks match the registry"
python3 - <<'LOGOS'
import json, struct
from pathlib import Path

manifest = json.loads(Path('assets/publishers/logos.json').read_text(encoding='utf-8'))
logos = manifest['logos']
registry = json.loads(Path('assets/data/sources.json').read_text(encoding='utf-8'))
known = {s['id'] for s in registry['sources']}
size = manifest['size']

files = {}
for publisher_id, entry in logos.items():
    assert publisher_id in known, f'logo for unknown publisher: {publisher_id}'
    relative = entry['file']
    assert relative.startswith('assets/publishers/'), relative
    path = Path(relative)
    assert path.exists(), f'missing logo file: {relative}'
    assert path not in files.values(), f'{publisher_id} reuses {relative}'
    files[publisher_id] = path

    raw = path.read_bytes()
    assert raw[:8] == b'\x89PNG\r\n\x1a\n', f'{relative} is not a PNG'
    width, height = struct.unpack('>II', raw[16:24])
    assert (width, height) == (size, size), f'{relative} is {width}x{height}, expected {size} square'
    assert len(raw) > 500, f'{relative} is suspiciously small'

# No orphan art: every PNG in the directory is declared, and every declared file
# is a distinct file. A missing mark is fine; a dangling reference is not.
on_disk = {p.name for p in Path('assets/publishers').glob('*.png')}
declared = {p.name for p in files.values()}
assert on_disk == declared, f'orphan or undeclared logo files: {sorted(on_disk ^ declared)}'

curated = {s['id'] for s in registry['sources'] if s.get('curated')}
covered = curated & set(logos)
print(f'    {len(logos)} bundled marks, each a distinct square {size}px PNG on disk')
print(f'    curated coverage: {len(covered)}/{len(curated)}; '
      f'falling back: {", ".join(sorted(curated - set(logos)))}')
LOGOS

echo "==> Dart structural checks (no SDK required)"
python3 tool/dart_lint.py

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
