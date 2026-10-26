# News Shield filter provenance

The bundled fallback in `news_shield_hosts.txt` is a compact, deterministic
host-only subset generated on 2026-10-25 from the maintained EasyList and
EasyPrivacy repository:

- https://github.com/easylist/easylist
- upstream license: https://easylist.to/pages/licence.html
- source files: `easylist_adservers.txt`, `easylist_thirdparty.txt`, and
  `easyprivacy_specific.txt`

The application does not claim to implement the complete Adblock Plus grammar.
It keeps exact host rules whose host labels identify advertising, analytics,
tracking, metrics, pixels or common ad networks, plus a small reviewed core.
Network updates are parsed with the same restricted grammar and capped to 4,000
hosts. Allow-list and site-specific path rules are intentionally not interpreted.
