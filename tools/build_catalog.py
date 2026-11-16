#!/usr/bin/env python3
"""Build LABS.md from lab README metadata and labs/tracks.json. No account access."""
import argparse
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "LABS.md"


def discover(root=ROOT):
    labs = []
    for readme in sorted((root / "labs").glob("[0-9][0-9]-*/README.md")):
        text = readme.read_text()
        metadata = dict(re.findall(r"^\|\s*\*\*(.+?)\*\*\s*\|\s*(.+?)\s*\|\s*$", text, re.M))
        title = re.search(r"^# (.+)$", text, re.M).group(1)
        labs.append({"id": readme.parent.name[:2], "folder": readme.parent.name,
                     "title": re.sub(r"^Lab\s*\d+\s*--\s*", "", title), "meta": metadata})
    return labs


def render(root=ROOT):
    config = json.loads((root / "labs/tracks.json").read_text())
    labs = discover(root)
    tracks = config["tracks"]
    assert all(lab["meta"]["Track"] in {track["id"] for track in tracks} for lab in labs)
    lines = ["# Full lab catalog", "",
             f"**{len(labs)} labs across {len(tracks)} tracks.** All are included for continued practice after the webinar.", "",
             "The two-hour [live guide](EVENT_GUIDE.md) remains curated: **10, 11, 41 and 62**.",
             "The original next-step recommendations (**21, 61, 71**) are still highlighted below.",
             "**Lab 12 -- diagramming** is also included: turn schema metadata into ER and data-flow diagrams, then export a shareable artifact.", "",
             "## Before choosing a lab", "",
             "- All duration estimates below are **guidance for the full lab**, not extra time in the webinar.",
             "- Read the lab's prerequisites, supported surface and cleanup before starting; Desktop is not the right surface for every lab.",
             "- Data labs use disposable sample resources. Run only the setup required by your chosen guide.",
             "- Lab 10 is research-only. Lab 74 works in a private Snowsight workspace and has separate file cleanup.",
             "- **Lab 42 is a 90-120 minute stretch project**, with elevated privileges, feature-availability restrictions and resources that can keep billing while idle. Read its warnings first.",
             "- Follow each lab's cleanup. Shared SQL cleanup does not remove local extensions, workspace files or all administrative resources.",
             "- Inclusion is not a claim of live validation on your account or installed build. Check feature access and permissions; record incomplete steps honestly.", ""]
    for track in tracks:
        lines.extend([f"## {track['label']}", "", track["blurb"], "",
                      "| Lab | Exercise | Full-lab time (guidance) | Session role |",
                      "|---|---|---|---|"])
        members = sorted([lab for lab in labs if lab["meta"]["Track"] == track["id"]],
                         key=lambda lab: (int(lab["meta"].get("Sequence", "999")), lab["id"]))
        for lab in members:
            role = "Live core" if lab["id"] == "11" else "Live checkpoint" if lab["id"] in config["recommended_path"] else "Curated take-home" if lab["id"] in config["curated_take_home"] else "Take-home"
            if lab["id"] == "12":
                role += " - diagramming"
            if lab["meta"].get("Stretch") == "yes":
                role = "Take-home stretch"
            duration = lab["meta"].get("Time", "See guide").replace("|", "&#124;")
            if lab["id"] == "42":
                duration = "90-120 minutes"
            lines.append(f"| {lab['id']} | [{lab['title']}](labs/{lab['folder']}/README.md) | {duration} | {role} |")
        lines.append("")
    return "\n".join(lines)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Fail if the catalog is stale; do not write files")
    args = parser.parse_args()
    content = render()
    if args.check:
        if not OUT.exists() or OUT.read_text() != content:
            raise SystemExit("LABS.md is stale: run python3 tools/build_catalog.py")
        print(f"Catalog current: {len(discover())} labs")
    else:
        OUT.write_text(content)
        print(f"Wrote catalog: {len(discover())} labs")
