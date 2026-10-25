# Performance notes — what was slow, what changed, what is still unmeasured

This file records the performance work on the glass-and-jelly interface: the defects that were
found by reading the render pipeline, the fixes, and — just as importantly — what has **not** been
measured, because this development sandbox has no Android device, no emulator, no Android SDK and
no Flutter SDK. No frame time, jank count, startup time or memory number in this document is
invented; every number below is a file size read from a real GitHub Actions build.

If a claim is not backed by an artifact in this repository or by the workflow output of a named
run, it is not in this document.

## How the investigation was done here

| Method | Available | Used for |
| --- | --- | --- |
| Flutter DevTools timeline / frame chart | **No** (no SDK, no device) | — |
| `flutter run --profile` on hardware | **No** | — |
| `flutter build apk --analyze-size` | **No** (needs the SDK) | — |
| Reading the widget/build layer (`lib/`) | Yes | every finding below |
| Measuring the real release APK in CI | Yes | the size section |
| Widget tests that pin structural properties | Yes | the regression section |

Findings are therefore stated as *causes on the render path*, not as measured milliseconds. Each
one is a property of the code that can be checked by reading it, and most are now asserted by a
test so they cannot quietly come back.

## A. What was actually costing frames

### A1. Every press rebuildt its own surface, twice

`JellySurface` called `setState` on touch-down and again on release to track whether it was held,
even though `build` never read that flag. Each press therefore rebuilt the content subtree — for a
news card that is a whole `Row` of text, an image, a gradient, two shadows and a clip — at the
exact moment the user was most likely to be scrolling.

*Fix*: the flag is now plain bookkeeping, no `setState`. The spring is the only thing that changes,
and it changes a transform.

### A2. Two transform layers per animated item

The press builder nested `Transform.translate` around `Transform.scale`. Each is a separate render
object and a separate layer.

*Fix*: one `Matrix4` combining the lift translation and the scale, applied by a single `Transform`
with `Alignment.center` and `FilterQuality.low`. Same visual result, half the layers.

### A3. Scaling re-rasterised the whole subtree every frame

Scaling a subtree that owns a `BackdropFilter`, a `ClipRRect`, a `BoxShadow` and text means Skia
repaints all of it per frame at a changing scale — the classic cause of "the animation stutters but
scrolling is fine".

*Fix*: `JellySurface` wraps its content in a `RepaintBoundary` by default, so the spring moves a
cached raster and nothing repaints inside. `boundary: false` is available for tiny inline marks
where the extra layer would cost more than the repaint.

### A4. Seventeen skeleton tickers for one shimmer

`ShimmerBox` created and `repeat()`ed its own `AnimationController`. The home loading state mounts
seventeen of them; the list skeleton nine more per screen. That is seventeen tickers, seventeen
schedules and seventeen rebuilds of one uniform pulse, all animating identically.

*Fix*: `ShimmerScope` owns a single controller; `ShimmerBox` became a `StatelessWidget` that listens
to it through an `InheritedWidget`, and is inert (no ticker at all) when no scope is present or when
motion is reduced. The pulse looks the same.

### A5. The article photo was rebuilt on every scroll frame

`ArticleDetailScreen` stored the reading progress in `setState`, so the reader's entire column —
photograph, headline, excerpt, actions — was rebuilt once per frame while scrolling, and
`ReadingProgressBar` then ran its own 110 ms implicit animation from each of those values, stacking
`AnimatedContainer`s.

*Fix*: progress is a `ValueNotifier`; the page is not rebuilt, and the rule is a
`ValueListenableBuilder` inside its own `RepaintBoundary` that resizes a `FractionallySizedBox`
instead of re-animating a container.

### A6. A `BackdropFilter` behind every card and every masthead disc

Nine surfaces paid for a full backdrop blur while sitting inside a scrolling column, over the static
`AuroraBackdrop`, with nothing moving behind them: the feed control card, the feed error note, the
category tiles, the directory search field, the "all publications" row, the saved-screen segmented
control, every settings panel, the search field, the two glass pills on the lead story (over a
photograph that already carries a black scrim), the bookmark and share discs on photographs, the
masthead's own icon buttons, and the browser toolbar's placement over a static page.

Each of those re-runs a `saveLayer` + Gaussian blur of its backdrop every time anything over it
moves — on the pinned masthead, every scroll frame.

*Fix*: blur is now only where something genuinely moves behind the surface and the surface is
chrome: the pinned masthead (`blurBar`), the floating bottom navigation (`blurStrong`), the browser
toolbar's glass bar, and the bottom sheets (`blurStrong`). Every other surface keeps its translucent
gradient fill, hairline, sheen and shadow — which is what you actually see when nothing is moving
behind it — and costs one `saveLayer` less per frame. Nothing became opaque.

### A7. Full-size photographs decoded for 92 dp thumbnails

`RemoteImage` asked the image cache for the publisher's original: a 1200–2000 px JPEG in a
92×88 dp box. Every distinct thumbnail in the river cost several megabytes of decoded bitmap, which
is both memory pressure and long decode frames while scrolling. There was no `memCacheWidth`
anywhere in the app.

*Fix*: `RemoteImage` takes the width it will actually paint and decodes for it
(`memCacheWidth`/`maxWidthDiskCache`, at the device pixel ratio), uses `FilterQuality.low`, and
skips the fade for thumbnails (a cross-fade on a row scrolling past is work nobody sees). Every call
site now states its size: 92 px for river thumbnails, the card width for the lead and featured
cards, screen width for the reader's photograph.

### A8. A slide animation around every region of the rail

The featured carousel's parallax built a nested translate + scale per card on every scroll frame,
and the river's `NewsCard` used an `AnimatedContainer` for a decoration that never changes — one
implicit controller per row, in a list that recycles rows.

*Fix*: one matrix for the parallax over a `RepaintBoundary`d photograph; `DecoratedBox` where
nothing animates.

### A9. The browser rebuilt the whole screen on every progress event

`_BrowserScreenState._onEngine` called `setState` for every engine notification — progress,
page-start, page-finish — which rebuilt `Scaffold`, the toolbar, and the platform-view *widget*.

*Fix*: the route state mirrors only `canGoBack` (which the system back gesture needs). The toolbar
and the page surface each rebuild through their own `ListenableBuilder`, so a load repaints the
chrome and nothing else.

### A10. Repeated identity lookups and network work

Checked and left alone deliberately: background refresh is a single `Timer` on a user-chosen
interval (`settings.refreshMinutes`, floored at 15), the feed query is not re-issued on rebuild, and
publisher icons go through the image disk cache rather than being refetched per build. No operation
in the app performs synchronous I/O on the UI isolate.

## B. The jelly system is unchanged in character

Nothing in this pass shortened a duration, removed a spring or replaced an interaction with a fade.
The press still compresses on touch-down (raw pointer events plus the tap recogniser), the release
still overshoots (`Springs.release`, damping ratio ≈ 0.42 — underdamped on purpose), the bookmark
still pops, and every `scale` value per component is untouched. What changed is the *cost* of each
frame: one transform instead of two, over a cached raster instead of a live subtree.

`test/widget/perf_test.dart` pins that the press owns exactly one transform, that its content is a
repaint boundary, and that the release spring is still underdamped — so a future "optimisation"
cannot turn the jelly into a fade without failing CI.

## C. APK size — measured, not assumed

The 118 MB figure that prompted this work was **not one APK**. The workflow uploaded
`build/app/outputs/flutter-apk/*.apk`, and that directory holds the debug *and* the release build, so
the artifact was a zip of both:

| Run | Artifact `apk` (zip) | Contents |
| --- | --- | --- |
| `40172294387` (before) | 118,486,545 B | `app-debug.apk` + `app-release.apk` under one name |
| `40187196211` (after) | 28,074,460 B (`apk-release`) | one release APK: 55,944,744 B |
| `40187196211` | 37,610,699 B (`apk-split`) | three per-ABI release APKs |
| `40187196211` | 90,801,186 B (`apk-debug`) | debug build, kept for inspection only |

An ARM64 phone installs the `app-arm64-v8a-release.apk` slice: **22,380,056 B** instead of
55,944,744 B for the universal APK — 60 % less to transfer, identical behaviour, because the other
two ABIs' engine copies are simply not there.

Where the bytes actually go, measured inside the universal release APK in run `40187196211`
(GitHub Actions prints this on every build):

| Group | Uncompressed | Share |
| --- | --- | --- |
| `lib/x86_64` (engine + Dart AOT) | 17.72 MB | 29.5 % |
| `lib/arm64-v8a` (engine + Dart AOT) | 16.57 MB | 27.6 % |
| `lib/armeabi-v7a` (engine + Dart AOT) | 14.20 MB | 23.7 % |
| `classes*.dex` | 9.52 MB | 15.9 % |
| bundled assets — the seven Bengali font weights (registry, glossary and icons are < 100 KB together) | 1.59 MB | 2.6 % |
| compiled Android resources | 0.45 MB | 0.7 % |
| everything else (signature, services, manifest) | 0.29 MB | 0.5 % |

The single largest entries are `lib/x86_64/libflutter.so` (11,888,112 B) and
`lib/arm64-v8a/libflutter.so` (10,814,048 B), then the per-ABI `libapp.so` (the compiled Dart:
6.5–7.6 MB each) and `classes.dex` (9,035,184 B). The 64 publication entries, the glossary and the
icon set together are a rounding error — which is exactly why no publisher was removed, no font was
subset, no feed integration was touched, and no aggressive minification was enabled. The only honest
lever was *what gets packaged*, and that is what changed:

1. the debug build no longer masquerades as part of the release download (it was 197 MB inside the
   artifact the user was told was "the APK");
2. per-ABI release APKs are published for phones that know their own architecture;
3. the universal release APK is still built and still available, because it installs on anything.

The new launcher artwork added 160 KB (`55,784,100 → 55,944,744` B between the previous and the
final build), mostly the five adaptive foreground PNGs — an honest trade for a launcher icon that is
not a placeholder.

## D. What is still not measured — device work

None of the above has been timed on hardware, because none is available here. To close that gap on a
phone, in this order:

1. `flutter run --profile` on the device, or install the release APK and use
   `adb shell dumpsys gfxinfo <package> framestats`.
2. Open DevTools → *Performance*, enable *Track widget builds* and *Track repaints*.
3. Record these five interactions one at a time, and read the frame chart (green = under 16 ms on a
   60 Hz panel, under 8.3 ms on 120 Hz):
   - cold start to first headline;
   - a long fling through the home river (this is where A6/A7/A8 would show);
   - dragging and releasing the featured rail (A8);
   - pressing and releasing a jelly card and a nav item (A1–A3);
   - opening the in-app browser and scrolling the publisher page (A6/A9).
4. In the *Memory* tab, watch the image cache while scrolling the river: with A7 it should stay flat
   instead of climbing per row.
5. `flutter run --trace-skia` (or the Impeller overlay) to confirm the remaining `saveLayer` calls
   correspond to the masthead, the nav bar, the toolbar and the sheets — and nothing else.

Expected if the analysis is right: the masthead's blur no longer re-runs per scroll frame, press
animations become layer transforms, and thumbnails stop dominating the raster and image-cache cost.
That expectation is a hypothesis until step 3 is run on a device, and this document will be updated
with the numbers when it is.
