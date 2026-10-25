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

Grayscale foundation, one accent, semantic colours used only semantically. Every value lives in
`lib/theme/tokens.dart`; screens never hard-code a colour.

| Token | Light | Dark/AMOLED | Purpose |
| --- | --- | --- | --- |
| `paper` | `#F3F1EE` | — | App background |
| `paperRaised` | `#FBFAF8` | — | Paper sheets |
| `paperSunken` | `#E8E5E0` | — | Inset wells |
| `ink` | `#17181A` | `#F2F1EE` | Primary text |
| `inkMuted` | `#54575C` | — | Secondary text |
| `hairline` | `#E0DCD6` | `#2A2C31` | Structural rules and borders |
| `accent` | `#AE1B27` | `#F2606B` | Brand rule, kickers, selected state |
| `accentSoft` | `#CB4A55` | — | Secondary accent (progress rule) |
| `signal` | `#BF1224` | — | Breaking-news label only |
| `success` / `warning` / `danger` | `#1E6B48` / `#94600A` / `#B0231C` | — | Feed health, cache states, errors |
| `nightBg` / `nightRaised` | — | `#0B0C0E` / `#15171A` | Night surfaces |

Rules:

- The accent never fills a large area: a 3 px masthead rule, a kicker, a selected pill, one icon.
- Content sits on paper, not on gradients. Glass is for chrome and for the river cards that float
  over the aurora backdrop.
- State colour goes on the icon and the label, never on a whole card.
- The aurora backdrop (`AuroraBackdrop`) paints two very soft accent blooms behind the paper so the
  glass has something real to refract. It is a static painting, wrapped in a `RepaintBoundary`.

## Type

- Headlines and body: `NotoSerifBengali` (bundled, OFL) — conjuncts and mixed Bengali/Latin strings
  render correctly, and a serif headline is the strongest signal that this is a reading app.
- Chrome, labels, buttons: `NotoSansBengali`.
- Scale: display 34, headline 25, title 19, lead 16, body 15, caption 12.5, label 11.5.
- Body line height 1.85 for Bengali excerpt text; headline 1.32–1.36.
- The user's text-size preference multiplies article and headline sizes only; the OS text scale is
  clamped to 0.85–1.6 so the grid cannot break.

## Layout and composition

The home page follows the three-device reference supplied for this rebuild:

1. a compact single-line masthead (3 px accent rule, wordmark, filter and search discs) on frosted
   glass, pinned;
2. a full-bleed landscape featured card per story, headline over a scrim, publisher and time inside
   the card, dots centred underneath — only rendered when at least three real stories carry images;
3. a horizontal strip of circular category tiles with labels beneath, the "all" tile first;
4. a slim control bar: an All / Following capsule, the live story count, and a refresh disc;
5. a freshness line that states offline / cached / last refresh honestly;
6. the headline river as translucent cards: 92×88 thumbnail, serif headline, monogram, publisher,
   time, share and bookmark on the meta line.

Other screens keep one gutter (`Tokens.gutter`, 20 px) and one rhythm, but change their composition so
no two screens look like the same template:

- **Directory**: glass search capsule, division and language chips, rows with monogram, language and
  a health badge; the follow disc is a jelly control.
- **Publication page**: the publisher's monogram leads in a glass disc, then name, meta chips, a
  filled "open website" button, the headline river, e-paper rows, and a facts panel.
- **Reader**: full-width photograph, serif headline at 26 px/1.38, excerpt at 16.8 px/1.92, a quiet
  excerpt note, one filled "read in app" action, two quiet secondary actions, related coverage.
- **Saved**: library header with a real count, a sliding capsule for Saved/History, saved-kind
  filters, swipe-to-remove, and an explicit note that a saved link is not an offline copy.
- **About**: app facts (registry counts, publisher disclaimer, privacy, licences, diagnostics) in one
  register, then the editable author profile in a visibly separate one.
- **Settings**: eyebrow section titles, glass panels and sliding capsule segmented controls.

The bottom navigation is a floating frosted bar with five labelled destinations; content scrolls
beneath it with 130–140 px of bottom padding.

## Glass

Real glass is layered, not one translucent rectangle: `BackdropFilter` + translucent gradient fill +
hairline border + top sheen + shadow + rounded clip. `GlassPanel` (surfaces and cards), `GlassBar`
(the bottom navigation and browser chrome), `GlassChip` (filters and tags) and `GlassIconButton`
(masthead actions) all build on the same material.

Glass is used **selectively** so it keeps meaning hierarchy:

- the pinned masthead,
- the bottom navigation,
- the feed control card and category circles,
- the river cards (they float over the aurora),
- bottom sheets, the browser chrome, and the reader's quoted note.

Blur sigma is 0 for anything that does not overlap moving content (a chip on flat paper does not pay
for a `BackdropFilter`), 12 for small floating controls, 22–30 for bars and sheets. Large scrolling
areas never blur more than the pinned masthead, and every glass surface is clipped so the blur cannot
bleed.

## Motion

`lib/theme/motion.dart` is the whole vocabulary: springs, durations, and the reduced-motion decision.
`Motion.of(context).reduce` is true when the OS asks for reduced motion or the in-app switch is on.

- **Jelly press**: `JellySurface` compresses on *touch-down* (raw pointer events, plus the tap
  recogniser as a second trigger), springs back with controlled overshoot on release. Press scales:
  0.985 for cards, 0.93 for chips, 0.955 for buttons, 0.90 for nav items and bookmark discs.
  Springs: press `(m1, k900, d30)`, release `(m1, k400, d17)`, settle `(320, 24)`, nav `(380, 20)`.
- **Bookmark**: outline → filled with its own overshoot and an accent colour, confirmed by a light
  haptic. Reduced motion keeps the state change and drops the pop.
- **Featured rail**: drag moves the photograph faster than its frame (6 % parallax + 1.07 scale) and
  springs to the nearest page; dots are tappable 5 px capsules that grow to 16 px.
- **Route**: fade + 3.5 % rise + 0.972 → 1 scale on `Cubic(0.17, 0.84, 0.28, 1)`.
- **Entrance**: staggered rise/fade for the first items of a screen, once per mount, never on scroll.
- **Reading progress**: a 2 px rule driven by scroll offset; nothing else animates on scroll.
- **Reduced motion**: every duration collapses to zero, springs become single-step state changes, and
  feedback remains through colour and geometry. Nothing loops.

## Honesty rules that affect design

- No invented headline, timestamp, count, badge or publisher.
- "Featured" is populated only from articles that actually have images; the rail is omitted when
  there are fewer than three.
- A saved item is labelled *link only* or *with excerpt*; neither is called offline.
- The translation panel says it is word-by-word and reports unknown words as unknown.
- The author profile is separate from the app description and editable; it states that the
  master's-level study is unconfirmed instead of claiming a qualification.
