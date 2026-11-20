#!/usr/bin/env python3
"""Render the attendee and host guides as self-contained HTML. Standard library only.

    python3 tools/build_html_docs.py           # write docs/html/*.html
    python3 tools/build_html_docs.py --check   # exit 1 if any page is stale

The Markdown stays the source of truth -- it is what GitHub shows and what CoCo
reads as project context. These pages exist so the same content can be opened
from a download in a browser, styled like the slides, with a copy button on
every prompt. They are generated, so edit the Markdown and re-run this.

Only the Markdown these guides actually use is supported: ATX headings, fenced
code, pipe tables, nested ordered/unordered lists, blockquotes, paragraphs, and
inline code, bold, italic and links. Anything else renders as plain paragraph
text rather than failing, which check_repo's link check will usually surface.
"""

from __future__ import annotations

import html
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "docs" / "html"
# Source file -> page title. Links between these become links between the pages.
PAGES = {
    "EVENT_GUIDE.md": "Live guide",
    "FACILITATION.md": "Facilitation notes",
    "README.md": "Overview",
}
UP = "../../"  # docs/html/ back to the repository root


def slug(heading: str) -> str:
    """GitHub's heading anchor, matching tools/check_repo.py."""
    s = re.sub(r"[^\w\- ]", "", heading.strip().lower())
    return s.replace(" ", "-")


def plain(md: str) -> str:
    """Heading text as GitHub sees it for anchors: markup stripped."""
    md = re.sub(r"\[([^\]]*)\]\([^)]*\)", r"\1", md)
    return re.sub(r"[`*_]", "", md)


def href(target: str) -> str:
    if re.match(r"^(https?:|mailto:|#)", target):
        return target
    path, hashmark, frag = target.partition("#")
    if path in PAGES:
        return path[:-3] + ".html" + hashmark + frag
    if path == "docs/html/README.html":
        return "README.html"
    return UP + path + hashmark + frag


def inline(text: str) -> str:
    """Code spans first, so their contents are never treated as markup."""
    parts = re.split(r"(`[^`]+`)", text)
    out = []
    for part in parts:
        if part.startswith("`") and part.endswith("`") and len(part) > 1:
            out.append("<code>" + html.escape(part[1:-1]) + "</code>")
            continue
        s = html.escape(part, quote=False)
        s = re.sub(r"\[([^\]]+)\]\(([^)\s]+)\)",
                   lambda m: f'<a href="{html.escape(href(html.unescape(m.group(2))))}">{m.group(1)}</a>', s)
        s = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", s)
        s = re.sub(r"(?<![\w*])\*(?!\s)(.+?)(?<!\s)\*(?![\w*])", r"<em>\1</em>", s)
        out.append(s)
    # Inline code inside link text was split out above; re-join and let links span it.
    joined = "".join(out)
    return re.sub(r"\[(.+?)\]\(([^)\s]+)\)",
                  lambda m: f'<a href="{html.escape(href(html.unescape(m.group(2))))}">{m.group(1)}</a>', joined)


def cells(row: str) -> list[str]:
    return [c.strip() for c in row.strip().strip("|").split("|")]


LIST_ITEM = re.compile(r"^(\s*)([-*]|\d+\.)\s+(.*)$")


def blocks(lines: list[str]) -> str:
    out: list[str] = []
    i = 0
    while i < len(lines):
        line = lines[i]
        if not line.strip():
            i += 1
            continue
        if line.lstrip().startswith("```"):
            lang = line.strip()[3:].strip()
            body = []
            i += 1
            while i < len(lines) and not lines[i].lstrip().startswith("```"):
                body.append(lines[i])
                i += 1
            i += 1
            cls = f' class="lang-{html.escape(lang)}"' if lang else ""
            out.append(f'<div class="code"><button class="copy" type="button">Copy</button>'
                       f'<pre><code{cls}>{html.escape(chr(10).join(body))}</code></pre></div>')
            continue
        m = re.match(r"^(#{1,6})\s+(.+)$", line)
        if m:
            level, text = len(m.group(1)), m.group(2).strip()
            out.append(f'<h{level} id="{slug(plain(text))}">{inline(text)}</h{level}>')
            i += 1
            continue
        if line.lstrip().startswith("|") and i + 1 < len(lines) and re.match(r"^\s*\|[\s:|-]+\|\s*$", lines[i + 1]):
            head = cells(line)
            i += 2
            rows = []
            while i < len(lines) and lines[i].lstrip().startswith("|"):
                rows.append(cells(lines[i]))
                i += 1
            th = "".join(f"<th>{inline(c)}</th>" for c in head)
            tb = "".join("<tr>" + "".join(f"<td>{inline(c)}</td>" for c in r) + "</tr>" for r in rows)
            out.append(f'<div class="table"><table><thead><tr>{th}</tr></thead><tbody>{tb}</tbody></table></div>')
            continue
        if line.startswith(">"):
            quote = []
            while i < len(lines) and lines[i].startswith(">"):
                quote.append(re.sub(r"^> ?", "", lines[i]))
                i += 1
            out.append(f"<blockquote>{blocks(quote)}</blockquote>")
            continue
        m = LIST_ITEM.match(line)
        if m:
            indent = len(m.group(1))
            ordered = m.group(2)[0].isdigit()
            items: list[list[str]] = []
            while i < len(lines):
                m2 = LIST_ITEM.match(lines[i])
                if m2 and len(m2.group(1)) == indent and m2.group(2)[0].isdigit() == ordered:
                    content_col = len(lines[i]) - len(m2.group(3))
                    items.append([m2.group(3)])
                    i += 1
                    # Continuation: blank lines, or lines indented past the marker.
                    while i < len(lines):
                        nxt = lines[i]
                        if not nxt.strip():
                            j = i + 1
                            while j < len(lines) and not lines[j].strip():
                                j += 1
                            if j < len(lines) and len(lines[j]) - len(lines[j].lstrip()) > indent:
                                items[-1].append("")
                                i += 1
                                continue
                            break
                        if len(nxt) - len(nxt.lstrip()) > indent:
                            items[-1].append(nxt[min(content_col, len(nxt) - len(nxt.lstrip())):])
                            i += 1
                            continue
                        break
                    while i < len(lines) and not lines[i].strip():
                        j = i + 1
                        while j < len(lines) and not lines[j].strip():
                            j += 1
                        m3 = LIST_ITEM.match(lines[j]) if j < len(lines) else None
                        if m3 and len(m3.group(1)) == indent:
                            i = j
                        break
                    continue
                break
            tag = "ol" if ordered else "ul"
            lis = []
            for item in items:
                first, rest = item[0], item[1:]
                body = inline(first)
                # Plain continuation lines belong to the first paragraph.
                k = 0
                while k < len(rest) and rest[k].strip() and not re.match(r"^\s*(```|\||[-*] |\d+\. |>)", rest[k]):
                    body += " " + inline(rest[k].strip())
                    k += 1
                lis.append(f"<li>{body}{blocks(rest[k:])}</li>")
            out.append(f"<{tag}>{''.join(lis)}</{tag}>")
            continue
        para = []
        while i < len(lines) and lines[i].strip() and not re.match(r"^\s*(```|#{1,6}\s|>|\|)", lines[i]) \
                and not LIST_ITEM.match(lines[i]):
            para.append(lines[i].strip())
            i += 1
        out.append(f"<p>{inline(' '.join(para))}</p>")
    return "\n".join(out)


STYLE = """
:root{--accent:#08769a;--orange:#a95716;--radius:16px}
:root[data-theme=light]{--bg:#f4f9fc;--page:radial-gradient(circle at 85% 4%,#d9f1fa 0,transparent 38%),linear-gradient(145deg,#fbfdff,#eaf5fb 65%,#f4f9fc);
 --card:#fff;--bg3:#e8f5fa;--fg:#102b42;--dim:#496479;--line:#c4dbe7;--ink:#08769a;--tag:#d4f0f8;--aside:#704014;--shadow:0 18px 36px #1e526616}
:root[data-theme=dark]{--bg:#0b1c2b;--page:radial-gradient(circle at 85% 4%,#12405a 0,transparent 40%),linear-gradient(145deg,#0d2235,#0a1a28 65%,#0b1c2b);
 --card:#12293d;--bg3:#173550;--fg:#eaf5fb;--dim:#a9c3d4;--line:#24465f;--ink:#5cc8ee;--tag:#134a63;--aside:#f0b47d;--orange:#e08a45;--shadow:0 18px 36px rgba(0,0,0,.35)}
*{box-sizing:border-box}
html{scroll-padding-top:4.5rem}
body{margin:0;background:var(--bg);background-image:var(--page);background-attachment:fixed;color:var(--fg);
 font:16px/1.6 Inter,-apple-system,BlinkMacSystemFont,"Segoe UI",system-ui,sans-serif;-webkit-font-smoothing:antialiased}
header.top{position:sticky;top:0;z-index:5;display:flex;align-items:center;gap:1rem;padding:.7rem 1.5rem;
 background:color-mix(in srgb,var(--bg) 88%,transparent);backdrop-filter:blur(8px);border-bottom:1px solid var(--line)}
header.top .brand{font-weight:800;letter-spacing:.14em;text-transform:uppercase;font-size:.75rem;color:var(--ink)}
header.top nav{display:flex;gap:.4rem;flex-wrap:wrap}
header.top nav a{color:var(--fg);text-decoration:none;padding:.3rem .75rem;border-radius:999px;font-size:.88rem;border:1px solid transparent}
header.top nav a:hover{border-color:var(--line)}
header.top nav a.on{background:var(--tag);color:var(--fg);font-weight:650}
header.top .spacer{flex:1}
button{font:inherit;cursor:pointer;color:var(--fg);background:var(--bg3);border:1px solid var(--line);border-radius:9px;padding:.32rem .7rem;font-size:.82rem}
button:hover{border-color:var(--ink);color:var(--ink)}
.layout{display:grid;grid-template-columns:240px minmax(0,1fr);gap:2.4rem;max-width:1240px;margin:0 auto;padding:2rem 1.5rem 5rem}
aside.toc{position:sticky;top:4.6rem;align-self:start;max-height:calc(100vh - 6rem);overflow:auto;font-size:.86rem}
aside.toc p{margin:0 0 .5rem;font-weight:800;letter-spacing:.14em;text-transform:uppercase;font-size:.7rem;color:var(--ink)}
aside.toc a{display:block;color:var(--dim);text-decoration:none;padding:.22rem 0 .22rem .7rem;border-left:2px solid var(--line);line-height:1.35}
aside.toc a.sub{padding-left:1.4rem;font-size:.82rem}
aside.toc a:hover{color:var(--fg);border-left-color:var(--ink)}
main{min-width:0}
main h1{font-size:clamp(2rem,4vw,3rem);line-height:1.05;letter-spacing:-.045em;margin:.2rem 0 1rem}
main h2{font-size:clamp(1.45rem,2.6vw,2rem);line-height:1.1;letter-spacing:-.03em;margin:2.6rem 0 .8rem;padding-top:1.4rem;border-top:1px solid var(--line)}
main h3{font-size:1.2rem;margin:1.8rem 0 .5rem}
main a{color:var(--ink);text-underline-offset:4px;overflow-wrap:anywhere}
p,li{max-width:78ch}
ul,ol{padding-left:1.4rem}li{margin:.35rem 0}
code{font-family:ui-monospace,SFMono-Regular,Menlo,monospace;font-size:.86em;background:var(--bg3);border:1px solid var(--line);border-radius:5px;padding:.08em .35em}
.code{position:relative;margin:1rem 0;max-width:90ch}
.code pre{margin:0;background:var(--card);border:1px solid var(--line);border-left:4px solid var(--ink);border-radius:12px;
 padding:1rem 1.1rem;overflow:auto;box-shadow:var(--shadow);font-size:.88rem;line-height:1.5}
.code pre code{background:none;border:0;padding:0;font-size:inherit;white-space:pre-wrap}
.code .copy{position:absolute;top:.5rem;right:.5rem;opacity:.85}
.table{overflow-x:auto;margin:1rem 0;background:var(--card);border:1px solid var(--line);border-radius:var(--radius);box-shadow:var(--shadow)}
table{border-collapse:collapse;width:100%;font-size:.92rem}
th,td{text-align:left;padding:.6rem .85rem;border-bottom:1px solid var(--line);vertical-align:top}
th{background:var(--bg3);font-weight:700}
tr:last-child td{border-bottom:0}
blockquote{margin:1.2rem 0;border-left:4px solid var(--orange);padding:.3rem 0 .3rem 1.2rem;color:var(--aside)}
blockquote p{margin:.3rem 0}
footer.gen{margin-top:3rem;color:var(--dim);font-size:.82rem}
@media (max-width:900px){.layout{grid-template-columns:1fr}aside.toc{display:none}}
@media print{header.top,aside.toc,.copy{display:none}.layout{display:block}body{background:#fff}}
"""

SCRIPT = """
(function(){
  var k='coco-docs-theme',r=document.documentElement;
  try{var t=localStorage.getItem(k);if(t==='dark'||t==='light')r.setAttribute('data-theme',t);}catch(e){}
  document.getElementById('theme').addEventListener('click',function(){
    var t=r.getAttribute('data-theme')==='dark'?'light':'dark';r.setAttribute('data-theme',t);
    try{localStorage.setItem(k,t);}catch(e){}
  });
  document.querySelectorAll('.copy').forEach(function(b){
    b.addEventListener('click',function(){
      var txt=b.parentNode.querySelector('code').innerText;
      function done(){b.textContent='Copied';setTimeout(function(){b.textContent='Copy';},1400);}
      if(navigator.clipboard&&window.isSecureContext){navigator.clipboard.writeText(txt).then(done);}
      else{var a=document.createElement('textarea');a.value=txt;document.body.appendChild(a);a.select();
        try{document.execCommand('copy');done();}catch(e){}document.body.removeChild(a);}
    });
  });
})();
"""


def page(source: str) -> str:
    md = (ROOT / source).read_text()
    body = blocks(md.splitlines())
    toc = []
    for m in re.finditer(r'<h([23]) id="([^"]+)">(.*?)</h\1>', body):
        text = re.sub(r"<[^>]+>", "", m.group(3))
        toc.append(f'<a{" class=\"sub\"" if m.group(1) == "3" else ""} href="#{m.group(2)}">{text}</a>')
    nav = "".join(f'<a{" class=\"on\"" if s == source else ""} href="{s[:-3]}.html">{t}</a>' for s, t in PAGES.items())
    nav += f'<a href="{UP}presentation/index.html">Slides</a>'
    title = html.escape(PAGES[source])
    return f"""<!DOCTYPE html>
<html lang="en" data-theme="light">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>{title} -- What's the Art of the Possible with CoCo?</title>
<style>{STYLE}</style>
</head>
<body>
<header class="top"><span class="brand">CoCo &middot; Dec 2</span><nav>{nav}</nav><span class="spacer"></span>
<button id="theme" type="button" title="Light / dark">Theme</button></header>
<div class="layout">
<aside class="toc"><p>On this page</p>{''.join(toc)}</aside>
<main>
{body}
<footer class="gen">Generated from <code>{html.escape(source)}</code> by <code>tools/build_html_docs.py</code>. Edit the Markdown, then re-run it.</footer>
</main>
</div>
<script>{SCRIPT}</script>
</body>
</html>
"""


def render_all() -> dict[Path, str]:
    return {OUT / (s[:-3] + ".html"): page(s) for s in PAGES}


def main() -> int:
    pages = render_all()
    if "--check" in sys.argv:
        stale = [p for p, text in pages.items() if not p.exists() or p.read_text() != text]
        for p in stale:
            print(f"{p.relative_to(ROOT)} is stale: run python3 tools/build_html_docs.py")
        return 1 if stale else 0
    OUT.mkdir(parents=True, exist_ok=True)
    for p, text in pages.items():
        p.write_text(text)
    print(f"Wrote {len(pages)} pages to {OUT.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
