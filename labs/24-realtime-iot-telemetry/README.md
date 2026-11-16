# Lab 24 -- Stream IoT telemetry in, and watch it live

| | |
|---|---|
| **Surface** | CoCo Desktop -- its integrated terminal runs the `node` and `npm` commands |
| **Track** | data-engineering |
| **Sequence** | 40 |
| **Topic** | Data engineering |
| **Time** | 40 minutes |
| **Privileges** | `CREATE DATABASE`, plus `CREATE PIPE` on the lab schema. Key-pair auth configured on your user (the lab shows how). Node.js 20 or later. The optional section needs `CREATE WAREHOUSE`. |
| **Creates** | `COCO_WS_LAB24_DB_<your_user>` -- setup makes the pipeline but **no data**. The rows are the lab. |
| **Tears down with** | `cleanup.sql` |

> **Choose your surface:** follow this lab's Surface row. Desktop is macOS/Windows only; Linux attendees should consult the VS Code/CLI routes in the prerequisites. Lab 74 specifically demonstrates Snowsight Workspaces.

## What you will learn

- How to get rows into Snowflake continuously with the Snowpipe Streaming high-performance SDK, where a `PIPE` and not a table is what the client binds to.
- Why streaming ingest is not synchronous, how long the lag actually is, and how to measure it rather than guess.
- Three failure modes that produce no error at all: a mistyped column key, a JSON string in a `VARIANT`, and a timezone mismatch that empties your dashboard.
- Where an interactive table earns its cost on a live dashboard, and where a plain view is the better answer.

## Why this matters

Batch pipelines are forgiving. If a nightly load is wrong you find out in the morning and fix it before anyone looks. Streaming is not forgiving in the same way, and the reason is specific: **most of its failure modes are silent.** Nothing throws. The SDK logs look healthy. Rows are simply missing, or NULL, or invisible, and the only way to know is to go and check.

This lab plants three of those silent failures on purpose, then makes you measure your way out of each. By the end you will have a live dashboard reading data that is a handful of seconds old, and — more usefully — you will know how to tell the difference between "the pipeline is slow" and "the pipeline is broken".

## Before you start

> **Your object names carry your user name.** Everything this lab creates at
> account level is suffixed with your Snowflake user, so a whole room can run it
> in one account without collisions: your database is
> `COCO_WS_LAB24_DB_<your_user>`. The last query in `setup.sql` prints every
> value the simulator and the dashboard need — keep it on screen.
>
> Inside the SQL files those names are built with session variables (`$LAB_DB`).
> **CoCo does not see them,** because it runs its own session.

```bash
snow sql -f labs/24-realtime-iot-telemetry/setup.sql -c <your-connection>
node --version    # must be 20 or later
```

Setup creates a landing table, a streaming `PIPE`, and three views. It creates **no rows**, which is the one confirm figure worth stating:

| Check | Value | Precision |
|---|---|---|
| `ROWS_NOW` | 0 | exact |
| `VIEWS_CREATED` | 3 | exact |
| `SHOW PIPES` &rarr; `kind` | `STREAMING` | exact |

> **Reading the Precision column.** *exact* means that number to the digit, on any
> date and in any account. *within n%* means the figure comes from a hash-based
> sample and moves slightly; anything inside the band is healthy. *guidance* means
> not reproducible -- an order of magnitude, not a target.

That `kind = STREAMING` is worth a second look. A pipe built over a stage reports `DEFAULT`; only a pipe declared `FROM TABLE(DATA_SOURCE(TYPE => 'STREAMING'))` will accept an SDK channel. Getting this wrong is the one streaming mistake that *does* fail loudly, and it is the last one that will.

### Key-pair authentication

The SDK authenticates with a key pair (or a PAT, from SDK 1.4.0). If you have not set one up:

```bash
openssl genrsa 2048 | openssl pkcs8 -topk8 -inform PEM -out rsa_key.p8 -nocrypt
openssl rsa -in rsa_key.p8 -pubout -out rsa_key.pub

# Then, as a role that can alter your user:
PUBK=$(grep -v KEY- rsa_key.pub | tr -d '\012')
echo "ALTER USER <your_user> SET RSA_PUBLIC_KEY='$PUBK';"
```

Confirm the key Snowflake has matches the one on disk, because a mismatch fails with a generic JWT error that tells you nothing:

```bash
openssl rsa -pubin -in rsa_key.pub -outform DER | openssl dgst -sha256 -binary | openssl enc -base64
```

That should equal the `RSA_PUBLIC_KEY_FP` in `DESCRIBE USER <your_user>`, minus the `SHA256:` prefix.

## Steps

### Step 1 -- Get the simulator running (about 8 minutes)

```bash
cd labs/24-realtime-iot-telemetry/queries/simulator
npm install
cp profile.example.json profile.json
# Edit profile.json with the values setup.sql printed.
```

`profile.json` is gitignored, because it names your account and points at your private key. `profile.example.json` is the template that is committed.

The account identifier is the field people get wrong: the SDK wants the `ORGNAME-ACCOUNTNAME` form, which `setup.sql` prints as `YOUR_ACCOUNT_IDENTIFIER`, and **not** the account locator. A locator gets you a confusing 404 from the ingest host rather than an auth error.

```bash
node simulate_devices.js
```

**What good looks like:** a channel opens and a counter ticks up every two seconds. On the reference run, five devices across two sites produced **295 rows in 59 batches over 118 seconds** — that is guidance, since it depends entirely on how long you leave it going.

```
channel open (new)
t+118s  batches=59  rows sent=295
flushing...
done. sent 295 rows in 59 batches.
```

**If it goes sideways:** a bare `Failed to convert JavaScript value 'Undefined' into rust type 'String'` means an option name is wrong. `openChannel` takes `name`, not `channelName`, and returns `{ channel, status }` rather than the channel directly. The error does not point anywhere near the cause.

### Step 2 -- Measure the ingest lag before you trust anything (about 6 minutes)

Do this before building the dashboard. If you skip it you will spend the dashboard step wondering whether your SQL is wrong.

Start the simulator, and in another terminal poll:

```sql
SELECT COUNT(*) FROM COCO_WS_LAB24_DB_<your_user>.LAB.SENSOR_READINGS;
```

**What good looks like:** zero for several seconds, then a jump. Measured on the reference run: rows appended and flushed at **t+7s** were not visible until **t+16s** — so roughly **ten seconds** from flush to queryable. Treat that as guidance; it is a distributed commit, not a fixed interval.

This is the lab's central trap, and it is worth stating plainly: **`appendRows()` returns immediately, returns nothing, and does not mean your data is in Snowflake.** It is fire-and-forget. `client.close()` flushes and waits, and *that* is what commits. Every "streaming is broken" report starts with someone querying too early.

Ask CoCo to make the design consequence explicit:

```
I am streaming rows into Snowflake with the Snowpipe Streaming SDK. appendRows() returns instantly
but rows take about ten seconds to become queryable. What does that mean for how I build a dashboard
on top, and what should I NOT do in a request handler?
```

**What good looks like:** the point that a request handler must never append-then-read and expect its own write back, and that anything needing read-after-write consistency does not belong on a streaming path. A good answer also mentions offset tokens: each batch here carries one, so a crashed and restarted client resumes from the last persisted token instead of double-counting.

### Step 3 -- Check the two silent corruptions (about 6 minutes)

Both of these land data successfully and wrongly.

```sql
-- 1. Did PAYLOAD arrive as an object, or as a string that looks like one?
SELECT TYPEOF(PAYLOAD) AS PAYLOAD_TYPE, COUNT(*)
FROM COCO_WS_LAB24_DB_<your_user>.LAB.SENSOR_READINGS
GROUP BY 1;

-- 2. Did every column actually get populated?
SELECT COUNT(*) AS ROWS_,
       COUNT_IF(TEMP_C IS NULL)     AS NULL_TEMP,
       COUNT_IF(SITE_NAME IS NULL)  AS NULL_SITE
FROM COCO_WS_LAB24_DB_<your_user>.LAB.SENSOR_READINGS;
```

**What good looks like:** `PAYLOAD_TYPE` is **`OBJECT`** and both NULL counts are **0** (both exact).

If `PAYLOAD_TYPE` is `VARCHAR`, the simulator passed `JSON.stringify(...)` instead of a native object. It stores fine, no error, and then every `PAYLOAD:key` lookup downstream returns NULL forever. `TYPEOF()` is the only thing that tells you.

If a NULL count is not zero, a key in the row object does not match a column name. The pipe uses `MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE`, so an unmatched key is silently dropped and the column arrives NULL. Rename `TEMP_C` to `TEMPC` in the simulator and watch it happen — no error, no warning, just a column of NULLs.

### Step 4 -- Build the live dashboard (about 12 minutes)

```bash
cd labs/24-realtime-iot-telemetry/queries/dashboard
npm install
cp .env.example .env.local     # fill in from setup.sql's output
npm run dev                    # http://localhost:3024
```

A Next.js app with one API route and one page: the route holds the Snowflake connection server-side and returns JSON, the page polls it every two seconds and redraws a Recharts line chart.

**What good looks like:** four stat tiles, a temperature line per site, and an alerts table that **starts empty and fills in while you watch** — the simulator injects a fault into `press-02` after about 90 seconds, and vibration climbs from there. On the reference run that produced **9 alert rows from one device, peaking at 10.27mm** (guidance).

Two design choices in that app worth understanding rather than copying:

- **Polling, not websockets.** The ingest lag is several seconds, so a push channel would spend nearly all its time pushing nothing. A poll interval comfortably shorter than your pipeline's latency is the right relationship; two seconds against a ten-second lag qualifies.
- **One reused connection.** Opening a Snowflake connection per poll would spend more time authenticating than querying. The route memoises it — and deliberately does *not* cache a failed connection, or one bad start would poison every later request until restart.

**If the dashboard is empty but the table has rows,** you have hit the third silent failure. Read on.

### Step 5 -- The timezone trap (about 5 minutes)

This one cost real time while the lab was being written, and it is the most insidious of the three.

The devices send UTC. `READING_TS` is `TIMESTAMP_NTZ` — a wall clock with no zone attached — so the stored values are UTC. But **`CURRENT_TIMESTAMP()` is not UTC**: it returns a zone-aware timestamp in the *session's* timezone. So this, which looks obviously correct, is wrong:

```sql
-- WRONG when the column holds UTC.
WHERE READING_TS >= DATEADD('minute', -15, CURRENT_TIMESTAMP())
```

Measured on this account (`America/Los_Angeles`), the dashboard's "behind live" figure came out at **-24,910 seconds** — about minus seven hours. Rows appeared to arrive from the future.

See it for yourself:

```sql
SELECT DATEDIFF('second', MAX(READING_TS), SYSDATE())            AS LAG_SYSDATE,
       DATEDIFF('second', MAX(READING_TS), CURRENT_TIMESTAMP())  AS LAG_CURRENT_TS
FROM COCO_WS_LAB24_DB_<your_user>.LAB.SENSOR_READINGS;
```

On the reference run: `LAG_SYSDATE` **290**, `LAG_CURRENT_TS` **-24910**.

**And it fails in opposite directions depending on where you are.** West of UTC the readings look like the future, so a "last 15 minutes" filter passes them regardless of age and your dashboard shows stale data as though it were live. East of UTC they look old, the filter discards perfectly fresh rows, and the dashboard is simply empty with nothing obviously wrong. A demo that works in London and fails in Sydney is this bug.

`SYSDATE()` returns the current UTC time as `TIMESTAMP_NTZ`, so it compares like with like. Every view in `setup.sql` uses it; inspect the view definitions and check that none has drifted back.

```
My readings are TIMESTAMP_NTZ holding UTC. Explain the difference between CURRENT_TIMESTAMP(),
SYSDATE(), LOCALTIMESTAMP() and CONVERT_TIMEZONE() here, and tell me which to use for a
"last 15 minutes" filter and why the others are wrong.
```

## Optional -- put an interactive table under the dashboard

Only if you have `CREATE WAREHOUSE` and want to see it. **Read the cost note first.**

**Check this is available to you before you start.** Interactive warehouses are GA in selected regions only, and `setup.sql`'s preflight prints your region so you can compare. Nothing in the main lab depends on this section, so if the first statement below fails with an unsupported-feature error, skip the section — you have not missed anything the rest of the lab needs.

> **An interactive warehouse is the most expensive thing this workshop can leave
> running.** Its minimum `AUTO_SUSPEND` is 86400 seconds — 24 hours — and it bills
> a minimum of one hour every time it resumes. It will not quietly go to sleep
> after a minute like the workshop's XSMALL warehouse does. `cleanup.sql` drops it,
> and it is an account-level object, so dropping the lab database does **not**
> remove it. Run the cleanup.

```sql
CREATE OR REPLACE WAREHOUSE COCO_WS_LAB24_IW_<your_user>
  WAREHOUSE_TYPE = 'INTERACTIVE'
  WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 86400
  INITIALLY_SUSPENDED = TRUE;

CREATE OR REPLACE INTERACTIVE TABLE IT_SITE_TELEMETRY
  TARGET_LAG = '60 seconds'
  WAREHOUSE = COCO_WS_WH_<your_user>    -- NOTE: the standard warehouse
  CLUSTER BY (SITE_NAME)
AS SELECT SITE_NAME, TIME_SLICE(READING_TS, 10, 'SECOND') AS BUCKET_TS,
          COUNT(*) AS READINGS, AVG(TEMP_C) AS AVG_TEMP_C
   FROM SENSOR_READINGS
   GROUP BY 1, 2;
```

**The `WAREHOUSE` there is the *refresh* warehouse and must be a standard one.** Passing the interactive warehouse fails with `010425 (42601): Warehouse '...' must not be an interactive warehouse.` The interactive warehouse is what you *query* it with:

```sql
USE WAREHOUSE COCO_WS_LAB24_IW_<your_user>;
SELECT * FROM IT_SITE_TELEMETRY ORDER BY BUCKET_TS DESC LIMIT 20;
```

**And then be honest about whether it helped.** `TARGET_LAG` has a 60-second floor, which is *longer than the ingest lag you measured in step 2*. So for this dashboard an interactive table is strictly worse on freshness than the plain view, in exchange for cheaper reads. That trade makes sense for a dashboard with many concurrent viewers hitting the same aggregate, and it does not make sense here. Knowing which situation you are in is the actual skill.

## Check your work

```sql
SET NS     = (SELECT REGEXP_REPLACE(CURRENT_USER(), '[^A-Za-z0-9]', '_'));
SET LAB_DB = 'COCO_WS_LAB24_DB_' || $NS;
USE DATABASE IDENTIFIER($LAB_DB);
USE SCHEMA LAB;

SELECT COUNT(*)                                  AS ROWS_,
       COUNT(DISTINCT DEVICE_ID)                 AS DEVICES,
       COUNT(DISTINCT SITE_NAME)                 AS SITES,
       TYPEOF(MAX(PAYLOAD))                      AS PAYLOAD_TYPE,
       COUNT_IF(TEMP_C IS NULL)                  AS NULL_TEMPS,
       DATEDIFF('second', MAX(READING_TS), SYSDATE()) AS SECONDS_BEHIND
FROM SENSOR_READINGS;

SELECT COUNT(*) AS ALERT_ROWS, COUNT(DISTINCT DEVICE_ID) AS ALERT_DEVICES
FROM V_VIBRATION_ALERTS;
```

Expected while the simulator is running: `DEVICES` **5** and `SITES` **2** (both exact), `PAYLOAD_TYPE` **`OBJECT`** (exact), `NULL_TEMPS` **0** (exact), `SECONDS_BEHIND` in the low tens, and `ALERT_DEVICES` **1** once the fault has had 90 seconds to develop. `ROWS_` depends on how long you ran it.

## What just happened

You built a streaming pipeline and then spent most of the lab checking whether it was lying to you, which is the correct ratio.

**The pipe is the contract, not the table.** The high-performance SDK binds to a `PIPE`, which owns the mapping into the table. That is why the client code never names a column list — and also why a mistyped key is silently dropped rather than rejected.

**Three failures, no errors between them.** A JSON string in a `VARIANT` lands as `VARCHAR`. A mistyped key lands as `NULL`. A session-local timestamp compared against UTC data yields a window that means something different in every timezone. None of these throws. `TYPEOF()`, a NULL count, and `SYSDATE()` are the three cheap checks that catch them, and they belong in your pipeline permanently, not just in a lab.

**Freshness is a number, not an adjective.** You measured the lag rather than describing the pipeline as "realtime". That number is what tells you a two-second poll is sensible, that read-after-write is off the table, and that a 60-second `TARGET_LAG` is the wrong tool for this particular dashboard.

## Take it further

- **Kill the simulator mid-batch and restart it.** Offset tokens mean it resumes from the last persisted token rather than replaying. Confirm the row count does not double.
- **Break a column name on purpose,** run for thirty seconds, and see how long it takes you to notice from the dashboard alone. This is the argument for a NULL-rate check in your pipeline.
- **Add an alert.** Have CoCo write a Snowflake alert on `V_VIBRATION_ALERTS` that notifies when a device crosses the threshold, so the fault does not need somebody watching a screen.
- **Push the dashboard to SPCS.** Lab 42 does exactly this for a React app over Snowflake Postgres; the same approach applies here, and this app is deliberately small enough to make a reasonable second attempt.
- **Compare the cost.** Lab 62 will show these runs as credits. Streaming bills per GB ingested rather than per warehouse-second, so it is a genuinely different line item from everything else in this workshop.

## Clean up

```bash
snow sql -f labs/24-realtime-iot-telemetry/cleanup.sql -c <your-connection>
```

That drops the lab database **and** the optional interactive warehouse. Do not skip it if you created the interactive warehouse — that one bills in hour-long minimums and will not auto-suspend for a day.

The Node.js projects are just files on your machine. Delete the folders if you want the space, and remember that `queries/simulator/profile.json` and `queries/dashboard/.env.local` hold your account details.
