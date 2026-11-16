# Lab 63 -- Make old data cost less, on purpose

| | |
|---|---|
| **Surface** | CoCo in Snowsight (recommended) -- also CoCo Desktop |
| **Track** | performance-cost |
| **Sequence** | 20 |
| **Topic** | Performance and cost |
| **Time** | 30 minutes |
| **Privileges** | `CREATE DATABASE`, plus `CREATE STORAGE LIFECYCLE POLICY` on the lab schema. Archive tiers are not available on every cloud provider -- the lab works without them. |
| **Creates** | `COCO_WS_LAB63_DB_<your_user>` -- 3 million seeded events and the retention rules they are subject to. You write the policies. |
| **Tears down with** | `cleanup.sql` |

> **Choose your surface:** follow this lab's Surface row. Desktop is macOS/Windows only; Linux attendees should consult the VS Code/CLI routes in the prerequisites. Lab 74 specifically demonstrates Snowsight Workspaces.

## What you will learn

- How to express a retention decision as a storage lifecycle policy, and why the syntax is a boolean expression rather than a number of days.
- Why a lifecycle policy has a running cost, and the two ways it can cost more than the storage it saves.
- How to separate "old" from "safe to delete", which are not the same set and differ here by more than half a million rows.
- When an archive tier is worth it, and the retention minimums that decide for you.

## Why this matters

Storage is the line item nobody looks at until it is large, and then the instinct is to delete the oldest thing. That instinct is wrong in two directions at once: some of the oldest data is legally required, and some of the newest is worthless. "How old is it" is not the question. "Who needs it, how fast, and for how long" is.

Snowflake's storage lifecycle policies let you encode that answer so it happens without anyone remembering to. They are also a scheduled, billable operation, which means a badly designed one is a recurring cost pretending to be a saving. This lab makes you design a good one.

## Before you start

> **Your object names carry your user name.** Everything this lab creates at
> account level is suffixed with your Snowflake user, so a whole room can run it
> in one account without collisions: your database is
> `COCO_WS_LAB63_DB_<your_user>`. The last query in `setup.sql` prints the exact
> names.
>
> Inside the SQL files those names are built with session variables (`$LAB_DB`).
> **CoCo does not see them,** because it runs its own session.

```bash
snow sql -f labs/63-storage-lifecycle/setup.sql -c <your-connection>
```

Setup writes 3 million events across three years, clustered on `EVENT_DATE`, plus a `RETENTION_RULES` table holding the obligations the data is subject to. It takes a minute or two.

| Metric | Value | Precision |
|---|---|---|
| `TOTAL_ROWS` | 3,000,000 | exact |
| `DISTINCT_DAYS` | 1,095 | exact |
| `PCT_OLDER_THAN_180D` | about 97.3 | within 1% |
| `PCT_BILLABLE` | about 10 | within 3% |
| `OLDER_THAN_180D` | about 2,918,000 | within 1% |
| `SAFE_TO_EXPIRE` | about 2,363,000 | within 2% |
| `PROTECTED_BY_A_RULE` | about 555,000 | within 3% |

> **Reading the Precision column.** *exact* means that number to the digit, on any
> date and in any account. *within n%* means the figure comes from a hash-based
> sample and moves slightly; anything inside the band is healthy. *guidance* means
> not reproducible -- an order of magnitude, not a target.

The 97.3% is worth a pause. It is not a sampling artefact — the generator draws the day offset as `FLOOR(SQRT(uniform))`, so the fraction of rows inside 180 days is `(180/1095)²`, and the number is arithmetic. The table is deliberately extreme so the effect is unmistakable, but the *shape* is entirely ordinary: old rows dominate the row count while recent rows take nearly all the queries.

**And then look at the last two numbers.** 2.9 million rows are older than six months. Only 2.36 million of them are safe to delete. The other **555,000 are protected by a retention rule** — billing evidence and audit trail. A policy written from "older than 180 days" deletes those. That gap is the lab.

## Steps

### Step 1 -- Establish what the data actually costs and who uses it (about 6 minutes)

```
COCO_WS_LAB63_DB_<your_user>.LAB.APP_EVENTS has three years of application events, and
RETENTION_RULES describes what we are obliged to keep. Before proposing any retention policy,
tell me: how the rows are distributed over time, how much storage the table occupies, which
categories of event dominate the old data, and what fraction of the old data is protected by a rule.
```

**What good looks like:** the long-tail shape identified, and — the part to insist on — the distinction between old and deletable stated *before* any policy is proposed. If CoCo goes straight to "expire everything over 180 days", ask:

```
How many of those rows are billable or admin_action events, and what does RETENTION_RULES say about them?
```

On storage figures: `ACCOUNT_USAGE.TABLE_STORAGE_METRICS` has up to a couple of hours of latency and reports compressed bytes, so a table created moments ago may show nothing. `INFORMATION_SCHEMA.TABLES` gives `BYTES` immediately. Either way treat the number as **guidance** — compression ratio is a storage-engine outcome, not a documented constant.

### Step 2 -- Write the analytics expiry policy (about 8 minutes)

```
Write a storage lifecycle policy that expires product analytics events -- page_view and api_call --
once they are older than the 180 days RETENTION_RULES allows, while never touching billable events
or admin_action events regardless of age. Attach it to APP_EVENTS. Explain the signature you chose
and why the attachment column matters.
```

**What good looks like:** something close to this, and it is worth reading for what the syntax *is*:

```sql
CREATE OR REPLACE STORAGE LIFECYCLE POLICY EXPIRE_OLD_ANALYTICS
  AS (event_date DATE, event_type VARCHAR, is_billable BOOLEAN)
  RETURNS BOOLEAN ->
    event_date < TO_DATE(DATEADD(DAY, -180, CURRENT_TIMESTAMP()))
    AND event_type IN ('page_view', 'api_call')
    AND NOT is_billable
  COMMENT = 'Product analytics only. Billing and audit events are excluded by predicate.';

ALTER TABLE APP_EVENTS ADD STORAGE LIFECYCLE POLICY EXPIRE_OLD_ANALYTICS
  ON (EVENT_DATE, EVENT_TYPE, IS_BILLABLE);
```

Four things in there that are easy to get wrong, all verified:

- **A policy is a boolean expression, not a retention setting.** There is no `EXPIRE_AFTER_DAYS` and no `SCHEDULE`. Guessing at those fails with a bare `syntax error line 2 at position 2 unexpected 'SCHEDULE'`, which does not hint that the whole shape is different. `RETURNS BOOLEAN -> <expression that is TRUE for rows to remove>` is the model.
- **`TO_DATE(...)` around the comparison is not cosmetic.** Comparing against a raw `CURRENT_TIMESTAMP()` makes the boundary depend on the time of day the policy happens to run, so the same policy removes a different set of rows each day. Snowflake's own guidance is to convert to a date.
- **The signature and the `ON (...)` columns must line up** in count and type. They are bound by column ID, not by name, so renaming a column afterwards is safe — but getting the order wrong at attachment time is not.
- **The exclusions belong in the predicate.** There is no "except" clause. If billable rows are not excluded by the expression, they are deleted.

**If it goes sideways:** `CREATE OR REPLACE` fails outright if the policy is already attached to a table. Detach with `ALTER TABLE APP_EVENTS DROP STORAGE LIFECYCLE POLICY` first. And a table can only have **one** policy attached, which is a real design constraint — see step 4.

### Step 3 -- Cost the policy honestly (about 6 minutes)

This is the step that distinguishes this lab from reading the documentation.

```
This policy will run every day. Explain what it costs to run, what determines that cost, and under
what circumstances running it would cost more than the storage it frees. Then tell me whether it is
worth attaching to this table, and what you would do differently if the table were not clustered on
EVENT_DATE.
```

**What good looks like:** three points.

- **Policies bill per execution**, and the execution has to find the rows. That means scanning — so cost is driven by how much of the table it must read to decide.
- **Clustering on the attachment column is what keeps that cheap.** `APP_EVENTS` is clustered on `EVENT_DATE` for exactly this reason. On an unclustered table each daily run scans far more micro-partitions than it needs, and on a large-but-slow-growing table the policy can plausibly cost more than the storage it releases.
- **A one-off cleanup should not be left attached.** If you only need to prune history once, attach the policy, wait for it to run, confirm through `STORAGE_LIFECYCLE_POLICY_HISTORY`, then **detach it**. Otherwise you pay daily, forever, for a job that finished on day one. This is the single most common way these policies waste money.

```sql
-- Note the argument: this table function needs to be told which policy.
SELECT * FROM TABLE(INFORMATION_SCHEMA.STORAGE_LIFECYCLE_POLICY_HISTORY(
  policy_name => 'COCO_WS_LAB63_DB_<your_user>.LAB.EXPIRE_OLD_ANALYTICS'));
```

Called with no arguments it errors and tells you it wants either `policy_name` or an entity name and domain. Expect it to be **empty immediately** — executions are scheduled, not instant, so an empty history right after attaching means "not yet", not "broken".

### Step 4 -- Design for the rules you cannot satisfy with one policy (about 8 minutes)

Now the constraint bites: **a table can have only one storage lifecycle policy**, and `RETENTION_RULES` has four different obligations, from 180 days to seven years.

```
RETENTION_RULES has four different retention periods on one table, and a table can only have one
storage lifecycle policy. Give me the options for satisfying all four, with the trade-off of each.
Include what an archive tier would and would not solve.
```

**What good looks like:** several genuinely different designs, not one answer.

- **One policy with a compound predicate** — the whole rule set expressed as a single boolean. Works, and becomes unreadable and untestable at four rules, let alone forty.
- **Split the table** by retention class, so each part gets its own policy. Costs you a rewrite and a view to put it back together, and buys clarity plus cheaper pruning.
- **Archive rather than expire** for the long obligations. `ARCHIVE_TIER = COOL` or `COLD` moves rows to cheaper storage for a period before expiry, which fits "must be retrievable, not necessarily fast" — exactly what the billing rule says.
- **Do nothing for the seven-year rule.** Sometimes right: 555,000 protected rows out of 3 million may simply not be worth engineering around yet.

Two hard limits worth knowing before designing around archive tiers, both enforced at `CREATE`:

| Tier | Minimum `ARCHIVE_FOR_DAYS` |
|---|---|
| `COOL` | 90 |
| `COLD` | 180 |

Asking for `COOL` with 30 days fails with `510827 ... Invalid value '30' for property 'ARCHIVE_FOR_DAYS' when using 'COOL' archive tier. It must be at least '90' days.` And `ARCHIVE_TIER` **cannot be changed once set** — you drop and recreate the policy, which means detaching it from every table first. Archive tiers are also not available on every cloud provider, so check before promising one.

## Check your work

```sql
SET NS     = (SELECT REGEXP_REPLACE(CURRENT_USER(), '[^A-Za-z0-9]', '_'));
SET LAB_DB = 'COCO_WS_LAB63_DB_' || $NS;
USE DATABASE IDENTIFIER($LAB_DB);
USE SCHEMA LAB;

-- Old, deletable, and protected are three different numbers.
SELECT
  COUNT(*)                                                          AS TOTAL_ROWS,
  COUNT_IF(EVENT_DATE < DATEADD('day', -180, CURRENT_DATE()))       AS OLDER_THAN_180D,
  COUNT_IF(EVENT_DATE < DATEADD('day', -180, CURRENT_DATE())
           AND EVENT_TYPE IN ('page_view','api_call')
           AND NOT IS_BILLABLE)                                     AS SAFE_TO_EXPIRE,
  COUNT_IF(EVENT_DATE < DATEADD('day', -180, CURRENT_DATE())
           AND (IS_BILLABLE OR EVENT_TYPE IN ('admin_action','export')))
                                                                    AS PROTECTED
FROM APP_EVENTS;

SHOW STORAGE LIFECYCLE POLICIES IN SCHEMA;
```

Expected: `TOTAL_ROWS` **3,000,000** (exact), `OLDER_THAN_180D` about **2,918,000** (within 1%), `SAFE_TO_EXPIRE` about **2,363,000** (within 2%), `PROTECTED` about **555,000** (within 3%) — and one policy listed, the one you created.

If your policy has already executed, `SAFE_TO_EXPIRE` will have fallen towards zero. That is the policy working, and it is the only figure here that legitimately changes.

## What just happened

You made a retention decision and then encoded it, in that order — which is the opposite of how it usually happens.

**"Old" is not "deletable".** 2.9 million rows qualified as old; 555,000 of them were protected. The predicate carries the whole obligation, because there is no exception clause and nothing checks your work.

**A retention policy is a running job, not a setting.** It bills per execution, its cost depends on how much it has to scan, and it does not stop when the work is done. Clustering on the attachment column and detaching after a one-off backfill are the two things that keep it from becoming a permanent tax.

**One policy per table is a design constraint, not a detail.** Four retention rules on one table forces a real decision — compound predicate, split the table, archive, or accept the cost — and there is no answer that is right for everyone.

**The syntax tells you what the feature is.** `RETURNS BOOLEAN ->` rather than a number of days means the feature is "delete rows matching this expression, on a schedule". Once that lands, the archive minimums and the single-policy limit stop being arbitrary.

## Take it further

- **Write the archival variant** for the billing rule, with `ARCHIVE_TIER = COLD` and `ARCHIVE_FOR_DAYS = 2555`, and read back what `GET_DDL('policy', ...)` returns. It is not identical to what you wrote.
- **Measure the pruning.** Run the policy predicate as a `SELECT` and check `QUERY_HISTORY` for partitions scanned versus total. That ratio is what the policy's daily cost is proportional to — this is the same technique lab 61 uses on a slow query.
- **Try it unclustered.** Copy `APP_EVENTS` without the clustering key, run the same predicate, and compare partitions scanned. This is the clustering argument as a number rather than an assertion.
- **Tie it back to cost.** Lab 62 reads your actual credit usage; storage and policy executions both appear there.
- **Compare against `DATA_RETENTION_TIME_IN_DAYS`.** Time Travel and lifecycle policies are unrelated mechanisms that both sound like retention. Ask CoCo to explain which one a compliance auditor means.

## Clean up

```bash
snow sql -f labs/63-storage-lifecycle/cleanup.sql -c <your-connection>
```

That drops the lab database, which takes the table and every policy attached to it — and therefore their daily, billable executions. If you attached a policy to a table outside this database while experimenting, find it with `SHOW STORAGE LIFECYCLE POLICIES IN ACCOUNT` and detach it with `ALTER TABLE <t> DROP STORAGE LIFECYCLE POLICY`.
