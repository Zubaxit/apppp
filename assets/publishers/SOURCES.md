# Bundled publisher marks

These files exist for exactly one reason: so a reader can tell **which newspaper** a headline came
from without waiting for a network request. They are used only to identify that publisher, at 20–62
dp inside the app, and never as decoration or in promotion of anything.

## Provenance

Every mark below was matched to its publisher by hand, from the file named in the second column, and
then looked at in `assets/publishers/` before being committed. Percentages are of the curated set.

| Registry id | Publisher | Artwork source | Notes |
| --- | --- | --- | --- |
| `prothomalo` | Prothom Alo (প্রথম আলো) | seeklogo.com, "Prothom Alo logo PNG" (`vector-logo/504130`) | Bengali nameplate with the red sun mark |
| `kaler_kantho` | Kaler Kantho (কালের কণ্ঠ) | seeklogo.com, "Kaler Kantho Bangladeshi Newspaper" (`vector-logo/362148`) | monochrome nameplate |
| `ajker_patrika` | Ajker Patrika (আজকের পত্রিকা) | Wikimedia Commons, `File:Ajker Patrika Logo.png` | teal nameplate |
| `dainik_azadi` | Dainik Azadi (দৈনিক আজাদী) | dainikazadi.net, site logo `wp-content/uploads/logo/azadi_logo.png` | publisher's own site asset |
| `dhaka_post` | Dhaka Post (ঢাকা পোস্ট) | dhakapost.com, site logo `media/common/dhaka-post-logo.svg` | publisher's own site asset |
| `bbc_bangla` | BBC News Bengali | seeklogo.com, "BBC News logo PNG" (`free-vector-logos/bbc-news`) | BBC News brand mark, shared with BBC World |
| `bbc_world` | BBC News (World) | as above | the same corporate brand mark; documented rather than duplicated by accident |
| `aljazeera` | Al Jazeera English | cdnlogo.com, "Al Jazeera logo" (`al-jazeera_145454`) | gold calligraphic mark with wordmark |
| `dw_news` | DW News (English) | seeklogo.com, "Deutsche Welle logo PNG" (`free-vector-logos/deutsche-welle`) | DW circles with wordmark |

## What is *not* bundled, and why

The remaining curated publishers have **no verified artwork in this set**, because no source was
found that could be confirmed as that publisher's own mark from inside the build environment (the
sandbox cannot reach Bangladeshi news sites, and search results for these names returned other
publications' logos, which would have been worse than nothing):

`daily_star`, `tbs`, `jagonews24`, `sarabangla`, `suprobhat` — and every non-curated registry entry.

They fall back in this order, all of which are honest:

1. the icon the publisher's own site advertises (`apple-touch-icon.png`, then `favicon.ico`), fetched
   at runtime and cached on disk;
2. the publisher's monogram on the same tile.

**The 59 other registry entries keep their records, their feed claims and their identity.** A missing
mark changes nothing except the picture.

## Rights

Each mark is the trademark of its publisher. It is bundled only to identify that publisher's content
in this reader, is displayed unmodified (scaled, never stretched, never recoloured), and is not used
to suggest any affiliation, endorsement or partnership. Publishers who prefer not to appear this way
can be removed from the manifest in one line: delete their entry from `assets/publishers/logos.json`
and their file, and the app falls back to the remote/derived mark.

## Regenerating

```
python3 -m venv .venv && .venv/bin/pip install pillow
# put the downloaded original in scripts/publisher_logo_sources/<id>.<png|jpg|webp>
.venv/bin/python scripts/prepare_publisher_logos.py
```

The script trims the margin, keeps the aspect ratio, centres the mark on a transparent 128 px square
and rewrites `assets/publishers/logos.json`. `./tool/verify.sh` then checks that every manifest entry
exists, is square, decodes as an image, and belongs to a registry id that actually exists.
