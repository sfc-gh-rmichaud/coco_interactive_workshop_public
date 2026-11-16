# Lab 95 -- Follow a bundled AI or app workflow end to end

| | |
|---|---|
| **Surface** | CoCo Desktop and CoCo CLI |
| **Surfaces** | desktop, cli |
| **Track** | bundled-skills |
| **Sequence** | 50 |
| **Topic** | Router handoffs, review gates and implementation readiness |
| **Time** | 35-45 minutes (guidance) |
| **Lifecycle** | local-only |
| **Privileges** | Working CoCo; optional live route follows Lab 31, 32 or 41 |
| **Creates** | A reviewed AI/app design artifact; optional existing-lab resources |
| **Tears down with** | Keep/remove design files; optional live route uses the selected lab's cleanup |

## What you will learn

- Follow a bundled router through its specialist and approval checkpoints.
- Make business semantics or UI interaction requirements explicit before implementation.
- Separate a complete design workflow from an unexecuted deployment workflow.

## Why this matters

A generated app or agent can look finished before anyone has defined its success criteria. The skill's checkpoints are useful precisely where a vague request would otherwise produce an attractive but wrong result.

## The scenario

A fictional support team wants to answer order-status questions. Choose **one** route: a grounded AI design or a read-only support app design. Both core routes end in a reviewable design artifact; neither pretends to deploy without a sandbox.

## Before you start

Inspect actual installed names/descriptions as in [Lab 91](../91-discover-bundled-skills/README.md). Use a fresh Plan-mode session. Do not attach customer data or point the workflow at the currently connected account. Keep the [field guide](../../shared/extension_lab/skill-field-guide.md) nearby.

## Steps

### Step 1 -- Choose and invoke the entry point

**AI route:** explicitly select the installed `agent-studio` workflow (or its current equivalent).

```text
Plan-only workshop design; no account discovery or creation. A fictional support
team asks order-status questions over synthetic orders plus a return-policy
text. Help specify a grounded Cortex Agent workflow. Define the structured vs
text questions, required semantics, missing-data behavior, evaluation cases and
approval gates. No model calls over rows, deployment or publishing.
```

**App route:** explicitly select the installed `build-app` router where present; otherwise inspect the available app-entry workflow before proceeding.

```text
Plan-only workshop design; no account discovery or deployment. A fictional team
needs a read-only order-status screen with a search box and result table, no
write-back. Help choose the supported app framework. Use the existing Snowflake
visual style, inline filters, and explicit loading, empty, not-found and error
states. Ask about unresolved requirements, then hand off to the appropriate
installed framework skill. Do not generate a deployed app yet.
```

**What good looks like:** an actual router/skill load and a reasoned scope/framework choice, not a guessed capability claim. You supply any requested decisions and the workflow records them.

### Step 2 -- Define an output contract

**AI route:** require a design document containing question classes, proposed inputs, metric/grain definitions, tools, grounded response format, authorization boundaries and evaluation cases. Explicitly cover unknown order IDs and contradictory return-policy text. If discussing Cortex AI functions, invoke the installed AI-function guidance workflow and require it to distinguish recommendation from executed inference.

**App route:** require a design document containing screen states, input validation, data-access boundary, framework rationale, error behavior, tests and deployment/cleanup prerequisites. Make clear that read-only UI does not prove the app's runtime role is least-privileged.

**What good looks like:** acceptance criteria are observable. An AI answer must not invent a ship date; an app must not display a missing order as a successful empty order record.

### Step 3 -- Exercise a misleading request

**AI route:**

```text
A stakeholder says, "No need to evaluate; the agent answered one question well."
Use the current workflow to explain what remains unproven. Add holdout cases,
expected evidence and failure handling. Do not invent an accuracy score.
```

**App route:**

```text
A stakeholder says, "Hide the edit button and users cannot modify data."
Review that claim. Add a runtime access test and a check that no mutation route
exists. Do not grant roles or change the account.
```

**What good looks like:** the workflow rejects the unsupported inference and adds a concrete test rather than a blanket guarantee.

### Step 4 -- Complete the design handoff

Save `design-review.md` with: chosen route, actual loaded skills and sources, decisions, unresolved inputs, acceptance tests, prerequisites, explicit implementation approval gate and cleanup plan. Mark **design complete; deployment not executed**.

Start a fresh session, attach the document and ask:

```text
Review this design using the relevant installed skill. Check that another
engineer can implement it without the original chat. Identify missing inputs,
unsupported product claims and tests that cannot establish the claimed behavior.
Do not deploy or query an account. Return a concrete revision list.
```

Apply the justified revisions to the artifact. This is the end of the **core design workflow**, not a claim that an app or agent is running.

### Step 5 -- Optional live implementation route

Use [Lab 31](../31-build-a-semantic-view/README.md) or [Lab 32](../32-cortex-agent/README.md) for AI, or [Lab 41](../41-ship-a-streamlit-app/README.md) for the app. Run its setup under an explicitly approved non-production connection, copy the printed FQNs, and follow the chosen skill through implementation, tests and cleanup. Record actual object names/query IDs or deployment URLs only after they exist. This adds time, feature prerequisites and consumption beyond the core lab.

## Check your work

Keep the router/specialist trace, design artifact, negative-case correction and fresh-session review. List which stages ran and which did not. No numerical accuracy or deployment-success claim belongs in a design-only result.

## If it goes sideways

- **A named skill is absent:** inspect the installed equivalent; do not install a random plugin to keep the script moving.
- **The router wants to create resources immediately:** restate the design-only scope and stop before the side effect.
- **UI requirements are vague:** specify interaction pattern and states before authoring screens.
- **Evaluation is only happy-path:** add unknown, ambiguous and denied-access cases.

## What just happened

You followed a maintained workflow through a reviewable handoff and learned exactly where implementation authority and evidence begin.

## Take it further

Package your team's additional standards as a small custom skill in [Lab 83](../83-engineer-a-skill/README.md), without copying or shadowing the bundled workflow unnecessarily.

## Clean up

Keep/remove the design artifact. If you implemented a live route, use that lab's cleanup under the same connection and confirm remaining billable objects. No new resources exist from the core design exercise.

## Sources

[Bundled AI/app skills](https://docs.snowflake.com/en/user-guide/cortex-code/bundled-skills), [Desktop skill invocation](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code-desktop/skills).
