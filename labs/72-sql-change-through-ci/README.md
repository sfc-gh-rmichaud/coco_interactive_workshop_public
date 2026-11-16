# Lab 72 -- Put a SQL change through CI

| | |
|---|---|
| **Surface** | CoCo Desktop, in its integrated terminal (recommended) -- also the CoCo CLI |
| **Track** | with-coco |
| **Sequence** | 20 |
| **Topic** | DevOps |
| **Time** | 25 minutes |
| **Privileges** | `CREATE DATABASE`. Cortex access for CoCo itself. Step 2 uses `SNOWFLAKE.CORE.GET_LINEAGE`, which needs Enterprise Edition and the `VIEW LINEAGE` privilege -- if you do not have it, the step still works via `ACCOUNT_USAGE.OBJECT_DEPENDENCIES`, just with about three hours of latency. |
| **Creates** | `COCO_WS_LAB72_DB_<your_user>`, plus CI files in your working directory |
| **Tears down with** | `cleanup.sql` |

> **Choose your surface:** follow this lab's Surface row. Desktop is macOS/Windows only; Linux attendees should consult the VS Code/CLI routes in the prerequisites. Lab 74 specifically demonstrates Snowsight Workspaces.

## What you will learn

- How to run CoCo non-interactively, so it can be a build step rather than a conversation.
- Why reviewing a SQL diff is not the same as reviewing a SQL *change*.
- How to write a CI gate that fails for a good reason and passes for a good reason.

## Why this matters

Everything else in this workshop has a human watching. This lab is the one where CoCo runs unattended and returns a verdict a pipeline can act on. That is the difference between a tool an individual likes and a control your team relies on.

The commands below are the same ones a build step would run, so they belong in a terminal. Use **CoCo Desktop's integrated terminal** rather than a separate app: the `cortex` command is already on your `PATH` there, the repo is already open beside it, and you can watch the file CoCo is reasoning about while it reasons. If you would rather use your own terminal, everything here works identically -- it is the same binary.

## The scenario

There is a ticket, DATA-4471:

> Rename `REVENUE_USD` to `REVENUE` in `V_DAILY_REVENUE`. The `_USD` suffix is redundant and it makes the BI field names ugly.

The proposed migration is in [`migrations/002_rename_revenue_column.sql`](migrations/002_rename_revenue_column.sql). It is four lines, it does exactly what the ticket asks, and reviewing the diff will not tell you it is broken.

## The dependency chain

```
ORDERS (table)
  -> V_DAILY_REVENUE (view)      <- the migration changes this
       -> V_EXEC_SUMMARY (view)  <- this references REVENUE_USD by name
```

`CREATE OR REPLACE VIEW` does not validate downstream objects, so the migration **applies successfully** and `V_EXEC_SUMMARY` only fails the next time somebody queries it. In a real account that is usually a dashboard, on a Monday.

## Before you start

> **Your object names carry your user name.** Everything this lab creates at
> account level is suffixed with your Snowflake user, so a whole room can run it
> in one account without collisions: your database is
> `COCO_WS_LAB72_DB_<your_user>`. The last query in `setup.sql` prints the exact
> names -- keep them to hand.
>
> Inside the SQL files those names are built with session variables (`$LAB_DB`).
> **CoCo does not see them,** because it runs its own session. So wherever a step
> below asks you to prompt CoCo, paste the real name rather than `$LAB_DB`.

```bash
snow sql -f labs/72-sql-change-through-ci/setup.sql -c <your-connection>
```

Expected, all **exact**: 20,000 orders, 360 daily rows, 3 executive rows, total revenue **10,070,078**. The revenue total is fully deterministic -- no date predicate enters it -- so if yours differs, the setup did not complete cleanly.

Confirm the command is available. In CoCo Desktop, open the integrated terminal and run:

```bash
cortex --version
cortex exec --help
```

If `cortex` is not found, the Desktop app installs it to `~/.local/bin` -- either add that to your `PATH` or call it as `~/.local/bin/cortex`.

## Steps

### Step 1 -- Review the change the naive way (about 4 minutes)

```bash
cortex exec "Review labs/72-sql-change-through-ci/migrations/002_rename_revenue_column.sql. \
Is this change safe to apply? Explain your reasoning." \
  --allowed "Read" \
  --max-turns 5 \
  -c <your-connection>
```

Note the `--allowed "Read"`: the agent can read files and nothing else. It cannot touch Snowflake.

**What good looks like:** honest uncertainty. With only the file to go on, the correct answer is that the SQL is valid and whether it is *safe* depends on what consumes the column -- which it cannot see. If it declares the change safe, that is the failure this lab is about.

### Step 2 -- Review it with the account in scope (about 6 minutes)

Now let it look at Snowflake.

```bash
cortex exec "Review labs/72-sql-change-through-ci/migrations/002_rename_revenue_column.sql \
against the live account. Check what depends on COCO_WS_LAB72_DB_<your_user>.LAB.V_DAILY_REVENUE and \
whether this change breaks any of it. Give me a clear verdict: SAFE or BREAKING, and name \
the objects affected." \
  --allowed "Read,Snowflake" \
  --max-turns 15 \
  -c <your-connection>
```

**What good looks like:** a `BREAKING` verdict naming `V_EXEC_SUMMARY`, having checked dependencies rather than guessed. `SNOWFLAKE.CORE.GET_LINEAGE` answers this instantly, including for objects created seconds ago. `ACCOUNT_USAGE.OBJECT_DEPENDENCIES` covers similar ground but lags about three hours, so on a freshly created schema it would show nothing -- if the agent uses it and reports "no dependencies", that is a false pass worth catching.

### Step 3 -- Prove the break is real (about 3 minutes)

```bash
snow sql -f labs/72-sql-change-through-ci/migrations/002_rename_revenue_column.sql -c <your-connection>
snow sql -q "SELECT * FROM COCO_WS_LAB72_DB_<your_user>.LAB.V_EXEC_SUMMARY LIMIT 1" -c <your-connection>
```

The migration succeeds. The second command fails:

```
SQL compilation error: invalid identifier 'REVENUE_USD'
```

Two things worth saying out loud. The migration reported success, and the breakage is in a *different object* -- so a pipeline that only checks "did the migration apply" is green while production is broken.

### Step 4 -- Fix it properly (about 4 minutes)

```bash
cortex exec "COCO_WS_LAB72_DB_<your_user>.LAB.V_EXEC_SUMMARY is now broken because REVENUE_USD was \
renamed. Propose a migration that achieves the ticket's goal without breaking consumers, \
explain the trade-off, and tell me what follow-up work it leaves behind." \
  --allowed "Read,Snowflake" \
  --max-turns 15 \
  -c <your-connection>
```

**What good looks like:** an additive change -- expose `REVENUE` and keep `REVENUE_USD` as a deprecated alias -- plus an explicit statement that dropping the old column is a *later* change, gated on migrating consumers. [`migrations/003_add_revenue_alias.sql`](migrations/003_add_revenue_alias.sql) is that version:

```bash
snow sql -f labs/72-sql-change-through-ci/migrations/003_add_revenue_alias.sql -c <your-connection>
snow sql -q "SELECT REGION_CD, TOTAL_REVENUE_USD FROM COCO_WS_LAB72_DB_<your_user>.LAB.V_EXEC_SUMMARY ORDER BY 1" -c <your-connection>
```

The executive view works again and totals 10,070,078.

### Step 5 -- Make it a gate (about 8 minutes)

```bash
cortex exec "Write me a CI job that runs this review automatically on any pull request \
touching migrations/. It must exit non-zero on a BREAKING verdict so the build fails. \
Put the review prompt in .cortex/prompts/review-migration.md and the workflow in \
.github/workflows/. Explain how the exit code is produced and which tools the agent is \
allowed to use." \
  --allowed "Read,Write,Edit" \
  --max-turns 25 \
  -c <your-connection>
```

**What good looks like:** a workflow that pipes the diff into `cortex exec`, uses `--format json` so the verdict is machine-readable, and fails the build on a breaking result. Something along these lines:

```bash
git diff origin/main...HEAD -- migrations/ \
  | cortex exec --file .cortex/prompts/review-migration.md \
      --format json \
      --allowed "Read,Snowflake" \
      --max-turns 20 \
      --no-history \
      -o /tmp/verdict.json \
      -c "$SNOWFLAKE_CONNECTION"
```

Three design points worth pressing on, because they are what make this trustworthy:

- **Least privilege.** `--allowed "Read,Snowflake"` in a review job. A reviewer has no business editing files.
- **A bounded run.** `--max-turns` is a safety ceiling. An unbounded agent in CI is an unbounded bill.
- **A parseable verdict.** `--format json` and `-o` mean the gate depends on structured output, not on grepping prose. Ask it: *what happens if the model phrases the verdict differently next time?* If the answer is "the grep fails", the gate is not reliable.

## Check your work

Run the review against the safe migration and confirm the verdict flips:

```bash
cortex exec "Review labs/72-sql-change-through-ci/migrations/003_add_revenue_alias.sql \
against the live account. Verdict: SAFE or BREAKING?" \
  --allowed "Read,Snowflake" --max-turns 15 -c <your-connection>
```

Expected: `SAFE`, because `REVENUE_USD` still exists.

A gate that only ever fails is as useless as one that only ever passes. This is the test that it discriminates.

## What just happened

You used CoCo as a build step. `cortex exec` disables plan mode, auto-rejects interactive prompts, and returns output a pipeline can parse -- it is designed for exactly this.

The substantive lesson is the difference between Step 1 and Step 2. Same file, same model, different scope: with only the diff, "is this safe" is genuinely unanswerable, and an agent that answers confidently is wrong. With the account in scope it becomes a lookup. The reason this is worth building into CI is that the human reviewer has the same blind spot -- they are reading the diff too.

## Take it further

- Add a second check that verifies every view in the schema still compiles after a migration, and make the gate depend on both.
- Ask what this job costs per pull request, and set a `--max-turns` you would be comfortable defending.
- Point the review prompt at a real migration from your own repo history that caused an incident, and see whether it catches it.
- Look at `cortex automation` for scheduling the same review unattended rather than on a pull request.

## Clean up

```bash
snow sql -f labs/72-sql-change-through-ci/cleanup.sql -c <your-connection>
```

Drops `COCO_WS_LAB72_DB_<your_user>`. The CI files stay in your working directory, which is the point -- they are the thing worth keeping.
