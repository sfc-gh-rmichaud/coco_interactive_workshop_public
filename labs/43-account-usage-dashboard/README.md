# Lab 43 -- Build an account usage dashboard

| | |
|---|---|
| **Surface** | CoCo in Snowsight for the guided build; Desktop for the supplied CLI reference deployment |
| **Surfaces** | snowsight, desktop |
| **Track** | app-dev |
| **Sequence** | 30 |
| **Topic** | Streamlit account observability |
| **Time** | 40-60 minutes (guidance) |
| **Privileges** | Base workshop role; `SNOWFLAKE.USAGE_VIEWER` for live telemetry; selected Streamlit runtime privileges |
| **Creates** | `COCO_WS_LAB43_DB_<your_user>`, demo fixture, app files and Streamlit object |
| **Tears down with** | `cleanup.sql`; do not drop an existing shared compute pool |

## What you will learn

Ask CoCo to build, validate and deploy an account-wide usage app. Keep credits, tokens and storage/transfer volume separate; preserve missing-data states; avoid counting the same spend twice.

## Why this matters

A dashboard can compile and still be financially misleading. Adding Cortex product totals to an account metering total double-counts activity. Summing daily storage snapshots is not stored capacity. An inaccessible view is not zero usage.

Lab 41 teaches a business-facing app. Lab 62 attributes workshop activity. This lab builds a reusable account-usage tool.

## Before you start

Run [setup.sql](setup.sql) with the workshop role and keep the resolved names. The tiny January 2026 fixture has **4 rows, 29 gross credits, -2 cloud-services adjustment and 27 billed credits (all exact, synthetic)**. These are not this account's usage or a price quote.

Ask an administrator for the optional usage bundle in [role setup](../../shared/00_admin_role_setup.sql). Prefer `SNOWFLAKE.USAGE_VIEWER` to broad imported privileges. Use a dedicated app-owner role with only the telemetry and app-object rights required. Sharing an owner-rights app can expose account-wide usage to its viewers; do not create or broadly share it as ACCOUNTADMIN.

The core prompts work in Snowsight without local npm, Go, or a local terminal. Select an available Streamlit runtime during creation and check its requirements. The supplied Desktop reference deploy uses container runtime and a verified existing compute pool; it is not a prerequisite to the browser walkthrough.

## Step 1 -- Discover sources and define totals

```text
Plan an account-wide usage dashboard for the last 7 complete days, bounded to at
most 30 days per query. Inspect actual ACCOUNT_USAGE columns and available grants.
Create a source/metric/unit/latency/access matrix before writing the app.
Use METERING_DAILY_HISTORY for the metered credit overview, including gross,
cloud-services adjustment and billed credits. Include all service types rather
than silently dropping new ones. Keep every service detail separate from that
total. Do not convert credits or bytes to dollars without contracted rates.
```

**What good looks like:** an explicit accounting boundary, not a sum of unrelated views. The source adapters in [reference_app/sources.py](reference_app/sources.py) illustrate the following coverage; verify them against your account, not against memory:

| Area | Source | Unit / limitation |
|---|---|---|
| Metered services and cloud adjustment | METERING_DAILY_HISTORY | Used and billed credits; includes serverless/other reported service types |
| Compute | WAREHOUSE_METERING_HISTORY | Gross compute/cloud-services credits; overlaps overview |
| CoCo interfaces | SNOWFLAKE_COCO_USAGE_HISTORY | Credits/tokens split by interface; IDE uses CLI backend |
| Agents / CoWork | CORTEX_AGENT_USAGE_HISTORY / SNOWFLAKE_COWORK_USAGE_HISTORY | Separate product views; do not add nested usage blindly |
| Analyst | CORTEX_ANALYST_USAGE_HISTORY | Credits/requests; no token column |
| AI SQL functions | CORTEX_AI_FUNCTIONS_USAGE_HISTORY | Credits plus token metrics when reported; page-based units may differ |
| Search | CORTEX_SEARCH_DAILY_USAGE_HISTORY | Serving/embedding credits; tokens apply to embedding, not serving |
| REST inference | CORTEX_REST_API_USAGE_HISTORY | Tokens; no credits column |
| Training / provisioned capacity | CORTEX_FINE_TUNING_USAGE_HISTORY / CORTEX_PROVISIONED_THROUGHPUT_USAGE_HISTORY | Training tokens/credits; reserved-capacity credits, not request tokens |
| Guardrails | CORTEX_AI_GUARDRAILS_USAGE_HISTORY | Reported credits/tokens; separate drill-down |
| Storage | STORAGE_USAGE | Daily average database/stage/Fail-safe/hybrid/archive bytes; not cumulative |
| Network transfer | DATA_TRANSFER_HISTORY | Bytes by route/type; not credit charges |
| Replication | REPLICATION_USAGE_HISTORY / REPLICATION_GROUP_USAGE_HISTORY | Credits and bytes; separate overlapping drill-downs |

Other AI features may have product-specific views in your account. Extend the source matrix deliberately; this inventory is not a claim that all future products expose the same fields. Coverage must say unavailable where a source/metric is absent.

## Step 2 -- Specify the interaction before coding

```text
Design a native Streamlit app with a date-range filter, explicit Demo/Live mode,
and sections Overview, AI, Compute, Storage and transfer, and Coverage.
Use clear metric cards, a service-type bar chart, a chart/detail toggle where
useful, and downloadable aggregates. Query only the selected drill-down rather
than all hidden tabs. Include a Refresh button and a short cache TTL. Show source,
units, last query time, reporting period and latency caveats on every section.
Give permission-denied, unavailable, empty, loading and error states real text.
Do not hide errors behind zeroes or switch to demo automatically. Propose the UI
and wait before building it.
```

**What good looks like:** the user can distinguish no rows, missing telemetry, and denied access. The app uses a bounded inclusive-start/exclusive-end window and never interpolates untrusted identifiers into SQL.

## Step 3 -- Build, test, deploy

```text
Build the approved app in my lab schema using the active Snowflake session or
hosted Snowflake connection, not embedded credentials. Aggregate in SQL and cache
bounded results with account/role context in the key. Do not grant the app to
PUBLIC. Verify the runtime and its dependencies before deployment. Compare the
Demo overview to the fixed fixture, then each selected Live query to its source.
Show the actual Streamlit object and URL; a deploy exit code alone is not proof.
```

**Snowsight:** create a Streamlit app in the lab database/schema, choose the permitted runtime and warehouse, and let CoCo generate/edit the app files. Use the runtime's package selector for supported dependencies. If your current CoCo tools cannot publish, use the Streamlit UI to run the files and report that manual step accurately.

**Desktop reference:** [streamlit_app.py](reference_app/streamlit_app.py) and [sources.py](reference_app/sources.py) provide a working starting point adapted from the Snowflake compute dashboard scaffold. They default to an explicit synthetic Demo overview and execute only the chosen Live source. The reference uses sidebar section navigation instead of eagerly evaluated tabs.

Discover the default compute pool and validate that it exists:

```sql
SHOW PARAMETERS LIKE 'DEFAULT_STREAMLIT_COMPUTE_POOL' IN ACCOUNT;
SHOW COMPUTE POOLS;
```

Generate your own deploy manifest from the verified values (do not deploy another attendee's manifest):

```bash
python3 labs/43-account-usage-dashboard/reference_app/configure.py --database <your-lab-database> --schema LAB --warehouse <your-workshop-warehouse> --compute-pool <verified-pool>
snow streamlit deploy --project labs/43-account-usage-dashboard/reference_app -c <your-connection> --prune
```

The manifest explicitly packages both Python files, not the local development dependency file. `--prune` removes default files created by Snowflake that are absent from this new lab app's artifact list; use it only on your disposable lab app, not an app with unrelated files. For your own subsequent edits add `--replace --prune`. The app uses `st.connection('snowflake')`; local runs select a named profile through `SNOWFLAKE_DEFAULT_CONNECTION_NAME`, while hosted runs use the platform default. This avoids an unnecessary PyPI EAI when the runtime already supplies the dependencies. Do not create a new compute pool or enable external access simply to bypass a deployment error.

## Step 4 -- Verify a boundary, not just a chart

```text
Prove the overview reconciles gross credits plus cloud adjustment to billed
credits. Show that selecting a service changes the displayed subtotal without
adding drill-down totals. Test a role with no USAGE_VIEWER, an empty date range,
and an unavailable source. Keep NULL token metrics as unavailable, not zero.
Explain which viewer can see this app's data under its actual execution model.
```

**Check your work:** the synthetic overview reconciles to 27 billed credits (exact). An empty Live source shows a no-rows message. A denied source shows an access error and no synthetic data. REST inference has no fabricated credit number. Storage daily averages are not summed into a capacity KPI. All account usage is reporting-lagged; the current day is excluded by default, but yesterday can still be incomplete.

Use `SHOW STREAMLITS IN SCHEMA COCO_WS_LAB43_DB_<your_user>.LAB;` and open the app. Limit downloads to authorized audiences. Account telemetry is not workshop fixture data and must not be checked into the repository or handoff archive.

## What just happened

You built an observability app with an explicit data contract. The hardest part was defining honest metrics and access boundaries, not drawing the chart.

## Take it further

Add source-specific freshness tests, budget links, serverless drill-down adapters, user-tag attribution, and a role-reviewed sharing workflow. Currency reconciliation belongs in a separate billing exercise with actual contracted rates.

## Clean up

Run [cleanup.sql](cleanup.sql) to drop the lab database/app. Do not drop or suspend the existing system/shared compute pool. Remove local telemetry exports separately.

Sources: [Account Usage](https://docs.snowflake.com/en/sql-reference/account-usage), [database roles](https://docs.snowflake.com/en/sql-reference/snowflake-db-roles), and the linked view references in the Coverage source inventory.
