# Lab 83 -- Engineer a skill that survives a fresh session

| | |
|---|---|
| **Surface** | CoCo Desktop and CoCo CLI |
| **Surfaces** | desktop, cli |
| **Track** | advanced-coco |
| **Sequence** | 30 |
| **Topic** | Skill contracts, references and regression tests |
| **Time** | 35-45 minutes (guidance) |
| **Lifecycle** | local-only |
| **Privileges** | Working CoCo sign-in; local Python 3.10+ |
| **Creates** | A local skill and a behavior-test record |
| **Tears down with** | Unregister only practice registrations; remove the practice folder |

## What you will learn

- Separate routing quality from the quality of instructions after loading.
- Use progressive disclosure: small entry point, specific reference files and deterministic helpers.
- Evaluate true positives, false positives and missing evidence without promising identical model wording.

## Why this matters

A long chat can hide a broken skill: the agent already knows the policy and answer. Only a fresh session shows whether the skill carries enough context.

## The scenario

The synthetic release summary says ready. One check failed, another was skipped and rollback evidence is missing. The rule is not "believe the summary" or "skip means pass". The policy is stored in a separate file that the skill must actually load.

## Before you start

```bash
python3 shared/extension_lab/practice.py init --lab 83 --dest ../coco-lab83
```

Windows: use `py -3`. Read the [practice guide](../../shared/extension_lab/README.md). Lab 71 is useful background but not a dependency; all fixtures are supplied here. No account access beyond CoCo inference is required.

## Steps

### Step 1 -- Review a deliberately weak starter

Open `templates/release-review.md`. Its TODOs mark what you must author, not a finished solution. Ask:

```text
Use the installed skill-development audit workflow to review the inert starter
at templates/release-review.md. Do not install or publish it. Identify gaps in
trigger precision, input handling, reference loading, evidence requirements,
output shape and stop conditions. Use the local release fixtures as context.
```

**What good looks like:** a concrete audit distinguishes the description (discovery) from the workflow body (execution). It identifies that a skill prompt is not a tool-permission control.

### Step 2 -- Implement a compact workflow

```text
Author ws-release-review as a workshop-only local skill. Use the current
skill-authoring workflow and its reuse check; this is a synthetic training
exercise, not a replacement for bundled skills. Keep it local and do not publish.
Put input validation, reference loading and output rules in SKILL.md. Keep detailed
release rules in references/release-policy.md, copied from this practice policy.
Read release.json and checks.json from the explicitly supplied practice directory.
Stop if input or policy is missing. Return review-schema.json's structure and
cite source filenames. Do not execute SQL, deploy, or alter evidence.
Explain where paths resolve; do not assume the terminal cwd is the skill folder.
```

Choose the project location documented in [Lab 82](../82-build-slash-commands/README.md) for your surface. A helper is optional; if used, pass paths as arguments and do not concatenate user input into a shell string. A skill that merely calls the supplied fixture checker without reviewing evidence has not completed the learning objective.

**What good looks like:** the entry point tells the agent exactly when to read its policy reference, and missing references are errors rather than an invitation to invent rules. The output contract is short and inspectable.

### Step 3 -- Run the behavior matrix

For each row below, start a **new session**, record whether the skill loaded, and save the observed result. Input descriptions are prompts, not exact-output expectations.

| Case | Request | Expected behavior |
|---|---|---|
| Explicit | Use ws-release-review for REL-204 in this practice folder | Load the practice skill and review evidence |
| Paraphrase | Is REL-204 safe to ship under our workshop release policy? | Matching skill should load; diagnose if it does not |
| Negative trigger | Explain what a release branch is; do not inspect this project | The workshop review skill should not hijack the task |
| Unknown | Review REL-999, without substituting another release | Not found |
| Missing evidence | Temporarily rename the copied checks file, then request REL-204 | Report missing evidence, not READY |
| Contradictory summary | Review REL-204 with the original files | Evidence overrides summary |

Restore the renamed file immediately after that case. Never edit the shipped fixture; work only on the practice copy.

**What good looks like:** your record includes the loaded source, a trace reference and what actually happened. Trigger selection can vary with model/context; record and improve false negatives/positives rather than assert a universal success percentage.

### Step 4 -- Verify the valid report

Save the original-fixture report as `review.json`:

```bash
python3 shared/extension_lab/practice.py verify --dest ../coco-lab83 --report review.json
```

Then ask the audit workflow to improve one specific weakness observed in Step 3. Repeat the failed case and one previously passing case in fresh sessions. Keep evidence for both revisions.

**What good looks like:** the correct decision and rule IDs pass, and a behavior regression would be visible. The checker is only the synthetic fixture oracle, not a general production release policy engine.

## Check your work

Your deliverable is the skill, referenced policy, valid report and behavior matrix. Verify the skill loads from the intended source, uses no account-specific paths, and stops when evidence is unavailable. Static frontmatter validation does not establish successful invocation.

## If it goes sideways

- **Explicit works, paraphrase fails:** check discoverability and description, then retry a fresh session.
- **Skill loads, wrong verdict:** inspect reference reads and policy logic, not only the description.
- **Reference missing:** resolve relative to the skill's base directory or supply an explicit path; do not rely on cwd.
- **Team skill shadows practice skill:** use a unique workshop name and confirm its source.

## What just happened

You tested both routing and execution. The skill is useful because it moves reliable context into a maintained artifact, not because it is long.

## Take it further

Use the audit/refactor workflows on a larger local skill. Consider a deterministic helper only for stable rules; keep ambiguous decisions in the reviewed workflow. Continue with [Lab 86](../86-package-a-plugin/README.md).

## Clean up

Restore fixture filenames, unregister any practice-only skill folder, and remove the practice directory when finished. Keep or share your authored skill only after reviewing its contents and choosing a destination/audience explicitly. This lab does not publish it.

## Sources

[CLI extensibility](https://docs.snowflake.com/en/user-guide/cortex-code/extensibility), [Desktop skills](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code-desktop/skills).
