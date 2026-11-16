# What's the Art of the Possible with CoCo?

**Virtual hands-on lab -- December 2, 2026, 12:00-2:00 p.m. ET**
Part 2 of *I Downloaded CoCo Desktop... Now What?*

Speakers: **Rick Michaud**, Senior Solution Engineer, Snowflake, and
**Caleb Alexander**, Account Engineer, Snowflake.

You have installed CoCo Desktop and learned your way around. This session is
about making it part of everyday work: framing multi-step tasks, giving useful
context, shaping output for a specific audience, checking results before you
use them, and saving what you learned so the next task starts ahead.

It is for analysts, data engineers, developers, data scientists, AI engineers and
other Snowflake practitioners.

## Start here

| | |
|---|---|
| **[EVENT_GUIDE.md](EVENT_GUIDE.md)** | The session, step by step: schedule, prework, every prompt, and what "done" looks like. Works live or on demand. |
| **[presentation/index.html](presentation/index.html)** | The slides. One self-contained file -- download it and open it in a browser. Arrow keys to move, `D` for light/dark, `G` for the slide grid. |
| **[docs/PREREQUISITES.html](docs/PREREQUISITES.html)** | Detailed setup for macOS, Windows and Linux, including administrator steps. |
| **[LABS.md](LABS.md)** | All 26 labs grouped by track for continued practice, including Lab 12 diagramming. |
| **[templates/PROJECT_CONTEXT.md](templates/PROJECT_CONTEXT.md)** | The reusable project note you finish the session with. |

## What we do in two hours

| Time (ET) | Activity |
|---|---|
| 12:00 | Welcome, the possibilities by role, readiness check |
| 12:20 | **Lab 10 checkpoint** -- research a question and check the evidence |
| 12:30 | **Lab 11** -- explore an unfamiliar schema, define the metric, explain it for an audience |
| 1:00 | **Lab 41 checkpoint** -- build and open a small Streamlit app |
| 1:30 | **Lab 62 checkpoint** -- read cost evidence and propose a guardrail |
| 1:43 | Save reusable context, clean up, Q&A |

That is one full core lab and three focused checkpoints. Times are guidance.

## What you need

- **CoCo Desktop**, installed, signed in and working (macOS or Windows). Linux
  users can follow along with the CoCo CLI or VS Code; see the prerequisites.
- **An approved, non-production Snowflake account** -- sandbox, dev or trial --
  and a role that can create a database and a warehouse, or access an
  administrator has provisioned. Do not use production.
- **This repository**, downloaded (*Code* > *Download ZIP*) and opened as a
  project in CoCo Desktop.
- About 20-30 minutes of prework, described in the
  [event guide](EVENT_GUIDE.md#before-the-session-prework-about-20-30-minutes).

Can't get access in time? Watch along. Everything is written down so you can
do it afterwards.

## What it creates and costs

The live data labs use disposable synthetic data under `COCO_WS_..._<your_user>`
with an XSMALL warehouse configured to suspend after 60 seconds. The expanded
catalog also includes research, local-only, design-only and workspace exercises:
follow each guide's setup and cleanup rather than running every SQL script.

CoCo inference, warehouse compute and other resources can incur charges. Lab 42
is a substantial stretch project with elevated privileges and resources that
can continue billing while idle. Lab 74's workspace files and local skills,
plugins and MCP registrations require their own cleanup; shared SQL cleanup is
not universal. Do not paste credentials or sensitive production data into prompts.

## Curated webinar and next steps

The live selection below is unchanged. The **[full catalog](LABS.md)** adds all
remaining labs for after the session. Start with **[Lab 12 -- generate ER and
data-flow diagrams](labs/12-generate-diagrams/README.md)** if you want a visual
follow-up to schema exploration (about 20 minutes, guidance; Desktop recommended).

| # | Lab | In the session | Desktop |
|---|---|---|---|
| 10 | [Answer architecture, technology and feature questions](labs/10-ask-architecture-questions/) | Checkpoint (Steps 1-2) | Yes |
| 11 | [Explore a schema you have never seen](labs/11-explore-unfamiliar-schema/) | Full core | Yes |
| 41 | [Ship a Streamlit app into Snowflake](labs/41-ship-a-streamlit-app/) | Checkpoint (Steps 1-3) | Yes, recommended |
| 62 | [What did today actually cost?](labs/62-cost-and-usage-capstone/) | Checkpoint (Steps 5-6) | Yes |
| 21 | [Build a pipeline from a plain-English spec](labs/21-build-a-pipeline/) | Take-home | Yes |
| 61 | [Fix a deliberately bad query](labs/61-fix-a-slow-query/) | Take-home | Yes |
| 71 | [Turn a recurring task into a reusable skill](labs/71-author-a-coco-skill/) | Take-home | Desktop only |

Run one lab's setup at a time. Two setups running together as the same user can
interfere with each other.

## Repository layout

```
EVENT_GUIDE.md      the live session, step by step
FACILITATION.md     run-of-show, polls and co-host notes for the hosts
LABS.md             full 26-lab catalog grouped by track
presentation/       the slides (self-contained HTML)
labs/               all lab guides and their required SQL, templates and fixtures
shared/             prerequisite checks, admin role setup, shared setup/cleanup
templates/          PROJECT_CONTEXT.md starter
docs/               prerequisites and reference links
tools/              catalog generator and repository/deck self-checks
```

## Maintain the catalog

After adding or changing a lab's README metadata, run:

```bash
python3 tools/build_catalog.py
python3 tools/build_catalog.py --check
python3 tools/check_repo.py
node tools/check_deck.js
```

These are local content checks, not live Snowflake validation.

## Status

These are workshop materials, provided as-is for learning. They are not a
Snowflake product, and product features, limits and pricing may change -- the
[Snowflake documentation](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code)
is authoritative.
