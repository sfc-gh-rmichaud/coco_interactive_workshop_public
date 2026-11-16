# Lab 75 -- Build a real Cortex Agent terminal client

| | |
|---|---|
| **Surface** | CoCo Desktop and its integrated terminal |
| **Surfaces** | desktop |
| **Track** | with-coco |
| **Sequence** | 50 |
| **Topic** | Python and Go developer tooling |
| **Time** | 45-60 minutes for one language; porting is a stretch (guidance) |
| **Privileges** | Workshop object ownership, CREATE AGENT and CREATE PROCEDURE in lab schema, Cortex access, warehouse USAGE; approved REST authentication |
| **Creates** | Lab database, synthetic orders, read-only procedure, Cortex Agent; customer-authored local client and tests |
| **Tears down with** | [cleanup.sql](cleanup.sql), then stop mock and review local outputs |

> This lab builds a client for a **Snowflake Cortex Agent**, not the **CoCo CLI itself** or a coding/research subagent. They are different kinds of agent.

## What you will learn

Build a real command-line client for a synthetic order-support agent through a spec/test/iterate loop. Choose Python for an editable script or Go for a compiled executable. **You build the clients live with CoCo: no completed Python or Go client is included in the customer package.**

## Why this matters

An HTTP 200 does not prove the agent completed an answer or successfully used its tool. Likewise, throughput is successful requests divided by the complete measured wall-clock interval, not the gap between request start times. This is a small application smoke test, not a service load or capacity test.

## Before you start

Open the workshop folder in CoCo Desktop. Check Python 3.11+ (mock and Python route) or Go 1.22+ (Go route). Follow your organization's installation policy. Desktop supports macOS/Windows; Linux attendees can adapt the terminal steps through Lab 73's VS Code extension or CoCo CLI. On Windows, use `python` if that is your launcher.

Run [setup.sql](setup.sql) under your workshop role. It resets only your Lab 75 database; do not rerun after deploying the agent unless you intend to reset it. Copy the printed database, procedure, agent and warehouse names: CoCo cannot read the worksheet's session variables.

The setup supplies **200 synthetic orders (exact)** and an owner-rights `LOOKUP_ORDER(ORDER_ID VARCHAR)` procedure. It resolves the table in its own lab schema even when the REST caller has a different current database. Its owner should be your workshop role, not a production administrator; USAGE exposes this fixed synthetic lookup, not arbitrary SQL, order updates, or external requests. No semantic view or continuously running search service is required.

**Costs:** setup/tool queries use warehouse credits; real agent calls use AI credits. Review current pricing and account eligibility before the live phase. Default to one request, zero warmup and concurrency one. The generated client must cap a live run at six measured requests, one warmup and concurrency two. Those are exercise guardrails, not a dollar cap; do not increase them during the lab. Canceling the client does not guarantee server-side work stops immediately.

## Step 1 -- Deploy the supplied sample agent

The backend is supplied so the exercise can focus on building a client. [agent.template.yaml](agent.template.yaml) specifies a real Cortex Agent with a read-only custom procedure tool, bounded orchestration, and sample questions.

```text
Read this lab's setup.sql and agent.template.yaml. Use the real names printed by
my setup, and verify the procedure and warehouse exist. Make a resolved copy of
the template without changing the shared template. Replace YOUR_LAB_DATABASE
and YOUR_WAREHOUSE. Deploy it as the printed YOUR_AGENT using agent-studio.
Do not replace an unrelated agent or change account settings. Use the workshop
role. Verify the deployed tool resource and instructions. Do not call it yet.
```

If the local CLI supports the agent-studio commands, the resolved YAML can be deployed with `cortex agent-studio agent-deploy --file-path <resolved-file> --fqn <YOUR_AGENT> --connection <your-connection>`. Otherwise use CoCo's agent workflow or the Snowsight agent editor with the same configuration; do not invent an unsupported CLI command.

After approving the small AI cost, test in CoCo or the agent playground:

- `What is the status of ORD-0003 and why is it delayed?`
- `Can you find ORD-9999?`

**What good looks like:** the first answer uses `lookup_order`: `DELAYED`, `Desk lamp`, USD `29.11`, replenishment delay, no confirmed ship date (exact fixture values; wording varies). The second reports not found. Inspect tool output, not just the final prose. A 401/403 is an authentication/access problem, not a reason to broaden grants or disable account policies.

## Step 2 -- Design the terminal client before coding

```text
Build a Cortex Agent smoke-test CLI in a NEW local folder, with a mock mode and
an explicitly enabled live mode. Do not search for or use a completed solution.
Consult the current Snowflake Agent Run REST API and authentication docs first.
Propose flags, output schema, failure rules, and tests before implementation.
Flags: mode, endpoint, agent, role, question, requests, concurrency, warmup,
timeout, format=json|csv. No secrets in flags, source, stdout, stderr or configs.
Use an approved secret store or SNOWFLAKE_PAT environment variable, supplied
outside chat. Never read or print credentials from my existing profiles.
Live mode: HTTPS only, an explicit allowlisted account hostname, verified TLS,
no URL credentials/query strings, no redirects; never forward a token to the mock.
Use the documented agent-object :run endpoint and messages/content request shape.
Make independent single-turn requests; never share a mutable thread across workers.
Send the approved role context compatible with the credential's role restriction.
Handle the actual JSON or SSE response selected by the documented API; do not
assume the mock's {ok:true} schema represents Snowflake. For SSE, parse event
boundaries, multiline data, error events and a terminal completed answer. EOF,
HTTP 200 or a text delta alone cannot establish success. Surface tool errors.
Default live requests=1, concurrency=1, warmup=0; hard caps 6,2,1 respectively.
No automatic retries; record 429s. Bound response bytes and total request duration.
Use monotonic time. Exclude warmup from measurements, but count it in cost budget.
Report requests, successes, errors, elapsed_seconds, success_rps, p50_ms, p95_ms.
Use nearest-rank percentiles over completed successful request durations; null
percentiles if all failed. Use successes/full measured elapsed time for throughput.
Progress on stderr; only JSON/CSV on stdout. Exit 0 on all success, 1 on request
failure, 2 on invalid flags, 130 on cancellation. No misleading partial success.
Keep protocol success separate from answer correctness. Wait for review.
```

Review the proposed contract. See [Agent Run API](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents-run) and [agent management/auth context](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-agents-manage). Role-scoped PATs must match the role used for the request. Do not change your default role or default warehouse blindly to fix a REST error.

## Step 3 -- Build your chosen implementation live

**Python prompt:**

```text
Implement the approved contract as client.py using argparse, urllib, a bounded
ThreadPoolExecutor and a real streaming parser if required. Keep dependencies
minimal. Cancel queued jobs on Ctrl+C; bound active calls by their deadline,
including streams that keep sending bytes. Write statistics and protocol tests.
```

**Go prompt:**

```text
Implement the approved contract as a Go module using flag, net/http, context,
a bounded worker pool, encoding/json and encoding/csv. Bound stream size and
whole-request duration, close response bodies, cancel in-flight calls on Ctrl+C.
Write statistics and protocol tests. Build once before timing measured requests.
```

No prewritten client commands can work before this step. Ask CoCo to print commands for **the files and flags it actually created**, and use `--help` to confirm them.

## Step 4 -- Prove failures locally before sending credentials

Start the supplied credential-free fixture:

```bash
python3 labs/75-build-terminal-tools/mock_server.py --port 8765
```

It accepts POST at `/ok`, `/malformed`, `/unauthorized`, `/throttle`, and `/slow`. Mock mode is restricted to `http://127.0.0.1`; it must not load or send a PAT. This simple JSON fixture tests scheduling and failures, **not the real Agent API protocol**.

```text
Test the CLI against all mock routes. Add synthetic Agent JSON/SSE fixtures
based on the documented protocol: complete answer, tool failure, error event,
truncated stream, split network chunks, multiline data and timeout. No live calls.
Also test invalid concurrency, URL/redirect rejection, all-failed statistics,
warmup exclusion, stdout parsing and Ctrl+C. For latencies [10,20,30,40], nearest-
rank p50=20 and p95=40 ms (exact test input). Show actual test results; fix failures.
```

On Windows manually check Ctrl+C if the test harness cannot send POSIX signals. Python and Go cancellation mechanics can differ; neither may claim an incomplete run succeeded.

## Step 5 -- Run a tiny real-agent comparison

Supply a short-lived approved credential privately, then ask CoCo to run your client against **only your lab agent**. Start with one request asking about `ORD-0003`. Verify the response against the lookup before any concurrency comparison.

If that succeeds and you approve the additional AI cost, compare two measured requests at concurrency one with two at concurrency two, warmup zero. Keep the question and agent fixed. Report both success/error counts and complete-response latency. Such a small sample checks the client; its p95 is not a production service percentile, and faster results do not establish a language performance advantage.

## Optional -- Port and compare

```text
Port my tested tool to the other language, keeping flags, output keys, timing,
percentiles, cancellation and error rules identical. Reuse synthetic protocol
fixtures. Compare interpreter/environment versus compiled executable deployment.
Do not run extra live calls without a reviewed request budget.
```

## Check your work

The agent calls the lookup, unknown IDs stay unknown, secrets never appear in artifacts, mock mode is credential-free, malformed/error/truncated responses fail, and successes divided by elapsed time matches `success_rps`. Keep answer quality separate from transport completion. SQL claims validate the backend fixture, not attendee-generated client code.

## Clean up

Run [cleanup.sql](cleanup.sql) to remove only your Lab 75 database and its agent/procedure/data. Shared warehouse and run log remain. Stop the mock. Review generated local clients/results before deleting them; revoke disposable credentials through your approved process. Clear session environment secrets without printing them.
