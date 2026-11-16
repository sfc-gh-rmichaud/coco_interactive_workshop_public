# Lab 85 -- Delegate work to bounded subagents

| | |
|---|---|
| **Surface** | CoCo CLI and CoCo Desktop |
| **Surfaces** | cli, desktop |
| **Track** | advanced-coco |
| **Sequence** | 50 |
| **Topic** | Delegation, context and independent evidence |
| **Time** | 30-40 minutes (guidance) |
| **Lifecycle** | local-only |
| **Privileges** | Working CoCo sign-in; Python 3.10+; subagents enabled in your build |
| **Creates** | Practice folder, custom reviewer and evidence reports |
| **Tears down with** | Stop lab agents, unregister practice agent if needed, remove practice folder |

## What you will learn

- Give a subagent a complete task rather than assume it knows the main conversation.
- Restrict a reviewer to reading files and require file/field evidence.
- Resolve conflicting reports by source authority, not a vote among models.

## Why this matters

Parallelism can multiply the same mistake. Different agents reading different evidence should disagree here; the parent must resolve the disagreement from the policy.

## The scenario

One reviewer sees the release summary. Another sees check results and rollback evidence. The summary says ready; the authoritative release policy disagrees. Both reviewers must explain their evidence limitations.

## Before you start

```bash
python3 shared/extension_lab/practice.py init --lab 85 --dest ../coco-lab85
```

Windows: use `py -3`. Read the [practice guide](../../shared/extension_lab/README.md). All inputs are local and synthetic. No git worktrees, new branches or external systems are needed.

## Steps

### Step 1 -- Discover the actual agent types

In CLI consult `/help` and `/agents`. In Desktop open **Agent Settings > Subagents**. Ask which built-in exploration agent is available; record its actual name rather than assume the same spelling in every build.

```text
Use an available exploration subagent to inventory this practice folder.
Read-only. Do not query Snowflake or execute shell commands. Return filenames,
the role of each file, and which sources can support a readiness decision.
Pass this complete scope to the subagent and show its actual result.
```

**What good looks like:** the transcript shows a real delegation and returned evidence. A parent response formatted as two fictional reviewers does not pass.

### Step 2 -- Author a restricted reviewer

Use `templates/reviewer.md` as the starter. Create `.cortex/agents/ws-evidence-reviewer.md` in the practice project for CLI, or create/import a practice-only custom agent through Desktop's Subagents interface. Inspect the saved path. Use only runtime tools available on your surface, such as `read`, `glob` and `grep`; no `bash`, `write`, SQL or network tools. Keep the model default rather than hard-code a model unavailable to attendees.

```text
Complete the workshop reviewer template. Its tools must be limited to the
available read/glob/grep runtime IDs. Review only the explicitly supplied
practice path. Inputs: release ID, source files, policy, output contract.
Missing evidence means INSUFFICIENT_EVIDENCE, not READY. Every conclusion must
name a file and field. No edits, commands, external calls or publication.
Explain how you verified the configured tools actually resolve on this surface.
```

**What good looks like:** exact lowercase tool IDs in the agent definition and evidence that the agent actually reads a fixture. A valid-looking YAML list alone does not prove tool access works.

### Step 3 -- Delegate independent scopes

```text
Run two read-only reviewer subagents in parallel, in the foreground.
A: inspect release.json only; state its readiness claim and explain what cannot
be verified from that file. B: inspect release-policy.md, release.json and
checks.json; determine the evidence-backed decision for REL-204.
Pass the absolute practice directory and complete instructions to each child.
Return separate reports with filenames and fields. Do not let either child edit
files. After both finish, reconcile them against the policy, not by majority vote.
```

**What good looks like:** A distinguishes a summary claim from verified readiness; B identifies the blockers. The parent explains why the sources have different authority. If either child claims READY without the required checks, preserve that failure in your notes.

### Step 4 -- Practice a background handoff

```text
Run one read-only background reviewer on the original REL-204 fixtures using
ws-evidence-reviewer if it is available. Return its tracking ID. No nested
background agents, edits or external calls. I will request its result separately.
```

Inspect the running-agent UI. When finished, request the output using its actual ID. If it finishes before you can observe it running, record completed rather than pretend it is still active. Optionally cancel a second run while it is active; confirm cancellation and do not silently restart it.

**What good looks like:** you can distinguish submitted, running, completed and cancelled, and you retrieve the child result rather than invent it. Background status is not a performance benchmark.

### Step 5 -- Verify the parent report

Ask the parent to return `review-schema.json`'s JSON based on the evidence, save as `review.json`, then run from the workshop root:

```bash
python3 shared/extension_lab/practice.py verify --dest ../coco-lab85 --report review.json
```

## Check your work

Keep the agent definition, delegation trace, child reports, reconciliation and checked parent report. No child should edit fixtures. An agent tool list narrows its tools; it is not filesystem isolation. Use a sandbox for sensitive material and never add broad shell access just to avoid a denied read.

## If it goes sideways

- **No subagent tools available:** record the limitation. A sequential main-agent review is a useful fallback but not completion of the delegation objective.
- **Empty child context:** pass the absolute path, files, policy and output contract explicitly.
- **Agent has no working tools:** compare runtime IDs and casing, then retry the bounded read test.
- **Conflicting file edits:** this exercise is read-only; stop the agents rather than reconcile unauthorized edits.

## What just happened

Delegation separates contexts and work. Evidence reconciliation remains the parent agent's responsibility.

## Take it further

Assign disjoint files to implementation agents only in a disposable project after reviewing a plan. Keep version-control worktree creation optional and explicit. Continue with [Lab 86](../86-package-a-plugin/README.md).

## Clean up

Wait for or stop all lab agents. Remove only the practice agent registration if one was added outside the project. Close the practice session and delete its folder after retaining your reports. No branch or account cleanup is needed.

## Sources

[CLI subagents](https://docs.snowflake.com/en/user-guide/cortex-code/extensibility), [Desktop plugins and subagents](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code-desktop/plugins).
