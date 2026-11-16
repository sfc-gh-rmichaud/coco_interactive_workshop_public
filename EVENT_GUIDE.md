# Live guide -- What's the Art of the Possible with CoCo?

**December 2, 2026, 12:00-2:00 p.m. ET** -- virtual hands-on lab, Part 2 of
*I Downloaded CoCo Desktop... Now What?*

This is the step-by-step guide for the session. It works live, from the
recording, or on your own afterwards. Each block says what "done" looks like, so
you always know whether to keep going or move on.

**Scope, honestly:** the two hours cover **one full core lab (11) and three
focused checkpoints (10, 41, 62)** -- not four complete labs. Each lab's full
guide is in `labs/` if you want to finish it later.

## Schedule

All times Eastern and approximate. If we run behind, we cut optional extras --
never verification, cleanup or Q&A.

| Time (ET) | Minutes | Block | Done when |
|---|---|---|---|
| 12:00 | 10 | Welcome, Part 1 bridge, possibilities by role | -- |
| 12:10 | 10 | [Readiness check](#readiness-check-1210) | CoCo answers in chat on an approved connection |
| 12:20 | 10 | [Lab 10 checkpoint](#lab-10-checkpoint-1220----research-a-question) | One answer, one claim you checked, one open question |
| 12:30 | 25 | [Lab 11 core](#lab-11-core-1230----explore-a-schema-you-have-never-seen) | A verified finding, explained for a named audience |
| 12:55 | 5 | Catch-up and stretch | -- |
| 1:00 | 30 | [Lab 41 checkpoint](#lab-41-checkpoint-100----a-small-app) | The app opens and the filter works |
| 1:30 | 13 | [Lab 62 checkpoint](#lab-62-checkpoint-130----what-did-it-cost) | Three findings and one recommended guardrail |
| 1:43 | 8 | [Save context and clean up](#save-context-and-clean-up-143) | `PROJECT_CONTEXT.md` saved; lab objects removed |
| 1:51 | 9 | Q&A and next steps | -- |
| | **120** | | |

## Before the session (prework, about 20-30 minutes)

Do this the day before if you can. Installing during the session costs you the
first lab.

1. **CoCo Desktop** installed, signed in, and working. Part 1 covered this. If
   you are on Linux, Desktop is not available; follow along with the
   [CLI or VS Code route](docs/PREREQUISITES.html).
2. **An approved, non-production Snowflake account.** Use a sandbox, dev or
   trial account you are allowed to use for training. Do not use production. If
   your organisation or the event organizers provide an account, use that.
3. **A role that can create a database and a warehouse**, or access an
   administrator has provisioned for you. Administrators: see
   [`shared/00_admin_role_setup.sql`](shared/00_admin_role_setup.sql), then
   have the attendee run [`shared/01_role_smoke_test.sql`](shared/01_role_smoke_test.sql)
   under their own role.
4. **Download this repository** (green *Code* button, *Download ZIP*, or
   `git clone`) and open the folder as a project in CoCo Desktop.
5. **Check your account** (read-only):
   [`shared/00_prereqs_check.sql`](shared/00_prereqs_check.sql).
6. **Pre-run the setup scripts** so the labs start instantly. Each prints the
   exact object names it created -- keep that output.

   ```bash
   snow sql -f shared/00_workshop_setup.sql -c <your-connection>
   snow sql -f labs/11-explore-unfamiliar-schema/setup.sql -c <your-connection>
   snow sql -f labs/41-ship-a-streamlit-app/setup.sql -c <your-connection>
   snow sql -f labs/62-cost-and-usage-capstone/setup.sql -c <your-connection>
   ```

   No Snowflake CLI? Open each file in a Snowsight worksheet and use *Run All*.
   Run each file top to bottom in one go; they rely on session variables.

The setups create only disposable objects named `COCO_WS_..._<your_user>`, on
synthetic data, with an XSMALL warehouse that suspends after 60 seconds. Running
them uses a small amount of warehouse compute, and using CoCo uses AI credits.

> **Object names.** CoCo runs in its own session, so it cannot see the `$LAB_DB`
> variables in the SQL files. Wherever a prompt below says `<your_user>`, paste
> the real name that setup printed.

## Readiness check (12:10)

In CoCo Desktop, with this repository open as the project, ask:

```text
Which Snowflake account, user and role am I connected as, and which warehouse
is active? Read-only -- do not change anything.
```

**Done when:** the answer names the approved non-production account and your
workshop role. If it names a production account, stop and switch connections.

**Not ready?** Watch along. Every step is in this guide; post your blocker in
chat and the co-host will help or point you to the fix.

## Lab 10 checkpoint (12:20) -- research a question

Full lab: [`labs/10-ask-architecture-questions`](labs/10-ask-architecture-questions/).
Today we do Steps 1-2 only. No SQL, nothing created.

Paste the research boundary first:

```text
For this exercise, act as my Snowflake technical research partner. Research and
advice only: do not run SQL, inspect my account, read local files or change
anything. Use public Snowflake documentation where available. Separate
documented facts, recommendations, assumptions and things not verified. Cite the
specific source for important claims, and never invent a link.
```

Then ask:

```text
What is the difference between Time Travel, Fail-safe and a zero-copy clone?
Explain it using an accidental table deletion as the example. Which questions
would you ask before advising how to recover? Include sources and mark
account-specific details as not verified.
```

Then audit it:

```text
Make a compact evidence table: claim, source URL and section, and whether it is
source inspected, user-supplied, or not verified. Which caveat would most likely
lead me to the wrong choice if I overlooked it?
```

**Open one cited page yourself** and check that the text really supports the
claim.

**Done when:** you have a short answer, one claim you personally checked, and
one question that depends on *your* account (retention, edition, privileges).

## Lab 11 core (12:30) -- explore a schema you have never seen

Full lab: [`labs/11-explore-unfamiliar-schema`](labs/11-explore-unfamiliar-schema/).
We run its Steps 1-4, then add an audience-specific rewrite.

**1. Get oriented, read-only.**

```text
I have just been given access to COCO_WS_LAB11_DB_<your_user>.LAB and I have
never seen it before. Read-only: profile it. What tables and views exist, what
does each represent, how do they join, and roughly how much data is in each?
Flag anything that should not be used for analysis, and say why.
```

Good looks like: lookups, dimensions and facts grouped; join keys identified; a
backup table and a legacy view called out as things to avoid.

**2. Define the metric before computing it.**

```text
Before I calculate any revenue, tell me exactly how to compute it correctly:
which price column is authoritative, what units DISC_PCT is actually stored in
(check real values, do not assume), and which ORD_STAT values count as revenue.
Show the evidence for each.
```

Good looks like: the order-line price, not the current list price; discounts
stored as whole percentages (so `1 - DISC_PCT/100`); cancelled, returned and
pending orders excluded. Including them quietly overstates revenue -- that is
the trap.

**3. Answer the question.**

```text
Across the last eight completed quarters, which product category is growing
fastest, and is any region falling behind? Use the revenue definition we just
agreed. Show the quarterly trend per category and per region.
```

Expected shape: Outdoor & Recreation growing steadily while other categories are
flat; EMEA rising, then dropping sharply in a single quarter. See the full lab
for the documented ranges.

**4. Make it defensible.**

```text
Someone will challenge this number. Write a short verification query that proves
the revenue total, and list the assumptions that would change the answer.
```

**5. Explain it for a specific audience.**

```text
Rewrite the verified finding for a regional sales director: plain language, two
sentences, no SQL, no jargon, and one recommended next question for the
business. Keep every number exactly as verified.
```

Compare it with the analytical version. The facts stay the same; the framing
changes.

**Done when:** you have a verified finding, the assumptions are named, and you
have a two-sentence version for the director.

## Lab 41 checkpoint (1:00) -- a small app

Full lab: [`labs/41-ship-a-streamlit-app`](labs/41-ship-a-streamlit-app/).
Today: Steps 1-3 with a deliberately small screen. Iteration and cost (Steps 4-5)
are take-home.

**1. Find the story first.**

```text
COCO_WS_LAB41_DB_<your_user>.LAB.STORE_PERFORMANCE has 18 months of monthly
retail performance. Something has gone wrong in one region. Find it, quantify
it, and tell me what the operations director needs to see to act.
```

Good looks like: one region's conversion has dropped while footfall is
unchanged, linked to a staffing change. Check how many months are on each side
of the comparison before trusting the delta.

**2. Agree a small screen before any code.**

```text
Design a Streamlit app for the operations director that makes this problem
obvious in five seconds. Keep it to: one chart comparing conversion with staff
hours, a single region filter in the sidebar, and one compact supporting table.
Aggregate in SQL, not Python. Tell me the plan before writing code.
```

**3. Build and deploy.**

```text
Build it and deploy it as a Streamlit app in COCO_WS_LAB41_DB_<your_user>.LAB,
using the existing APP_STAGE stage and the COCO_WS_WH_<your_user> warehouse. Use
the active Snowflake session, never credentials in code. Give me the URL and the
SQL you used to create the app.
```

**Open the URL** and change the region filter.

**Done when:** the app opens and the filter changes the view. A Streamlit object
that does not open is not done. No username or password should appear in the
Python file.

**If deployment is blocked** (privileges, policy, time): keep the agreed screen
design, mark the checkpoint incomplete, and watch the presenter's deployment.

## Lab 62 checkpoint (1:30) -- what did it cost?

Full lab: [`labs/62-cost-and-usage-capstone`](labs/62-cost-and-usage-capstone/).
Today: Step 5 (seeded data) and Step 6 (guardrail). The live-telemetry steps
need extra privileges and lag by up to hours, so they are take-home.

```text
COCO_WS_LAB62_DB_<your_user>.LAB has three seeded tables shaped like the
ACCOUNT_USAGE views: USAGE_SNAPSHOT_QUERIES, USAGE_SNAPSHOT_METERING and
USAGE_SNAPSHOT_COCO. They represent a five-lab workshop session. Find the three
most important things wrong with that session. Keep warehouse credits and CoCo
usage separate.
```

Good looks like: one lab dominating compute, a single runaway query with no
partition pruning, and an idle billed hour. The full lab lists the exact planted
values.

```text
Based on what we found, recommend a cost guardrail for CoCo in this account.
Explain the parameter and its values, give a permissive and a default-closed
option, and show what is currently set. Do not change anything.
```

**Done when:** you have three findings and one recommendation -- with nothing
changed. This is sample data, not your bill for today.

## Save context and clean up (1:43)

**Save a project note you own.** Ask:

```text
Draft PROJECT_CONTEXT.md for this folder from today's session: the revenue
definition we agreed, my preferences for how you work (read-only exploration
first, explain for business readers, show SQL), and the verification checks
that mattered. Keep it under 30 lines. Show it to me before saving.
```

Edit it yourself, then save. Next time, start with: *"Read PROJECT_CONTEXT.md
first and follow it."* That reuse is explicit -- do not assume CoCo remembers
today on its own. A starting template is in
[`templates/PROJECT_CONTEXT.md`](templates/PROJECT_CONTEXT.md).

**Clean up.** Review the names each script prints, then:

```bash
snow sql -f labs/11-explore-unfamiliar-schema/cleanup.sql -c <your-connection>
snow sql -f labs/41-ship-a-streamlit-app/cleanup.sql -c <your-connection>
snow sql -f labs/62-cost-and-usage-capstone/cleanup.sql -c <your-connection>
```

When you have finished every lab you plan to do, the shared cleanup removes
**all** of your `COCO_WS_LABnn_DB_<your_user>` databases, your shared workshop
database and your workshop warehouse:

```bash
snow sql -f shared/99_workshop_cleanup.sql -c <your-connection>
```

If you used this account for earlier CoCo workshops, those lab databases have
the same names and will be dropped too -- check before running it. Shared roles
are left for an administrator.

## After the session

| If you are... | Try next |
|---|---|
| A data engineer | [Lab 21 -- build a pipeline from a plain-English spec](labs/21-build-a-pipeline/) |
| SQL-heavy or performance-minded | [Lab 61 -- fix a deliberately bad query](labs/61-fix-a-slow-query/) |
| Doing the same task repeatedly | [Lab 71 -- turn a recurring task into a reusable skill](labs/71-author-a-coco-skill/) |
| Wanting to finish today's labs | Lab 10 Steps 3-6, Lab 41 Steps 4-5, Lab 62 Steps 1-4 |

**The [full 37-lab catalog](LABS.md) is included for continued practice.** The
live agenda above and the curated recommendations remain unchanged. For a visual
follow-up, try [Lab 12 -- generate ER and data-flow diagrams](labs/12-generate-diagrams/README.md)
(about 20 minutes, guidance; Desktop recommended for the complete exercise).

Read each lab's surface, privileges and lifecycle before starting. Research and
local-only exercises do not need shared SQL setup; workspace and administrative
resources need their documented cleanup. Run data setups one at a time, not in
parallel.
