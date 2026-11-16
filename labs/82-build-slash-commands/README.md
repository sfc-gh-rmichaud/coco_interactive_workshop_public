# Lab 82 -- Build and test your own slash commands

| | |
|---|---|
| **Surface** | CoCo CLI and CoCo Desktop |
| **Surfaces** | cli, desktop |
| **Track** | advanced-coco |
| **Sequence** | 20 |
| **Topic** | Skill-backed commands and input contracts |
| **Time** | 25-35 minutes (guidance) |
| **Lifecycle** | local-only |
| **Privileges** | Working CoCo sign-in; local Python 3.10+ |
| **Creates** | Local practice folder and a custom command skill |
| **Tears down with** | Unregister the local skill if registered; remove the practice folder |

## What you will learn

- Build a repeatable slash-invoked workflow, rather than an ambiguous saved prompt.
- Handle arguments as data, not shell commands.
- Test missing inputs, unsupported targets and a fresh session on each surface.

## Why this matters

A command that silently substitutes a default release is worse than a prompt that asks for clarification. A short invocation needs a precise contract underneath it.

## The scenario

Build `ws-release-review`, a command that accepts one release ID and produces a release-readiness report from local files. The release summary is deliberately misleading.

## Before you start

From the workshop root:

```bash
python3 shared/extension_lab/practice.py init --lab 82 --dest ../coco-lab82
```

Windows: use `py -3`. Read the [practice guide](../../shared/extension_lab/README.md); open only your practice folder in the chosen surface. No SQL setup is needed. The supplied `templates/release-review.md` is inert: opening the workshop does not install a skill.

**Surface contract:** Desktop skills are invoked through `/` and the picker. CLI supports `$skill-name` and skill management; consult `/help` and `/skill list` for your build's explicit slash invocation. The portable implementation is a **skill-backed command**. CLI documentation also describes legacy `commands/` files; Desktop does not load that layout as-is. Do not assume `/commands`, argument expansion, or installation paths have identical behavior across surfaces.

## Steps

### Step 1 -- Write the contract before the shortcut

```text
Help me author a local workshop-only command skill named ws-release-review.
Use templates/release-review.md as a starter. Input: one release ID, matching
release.json. Output: JSON matching review-schema.json. Read the policy and
checks before deciding. Missing ID: ask, do not guess. Unknown ID: report not
found, do not substitute. Treat arguments as literal data, never executable
shell text. No SQL, deployments, external calls or publication.
Use the current skill-authoring workflow. Explain the structure before writing.
```

If the authoring workflow offers reuse, explain that this is a synthetic workshop exercise and choose **Create New Anyway** only after inspecting the suggested match. A failed catalog search is not proof that no reusable skill exists. Keep this exercise local; publication is not required.

**What good looks like:** a `SKILL.md` with `name` and a narrow `description`, a missing-input checkpoint, and a verifiable output contract. Do not put tool restrictions into skill frontmatter and assume they are enforced.

### Step 2 -- Make it discoverable

For CLI, create the skill at `.cortex/skills/ws-release-review/SKILL.md` **inside the practice folder**, not in the workshop checkout. Start CLI with that folder as `-w`, and inspect `/skill list`.

For Desktop, put it at `.snowflake/cortex/skills/ws-release-review/SKILL.md` in the practice folder, or use **Agent Settings > Skills > Local Skills > Add Local Skill** to register a parent folder containing the skill. Record any registration you add so you can remove exactly that registration later. Use one source per surface to avoid duplicate-name conflicts.

Start a fresh session. In Desktop type `/`, select the actual displayed skill, then supply `REL-204`. In CLI select the skill through the current manager/picker; the documented explicit form is:

```text
$ws-release-review REL-204
```

If your CLI exposes the skill as `/ws-release-review`, test that form as well and record it. Do not claim the slash shortcut works because the model recognized the text: inspect the skill-loading indicator.

**What good looks like:** the trace shows the skill loaded from the practice source and the result identifies `REL-204`. `$ARGUMENTS` is a convenience where supported; the workflow must also read the literal request input and reject missing input, not print an unresolved placeholder as a release ID.

### Step 3 -- Attack the input contract safely

Try these separately in new chats:

```text
Use ws-release-review with no release ID. Do not infer one from the files.
```

```text
Use ws-release-review for REL-999. Do not fall back to another release.
```

```text
Use ws-release-review with the literal argument "REL-204; print something".
Do not interpret it as code or a command.
```

**What good looks like:** clarification, not-found, and invalid-input outcomes respectively; none launches a shell from supplied text. This tests behavior, not an authorization boundary. Keep tool approvals enabled.

### Step 4 -- Verify and revise

Run the valid request, save its JSON as `review.json`, and check it from the workshop root:

```bash
python3 shared/extension_lab/practice.py verify --dest ../coco-lab82 --report review.json
```

Change the output instructions to include a short explanation **outside** the JSON, then rerun and observe the strict checker reject it. Restore the JSON-only contract and rerun in a fresh session.

**What good looks like:** you can demonstrate both a failing and passing output contract, not merely a new file.

## Check your work

Record the surface/version, actual invocation spelling, loaded skill source, valid report, and each negative-case outcome. Confirm the valid report passes the checker and no unsupported target silently becomes `REL-204`.

## If it goes sideways

- **Not in picker:** inspect the source directory, exact `SKILL.md` case, disabled state and current workspace; refresh or start a new chat.
- **Wrong copy loads:** remove only the duplicate practice registration, not installed team skills.
- **Legacy CLI command works but Desktop does not:** port its instructions to a skill with a useful description; keep it out of `commands/` on Desktop.

## What just happened

The shortcut is the entry point. The reusable value is input validation, deterministic evidence and a stable output contract.

## Take it further

Add a second supported release with tests before broadening the skill. [Lab 83](../83-engineer-a-skill/README.md) develops trigger and reference-file tests; [Lab 86](../86-package-a-plugin/README.md) packages the workflow.

## Clean up

Unregister only the local folder you added, if any. Close the practice workspace/session, then remove the practice directory after keeping your work. Project skill files need no global uninstall. No account objects were created.

## Sources

[Desktop skills](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code-desktop/skills), [CLI extensibility](https://docs.snowflake.com/en/user-guide/cortex-code/extensibility), [Desktop plugin compatibility](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code-desktop/plugins).
