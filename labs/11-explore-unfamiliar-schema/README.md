# Lab 11 -- Explore a schema you have never seen

| | |
|---|---|
| **Surface** | CoCo in Snowsight (recommended) -- also CoCo Desktop |
| **Track** | discover |
| **Sequence** | 10 |
| **Topic** | Analytics |
| **Time** | 20 minutes |
| **Privileges** | `CREATE DATABASE`. Cortex access for CoCo itself. Nothing else. |
| **Creates** | `COCO_WS_LAB11_DB_<your_user>` |
| **Tears down with** | `cleanup.sql` |

> **Choose your surface:** follow this lab's Surface row. Desktop is macOS/Windows only; Linux attendees should consult the VS Code/CLI routes in the prerequisites. Lab 74 specifically demonstrates Snowsight Workspaces.

## What you will learn

- How to get oriented in an inherited schema with unhelpful table names, without reading every DDL by hand.
- How to make CoCo show its reasoning about *which* tables to trust, so you can check it rather than take it on faith.
- Why the first plausible-looking answer is often wrong, and how to catch that.

## Why this matters

Everyone has inherited a schema like this one. Cryptic names, a backup table nobody deleted, a view marked deprecated that half the business still uses, and a discount column whose units are not what you would guess. The slow part of answering a question is never the SQL. It is working out what the columns mean and which object is the real one.

## The scenario

You have just been handed access to a sales schema. Someone in the business asks:

> Which product category is growing fastest, and is any region falling behind?

You have never seen this schema before. There is no documentation.

## Before you start

> **Your object names carry your user name.** Everything this lab creates at
> account level is suffixed with your Snowflake user, so a whole room can run it
> in one account without collisions: your database is
> `COCO_WS_LAB11_DB_<your_user>`. The last query in `setup.sql` prints the exact
> names -- keep them to hand.
>
> Inside the SQL files those names are built with session variables (`$LAB_DB`).
> **CoCo does not see them,** because it runs its own session. So wherever a step
> below asks you to prompt CoCo, paste the real name rather than `$LAB_DB`.

Run the setup:

```bash
snow sql -f labs/11-explore-unfamiliar-schema/setup.sql -c <your-connection>
```

Or open `setup.sql` in Snowsight and Run All. It takes about 30 seconds.

The last statement prints row counts. They should look like this:

| Object | Rows | Precision |
|---|---|---|
| `LKP_RGN` | 4 | exact |
| `LKP_CAT` | 5 | exact |
| `DIM_CUST` | 1,200 | exact |
| `DIM_PROD` | 300 | exact |
| `FCT_ORD` | 30,000 | exact |
| `FCT_ORD_LN` | about 71,000 | within 1% |
| `FCT_ORD_LN_BAK` | about 47,000 | within 1% |

> **Reading the Precision column.** *exact* means you should see that number to
> the digit, on any date and in any account -- if you do not, something is wrong.
> *within n%* means the figure moves a little and anything inside that band is
> healthy. *guidance* (used later in this guide) means the number is not
> reproducible at all and is there to tell you what order of magnitude to expect.

The two order-line counts move because the data is anchored to the last eight
completed quarters, and quarters differ in length. Simulated across two years of
run dates the spread is 70,983-71,031 and 46,885-47,069 -- so "about 71,000" and
"about 47,000" hold on any day you run this.

Then open CoCo in Snowsight and set your context to `COCO_WS_LAB11_DB_<your_user>.LAB`.

## Steps

### Step 1 -- Get oriented (about 4 minutes)

Do not ask for the answer yet. Ask what you are looking at.

```
I have just been given access to COCO_WS_LAB11_DB_<your_user>.LAB and I have never seen it
before. Profile it for me: what tables and views exist, what does each one appear
to represent, how do they join, and roughly how much data is in each. Flag anything
that looks like it should not be used for analysis, and tell me why you think so.
```

**What good looks like:** a summary that groups the objects into lookups, dimensions and facts, identifies the join keys (`CUST_SK`, `PROD_SK`, `ORD_ID`), and explicitly calls out `FCT_ORD_LN_BAK` and `V_SALES_LEGACY` as things to avoid. It should notice the table comments.

**If it goes sideways:** if the reply is a bare list of table names with no interpretation, your context is probably not set to the right schema, so it is guessing from names alone. Set database and schema, then ask again.

### Step 2 -- Interrogate the columns that matter (about 4 minutes)

This is the step people skip, and it is the one that prevents a wrong answer.

```
Before I calculate any revenue from this schema, tell me exactly how to compute it
correctly. Specifically: which price column is authoritative, what units DISC_PCT is
actually stored in (check the real values, do not assume), and which ORD_STAT values
should count as revenue. Show me the evidence for each answer.
```

**What good looks like:** it should check actual values rather than reason from names, and conclude that:

- `FCT_ORD_LN.UNIT_PRC` is authoritative, not `DIM_PROD.UNIT_PRC` (that is current list price).
- `DISC_PCT` holds whole percentages such as `25`, so the multiplier is `(1 - DISC_PCT/100)`.
- `ORD_STAT` has five values, and `CANCELLED`, `RETURNED` and `PENDING` are not realised revenue.

**Why this step exists:** treating `DISC_PCT` as a fraction gives you `(1 - 25)`, which makes discounted lines massively negative. It is a mistake that announces itself. Including cancelled and returned orders is the dangerous one, because it just quietly overstates revenue by about 18% and still looks reasonable.

### Step 3 -- Answer the actual question (about 6 minutes)

```
Now answer the business question: across the last eight completed quarters, which
product category is growing fastest, and is any region falling behind? Use the
revenue definition you just established. Show the quarterly trend per category and
per region, and give me a two-sentence answer I could send to the person who asked.
```

**What good looks like:** the numbers should show

- **Outdoor & Recreation** growing steadily and roughly tripling across the window, while every other category is flat or slightly down.
- **EMEA** rising for the first five quarters and then dropping sharply, losing about 45% of its quarterly revenue in a single quarter (the 42-48% band is healthy) and only partially recovering after. The break is abrupt, not a gentle slide.

### Step 4 -- Make it defensible (about 4 minutes)

```
Someone is going to challenge this number. Write me a short verification query that
proves the revenue total is right, and tell me what would change the answer:
which assumptions did you make, and what would I need to confirm with the business?
```

**What good looks like:** it names its assumptions rather than hiding them. The honest open question here is whether `SHIPPED` counts as revenue or only `COMPLETE` -- that is a business decision, not a data one, and a good answer says so.

## Check your work

```sql
-- Rebuild the per-user names, because a new worksheet is a new session.
SET NS     = (SELECT REGEXP_REPLACE(CURRENT_USER(), '[^A-Za-z0-9]', '_'));
SET LAB_DB = 'COCO_WS_LAB11_DB_' || $NS;
USE DATABASE IDENTIFIER($LAB_DB);
USE SCHEMA LAB;

-- The trap, made visible. The deprecated view treats DISC_PCT as a
-- fraction, so most of its lines go negative.
SELECT COUNT_IF(REVENUE < 0) AS negative_lines,
       ROUND(SUM(REVENUE))   AS nonsense_total
FROM V_SALES_LEGACY;

-- Correct revenue, and what including non-revenue statuses would have cost you.
SELECT
  ROUND(SUM(CASE WHEN o.ORD_STAT IN ('COMPLETE','SHIPPED')
            THEN l.QTY * l.UNIT_PRC * (1 - l.DISC_PCT/100.0) END)) AS revenue_correct,
  ROUND(SUM(l.QTY * l.UNIT_PRC * (1 - l.DISC_PCT/100.0)))          AS revenue_all_statuses
FROM FCT_ORD_LN l
JOIN FCT_ORD o ON o.ORD_ID = l.ORD_ID;
```

Expected: tens of thousands of negative lines (about 28,300, within 2%) and a large negative total from the view. In the second query, `revenue_all_statuses` is about 18% higher than `revenue_correct` -- treat anything in the 16-19% band as correct. If CoCo's answer matched the inflated figure, it skipped Step 2.

## What just happened

CoCo read the schema's metadata -- table and column names, comments, row counts -- and then sampled actual values to test its assumptions. That second part is the difference between this and a text-to-SQL box: it checked what `DISC_PCT` really contained instead of inferring from the name, and it read the table comments that flagged the backup and the deprecated view.

It still needed you to insist on Step 2. An agent asked only for "revenue by category" will usually produce something reasonable-looking on the first try. Asking it to justify the definition first is what makes the answer trustworthy.

## Take it further

- Ask it to write the trustworthy version as a view, with comments explaining the revenue definition, so the next person does not repeat this.
- Ask what happened in EMEA in the quarter where the drop starts, and whether the drop is fewer orders or smaller orders. (It is smaller: the number of EMEA orders barely moves, but lines per order fall by about a third. Getting this right requires looking at both, which is the point.)
- Point it at `FCT_ORD_LN_BAK` and ask it to prove whether the backup is safe to delete.

## Clean up

```bash
snow sql -f labs/11-explore-unfamiliar-schema/cleanup.sql -c <your-connection>
```

Drops `COCO_WS_LAB11_DB_<your_user>` only. The shared warehouse and your other labs are untouched.
