# Lab 94 -- Diagnose cost and access with the right skills

| | |
|---|---|
| **Surface** | CoCo Desktop and CoCo CLI |
| **Surfaces** | desktop, cli |
| **Track** | bundled-skills |
| **Sequence** | 40 |
| **Topic** | Evidence, units, warehouse choices and least-privilege proposals |
| **Time** | 30-40 minutes (guidance) |
| **Lifecycle** | local-only |
| **Privileges** | Working CoCo; Python 3.10+; no administrative privileges for core exercise |
| **Creates** | A local synthetic incident report |
| **Tears down with** | Remove practice files; optional live route follows Lab 62 |

## What you will learn

- Choose cost analysis, warehouse configuration and access diagnosis workflows deliberately.
- Separate observed credits from dollar billing and hypotheses from proven causes.
- Produce a scoped remediation proposal without granting privileges or resizing compute.

## The scenario

A fictional report claims a warehouse is expensive and a reader is blocked. The supplied evidence contains credit totals but no contract price, query durations but no warehouse idle intervals, and an access matrix where table SELECT alone is insufficient. You must not fill those evidence gaps with guesses.

## Before you start

```bash
python3 shared/extension_lab/practice.py init --lab 94 --dest ../coco-lab94
```

Windows: use `py -3`. Read `ops-evidence.json` in the practice folder. Its object names are **fictional labels, not discovery targets**. Do not query internal or customer accounts for this synthetic exercise. Inspect the installed descriptions for `cost-intelligence`, `warehouse`, `data-governance` and `access-troubleshooter` as in [Lab 91](../91-discover-bundled-skills/README.md).

## Why this matters

The wrong specialist can give an authoritative answer to the wrong question. More permissions and a smaller warehouse are not universal fixes.

## Steps

### Step 1 -- Analyze only the cost evidence

```text
Use the installed cost-intelligence workflow on ops-evidence.json only.
This is offline synthetic evidence. Do not query any account. Compare warehouse
credits over the supplied fixed period and name the units. Can you derive a
dollar invoice or exact idle waste from this evidence? State missing inputs.
No budget, monitor, suspension or sizing changes.
```

**What good looks like:** the trace shows the skill loaded; the report separates credits from currency and does not infer idle hours by subtracting overlapping query durations. It names the fixed period rather than "last week".

### Step 2 -- Hand off the sizing question

Select the installed warehouse workflow:

```text
Using only ops-evidence.json, review a proposal to halve the warehouse size
because it used more credits. What measurements are missing before that change
can be recommended? Propose a bounded test with performance and cost acceptance
criteria. Do not resize, suspend or create a warehouse.
```

**What good looks like:** concurrency, queueing, spill, runtime/SLA and representative workload evidence are considered. The skill does not convert a credit ranking into a proven sizing recommendation.

### Step 3 -- Diagnose the access case

Select the installed governance/access workflow and allow its specialist handoff:

```text
Review only the fictional access matrix in ops-evidence.json. The reader has
SELECT on the table but cannot query it. Use the installed governance and access
troubleshooting workflows to identify missing parent-object access and explain
why "object does not exist or not authorized" is ambiguous. Propose the smallest
change in prose and how an administrator would verify it with the real role.
Do not discover real objects, execute SQL, grant privileges or switch roles.
```

**What good looks like:** the proposal concerns missing database/schema access shown in the fixture, not ACCOUNTADMIN or PUBLIC grants. A real diagnosis would require the actual role context and grants; this exercise proves reasoning over a supplied matrix only.

### Step 4 -- Inject an unsupported conclusion

```text
A draft says: "These credits cost exactly $500, all unused query time is waste,
and ACCOUNTADMIN fixes the reader." Audit those claims against the supplied
evidence. Label each as supported, unsupported or unsafe, with a reason.
Do not execute any remediation.
```

The dollar value is an intentionally unsupported claim, **not an expected result**. Save your corrected report as `incident-review.md`. Include observations, unknowns, rejected claims, proposed next evidence, role-scoped validation and approval requirements.

### Step 5 -- Fresh-session review

Open a new chat and provide only the evidence file and your report. Ask it to check every factual claim and confirm that no synthetic finding is presented as live account telemetry. Record the loaded skill/source and the resulting corrections.

## Check your work

- The report says **offline synthetic evidence** and identifies its input file/period.
- Credit rankings do not become dollar invoices without pricing evidence.
- Query time is not treated as additive warehouse occupancy.
- Sizing remains a testable proposal, not an executed change.
- The access proposal is narrow and distinguishes missing access from missing objects.
- Actual skill traces exist for the workflows you claim to have used.

## Optional live route

Use [Lab 62](../62-cost-and-usage-capstone/README.md) for a seeded or authorized live cost exercise. Follow its exact source, units, access requirements and cleanup. Do not expand an account-wide audit just to complete this offline lab. Actual production grants or warehouse changes need separate authorization.

## If it goes sideways

- **The workflow needs live telemetry:** return to the offline scope and mark its live steps not executed.
- **Empty metadata treated as no usage:** distinguish denied, unavailable, empty and latency-limited evidence.
- **A proposed grant is too broad:** ask which fixture requirement it satisfies; reject unrelated privileges.

## What just happened

The skills organized the investigation, but the evidence limited its conclusions. That boundary is the lesson.

## Take it further

Inspect the billing workflow for currency questions and lineage for impact analysis using the [field guide](../../shared/extension_lab/skill-field-guide.md). Do not run either account-wide without a bounded request.

## Clean up

Remove the practice directory after retaining your report. If you ran Lab 62, follow its cleanup. The core exercise created no grants, policies, monitors or warehouses.

## Sources

[Bundled cost and governance skills](https://docs.snowflake.com/en/user-guide/cortex-code/bundled-skills).
