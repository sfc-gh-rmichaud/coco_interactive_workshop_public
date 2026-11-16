#!/usr/bin/env python3
"""Self-checks for the public workshop repository. Standard library only.

    python3 tools/check_repo.py

Checks:
  * every relative link in Markdown and HTML points at a file that exists
    (and, for links into EVENT_GUIDE.md, at a heading that exists);
  * the EVENT_GUIDE.md schedule adds up to exactly 120 minutes;
  * nothing private or internal has crept in: credentials, meeting passcodes,
    personalised meeting links, absolute local paths, internal-only files,
    or verification files that belong to the source workshop.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SKIP_DIRS = {".git", ".snowflake", "node_modules", "__pycache__"}

LINK_MD = re.compile(r"(?<!!)\[[^\]]*\]\(([^)\s]+)\)")
LINK_HTML = re.compile(r"""(?:href|src)\s*=\s*["']([^"'#][^"']*|#[^"']*)["']""")

FORBIDDEN = [
    (re.compile(r"zoom\.us/(?:w|j|webinar)/", re.I), "personalised meeting link"),
    (re.compile(r"\bpass\s?code\b\s*[:=]?\s*\d{4,}", re.I), "meeting passcode"),
    (re.compile(r"\b(?:webinar|participant)\s+id\b", re.I), "meeting identifier"),
    (re.compile(r"/Users/[A-Za-z]|C:\\\\Users\\\\", re.I), "absolute local path"),
    (re.compile(r"-----BEGIN [A-Z ]*PRIVATE KEY-----"), "private key"),
    (re.compile(r"\b(?:gh[pousr]_[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16})\b"), "access token"),
    (re.compile(r"password\s*=\s*['\"][^'\"]+['\"]", re.I), "hard-coded password"),
    (re.compile(r"snowhouse|snowflake-corp|lift\.snowflake\.com|glean", re.I), "internal reference"),
]
FORBIDDEN_FILES = [re.compile(p) for p in (r"\.eml$", r"(^|/)claims\.sql$", r"branding\.js$",
                                           r"speaker-notes\.js$", r"(^|/)customers/", r"\.pdf$")]


def files() -> list[Path]:
    out = []
    for p in ROOT.rglob("*"):
        if p.is_file() and not any(part in SKIP_DIRS for part in p.relative_to(ROOT).parts):
            out.append(p)
    return sorted(out)


def slug(heading: str) -> str:
    """GitHub's heading anchor: lowercase, drop punctuation, spaces to hyphens."""
    s = heading.strip().lower()
    s = re.sub(r"[^\w\- ]", "", s)
    return s.replace(" ", "-")


def anchors(md: Path) -> set[str]:
    return {slug(m.group(1)) for m in re.finditer(r"^#{1,6}\s+(.+)$", md.read_text(), re.M)}


def check_links(errors: list[str]) -> None:
    for f in files():
        if f.suffix not in {".md", ".html"}:
            continue
        text = f.read_text(errors="replace")
        pattern = LINK_MD if f.suffix == ".md" else LINK_HTML
        for m in pattern.finditer(text):
            target = m.group(1)
            if re.match(r"^(https?:|mailto:|tel:|data:|\$\{|javascript:)", target) or "${" in target:
                continue
            path, _, frag = target.partition("#")
            dest = (f.parent / path).resolve() if path else f
            if not dest.exists():
                errors.append(f"{f.relative_to(ROOT)}: broken link -> {target}")
                continue
            if frag and dest.suffix == ".md" and frag not in anchors(dest):
                errors.append(f"{f.relative_to(ROOT)}: missing anchor -> {target}")


def check_schedule(errors: list[str]) -> None:
    guide = (ROOT / "EVENT_GUIDE.md").read_text()
    section = guide.split("## Schedule", 1)[1].split("\n## ", 1)[0]
    minutes = [int(m.group(1)) for m in re.finditer(r"^\| [0-9:]+ \| (\d+) \|", section, re.M)]
    if sum(minutes) != 120:
        errors.append(f"EVENT_GUIDE.md schedule totals {sum(minutes)} minutes, expected 120")


def check_privacy(errors: list[str]) -> None:
    for f in files():
        rel = f.relative_to(ROOT).as_posix()
        if any(p.search(rel) for p in FORBIDDEN_FILES):
            errors.append(f"{rel}: file type must not be published")
            continue
        if f.suffix in {".png", ".jpg", ".jpeg"}:
            continue
        text = f.read_text(errors="replace")
        for pattern, label in FORBIDDEN:
            if rel == "tools/check_repo.py":
                break
            if pattern.search(text):
                errors.append(f"{rel}: {label}")


def main() -> int:
    errors: list[str] = []
    check_links(errors)
    check_schedule(errors)
    check_privacy(errors)
    for e in errors:
        print("FAIL", e)
    print(f"{len(files())} files checked, {len(errors)} problems")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
