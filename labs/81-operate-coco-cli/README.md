# Lab 81 -- Operate CoCo CLI like a development tool

| | |
|---|---|
| **Surface** | CoCo CLI (recommended); CoCo Desktop for comparison |
| **Surfaces** | cli, desktop |
| **Track** | advanced-coco |
| **Sequence** | 10 |
| **Topic** | CLI sessions, context and bounded automation |
| **Time** | 30-40 minutes (guidance) |
| **Lifecycle** | local-only |
| **Privileges** | Working CoCo sign-in; local Python 3.10+; no database privileges |
| **Creates** | A new local practice folder and review artifacts; no Snowflake objects |
| **Tears down with** | Unregister lab extensions if added, then remove only your practice folder |

## What you will learn

- Distinguish `cortex` (CoCo CLI), `coco` (Desktop editor launcher), and `snow` (Snowflake CLI).
- Control the connection, working directory and session context instead of relying on defaults.
- Separate a successful agent process from a correct review, and interactive planning from batch execution.

## Why this matters

A review of the wrong directory can sound completely reasonable. A batch process can exit successfully while its findings are incomplete. This lab makes both errors observable.

## The scenario

A synthetic release desk contains a release marked ready in a summary, but its underlying checks disagree. You must decide whether to ship using the evidence, not the summary. No real customer or account data is required.

## Before you start

Read the [extension practice guide](../../shared/extension_lab/README.md). From the workshop root, create a **new, empty-name** practice destination outside the workshop checkout:

```bash
python3 shared/extension_lab/practice.py init --lab 81 --dest ../coco-lab81
cortex --version
cortex --help
cortex exec --help
```

On Windows use `py -3` instead of `python3`; paths and the remaining arguments are the same in PowerShell. Replace `../coco-lab81` with your chosen path consistently. The initializer refuses any existing destination, including an empty directory; choose a new name to restart. It prints the resolved directory and Python executable.

The fixtures are local. CoCo inference still requires your approved Snowflake connection and can incur AI charges. Do not select production by habit. CLI flags below were checked against v1.2.8; check your installed help before using them. No global configuration is changed by the initializer.

## Steps

### Step 1 -- Choose the context deliberately

Start an interactive session, replacing both placeholders:

```bash
cortex -c <approved-connection> -w <absolute-practice-path> --plan --no-mcp
```

Type this **inside CoCo**, not in your shell:

```text
Review only this synthetic practice directory. Do not query Snowflake, fetch
external information, run deployments, or edit files. Read release-policy.md,
release.json and checks.json. Propose how you will establish release readiness.
Name the exact directory and evidence files you will use. Wait before executing.
```

**What good looks like:** the plan names the practice directory, not the workshop repository. It requires checks and rollback evidence rather than trusting `release.json`'s readiness label. Inspect the actual plan/mode indicator. A sentence saying "read-only" is not an OS sandbox.

### Step 2 -- Execute and collect evidence

Approve the read-only review, then ask:

```text
Perform that review. Return the release ID, READY or BLOCKED, and a findings
list with rule_id, source file and evidence for every blocker. Separate facts
from recommendations. Do not fix anything. Explain why the summary alone is
insufficient. Give me JSON matching review-schema.json.
```

Save only the returned JSON to `review.json` in the practice directory, using the editor. Check it with:

```bash
python3 shared/extension_lab/practice.py verify --dest ../coco-lab81 --report review.json
```

**What good looks like:** the checker accepts the correct decision and required rule IDs. It checks factual coverage against the fixture; it does not certify the quality of prose or that the model actually read a file. The transcript provides that second kind of evidence.

### Step 3 -- Resume, then start fresh

Record the session ID. Exit normally and resume that exact session:

```bash
cortex -c <approved-connection> -w <absolute-practice-path> --resume <session-id> --no-mcp
```

Ask which evidence supported the last decision. Then start a **new** session without `--resume` and rerun Step 2 with the policy and filenames explicitly named. Compare results. Use `/help` to find your version's session/context controls; do not assume `/clear` only clears the screen. Recent releases distinguish clearing context from clearing terminal output.

**What good looks like:** the fresh session can reproduce the decision from files without relying on the earlier explanation. If it cannot, your request or saved evidence is incomplete.

### Step 4 -- Run a bounded batch review

Inspect `batch-review.txt`, then run from your normal terminal:

```bash
cortex exec -c <approved-connection> -w <absolute-practice-path> --file <absolute-practice-path>/batch-review.txt --no-mcp --allowed read --max-turns 8 --output-last-message <absolute-practice-path>/batch-review.json
```

Use `cortex exec --help` to confirm the permission syntax for your build. This example permits only the runtime `read` tool, not shell execution, SQL or writes. If your build uses different permission aliases, resolve them from its help/runtime rather than grant all tools. The output file is written by the CLI output option.

`exec` has **no interactive plan approval**: it disables plan mode and auto-rejects questions. Interactive slash commands do not work inside its prompt file. Eight turns is a safety ceiling (guidance), not an expected usage figure. An incomplete result at the limit is a failed review, not permission to remove all controls.

```bash
python3 shared/extension_lab/practice.py verify --dest ../coco-lab81 --report batch-review.json
```

**What good looks like:** both process status and the independent report check succeed. If JSON is wrapped in a code fence or an explanation, the strict checker fails; refine the output contract rather than silently stripping arbitrary text in a production pipeline.

### Step 5 -- Compare Desktop

Open the same practice folder in Desktop (`coco <absolute-practice-path>` if the launcher is installed). Start a new chat, choose Plan mode, and repeat Steps 1-2. Review the file/tool trace and save a separate report. Desktop's visual diff/session controls and CLI shell automation are different interfaces to related work; do not assume session IDs can be moved between them.

## Check your work

- The reported directory is the practice folder.
- The transcript contains reads of policy and checks, not a guessed verdict.
- Interactive and batch reports pass the deterministic checker.
- The fresh-session replay uses only saved evidence.
- No SQL or deployment was executed.

## If it goes sideways

- **Wrong files:** exit and fix `-w`; do not broaden filesystem access.
- **Batch asks a question:** supply the missing input up front; do not enable bypass.
- **Read tool denied:** inspect the installed permission syntax; names in agent definitions and CLI permission patterns can differ.
- **No `coco` executable:** open the folder through Desktop or install its launcher from the Command Palette. Do not substitute `code`.

## What just happened

You made the environment and output contract explicit. Session continuity is convenient, but reproducibility comes from files and checks, not remembered chat.

## Take it further

Proceed to [Lab 82](../82-build-slash-commands/README.md) to package the prompt, or [Lab 85](../85-delegate-subagents/README.md) to compare independent reviewers. Keep automation local until a real scheduling and permission model has been reviewed.

## Clean up

Close the sessions. Review the practice directory for anything worth keeping, then delete that directory in your file manager. Do not delete shared CoCo configuration, history or credentials. There is no SQL cleanup.

## Sources

[CLI reference](https://docs.snowflake.com/en/user-guide/cortex-code/cli-reference), [CLI changelog](https://docs.snowflake.com/en/user-guide/cortex-code/changelog). The current public export has no end-to-end surface validation; help/schema validation alone is not an end-to-end run.
