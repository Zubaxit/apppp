# Design notes — Amar News

This file records the rules the interface follows and the reasoning behind them, so a future change
can be judged against intent instead of taste.

## Identity

| Where | Value |
| --- | --- |
| Bengali display name | আমার নিউজ |
| English name | Amar News |
| Tagline (bn / en) | আপনার পত্রিকা, আপনার মতো / *Your newspapers, the way you read* |
| Android label | `Amar News` |
| Application ID | `com.zubaxit.bdnewspaperhub` (intentionally unchanged) |
| Dart package | `bangladesh_newspaper_hub` (unchanged; renaming it would add churn for no user-visible gain) |

The mark is a front page with a folded corner: graphite tile, white sheet, one printed-red masthead
rule, three ink text lines. It exists in three places that share one geometry:

1. `scripts/generate_icons.py` → PNG launcher icons in `android/app/src/main/res/mipmap-*` and
   `assets/icons/`;
2. `android/app/src/main/res/drawable/ic_launcher_foreground.xml` (adaptive icon) and
   `drawable/launch_background.xml` (splash);
3. `lib/ui/widgets/brand.dart` → `AmarNewsMark`, the in-app vector version.

No emoji is used as an icon. No raster image is used for an ordinary UI icon.

## Colour

Grayscale foundation, one accent, semantic colours used only semantically.

| Token | Light | Dark | Purpose |
| --- | --- | --- | --- |
| `paper` | `#F6F4F1` | — | App background |
| `paperRaised` | `#FFFFFF` | — | Sheets, dialogs |
| `ink` | `#191A1B` | — | Primary text |
| `inkMuted` / `inkFaint` | `#5B5E61` / `#8C9094` | — | Secondary / tertiary text |
| `accent` | `#AF1F2B` | `#FF6B73` | Brand rule, kickers, links, saved state |
| `signal` | `#C0182A` | — | Breaking-news label only |
| `success` / `warning` / `danger` | `#1F6F4A` / `#9A6407` / `#B3261E` | — | Feed health, cache states, errors |
| `nightBg` / `nightRaised` | — | `#0B0B0C` / `#171719` | Dark surfaces |
| `hairline` | `#E3DFD9` | `#2B2B2E` | Structural rules and borders |

Rules:

- The accent never fills a large area. It is a 2–3 px rule, a kicker, a link, or a single 10 px mark.
- No gradients on content. The one exception is the launcher tile, which has a graphite gradient to
  read as a physical icon, and the fading rule used as a separator.
- No coloured success/error chips around whole cards; state colour goes on the icon and the label.

## Type

- Headlines and body: `NotoSerifBengali` (bundled, OFL) — conjuncts and mixed Bengali/Latin strings
  render correctly, and a serif headline is the strongest signal that this is a reading app.
- Chrome, labels, buttons: `NotoSansBengali`.
- Scale: display 34, headline 25, title 19, lead 16, body 15, caption 12.5, label 11.5.
- Body line height 1.85 for Bengali excerpt text; headline 1.32–1.36.
- The user's text-size preference multiplies article and headline sizes only; the OS text scale is
  clamped to 0.85–1.6 so the grid cannot break.

## Layout

- One gutter value (`Tokens.gutter`, 20 px) on every screen.
- Structure comes from hairline rules, not from stacked rounded cards. Nested cards are avoided.
- Images are full-bleed inside the gutter with an 8 px radius; they are never cropped into circles.
- The bottom navigation is a floating frosted bar with five destinations; content scrolls beneath it
  and gets 120 px of bottom padding so nothing is permanently hidden.

## Glass

`GlassSurface` and `GlassBar` blur what is behind them (`BackdropFilter`, 18–24 px sigma), fill with
72–80 % paper/graphite and draw one hairline. Used **only** for chrome:

- the pinned masthead,
- the bottom navigation,
- the browser toolbar,
- the translation sheet's container is opaque instead — it sits over text, so blur would reduce
  contrast for no benefit.

Blur is never applied to content, list rows or images. Each glass surface is inside a `SafeArea`
where it touches the system bars, and `ClipRect` keeps the blur from bleeding outside its bounds.

## Motion

All durations and curves are in `lib/theme/tokens.dart`; `Motion.of(context)` exposes them along with
the reduced-motion decision.

- Press: 120 ms scale to 0.97, selection haptic.
- Bookmark: outline → filled with a 0.7 → 1 overshoot, accent colour, light haptic.
- Route: fade + 3.5 % rise, 280 ms in / 200 ms out.
- Page entrance: staggered rise/fade for at most the first six items, once per mount.
- Reading progress: a 2 px rule driven by scroll offset, 90 ms smoothing; no other scroll animation.
- Nothing loops except an opt-in skeleton pulse.
- Reduced motion (system or in-app) collapses every duration to zero and skips scale/slide wrappers.
  No content is unreachable when animation is off.

## Honesty rules that affect design

- No invented headline, timestamp, count, badge or publisher.
- "Featured" is populated only from articles that actually have images; the rail is omitted when
  there are fewer than three.
- A saved item is labelled *link only* or *with excerpt*; neither is called offline.
- The translation panel says it is word-by-word and reports unknown words as unknown.
- The author profile is separate from the app description and editable; it states that the
  master's-level study is unconfirmed instead of claiming a qualification.
