# Lab 25 -- Files into raw tables

| | |
|---|---|
| **Surface** | CoCo Desktop recommended; VS Code + Snowflake extension for Linux; Snowsight upload/SQL route below |
| **Surfaces** | desktop, ide, snowsight |
| **Track** | data-engineering |
| **Sequence** | 50 |
| **Topic** | File ingestion and document extraction |
| **Time** | 35-45 minutes (guidance) |
| **Privileges** | Base workshop role with CREATE PROCEDURE; Python package policy permitting snowflake-snowpark-python; Cortex access for live PDF extraction |
| **Creates** | `COCO_WS_LAB25_DB_<your_user>`, raw tables, file formats, internal stage and your Python stored procedure |
| **Tears down with** | `cleanup.sql` |

## What you will learn

Load CSV, JSON and XML with native COPY; build a Snowflake Python stored procedure that parses a staged HTML table; extract a PDF table without losing its original or its provenance. A stage is a file store, not a raw table. A successful model call is not proof that every table cell is correct.

## Why this matters

A file landing zone often contains structured exports alongside human-readable reports. Treating all of them as CSV loses nesting, source identity or records. CSV, JSON, XML and HTML express the same larger synthetic order set. The PDF deliberately contains only the first 30 orders to bound extraction cost: reconcile it against that subset, not the whole CSV.

## Before you start

Read the [prerequisites](../../docs/PREREQUISITES.html). Open [fixtures/orders.pdf](fixtures/orders.pdf) and [fixtures/orders.html](fixtures/orders.html). All data is synthetic. [fixtures/checksums.json](fixtures/checksums.json) records the original fixture hashes. All files are ready to use. [fixtures/expected.json](fixtures/expected.json) records expected counts, totals and the PDF ID range. No local generator, parser or preconverted HTML CSV is required or included in the customer package.

Run setup once; rerunning it **replaces this lab's database**, including load history:

```bash
snow sql -c <your-connection> -f labs/25-ingest-files/setup.sql
```

Paste the resolved database and warehouse names printed by setup into prompts. CoCo has its own session and cannot see your `$LAB_DB` variable. The setup creates empty raw tables, not preloaded data.

## Step 1 -- Inspect and choose the loading method

```text
Inspect the five orders fixture formats in labs/25-ingest-files/fixtures.
Propose a raw ingestion design before executing anything. Which formats support
native COPY? Preserve nested JSON/XML and original document files. Include file
name, source-row identity and ingestion time. Do not infer PDF accuracy from a
successful API call. Explain which outputs are deterministic and which need review.
```

**What good looks like:** CSV columns stay as raw strings; JSON stays VARIANT; XML stays one document with nested orders. HTML is parsed structurally, never executed. PDF retains both source bytes and the complete extraction response.

## Step 2 -- Upload the original files

Upload the fixtures using the stage's Upload Files UI in Snowsight or the VS Code extension. Select the five original `orders.*` files plus `pdf-fallback.json`. Alternatively run this in a **local SQL client**, replacing the absolute path and user suffix:

```sql
PUT 'file:///absolute/path/to/labs/25-ingest-files/fixtures/*'
  @COCO_WS_LAB25_DB_<your_user>.LAB.FILES
  AUTO_COMPRESS=FALSE OVERWRITE=FALSE;
```

**Snowsight route:** upload through the stage UI, not a local `PUT` command in a worksheet. The HTML procedure runs inside Snowflake for every surface; no local Python runtime is assumed.

**Check:** `LIST @COCO_WS_LAB25_DB_<your_user>.LAB.FILES;` proves bytes arrived, not that rows exist in tables.

## Step 3 -- Native loads and a safe rerun

```text
Load only orders.csv, orders.json and orders.xml from my FILES
stage into their matching RAW tables. Use explicit file selections, metadata
columns and fail-on-error behavior. Show the COPY results, then rerun unchanged
loads without FORCE and compare row counts. Explain the limits of COPY load history.
```

[load.sql](load.sql) is the runnable reference. Native-load results verified on the fixture:

| Table | Records | Precision |
|---|---|---|
| RAW_CSV | 2,000 | exact |
| RAW_JSON | 2,000 | exact |
| RAW_XML | 1 document, containing 2,000 orders | exact |
| RAW_HTML (after Step 4) | 2,000 | exact |

CSV and HTML amounts each sum to **206,820.00 (exact)** after conversion. The comma in `Cable, blue` must stay inside one field. Unchanged recent files are skipped on rerun; this is not permanent exactly-once ingestion. Recreated tables, expired load history, changed filenames/content, or FORCE require an explicit production deduplication design.

## Step 4 -- Prompt CoCo to build a Snowflake Python stored procedure

```text
Build INGEST_ORDERS_HTML() in my resolved LAB schema as a LANGUAGE PYTHON stored
procedure, not a local script or CSV conversion. Inspect RAW_HTML and the actual
staged orders.html first. Show the design and DDL before deployment.
Use SnowflakeFile to read only the fixed FILES/orders.html in this lab and write
only the fully qualified RAW_HTML table. Use Python's HTMLParser, not regex to
parse markup; never execute HTML/scripts or fetch external resources. No external
access integration. Use a supported runtime and snowflake-snowpark-python package.
The runtime supplies session; do not create/close it or USE DATABASE in the handler.
Select exactly one table id=orders, ignore the summary table, decode entities,
preserve commas and quotes, require the exact order_id/item/amount header and
three fields per row. Reject duplicate IDs, bad amounts, nested/spanned cells,
truncated markup and missing/duplicate orders tables BEFORE any write.
Bound file size at 2 MiB and rows at 10,000. These are exercise safety limits.
Preserve raw amount text. Set ORIGINAL_FILE=SOURCE_FILE='orders.html', SOURCE_ROW
to the 1-based data-row ordinal, and retain LOADED_AT. Return parsed/inserted counts
and an explicit skipped status on a sequential rerun. Use one atomic insert and
bound parameters; do not concatenate file content into SQL or insert row-by-row.
Choose execution rights deliberately: an owner-rights version must have fixed
source/destination names and be owned by the workshop role, not an admin. It must
not accept arbitrary URLs, stage paths, SQL or output tables from callers.
No prebuilt parser solution is supplied. Generate the code, tests and CALL yourself.
```

Review and approve the generated DDL, then ask CoCo to deploy and **actually CALL it**. DDL compilation alone does not test the Python runtime, packages or stage access. Run it twice: the first inserts 2,000 rows and the second inserts zero (exact acceptance gates). Inspect `Dock & hub` and `Monitor "wide"` to catch entity/quote handling mistakes.

```text
Test malformed HTML, a missing table, duplicate order IDs and an invalid amount
using isolated parser tests or separate disposable fixtures, never overwriting the
original staged file. Show that errors leave RAW_HTML unchanged. Reconcile every
HTML row against RAW_CSV. Explain why a single-session NOT EXISTS rerun guard is
not a concurrency-safe ingestion ledger, and reject changed-file reloads rather
than silently appending a second copy. Keep the original HTML staged.
```

**What good looks like:** generated code runs in Snowflake, preserves original provenance, validates before writing and returns visible errors. A file replacement under the same name requires a reviewed reload policy; the simple source-name guard intentionally skips it. Do not claim permanent exactly-once processing.

## Step 5 -- PDF extraction, raw response, then rows

**Paid optional step:** review [current AI Functions costs](https://docs.snowflake.com/en/user-guide/snowflake-cortex/aisql-cost) and [AI_EXTRACT requirements](https://docs.snowflake.com/en/sql-reference/functions/ai_extract). This exercise processes only the small supplied PDF. Do not apply it to a whole stage by accident.

```text
Extract the orders table from orders.pdf using AI_EXTRACT's documented table
schema. Save the entire response and extraction method in RAW_DOCUMENTS first.
Then project rows by matching column-array indices, not a cross join. Check the
error, array lengths, IDs, descriptions, numeric casts and total against the PDF
and the matching CSV subset A00001 through A00030. Keep errors visible. Do not overwrite a prior response automatically.
```

Run [extract_pdf.sql](extract_pdf.sql) as reference. `RAW_PDF_LINES` is a view over the stored raw response. The SQL checks for an existing source record to avoid repeat charges in this single-session exercise; that check is not a concurrency-safe uniqueness guarantee.

**If extraction is unavailable:** explicitly choose [load_pdf_fallback.sql](load_pdf_fallback.sql). It loads a manually transcribed synthetic response labeled `MANUAL_FIXTURE_FALLBACK`. This teaches the projection and reconciliation, **not** live extraction. Never report fallback rows as model output.

## Check your work

Run [verify_loaded.sql](verify_loaded.sql) after all loads. Compare EXPECTED and ACTUAL and inspect the final provenance/error output. PDF quality gates are 30 matching orders (A00001-A00030) and total 937.05; these are **acceptance criteria**, not promises about every model run. Array lengths must agree, and every source cell should match. Reject partial or invalid output before downstream use.

```text
Reconcile every source row against its raw representation. Show discrepancies,
not just counts. Demonstrate that the original PDF and HTML remain staged, and
that rerunning unchanged native loads does not add rows. Explain what would break
that property in production.
```

## What just happened

You preserved source bytes, raw payloads, and lineage while using the right loader for each format. JSON/XML structure and document extraction errors remain inspectable instead of disappearing into a guessed relational schema.

## Take it further

Add an explicit checksum-based file ledger, rejected-record table, and a reviewed reprocessing policy. Add schema validation before promotion into curated tables. Keep automatic ingestion as a separate design exercise.

## Clean up

```bash
snow sql -c <your-connection> -f labs/25-ingest-files/cleanup.sql
```

This drops the lab database, stages, tables and your generated stored procedure, not shared compute or local files.
