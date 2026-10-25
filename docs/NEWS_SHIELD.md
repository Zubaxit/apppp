# News Shield: scope, updates and limitations

News Shield is an opt-out browser protection layer for Amar News. It is **not**
Brave Shields, an Android browser extension, a VPN or a claim of complete ad
blocking.

## What is actually enforced

`webview_flutter 4.10` does not expose Android WebView's native
`shouldInterceptRequest` callback for every subresource. Within that constraint,
`WebViewBrowserEngine` installs `NewsShield.script` at `onPageStarted` and again
at `onPageFinished`:

- host rules stop matching third-party `fetch`, XHR and `sendBeacon` calls;
- matching dynamically inserted script, iframe, image and link resources are
  rejected;
- a navigation to a known ad/tracker host is rejected by `NavigationDelegate`;
- a short, reviewed cosmetic selector set removes conventional ad containers and
  collapses their space;
- first-party hosts (same registrable last-two-label domain) are never blocked by
  the host engine.

Parser-created images/scripts can begin before page-start JavaScript executes,
and native requests not initiated through the patched web APIs can escape. The
feature therefore reduces known advertising/tracking traffic; it cannot promise
100% blocking. The cosmetic rules deliberately do not use dangerous universal
selectors such as every class containing `ad`, so article text, menus and video
controls are less likely to be damaged.

## Rules and license

The bundled fallback (`assets/filters/news_shield_hosts.txt`, about 55 KB) is a
restricted host-only subset of maintained **EasyList** and **EasyPrivacy** rules.
The exact upstream repository and license are recorded in
`assets/filters/SOURCES.md`. Amar News understands exact host rules only; it does
not claim compatibility with the complete Adblock Plus filter grammar.

The parser validates host syntax, ignores exceptions/path rules it cannot safely
implement, and caps the active set at 4,000 hosts. The bundled list is always
available offline.

## Update/cache policy

When News Shield is globally ON, startup loads the bundled or last-known-good
rules. If the cache is at least seven days old, one background update fetches
EasyList's ad-server list and EasyPrivacy. It uses 20-second request timeouts,
validates both response status/size and requires at least 200 usable hosts before
replacing the old list. A failed or malformed update leaves the last-known-good
cache untouched. Lists are **not** downloaded on navigation.

The validated set and UTC update time use SharedPreferences. No browsing history
or page URL is sent to the list provider.

## Controls and exceptions

- Settings → **News Shield** is the persisted global switch; OFF means no Amar
  News blocking or cosmetic rules are active.
- When the global switch is ON, the shield icon beside the browser address is the
  effective state for that host. Tapping it adds/removes a persisted site
  exception and reloads the page so the next document starts consistently.
- A site exception cannot override global OFF. Re-enabling globally restores
  protection everywhere except the saved exception set.

If login, video, download or interactive content fails, turn the shield off for
that site and reload. Downloads and authenticated flows still depend on Android
WebView and each publisher; News Shield does not weaken JavaScript, TLS, origin,
or permission settings.
