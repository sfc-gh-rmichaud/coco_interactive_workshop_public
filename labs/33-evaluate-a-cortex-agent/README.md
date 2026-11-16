# Lab 33 -- Evaluate a Cortex Agent, then make it measurably better

| | |
|---|---|
| **Surface** | CoCo in Snowsight (recommended) -- also CoCo Desktop |
| **Track** | ai-agents |
| **Sequence** | 30 |
| **Topic** | AI agents |
| **Time** | 35 minutes |
| **Privileges** | `CREATE DATABASE`, `SNOWFLAKE.CORTEX_USER`, `USE AI FUNCTIONS` on account, `EXECUTE TASK` on account, plus `CREATE AGENT`, `CREATE DATASET`, `CREATE STAGE` and `CREATE FILE FORMAT` on the lab schema. |
| **Creates** | `COCO_WS_LAB33_DB_<your_user>` -- including the agent under test, so this lab is self-contained. |
| **Tears down with** | `cleanup.sql` |

> **Choose your surface:** follow this lab's Surface row. Desktop is macOS/Windows only; Linux attendees should consult the VS Code/CLI routes in the prerequisites. Lab 74 specifically demonstrates Snowsight Workspaces.

## What you will learn

- How to score an agent on more than whether its final answer was right, using Snowflake's four system metrics.
- Why a perfect answer-correctness score can hide an agent that is choosing tools badly -- demonstrated, not asserted.
- How to write ground truth that an LLM judge can actually grade, and where a dataset design quietly stops being able to detect anything.
- How to change an agent and prove the change helped, rather than reading a few replies and deciding it feels better.

## Why this matters

Lab 32 built an agent and checked it by reading its answers. That is how nearly everyone evaluates an agent, and it has a specific blind spot: **a fluent, correct answer tells you nothing about how the agent got there.** An agent that calls three tools where one would do is right, slow and expensive. An agent that reaches the right answer from the wrong evidence is right until the data shifts.

This lab starts from a working agent whose answers are genuinely correct -- and shows you, with numbers, that it is nevertheless doing the job badly. Then you fix it and watch the numbers move.

You do not need lab 32 first. This lab creates its own agent.

## The metrics, and what each one is for

Snowflake's system metrics follow a Goal-Plan-Action framing: rather than grading only the final answer, they grade each stage of how the agent got there.

| Metric | Stage it grades | Needs ground truth | Deterministic |
|---|---|---|---|
| `tool_selection_accuracy` | goal to plan: did it call the right tools? | yes, `ground_truth_invocations` | yes |
| `tool_execution_accuracy` | plan to action: was each call sensible in and out? | yes, `ground_truth_invocations` | no (LLM judge) |
| `answer_correctness` | action back to goal: is the final answer right? | yes, `ground_truth_output` | no (LLM judge) |
| `logical_consistency` | the whole loop: do instructions, plan and calls agree? | **no** | no (LLM judge) |

`tool_selection_accuracy` is the one to understand properly, because it is the metric that catches the failure in this lab. It scores `matched tools / max(expected tools, actual calls)`. Order does not matter. Crucially, **it penalises extra calls exactly as hard as missing ones**: expecting one tool and calling two scores 0.5, the same as expecting two and calling one.

## Before you start

> **Your object names carry your user name.** Everything this lab creates at
> account level is suffixed with your Snowflake user, so a whole room can run it
> in one account without collisions: your database is
> `COCO_WS_LAB33_DB_<your_user>`. The last query in `setup.sql` prints the exact
> names -- keep them, you will paste them into a YAML file.
>
> Inside the SQL files those names are built with session variables (`$LAB_DB`).
> **CoCo does not see them,** because it runs its own session.

```bash
snow sql -f labs/33-evaluate-a-cortex-agent/setup.sql -c <your-connection>
```

Setup creates the policy documents and their search service, the ticket data and a semantic view over it, **the agent under test**, six evaluation inputs with ground truth, and a stage for the evaluation config.

The confirm queries should show:

| Metric | Value | Precision |
|---|---|---|
| `POLICY_DOCS` | 4 | exact |
| `TICKETS` | 6,000 | exact |
| `EVAL_INPUTS` | 6 | exact |
| Iberia P1 breach rate | about 55% | within 5% |
| Iberia mean P1 hours | about 4.3 | within 5% |
| Every other region's P1 breaches | 0 | exact |

> **Reading the Precision column.** *exact* means that number to the digit, on any
> date and in any account. *within n%* means the figure comes from a hash-based
> sample and moves slightly; anything inside the band is healthy. *guidance* means
> not reproducible -- an order of magnitude, not a target.

Two things to notice in that answer key, because the whole lab turns on them:

- **The four-hour P1 target appears in exactly one policy document and nowhere in the ticket data.** So any question about whether a region met its target genuinely needs both tools. An agent that answers from the tickets alone is inventing the target.
- **Iberia's mean P1 time is about 4.3 hours against a four-hour target, while about 55% of its P1 tickets breach.** The average is only just over the line. An agent reasoning from the average lands on the right verdict almost by accident, and the same reasoning would say "compliant" for a region whose average sat at 3.9 with half its tickets over. That is the difference between a right answer and a right method.

## Steps

### Step 1 -- Look at the agent you are about to judge (about 4 minutes)

```
Describe the agent COCO_WS_LAB33_DB_<your_user>.LAB.SUPPORT_AGENT_V1. Show me its instructions and
its tool descriptions. Then tell me, from those alone, what kinds of question it is likely to get
wrong and why. Be concrete about which tool it will reach for.
```

**What good looks like:** CoCo should notice that the instructions say nothing about which tool answers which kind of question, and that the Analyst tool's description claims it covers "SLA compliance" when the ticket data holds no targets. A sharp answer predicts that the agent will either answer policy questions from the numbers, or call both tools for everything because it has no basis for choosing.

Hold on to that prediction. Step 3 tests it.

### Step 2 -- Build the dataset and the config (about 8 minutes)

The inputs already exist in `AGENT_EVAL_INPUTS`. Turn them into a dataset:

```sql
USE DATABASE COCO_WS_LAB33_DB_<your_user>; USE SCHEMA LAB;

CALL SYSTEM$CREATE_EVALUATION_DATASET(
  'Cortex Agent',
  'COCO_WS_LAB33_DB_<your_user>.LAB.AGENT_EVAL_INPUTS',
  'COCO_WS_LAB33_DB_<your_user>.LAB.SUPPORT_EVALSET',
  OBJECT_CONSTRUCT('query_text', 'INPUT_QUERY', 'expected_tools', 'GROUND_TRUTH')
);
```

**Two mapping traps here, both worth knowing before they cost you twenty minutes:**

1. **The mapping key is `expected_tools` in SQL and `ground_truth` in YAML.** Same concept, two names, depending on which path creates the dataset. Using the YAML name in the SQL call fails.
2. **`OBJECT_CONSTRUCT` is correct *here*, in the mapping argument, but wrong in the ground truth column.** The dataset's ground truth must be `VARIANT`, and `OBJECT_CONSTRUCT` returns `OBJECT`. `setup.sql` uses `PARSE_JSON` for exactly this reason. If you build your own inputs with `OBJECT_CONSTRUCT`, the insert succeeds and dataset creation is what breaks.

Now the config. Copy [`queries/evaluation_config.yaml`](queries/evaluation_config.yaml), replace `<YOUR_USER>`, and upload it:

```sql
PUT file://<path>/evaluation_config.yaml @COCO_WS_LAB33_DB_<your_user>.LAB.EVAL_CONFIG
  AUTO_COMPRESS=FALSE OVERWRITE=TRUE;
```

Three things about that file that are not obvious and all of which bite:

- **There is no `dataset:` block, on purpose.** If you leave one in, Snowflake tries to create the dataset on *every* run, and the second run fails saying the dataset already exists -- even when you only changed `run_name`. Create the dataset once, reference it by name.
- **The metrics are pinned to `v3`.** The default is `v1`, whose judge model `claude-4-sonnet` went legacy on 12 August 2026: only accounts that had already used it can still use it as a judge, so on a newer account an unpinned run **fails** rather than falling back. Pinning also keeps runs comparable, because scores from different metric versions are not.
- **The stage needs the `YAML_FILE_FORMAT` that setup created** (`TYPE=CSV`, `FIELD_DELIMITER=NONE`). With default CSV settings the YAML is mangled, and the error blames your YAML rather than the file format.

### Step 3 -- Run the baseline and read it properly (about 8 minutes)

```sql
CALL EXECUTE_AI_EVALUATION(
  'START',
  OBJECT_CONSTRUCT('run_name', 'baseline-v1'),
  '@COCO_WS_LAB33_DB_<your_user>.LAB.EVAL_CONFIG/evaluation_config.yaml'
);

-- Poll. Expect a few minutes: the agent answers all six queries, then the
-- judges score them.
CALL EXECUTE_AI_EVALUATION(
  'STATUS',
  OBJECT_CONSTRUCT('run_name', 'baseline-v1'),
  '@COCO_WS_LAB33_DB_<your_user>.LAB.EVAL_CONFIG/evaluation_config.yaml'
);
```

`STATUS` moves through `INVOCATION_IN_PROGRESS`, then `COMPUTATION_IN_PROGRESS`, then `COMPLETED`. On the reference run the whole thing took a little over two minutes.

Then read the scores:

```sql
SELECT METRIC_NAME,
       COUNT(*)                        AS RECORDS,
       ROUND(AVG(EVAL_AGG_SCORE), 3)   AS AVG_SCORE,
       ROUND(MIN(EVAL_AGG_SCORE), 2)   AS WORST
FROM TABLE(SNOWFLAKE.LOCAL.GET_AI_EVALUATION_DATA(
  'COCO_WS_LAB33_DB_<your_user>', 'LAB', 'SUPPORT_AGENT_V1', 'CORTEX AGENT', 'baseline-v1'))
GROUP BY 1 ORDER BY 1;
```

**What good looks like** -- and this is the moment the lab exists for. The reference run scored:

| Metric | Baseline score | Precision |
|---|---|---|
| `answer_correctness` | 1.00 | guidance |
| `tool_selection_accuracy` | about 0.78 | guidance |
| `logical_consistency` | about 0.73 | guidance |

**Answer correctness was perfect.** Every one of the six answers was right. If you had evaluated this agent the way lab 32 does -- by reading its replies -- you would have shipped it and been satisfied.

And yet it is doing the job badly, which the other two metrics say plainly. Look per record:

```sql
SELECT LEFT(INPUT, 55) AS QUERY_, METRIC_NAME, EVAL_AGG_SCORE
FROM TABLE(SNOWFLAKE.LOCAL.GET_AI_EVALUATION_DATA(
  'COCO_WS_LAB33_DB_<your_user>', 'LAB', 'SUPPORT_AGENT_V1', 'CORTEX AGENT', 'baseline-v1'))
WHERE METRIC_NAME = 'tool_selection_accuracy'
ORDER BY EVAL_AGG_SCORE;
```

On the reference run, the shape of the failure was consistent and specific: the purely-numeric question ("how many tickets are still open, by region") scored **0.5**, because the agent called the document search as well as the Analyst tool. Expecting one tool and calling two is 0.5. The two-tool questions also lost points for making more calls than needed. The three questions it scored 1.0 on were the two pure-policy questions and the out-of-scope one, where it correctly called nothing at all.

So the measured diagnosis is not "it answers wrongly". It is **the agent has no basis for choosing a tool, so it reaches for everything** -- which costs latency and tokens on every single request, and is the behaviour that breaks first when the questions get harder.

> **Why these are labelled guidance.** Three of these metrics are scored by an LLM
> judge, and the agent's own tool choices vary between runs. Your numbers will not
> match these to two decimal places and are not supposed to. What is reproducible
> is the *shape*: answer correctness at or near 1.0, and tool selection and
> logical consistency visibly below it. If you see that, the lab is working.

### Step 4 -- Fix it, and prove the fix (about 10 minutes)

```
Here is the agent spec for COCO_WS_LAB33_DB_<your_user>.LAB.SUPPORT_AGENT_V1, and here are its
evaluation results: answer_correctness 1.0, tool_selection_accuracy 0.78, logical_consistency 0.73.
The per-record scores show it calls the document search even for questions that are purely counts.

Create SUPPORT_AGENT_V2 with the same tools but instructions and tool descriptions that fix this.
Do not change the semantic view or the search service. Explain which change targets which metric.
```

**What good looks like:** four specific changes, and CoCo should be able to say what each is for.

- **An orchestration instruction that routes by where the answer lives** -- policy questions to search, counting questions to Analyst, comparisons to both -- *and* an explicit instruction not to call a tool whose answer it does not need. That last clause is what recovers the 0.5 scores.
- **Honest tool descriptions.** The baseline claimed the Analyst tool covered "SLA compliance". It cannot; the ticket data has no targets. That description is the invitation to answer a policy question from numbers.
- **A response instruction forbidding an assumed target**, and requiring the breach *share* rather than the average -- because Iberia's average sits just over the line and the average is not the right evidence.
- **Sample questions covering all three shapes**, which is planning context the baseline never had.

The reference implementation is [`queries/reference_agent_v2.sql`](queries/reference_agent_v2.sql). Then re-run, against the same dataset, changing only the agent name and run name in the config:

| Metric | Baseline v1 | Improved v2 | Precision |
|---|---|---|---|
| `answer_correctness` | 1.00 | 1.00 | guidance |
| `tool_selection_accuracy` | about 0.78 | **1.00** | guidance |
| `logical_consistency` | about 0.73 | **1.00** | guidance |

That is the measured result on the reference run: both process metrics went to a perfect score, and answer correctness did not move because it had nowhere to go. The agent now answers the same questions correctly *and* calls only the tools it needs.

**If it goes sideways:** if v2 scores no better, check whether the orchestration instruction actually says *not to call unnecessary tools*. Routing guidance alone tends to leave the agent hedging by calling both anyway. If a run fails at start with a model error, your account cannot use the judge for the metric version you pinned -- see the note on `v3` in step 2.

### Step 5 -- Break the dataset, and see the blind spot (about 5 minutes)

A metric can only catch what your dataset asks about. Test that claim rather than believing it.

```
Add a seventh input to AGENT_EVAL_INPUTS: a question the agent should answer using only the ticket
data, but give it ground_truth_invocations listing BOTH tools. Re-run the evaluation and tell me
what happens to tool_selection_accuracy, and which of the two -- the agent or my ground truth --
the metric is actually blaming.
```

**What good looks like:** the score drops, and the agent did nothing wrong. Tool selection accuracy compares against what *you* declared, so wrong ground truth reads exactly like a wrong agent. A good answer makes the uncomfortable point explicit: **these metrics measure agreement with your dataset, not correctness in the abstract.** A dataset of only happy-path questions produces a reassuring score that means very little, which is why the seeded set includes an out-of-scope question with an empty expected-tool list.

## Check your work

```sql
SET NS     = (SELECT REGEXP_REPLACE(CURRENT_USER(), '[^A-Za-z0-9]', '_'));
SET LAB_DB = 'COCO_WS_LAB33_DB_' || $NS;
USE DATABASE IDENTIFIER($LAB_DB);
USE SCHEMA LAB;

-- Both runs side by side. This is the artefact worth keeping.
WITH v1 AS (
  SELECT METRIC_NAME, AVG(EVAL_AGG_SCORE) S
  FROM TABLE(SNOWFLAKE.LOCAL.GET_AI_EVALUATION_DATA(
    $LAB_DB, 'LAB', 'SUPPORT_AGENT_V1', 'CORTEX AGENT', 'baseline-v1')) GROUP BY 1),
v2 AS (
  SELECT METRIC_NAME, AVG(EVAL_AGG_SCORE) S
  FROM TABLE(SNOWFLAKE.LOCAL.GET_AI_EVALUATION_DATA(
    $LAB_DB, 'LAB', 'SUPPORT_AGENT_V2', 'CORTEX AGENT', 'improved-v2')) GROUP BY 1)
SELECT v1.METRIC_NAME,
       ROUND(v1.S, 3) AS BASELINE,
       ROUND(v2.S, 3) AS IMPROVED,
       ROUND(v2.S - v1.S, 3) AS DELTA
FROM v1 JOIN v2 ON v1.METRIC_NAME = v2.METRIC_NAME
ORDER BY 1;
```

You are looking for a positive `DELTA` on `tool_selection_accuracy` and `logical_consistency`, and roughly zero on `answer_correctness`. The exact values are not the point and will not reproduce; the direction is.

## What just happened

You measured an agent that was, by the only test most people apply, perfect -- and found two real problems in how it worked.

**The headline metric was the least informative one.** Answer correctness was 1.0 before and after. Had you tracked only that, you would have concluded there was nothing to improve, and you would have been wrong twice over: the agent was making unnecessary tool calls on every request, and its planning was inconsistent with its own instructions.

**The fix was instructions, not models or data.** No change to the semantic view, the search service, or the orchestration model. The agent was capable all along; it had not been told how to choose. That is the usual finding, and it is cheap to act on.

**The metrics only know what your dataset tells them.** Step 5 made that concrete: bad ground truth is indistinguishable from a bad agent. The dataset is the instrument, and an instrument nobody checks is not a measurement.

**Ground truth has to be written for a judge, not for a human.** The seeded ground truth states literal values, names the document a target must come from, and says what a wrong answer would look like. "Should mention the SLA" is not gradeable. Every input is also scoped to absolute dates, because "last quarter" scores differently every time you run it.

## Take it further

- **Pin the agent version.** The runs above targeted the live version, which is mutable, so two runs can differ for reasons unrelated to your dataset. Commit a version and set `agent_version: "VERSION$1"` before comparing anything you care about.
- **Add `tool_execution_accuracy`.** It grades the input and output of each call rather than just which tool was chosen -- so it catches an agent that calls the right tool with a poorly-formed question. The seeded ground truth already has the `tool_input` and `tool_output` fields it needs.
- **Write a custom metric.** Ask CoCo for one that fails any answer stating an SLA target without citing the document it came from. Custom metrics see the whole trace through `{{tool_info}}`, so they can check process, not just prose.
- **Schedule it.** `EXECUTE_AI_EVALUATION` can be called from a task, so the evaluation becomes a regression test that runs on a schedule with an alert on a threshold. That is the point at which "we evaluated the agent" turns into "we would know if it regressed".
- **Grow the dataset from real traffic.** Snowsight's Evaluations tab can build a dataset from production monitoring data, which is a far better source of hard questions than anything written at a desk.

## Clean up

```bash
snow sql -f labs/33-evaluate-a-cortex-agent/cleanup.sql -c <your-connection>
```

That drops the lab database, taking both agents, the semantic view, the search service, the dataset, the config stage and every evaluation run's traces with it.
