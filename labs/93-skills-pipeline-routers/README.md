# Lab 93 -- Navigate the data-engineering skill routers

| | |
|---|---|
| **Surface** | CoCo Desktop and CoCo CLI |
| **Surfaces** | desktop, cli |
| **Track** | bundled-skills |
| **Sequence** | 30 |
| **Topic** | Ingestion, dynamic tables and task workflow selection |
| **Time** | 30-40 minutes (guidance) |
| **Lifecycle** | local-only |
| **Privileges** | Working CoCo; optional live route follows Lab 21 or 25 |
| **Creates** | A local decision record and implementation plan |
| **Tears down with** | Keep/remove notes; optional live route uses its own cleanup |

## What you will learn

- Match the mechanism to the requirement before asking a skill to implement it.
- Observe router-to-specialist handoffs and preserve scope across them.
- Distinguish a verified plan from a deployed pipeline.

## Why this matters

The word "pipeline" is not enough to choose between a batch load, continuous ingestion, declarative refresh and scheduled procedural work.

## The scenario

A fictional team has three separate requirements:

1. Load a fixed set of CSV files once, then stop. The files are already staged.
2. Maintain a relational aggregate within a stated freshness target as source rows change.
3. Run a procedural reconciliation after business close, with an explicit timezone and failure handling.

A proposed design uses an always-running service for all three. Your job is to replace the proposal with a justified plan, **not deploy it**.

## Before you start

Use [Lab 91](../91-discover-bundled-skills/README.md) to inspect installed descriptions for `copy-load`, `snowpipe`, `dynamic-tables` and `snowflake-tasks`, or their current equivalents. Use Plan mode and a fresh chat without production context. Create a local `pipeline-decisions.md` for your findings. No SQL setup is required.

## Steps

### Step 1 -- Route the one-time ingestion

```text
This is a fictional workshop design, not a live account task. Use the installed
workflow for loading an already-staged fixed CSV batch once. No continuous
ingestion. Do not discover account objects or execute SQL. Explain which skill
you loaded, the minimal prerequisites, rerun behavior and a validation plan.
Compare that with what would change if files arrived continuously.
```

**What good looks like:** the actual trace loads the batch-load workflow where available; continuous ingestion is a different route. No storage integration or auto-ingest pipe is created for the one-time requirement.

### Step 2 -- Ask the declarative refresh specialist

Explicitly select the installed dynamic-table workflow, then ask:

```text
Plan-only, fictional workshop: source orders change and a daily product aggregate
must meet a freshness target chosen by the owner. Use the dynamic-table workflow
to list the facts needed before selecting refresh mode and target lag. Explain
how to verify the resolved refresh behavior and diagnose upstream failure.
No account scan, DDL, scheduled refresh or billable resource creation.
```

**What good looks like:** the workflow identifies missing query/volume/freshness requirements, does not promise incremental refresh merely from the word "dynamic", and names observable validation evidence.

### Step 3 -- Follow the procedural route

In a fresh session explicitly select the installed task workflow:

```text
Plan-only, fictional workshop: reconciliation must run after business close.
Use the task workflow. Ask for the schedule timezone and dependencies instead
of inventing them. Document ownership/privileges, retries, failure evidence,
initial suspended state and cleanup. Do not create or resume any task.
```

Answer the clarification with a **fictional** agreed schedule and timezone and label it as such in your record. Do not borrow the connected account's timezone without checking.

**What good looks like:** the plan distinguishes defining a task from resuming its schedule, and includes evidence for completion/failure rather than "the creation command succeeded".

### Step 4 -- Exercise the wrong-route repair

```text
A colleague says: "Use Snowpipe Streaming to load this fixed staged CSV batch
once, and use a dynamic table to send the nightly reconciliation email." Review
that proposal against our requirements. Separate ingestion, transformation,
procedural scheduling and notification. Identify appropriate installed skill
handoffs. Do not implement or send anything.
```

**What good looks like:** the assistant questions the mismatch, uses installed descriptions, and treats notification delivery as a separately approved side effect. A plan is not permission to send an email.

### Step 5 -- Build the reviewable artifact

Save `pipeline-decisions.md` with one row per requirement: input, cadence, chosen mechanism, actual skill(s) loaded, rejected alternative and reason, required privileges, cost drivers, validation evidence and cleanup. Include an explicit **not executed** status and the unresolved inputs.

Start a new chat and ask another review-only pass to find missing approvals or unverifiable claims in that artifact. Correct at least one identified gap, or record why none was found.

## Check your work

Your artifact separates the three requirements, names actual loaded workflows, and does not claim anything was deployed. The failure exercise must expose at least one mismatched mechanism. No real task, pipe, dynamic table or notification exists from this core exercise.

## Optional live route

Run [Lab 21](../21-build-a-pipeline/README.md) for dynamic tables or [Lab 25](../25-ingest-files/README.md) for file ingestion, using an explicitly approved non-production connection. Use that lab's setup/printed FQNs and cleanup. Record the skill handoff and actual verification outputs. This is additional work, not a hidden dependency of the core lab.

## If it goes sideways

- **A skill starts account discovery:** restate the fictional plan-only scope and stop execution.
- **Skill unavailable:** record the installed version and missing workflow; choose a documented available equivalent without inventing it.
- **Plan has no testable exit condition:** require a concrete status/result check and a failure path before approving any live work.

## What just happened

You used skills as maintained decision workflows, while keeping approval boundaries around implementation and ongoing compute.

## Take it further

Compare native deployed dbt projects with local dbt development using the installed descriptions; do not assume the same skill owns both. Consult the [field guide](../../shared/extension_lab/skill-field-guide.md).

## Clean up

Keep or remove the local decision record. If you took a live route, run its cleanup promptly; dynamic tables may continue refreshing until removed/suspended. No new global config or account object is required for this core lab.

## Sources

[Bundled data-engineering skills](https://docs.snowflake.com/en/user-guide/cortex-code/bundled-skills).
