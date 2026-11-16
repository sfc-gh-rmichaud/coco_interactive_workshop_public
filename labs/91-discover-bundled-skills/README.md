# Lab 91 -- Find the bundled skill for the job

| | |
|---|---|
| **Surface** | CoCo Desktop and CoCo CLI |
| **Surfaces** | desktop, cli |
| **Track** | bundled-skills |
| **Sequence** | 10 |
| **Topic** | Skill inventory, invocation and provenance |
| **Time** | 20-30 minutes (guidance) |
| **Lifecycle** | local-only |
| **Privileges** | Working CoCo sign-in; no database setup |
| **Creates** | A local skill map and invocation evidence |
| **Tears down with** | Keep or remove your notes; restore only preferences changed during the exercise |

## What you will learn

- Find the skills actually installed on your surface instead of memorizing a catalog count.
- Distinguish a bundled workflow from a user override, plugin contribution or shared catalog skill.
- Prove explicit and automatic invocation from the trace.

## Why this matters

"CoCo knows about pipelines" and "CoCo loaded the maintained pipeline workflow" are not equivalent. The latter is observable and gives you checkpoints to follow.

## The scenario

You are onboarding a teammate who needs a small task-to-skill map, not a list of every skill. The [field guide](../../shared/extension_lab/skill-field-guide.md) supplies task families and starter prompts; your installed inventory is authoritative for actual names and availability.

## Before you start

Open a fresh practice folder or a new CoCo chat without customer files. CLI users run `cortex --version` and `/skill list` inside a session. Desktop users open **Agent Settings > Skills**, inspect **Packaged Skills**, and record the application version. No SQL setup, downloads or new skill installation is required.

## Steps

### Step 1 -- Inspect source, not just name

Find the guide, skill-development and SQL-authoring workflows in your inventory. Record each one's actual name, source, description and supported invocation spelling. A same-named local or profile skill can change what loads; inspect the loaded path/source before calling it bundled.

**What good looks like:** your notes distinguish packaged/bundled from local, project, profile, plugin and shared sources. Missing is an explicit state, not permission to install an arbitrary similarly named repository.

### Step 2 -- Invoke one explicitly

Desktop: type `/`, select the installed guide skill, then enter the request below. CLI: use the installed skill picker/manager or the documented `$cortex-code-guide` form with the request.

```text
Using the installed CoCo guide, explain how to resume a session, inspect loaded
skills and see MCP connection status on this surface. Do not change any settings.
Distinguish shell commands from chat commands and list anything you cannot verify.
```

**What good looks like:** an actual skill-loading event appears in the transcript and the answer matches this surface. Do not infer loading from the phrase "using the guide" in the answer.

### Step 3 -- Compare automatic routing

Start a new session and ask the same question without naming a skill:

```text
How do I resume my CoCo session and inspect available skills on this surface?
Explain only; do not change settings.
```

Record the actual skill selected, if any. Compare explicit versus automatic routing. If none loads, explicitly invoke the guide; record the fallback, not an invented success.

### Step 4 -- Build your task map

Choose one task from each row in the field guide. Inspect the relevant installed description and complete this local table:

| Task | Installed skill name | Source | Why it fits | Required access | Evidence/checkpoint |
|---|---|---|---|---|---|
| Explain CoCo commands | Fill from inventory | Fill from inventory | Surface guidance | Working chat | Loading trace |
| Review a query | Fill from inventory | Fill from inventory | SQL correctness | Local review or sandbox | Verification result |
| Investigate cost | Fill from inventory | Fill from inventory | Credit analysis | Synthetic or authorized telemetry | Units and period |
| Plan a pipeline | Fill from inventory | Fill from inventory | Chosen pipeline mechanism | Plan-only or sandbox | Router and handoff |

For each, write one natural-language prompt and one explicit invocation using your surface's actual picker. Do not run account scans merely to fill this map.

### Step 5 -- Find a misleading name

Inspect the installed `search-optimization` description if present. Determine whether it builds **Cortex Search** services or tunes SQL **Search Optimization Service**. Identify the appropriate workload-performance workflow for the latter from the installed descriptions. Also distinguish account credit analysis from dollar billing and a CoCo subagent from a Snowflake Cortex Agent.

**What good looks like:** task routing follows the description, not a guessed meaning of the name. A plugin-dependent skill is not reported as bundled merely because a documentation page mentions it.

## Check your work

Your map includes actual source badges/names, explicit invocation evidence, a fresh-session routing comparison and at least one name-confusion correction. Do not copy a total skill count from another installation.

## If it goes sideways

- **Skill absent:** record version and source; consult official docs. Use an available equivalent only after inspecting its scope.
- **Disabled skill:** do not enable organizationally disabled capabilities without approval. Choose another exercise.
- **Answer without loading trace:** repeat with explicit picker invocation and retain both outcomes.

## What just happened

You learned a discovery and verification process that remains useful when the bundled catalog changes.

## Take it further

Continue with [Lab 92](../92-skills-review-sql/README.md), [93](../93-skills-pipeline-routers/README.md), [94](../94-skills-cost-and-access/README.md) or [95](../95-skills-ai-and-apps/README.md). Community and catalog extensions are separate from the bundled set; installing them is optional and requires source review.

## Clean up

No account objects or registrations were created. Keep your map; restore any personal favorites/preferences you deliberately changed. Do not delete packaged skills.

## Sources

[Bundled skills](https://docs.snowflake.com/en/user-guide/cortex-code/bundled-skills), [Desktop skill sources](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code-desktop/skills).
