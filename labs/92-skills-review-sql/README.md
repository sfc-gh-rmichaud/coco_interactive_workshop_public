# Lab 92 -- Use skills to review and verify SQL

| | |
|---|---|
| **Surface** | CoCo Desktop and CoCo CLI |
| **Surfaces** | desktop, cli |
| **Track** | bundled-skills |
| **Sequence** | 20 |
| **Topic** | SQL authoring, data quality and independent verification |
| **Time** | 30-40 minutes (guidance) |
| **Lifecycle** | local-only |
| **Privileges** | Working CoCo; Python 3.10+; optional live route follows Lab 61 |
| **Creates** | Local query revision and verification notes; optional Lab 61 resources |
| **Tears down with** | Remove practice files; optional live route uses Lab 61 cleanup |

## What you will learn

- Observe SQL-authoring and verification skill loading rather than assume a prompt invokes them.
- Detect fanout and NULL filtering with a tiny independent fixture.
- Distinguish local relational checks from Snowflake compilation and live execution.

## The scenario

`orders.csv` has one row per order. `events.csv` has multiple events per order. The business rule includes orders whose status is unknown and excludes only cancelled orders. The bad query counts revenue after joining to event grain and drops unknown statuses.

## Before you start

```bash
python3 shared/extension_lab/practice.py init --lab 92 --dest ../coco-lab92
python3 shared/extension_lab/practice.py sql-check --dest ../coco-lab92 --query bad-query.sql
```

Windows: use `py -3`. **The second command should fail**: the supplied query is deliberately wrong. The checker creates an in-memory SQLite fixture and compares the result to an independent Python oracle. It performs no Snowflake connection and is not a Snowflake dialect validator. The files contain only synthetic data.

Inspect available skills as in [Lab 91](../91-discover-bundled-skills/README.md). Names may differ by version; do not silently substitute unrelated skills.

## Why this matters

A query can compile and still answer the wrong question. A successful edit needs a metric definition, a grain check and adversarial verification.

## Steps

### Step 1 -- Establish grain before code

```text
Use the installed sql-author skill. Review bad-query.sql, orders.csv,
events.csv and sql-contract.md in this practice folder. Offline review only:
do not connect to Snowflake or inspect any account. Identify each input's grain,
join cardinality, NULL rule and intended metric. Explain why compilation alone
cannot establish correctness. Do not change anything yet.
```

**What good looks like:** the loading trace names the actual skill. The review explains both one-to-many multiplication and the unknown-status filter, with fixture rows as evidence. If the workflow requires live schema inspection, explicitly keep this exercise offline and record that limitation.

### Step 2 -- Produce the smallest correction

```text
Write corrected-query.sql for the documented contract. Keep the SQL portable
for this local fixture check. Do not execute against an account. Return exactly
one row with order_count and revenue. Do not use DISTINCT on revenue values to
hide the join problem. Explain how a new duplicate event would affect the result.
```

Run from the workshop root:

```bash
python3 shared/extension_lab/practice.py sql-check --dest ../coco-lab92 --query corrected-query.sql
```

**What good looks like:** the baseline and adversarial cases pass. Two orders can have the same amount, so `SUM(DISTINCT amount)` is not a valid general repair. The checker prints observed values; use those values rather than hand-calculating numbers for a report.

### Step 3 -- Invoke an independent verification workflow

Start a fresh session. Select the installed `verification-skill` explicitly if available:

```text
Verify corrected-query.sql against sql-contract.md and the local CSV fixtures.
Use the local practice.py sql-check command, not Snowflake or dbt. Explain the
baseline, duplicate-event and same-amount-order cases. Do not trust an earlier
chat's reported result. Distinguish a local semantics check from a Snowflake
compile or production data test. Do not edit the checker or expected rules.
```

If that installed skill only supports live Snowflake/dbt verification, ask it for a **review-only verification plan**, run the local checker yourself, and label the skill's execution as not performed. Do not force unrelated live operations to manufacture a pass.

### Step 4 -- Turn the incident into a quality contract

Invoke the installed `data-quality` workflow, constrained to planning:

```text
Using this synthetic SQL incident only, propose quality checks that would catch
order-key duplicates, orphan events and incorrect aggregation grain. Do not
attach DMFs, create monitors, query account data or change settings. Separate
row-level data defects from a query that double-counts valid one-to-many data.
State what each check proves and what it cannot prove.
```

**What good looks like:** it does not label valid multiple events as duplicate orders, or propose deleting legitimate rows to make the bad query work.

### Step 5 -- Optional Snowflake validation

Use [Lab 61](../61-fix-a-slow-query/README.md) in an explicitly approved non-production account for a real query exercise. Follow its setup, resolved FQNs, verification and cleanup. Apply the same skill-loading and independent-check discipline to **its** schema; do not run this local fixture SQL against invented Snowflake tables. Record query IDs only for queries actually executed. This optional route adds time and compute cost.

## Check your work

Retain the failing original check, passing corrected check, actual skill-loading events and a quality-plan artifact. Label results **offline synthetic** unless you performed the optional live exercise. A SQLite pass is not Snowflake compilation evidence.

## If it goes sideways

- **Fix only changes COUNT:** revenue may still be multiplied; inspect all outputs.
- **Distinct amounts seems to work:** the same-amount adversarial case exposes it.
- **Unsupported SQL in local check:** keep this exercise to its documented portable subset; validate Snowflake-specific syntax on the optional live route.
- **Skill requests broader account access:** stop and preserve the offline boundary.

## What just happened

You combined a maintained authoring workflow with an independent oracle. Neither the skill nor the model's confidence replaces tests.

## Take it further

Use the [field guide](../../shared/extension_lab/skill-field-guide.md) to select a lineage workflow for a real downstream dependency question. Do not claim local file inspection is account lineage.

## Clean up

Remove only the practice folder after retaining your report. If you ran Lab 61, use its cleanup script under the same approved connection. This lab itself has no SQL setup or run-log entry.

## Sources

[Bundled workflows](https://docs.snowflake.com/en/user-guide/cortex-code/bundled-skills), [skill invocation](https://docs.snowflake.com/en/user-guide/cortex-code/extensibility).
