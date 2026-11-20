# Live guide -- What's the Art of the Possible with CoCo?

**December 2, 2026, 12:00-1:30 p.m. ET** -- virtual hands-on lab, Part 2 of
*I Downloaded CoCo Desktop... Now What?*

This is the step-by-step guide for the session. It works live, from the
recording, or on your own afterwards. Each block says what "done" looks like, so
you always know whether to keep going or move on.

**Scope, honestly:** 90 minutes covers **five focused checkpoints (Labs 10, 11,
21, 31 and 32)** -- not five complete labs, which would take well over two
hours. Each block names the steps we do live; the rest of every lab is in
`labs/` to finish later.

## Schedule

All times Eastern and approximate. If we run behind, we cut a lab's later
steps -- never verification or cleanup. Ask questions in chat at any time.

| Time (ET) | Minutes | Block | Done when |
|---|---|---|---|
| 12:00 | 12 | Welcome, Part 1 bridge, framing a task, guardrails | -- |
| 12:12 | 4 | [Readiness check](#readiness-check-1212) | CoCo answers in chat on an approved connection, as `COCO_WS_USER` |
| 12:16 | 8 | [Lab 10 checkpoint](#lab-10-checkpoint-1216----research-a-question) | One answer, one claim you checked, one open question |
| 12:24 | 15 | [Lab 11 checkpoint](#lab-11-checkpoint-1224----explore-a-schema-you-have-never-seen) | A verified finding and its assumptions |
| 12:39 | 16 | [Lab 21 checkpoint](#lab-21-checkpoint-1239----a-pipeline-from-a-spec) | Three dynamic tables that reconcile, with a lag that actually refreshes |
| 12:55 | 15 | [Lab 31 checkpoint](#lab-31-checkpoint-1255----a-semantic-view) | A semantic view whose MRR totals 4,772,430 |
| 1:10 | 16 | [Lab 32 checkpoint](#lab-32-checkpoint-110----a-cortex-agent) | An agent that names Iberia, citing the SLA document |
| 1:26 | 4 | [Save context and clean up](#save-context-and-clean-up-126) | `PROJECT_CONTEXT.md` saved; lab objects removed |
| | **90** | | |

## Before the session (prework, about 30-40 minutes)

Do this the day before if you can. Setting up during the session costs you the
first labs, and every block below assumes its setup has already run.

### 1. Your administrator creates the workshop role (once)

An account administrator runs
[`shared/00_admin_role_setup.sql`](shared/00_admin_role_setup.sql) as
`ACCOUNTADMIN` in an **approved, non-production** account -- a sandbox, dev or
trial account you are allowed to use for training. Never production.

1. Change `ATTENDEE` to your exact Snowflake user name (names are
   case-sensitive). Never substitute the admin's own user.
2. Run the script down to the `STOP HERE` comment. That creates the role
   `COCO_WS_USER` with:

   | Grant | Why |
   |---|---|
   | `CREATE DATABASE` on the account | Each lab creates its own disposable database |
   | `CREATE WAREHOUSE` on the account | Your own XSMALL workshop warehouse |
   | `SNOWFLAKE.CORTEX_USER` database role | Cortex AI features, Cortex Search and agents |
   | `SNOWFLAKE.COPILOT_USER` database role | CoCo itself |
   | `USE AI FUNCTIONS` on the account | AI functions the labs call |

   and grants the role to your user. It changes no account settings, default
   roles or `PUBLIC` grants.
3. **Leave the optional bundles commented out.** None of today's five labs need
   them; they exist for other labs in the catalog.

Self-service trial? An administrator must add a payment method before AI
features work.

### 2. You check the role works

From here on, **never run as `ACCOUNTADMIN`.** Select `COCO_WS_USER` in **both**
your CoCo Desktop connection and your SQL session (Snowflake CLI or Snowsight).

1. **CoCo Desktop** installed, signed in, and working. Part 1 covered this. If
   you are on Linux, Desktop is not available; follow along with the
   [CLI or VS Code route](docs/PREREQUISITES.html).
2. **Download this repository** (green *Code* button, *Download ZIP*, or
   `git clone`) and open the folder as a project in CoCo Desktop.
3. **Check your account** (read-only):
   [`shared/00_prereqs_check.sql`](shared/00_prereqs_check.sql). Some
   statements fail by design; run them one at a time.
4. **Prove the role can create and drop objects:**
   [`shared/01_role_smoke_test.sql`](shared/01_role_smoke_test.sql). It uses
   unique names and cleans up after itself.

### 3. You pre-run the lab setups

Run these one at a time, not in parallel. Each prints the exact object names it
created -- keep that output.

```bash
snow sql -f shared/00_workshop_setup.sql -c <your-connection>
snow sql -f labs/11-explore-unfamiliar-schema/setup.sql -c <your-connection>
snow sql -f labs/21-build-a-pipeline/setup.sql -c <your-connection>
snow sql -f labs/31-build-a-semantic-view/setup.sql -c <your-connection>
snow sql -f labs/32-cortex-agent/setup.sql -c <your-connection>
```

No Snowflake CLI? Open each file in a Snowsight worksheet and use *Run All*.
Run each file top to bottom in one go; they rely on session variables. Lab 10
needs no setup.

The setups create only disposable objects named `COCO_WS_..._<your_user>`, on
synthetic data, with an XSMALL warehouse that suspends after 60 seconds. Lab
32's setup also creates a Cortex Search service, which keeps consuming
resources until it is dropped -- if the session is more than a day away, run
that setup the morning of. Running setups uses a small amount of warehouse
compute, and using CoCo uses AI credits.

> **Object names.** CoCo runs in its own session, so it cannot see the `$LAB_DB`
> variables in the SQL files. Wherever a prompt below says `<your_user>`, paste
> the real name that setup printed.

## Readiness check (12:12)

In CoCo Desktop, with this repository open as the project, ask:

```text
Which Snowflake account, user and role am I connected as, and which warehouse
is active? Read-only -- do not change anything.
```

**Done when:** the answer names the approved non-production account and the
`COCO_WS_USER` role. If it names a production account or `ACCOUNTADMIN`, stop
and switch connections.

**Not ready?** Watch along. Every step is in this guide; post your blocker in
chat and the co-host will help or point you to the fix.

## Lab 10 checkpoint (12:16) -- research a question

Full lab: [`labs/10-ask-architecture-questions`](labs/10-ask-architecture-questions/).
Today: Steps 1-2 only. No SQL, nothing created.

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

**Open one cited page yourself** and check that the text really supports the
claim.

**Done when:** you have a short answer, one claim you personally checked, and
one question that depends on *your* account (retention, edition, privileges).

**Stretch, if you finish early:**

```text
Make a compact evidence table: claim, source URL and section, and whether it is
source inspected, user-supplied, or not verified. Which caveat would most likely
lead me to the wrong choice if I overlooked it?
```

## Lab 11 checkpoint (12:24) -- explore a schema you have never seen

Full lab: [`labs/11-explore-unfamiliar-schema`](labs/11-explore-unfamiliar-schema/).
Today: Steps 1-3, kept brisk. Making it defensible (Step 4) and the audience
rewrite are stretches.

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

**Done when:** you have a finding computed with the agreed revenue definition.

**Stretch -- make it defensible:**

```text
Someone will challenge this number. Write a short verification query that proves
the revenue total, and list the assumptions that would change the answer.
```

**Stretch -- explain it for a specific audience:**

```text
Rewrite the verified finding for a regional sales director: plain language, two
sentences, no SQL, no jargon, and one recommended next question for the
business. Keep every number exactly as verified.
```

## Lab 21 checkpoint (12:39) -- a pipeline from a spec

Full lab: [`labs/21-build-a-pipeline`](labs/21-build-a-pipeline/).
Today: Steps 1-3. The presenter demos Step 1 (about 2 minutes) -- watch it,
then run Steps 2 and 3 yourself; the Step 2 prompt already names every trap.
Proving the pipeline is incremental (Step 4) is take-home.

**1. Profile the raw data first (presenter demo)** -- do not ask for a pipeline yet.

```text
COCO_WS_LAB21_DB_<your_user>.LAB.RAW_ORDER_EVENTS is a raw landing table of
storefront order events in a VARIANT column. Before we build anything, profile
it and tell me every data quality problem you can find that would break a naive
pipeline. For each one, show me the evidence and the row counts. Be specific
about the payload fields.
```

Good looks like all four traps, with counts: about 2,400 duplicate deliveries
sharing an `event_id`; `occurred_at` in epoch milliseconds on half the rows and
ISO-8601 on the rest; about 1,200 JSON nulls in `customer_id` that `IS NULL`
does not catch; and a nested `items` array. If it finds only two or three, name
the field you suspect and ask it to check the values.

**2. Specify the pipeline, not the SQL.**

```text
Build a three-layer pipeline in COCO_WS_LAB21_DB_<your_user>.LAB using dynamic
tables:

  - Leave RAW_ORDER_EVENTS untouched.
  - A staged layer, one row per event, correctly typed, with duplicates removed
    (keep the most recently ingested copy) and both timestamp formats parsed
    into a single TIMESTAMP_LTZ column.
  - A second staged layer with one row per order line, flattened out of the
    items array.
  - A curated daily aggregate: orders and gross sales by date, channel and
    currency. Only order_placed counts as revenue -- count cancellations and
    refunds separately rather than dropping them.

It must keep up automatically as new events land. Explain your TARGET_LAG
choices before you create anything.
```

Watch for two things. Timestamp parsing needs `TRY_` functions on both arms of
the `CASE`, or the numeric rows fail the whole query. And the idiomatic lag is
`TARGET_LAG = DOWNSTREAM` on the intermediate tables with a concrete lag on the
curated leaf. If it sets `DOWNSTREAM` on *all* of them, do not just correct it
-- ask:

```text
If every table in the chain is TARGET_LAG = DOWNSTREAM, what actually triggers
a refresh?
```

**3. Verify it.**

```text
Prove the pipeline is correct in one verification query: staged row count
versus distinct event_id in raw, the count of NULL parsed timestamps, and the
TARGET_LAG of each dynamic table.
```

**Done when:** staged rows exactly equal `DISTINCT_EVENTS` from setup, zero
timestamps failed to parse, and at least one table has a concrete lag. If
timestamps parsed to 1970, epoch milliseconds were read as seconds.

## Lab 31 checkpoint (12:55) -- a semantic view

Full lab: [`labs/31-build-a-semantic-view`](labs/31-build-a-semantic-view/).
Today: Steps 1-3. The presenter demos Step 1 (about 2 minutes) -- watch for
the grain trap, then run Steps 2 and 3 yourself. A proper evaluation set
(Step 4) is take-home.

**1. Model it, and watch for the trap (presenter demo).**

```text
COCO_WS_LAB31_DB_<your_user>.LAB is a subscription revenue schema. I want a
Snowflake semantic view over it so business users can ask questions in natural
language. Before you write any DDL, explain the grain of each fact table and
tell me what could go wrong when aggregating revenue.
```

Good looks like: `FACT_SUBSCRIPTION` is one row per subscription *version*
(1,144 rows against 900 distinct subscriptions), and `FACT_USAGE` is daily, so
joining it to MRR multiplies revenue. If it starts writing DDL straight away,
stop it:

```text
What is the grain of FACT_SUBSCRIPTION? Prove it with a query before you model it.
```

**2. Build it.**

```text
Build the semantic view. Include synonyms real people would actually type,
comments on everything, and metrics that make the double-counting mistake
impossible rather than merely documented. Explain your decision about
FACT_USAGE.
```

Good looks like a guard *inside* the MRR metric -- for example
`SUM(IFF(subs.IS_CURRENT AND subs.SUB_STATUS='ACTIVE', subs.MRR, 0))` -- not a
comment asking people to remember a filter. `FACT_USAGE` is best left out, or
included only through a pre-aggregated view.

**3. Query it as a business user would.**

```text
Query the semantic view to answer: what is our current MRR by plan tier? Show
the total.
```

Take-home: also break it down by customer segment, and prove the semantic view
agrees with an equivalent query written directly against the tables.

**Done when:** the tier breakdown totals exactly **4,772,430**. If it totals
7,013,085, the guard is missing.

## Lab 32 checkpoint (1:10) -- a Cortex Agent

Full lab: [`labs/32-cortex-agent`](labs/32-cortex-agent/).
Today: Steps 1-3. The presenter demos Step 1 (about 2 minutes) -- start the
Step 2 prompt as soon as it ends, since the build is the longest part. Trying
to break the agent (Step 4) is take-home.

**1. Establish that neither half is enough (presenter demo).**

```text
COCO_WS_LAB32_DB_<your_user>.LAB has a support ticket table and a set of policy
documents. I want to know which regions breached our support SLA. Can you
answer that from SUPPORT_TICKETS alone? Explain precisely what is missing.
```

Good looks like: the table has resolution times but no targets, so "breach" is
undefined without the policy. If it invents a target ("assuming a 24-hour
SLA"), call it out:

```text
Where did that target come from? Do not assume one. Find the real one.
```

**2. Build the agent.**

```text
Build a Cortex Agent that can answer SLA questions for our support leadership.
It needs two tools: retrieval over the policy documents (there is already a
POLICY_SEARCH Cortex Search service), and analytics over SUPPORT_TICKETS.
Create whatever semantic layer the analytics tool needs. Give it instructions
that make it look up the target from policy rather than assuming one, and make
it cite which document a target came from.
```

The instruction text is what matters: the agent must retrieve the target before
computing compliance, never assume one, and say which document it came from.

**3. Ask it the real question.**

```text
Which regions breached our support SLA, and by how much? Show your reasoning.
```

**Done when:** Iberia is the only breaching region, at roughly 54-55% of P1
tickets against a 5% threshold, with the four-hour target attributed to the SLA
document -- and it used both tools. Then ask *"Where did the four-hour figure
come from?"* to confirm it retrieved rather than guessed.

## Save context and clean up (1:26)

**Save a project note you own.** Ask:

```text
Draft PROJECT_CONTEXT.md for this folder from today's session: the revenue and
MRR definitions we agreed, my preferences for how you work (read-only
exploration first, explain for business readers, show SQL), and the
verification checks that mattered. Keep it under 30 lines. Show it to me before
saving.
```

Edit it yourself, then save. Next time, start with: *"Read PROJECT_CONTEXT.md
first and follow it."* That reuse is explicit -- do not assume CoCo remembers
today on its own. A starting template is in
[`templates/PROJECT_CONTEXT.md`](templates/PROJECT_CONTEXT.md).

**Clean up -- Lab 32 first**, because its Cortex Search service keeps running
until it is dropped. Review the names each script prints, then:

```bash
snow sql -f labs/32-cortex-agent/cleanup.sql -c <your-connection>
snow sql -f labs/31-build-a-semantic-view/cleanup.sql -c <your-connection>
snow sql -f labs/21-build-a-pipeline/cleanup.sql -c <your-connection>
snow sql -f labs/11-explore-unfamiliar-schema/cleanup.sql -c <your-connection>
```

Short on time? Run the Lab 32 cleanup now and the rest straight after the
session. Lab 21's dynamic tables refresh on their lag until dropped too.

When you have finished every lab you plan to do, the shared cleanup removes
**all** of your `COCO_WS_LABnn_DB_<your_user>` databases, your shared workshop
database and your workshop warehouse:

```bash
snow sql -f shared/99_workshop_cleanup.sql -c <your-connection>
```

If you used this account for earlier CoCo workshops, those lab databases have
the same names and will be dropped too -- check before running it. The
`COCO_WS_USER` role is left for your administrator, who can remove it with
[`shared/99_admin_role_cleanup.sql`](shared/99_admin_role_cleanup.sql).

## After the session

| If you want to... | Try next |
|---|---|
| Finish today's labs | Lab 10 Steps 3-6, Lab 21 Step 4, Lab 31 Step 4, Lab 32 Step 4 |
| Put a finding on a screen | [Lab 41 -- ship a Streamlit app into Snowflake](labs/41-ship-a-streamlit-app/) |
| Tune SQL | [Lab 61 -- fix a deliberately bad query](labs/61-fix-a-slow-query/) |
| Stop repeating yourself | [Lab 71 -- turn a recurring task into a reusable skill](labs/71-author-a-coco-skill/) |

**The [full 26-lab catalog](LABS.md) is included for continued practice.** For
a visual follow-up, try
[Lab 12 -- generate ER and data-flow diagrams](labs/12-generate-diagrams/README.md)
(about 20 minutes, guidance; Desktop recommended for the complete exercise).

Read each lab's surface, privileges and lifecycle before starting -- some need
the optional grant bundles in the admin script. Research and local-only
exercises do not need shared SQL setup; workspace and administrative resources
need their documented cleanup. Run data setups one at a time, not in parallel.
