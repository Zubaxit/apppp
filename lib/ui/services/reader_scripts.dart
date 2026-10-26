/// JavaScript that runs inside the publisher's page.
///
/// Two jobs, both read-only: find the readable article, and report what the
/// user selected. Nothing here writes to the page, removes nodes, injects
/// styles into the publisher's document, hides adverts or touches a paywall —
/// the page is left exactly as the publisher served it. Extraction happens in
/// the page because the DOM is already parsed there, which avoids shipping the
/// HTML over the platform channel and avoids a second request.
class ReaderScripts {
  const ReaderScripts._();

  /// The channel the page posts selection changes to.
  static const String channel = 'AmarNews';

  /// Small helper library, installed before anything else is called.
  static const String installGlobals = r"""
(function () {
  if (window.__amarReader) return 'ready';
  var BLOCKED = /(^|[\s_-])(ad|ads|advert|advertisement|promo|sponsor|related|recommend|mostread|popular|newsletter|subscribe|paywall|cookie|consent|share|social|comment|footer|sidebar|nav|menu|breadcrumb|tags|outbrain|taboola)([\s_-]|$)/i;

  function blocked(el) {
    for (var node = el; node && node.nodeType === 1; node = node.parentElement) {
      var name = (node.tagName || '').toLowerCase();
      if (name === 'nav' || name === 'aside' || name === 'footer' || name === 'form') return true;
      var tag = node.getAttribute('class') || '';
      var id = node.getAttribute('id') || '';
      if (BLOCKED.test(tag) || BLOCKED.test(id)) return true;
      if (node.getAttribute('role') === 'navigation' || node.getAttribute('aria-hidden') === 'true') return true;
    }
    return false;
  }

  function text(el) {
    return (el.innerText || el.textContent || '').replace(/\s+/g, ' ').trim();
  }

  function meta(names) {
    var list = names.split(',');
    for (var i = 0; i < list.length; i++) {
      var el = document.querySelector('meta[property="' + list[i] + '"], meta[name="' + list[i] + '"]');
      if (el) {
        var value = el.getAttribute('content');
        if (value) return value.trim();
      }
    }
    return '';
  }

  function firstText(selectors) {
    for (var i = 0; i < selectors.length; i++) {
      var el = document.querySelector(selectors[i]);
      if (el) {
        var value = text(el);
        if (value) return value;
      }
    }
    return '';
  }

  /// Candidate containers, best first. A publisher's own markup wins over the
  /// generic guess, and the <article> element is the usual correct answer.
  function containers() {
    return [
      'article [itemprop="articleBody"]',
      '[itemprop="articleBody"]',
      'article',
      '.article-body',
      '.articleBody',
      '.story-body',
      '.post-content',
      '.entry-content',
      '.content-body',
      '#article-body',
      '#content',
      'main'
    ];
  }

  /// Scores a container by how much real prose it holds in direct children.
  /// This is what stops a page of teaser links from being read as an article.
  function score(el) {
    var total = 0;
    var paragraphs = el.querySelectorAll('p, h2, h3, blockquote, li');
    for (var i = 0; i < paragraphs.length; i++) {
      var value = text(paragraphs[i]);
      if (value.length > 40 && !blocked(paragraphs[i])) total += Math.min(value.length, 400);
    }
    return total;
  }

  function pick() {
    var list = containers();
    var best = null;
    var bestScore = 0;
    for (var i = 0; i < list.length; i++) {
      var nodes = document.querySelectorAll(list[i]);
      for (var j = 0; j < nodes.length; j++) {
        var value = score(nodes[j]);
        if (value > bestScore) {
          bestScore = value;
          best = nodes[j];
        }
      }
      if (bestScore > 1200 && i < 3) break;
    }
    return best;
  }

  function paragraphs(root) {
    var out = [];
    var seen = {};
    var nodes = root.querySelectorAll('p, h2, h3, blockquote, figure');
    for (var i = 0; i < nodes.length; i++) {
      var node = nodes[i];
      if (blocked(node)) continue;
      if ((node.tagName || '').toLowerCase() === 'figure') {
        var img = node.querySelector('img');
        if (img) {
          var src = img.currentSrc || img.src || img.getAttribute('data-src') || '';
          if (/^https:\/\//i.test(src) && !seen[src]) {
            seen[src] = 1;
            var caption = node.querySelector('figcaption');
            out.push({ image: src, text: caption ? text(caption) : (img.alt || '') });
          }
        }
        continue;
      }
      var value = text(node);
      if (value.length < 30) continue;
      if (seen[value]) continue;
      seen[value] = 1;
      out.push({ text: value, heading: /^h[23]$/i.test(node.tagName) });
      if (out.length >= 400) break;
    }
    return out;
  }

  window.__amarReader = {
    blocked: blocked,
    text: text,
    meta: meta,
    firstText: firstText,
    pick: pick,
    paragraphs: paragraphs
  };
  return 'ready';
})();
""";

  /// Reads the article. Always returns JSON; `ok:false` carries a reason the UI
  /// can show verbatim instead of pretending extraction worked.
  static const String extract = r"""
(function () {
  try {
    var lib = window.__amarReader;
    if (!lib) return JSON.stringify({ ok: false, error: 'reader not installed' });
    var root = lib.pick();
    if (!root) return JSON.stringify({ ok: false, error: 'no article container' });
    var blocks = lib.paragraphs(root);
    var bodyLength = 0;
    for (var i = 0; i < blocks.length; i++) bodyLength += blocks[i].text.length;
    if (blocks.length < 2 || bodyLength < 200) {
      return JSON.stringify({ ok: false, error: 'not enough article text' });
    }
    var title = lib.meta('og:title,twitter:title') || lib.firstText(['h1', 'article h1', 'header h1']) || document.title || '';
    var byline = lib.meta('article:author,author,og:article:author') ||
      lib.firstText(['[rel="author"]', '.author', '.byline', '[itemprop="author"]']);
    var published = lib.meta('article:published_time,og:updated_time,date,pubdate') ||
      lib.firstText(['time[datetime]', 'time']);
    var site = lib.meta('og:site_name') || location.hostname.replace(/^www\./, '');
    return JSON.stringify({
      ok: true,
      url: location.href,
      title: title,
      byline: byline,
      published: published,
      site: site,
      blocks: blocks
    });
  } catch (e) {
    return JSON.stringify({ ok: false, error: 'extraction error: ' + e });
  }
})();
""";

  /// Reports the current selection, debounced. Sending an empty string on an
  /// emptied selection is how the screen knows to put its action away.
  static const String watchSelection = r"""
(function () {
  if (window.__amarSelection) return 'ready';
  window.__amarSelection = true;
  function post(payload) {
    try {
      if (window.AmarNews && window.AmarNews.postMessage) {
        window.AmarNews.postMessage(JSON.stringify(payload));
      }
    } catch (e) {}
  }
  function clean(value) {
    return (value || '').replace(/\s+/g, ' ').trim().slice(0, 600);
  }
  function report() {
    var selection = window.getSelection ? window.getSelection() : null;
    var value = clean(selection ? String(selection) : '');
    post({ text: value });
  }
  var timer = null;
  document.addEventListener('selectionchange', function () {
    if (timer) clearTimeout(timer);
    timer = setTimeout(report, 80);
  });
  document.addEventListener('touchend', function () { setTimeout(report, 120); }, true);
  return 'ready';
})();
""";
}
