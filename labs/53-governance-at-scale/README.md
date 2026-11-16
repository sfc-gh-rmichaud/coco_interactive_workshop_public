# Lab 53 -- Govern a hundred columns without touching a hundred columns

| | |
|---|---|
| **Surface** | CoCo in Snowsight (recommended) -- also CoCo Desktop |
| **Track** | governance |
| **Sequence** | 30 |
| **Topic** | Governance and security |
| **Time** | 35 minutes |
| **Privileges** | `CREATE DATABASE`, plus `CREATE TAG` and `CREATE MASKING POLICY` on the lab schema (Enterprise Edition or higher). Step 4 needs `CREATE ROLE`; it can be read instead of run. |
| **Creates** | `COCO_WS_LAB53_DB_<your_user>` -- four tables with sensitive columns and **no governance**. You add all of it. |
| **Tears down with** | `cleanup.sql` |

> **Choose your surface:** follow this lab's Surface row. Desktop is macOS/Windows only; Linux attendees should consult the VS Code/CLI routes in the prerequisites. Lab 74 specifically demonstrates Snowsight Workspaces.

## What you will learn

- How to classify sensitive columns when their names do not tell you, using the data instead of a regex.
- How to attach protection to a *tag* rather than to a column, so one statement governs every column that carries it -- including columns that do not exist yet.
- The failure mode that silently destroys data: a masked value copied into a derived table, permanently.
- Why views are safe here and `CREATE TABLE AS SELECT` is not.

## Why this matters

Governance fails at scale for a boring reason: it is applied per column, by hand, by someone who has to know which columns matter. That works for four columns and collapses at four hundred. Then a new table lands, nobody tags it, and the gap is invisible until an audit finds it.

Tag-based policies invert the problem. You attach a masking policy to a *tag*, tag the columns, and every current and future column carrying that tag is protected by one statement. The hard part stops being mechanical and becomes the part that actually needs a person: deciding what is sensitive.

And there is one trap in here that is worth the whole lab. Masking protects queries, not values — so a pipeline can read masked data and write the placeholder into a new table as though it were real. Nothing errors. This lab makes that happen in front of you.

## Before you start

> **Your object names carry your user name.** Everything this lab creates at
> account level is suffixed with your Snowflake user, so a whole room can run it
> in one account without collisions: your database is
> `COCO_WS_LAB53_DB_<your_user>`. The last query in `setup.sql` prints the exact
> names.
>
> Inside the SQL files those names are built with session variables (`$LAB_DB`).
> **CoCo does not see them,** because it runs its own session.

```bash
snow sql -f labs/53-governance-at-scale/setup.sql -c <your-connection>
```

| Metric | Value | Precision |
|---|---|---|
| `CUSTOMER_ROWS` | 200 | exact |
| `ORDER_ROWS` | 500 | exact |
| `TICKET_ROWS` | 150 | exact |
| `EMPLOYEE_ROWS` | 40 | exact |
| `TOTAL_COLUMNS` | 24 | exact |
| `COLUMNS_MATCHING_EMAIL` | 5 | exact |

> **Reading the Precision column.** *exact* means that number to the digit, on any
> date and in any account. *within n%* means the figure comes from a hash-based
> sample and moves slightly; anything inside the band is healthy. *guidance* means
> not reproducible -- an order of magnitude, not a target.

Four tables, 24 columns, no tags and no policies. That is the starting position, and 24 columns is already more than anyone wants to protect one at a time.

## Steps

### Step 1 -- Classify, and refuse to do it by column name (about 8 minutes)

```
COCO_WS_LAB53_DB_<your_user>.LAB has four tables. Identify every column holding personal or
confidential data, and for each one tell me how you know -- from the name, the comment, or the
values. Then tell me which columns your classification is least confident about.
```

**What good looks like:** a classification that treats the column names as a hint and the data as evidence. Five columns match `%EMAIL%`, and a name-based approach gets **two of them wrong in opposite directions**:

- **`SUPPORT_TICKETS.SUPPORT_EMAIL` is not personal data.** It is a shared inbox. Masking it protects nothing and breaks every support dashboard. A name-based rule flags it.
- **`CUSTOMERS.REF_CODE` is a national insurance number.** It matches no sensible name pattern at all. A name-based rule misses it entirely — and it is the most sensitive column in the schema.

The empirical test is cheap, and it is what a good answer reaches for:

```sql
SELECT COUNT(*) AS ROWS_,
       COUNT(DISTINCT SUPPORT_EMAIL)  AS DISTINCT_SUPPORT,
       COUNT(DISTINCT REPORTER_EMAIL) AS DISTINCT_REPORTER
FROM COCO_WS_LAB53_DB_<your_user>.LAB.SUPPORT_TICKETS;
```

**1** distinct support address across 150 rows versus **150** distinct reporter addresses (both exact). One value repeated everywhere is an inbox; one value per row is a person. Cardinality answers what naming cannot.

Note also that `EMPLOYEES.SALARY_GBP` is confidential *without* being personally identifying. It needs a different policy from the PII columns, which is why one tag value will not be enough.

**If it goes sideways:** if CoCo classifies purely from names, ask `How many distinct values does SUPPORT_EMAIL have?` and let the data make the argument.

### Step 2 -- Tag the columns, then attach the policy to the tag (about 10 minutes)

The order matters conceptually: the tag is the classification, the policy is the consequence.

```
Create a tag PII_KIND with allowed values for the classes you found, plus a separate tag for
confidential-but-not-personal data. Write masking policies that reveal the real value only to a
PII_READER role and mask it for everyone else. Attach the policies to the TAGS, not to the columns,
then tag every column you classified. Explain what this buys me over per-column policies.
```

**What good looks like:** the tag carrying the policy, so tagging becomes the only per-column action:

```sql
CREATE OR REPLACE TAG PII_KIND
  ALLOWED_VALUES 'email', 'phone', 'name', 'postcode', 'national_id'
  COMMENT = 'Class of personal data held in this column.';

CREATE OR REPLACE MASKING POLICY MASK_PII AS (val VARCHAR) RETURNS VARCHAR ->
  CASE WHEN IS_ROLE_IN_SESSION('PII_READER') THEN val ELSE '***MASKED***' END;

-- One statement. Governs every column carrying the tag, now and in future.
ALTER TAG PII_KIND SET MASKING POLICY MASK_PII;

ALTER TABLE CUSTOMERS       MODIFY COLUMN EMAIL_ADDRESS  SET TAG PII_KIND = 'email';
ALTER TABLE CUSTOMERS       MODIFY COLUMN REF_CODE       SET TAG PII_KIND = 'national_id';
ALTER TABLE ORDERS          MODIFY COLUMN CONTACT_EMAIL  SET TAG PII_KIND = 'email';
ALTER TABLE SUPPORT_TICKETS MODIFY COLUMN REPORTER_EMAIL SET TAG PII_KIND = 'email';
-- and deliberately NOT SUPPORT_TICKETS.SUPPORT_EMAIL
```

Three details worth understanding rather than copying:

- **`ALLOWED_VALUES` is the guard rail that makes this maintainable.** Without it, `'email'`, `'Email'` and `'e-mail'` all become valid classifications and your governance quietly forks.
- **One policy per data type per tag.** A `VARCHAR` masking policy cannot protect `SALARY_GBP`; a `NUMBER` column needs its own policy with a `NUMBER` signature. This is the usual reason a "fully tagged" schema still has holes.
- **`IS_ROLE_IN_SESSION()`, not `CURRENT_ROLE()`.** `CURRENT_ROLE()` only sees the primary role, so a user whose access comes through a secondary role gets masked despite being authorised. This is the single most common bug in hand-written masking policies.

Confirm the coverage rather than assuming it:

```sql
SELECT LEVEL, OBJECT_NAME, COLUMN_NAME, TAG_NAME, TAG_VALUE
FROM TABLE(COCO_WS_LAB53_DB_<your_user>.INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS(
  'COCO_WS_LAB53_DB_<your_user>.LAB.CUSTOMERS', 'TABLE'));
```

### Step 3 -- Break it on purpose: the CTAS trap (about 10 minutes)

This is the most important thing in the lab. **A masking policy protects a query, not a value.**

Have CoCo demonstrate it, or run it yourself. As a role *without* `PII_READER`:

```sql
-- Reading the original: masked, as designed.
SELECT EMAIL_ADDRESS FROM CUSTOMERS LIMIT 1;        -- ***MASKED***

-- Now copy the table, as a pipeline would.
CREATE OR REPLACE TABLE CUSTOMERS_COPY AS SELECT * FROM CUSTOMERS;

SELECT EMAIL_ADDRESS FROM CUSTOMERS_COPY LIMIT 1;   -- ***MASKED***
```

So far this looks fine — reassuring, even. Now grant yourself `PII_READER` and read both:

| Read as `PII_READER` | Result |
|---|---|
| `CUSTOMERS.EMAIL_ADDRESS` | the real address |
| `CUSTOMERS_COPY.EMAIL_ADDRESS` | `***MASKED***` |

**The copy is permanently destroyed.** Verified on a live account: the original returned `a@b.com` while the copy returned `***MASKED***` *to the same authorised role*. The CTAS did not copy the protection — it read the placeholder and stored it as real data. The tag did not follow, and the true value is simply gone.

Nothing errored. No warning. The pipeline succeeded.

```
Explain exactly why the CTAS copy can never be unmasked, and tell me which things in a real Snowflake
account are exposed to this. Then tell me what to do about it.
```

**What good looks like:** the recognition that **anything materialising a query result as a role without unmasking rights** is exposed — dbt models, CTAS backfills, tasks writing summary tables, `COPY INTO` exports to a stage. And the mitigations, roughly in order of usefulness:

1. **Prefer views over materialised copies** for anything crossing a governance boundary. Verified: a view *does* inherit the mask, returning the masked value at query time while leaving the underlying value intact. A view is safe in the exact way a CTAS is not.
2. **Give the pipeline role unmasking rights**, so it reads and writes real values — and then govern the *destination* with the same tags.
3. **Never let a pipeline role read a masked column at all.** If it cannot see it, it cannot bake in a placeholder.
4. **Tag the derived tables too**, which is a rule someone has to remember — and therefore the weakest option, listed last.

### Step 4 -- Prove the coverage, and find what is missing (about 7 minutes)

```
Write me a query that finds every column in this database that is NOT tagged but probably should be.
Then tell me how I would run this check across the whole account, and what it cannot tell me.
```

**What good looks like:** a left join from `INFORMATION_SCHEMA.COLUMNS` to the tag references, plus honesty about the limits. `SNOWFLAKE.ACCOUNT_USAGE.TAG_REFERENCES` covers the whole account and is the right tool for a real audit — with the same caveat as lab 52: **it has latency of up to about two hours**, so a column tagged five minutes ago will look untagged.

The thing it cannot tell you is whether the classification is *correct*. A fully tagged schema where `SUPPORT_EMAIL` is tagged `'email'` scores 100% coverage and is wrong. Coverage is measurable; classification is a judgement, and only one of those two can be automated.

## Check your work

```sql
SET NS     = (SELECT REGEXP_REPLACE(CURRENT_USER(), '[^A-Za-z0-9]', '_'));
SET LAB_DB = 'COCO_WS_LAB53_DB_' || $NS;
USE DATABASE IDENTIFIER($LAB_DB);
USE SCHEMA LAB;

-- The starting position, and the two numbers that defeat a name-based rule.
SELECT
  (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = 'LAB') AS TOTAL_COLUMNS,
  (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = 'LAB' AND COLUMN_NAME ILIKE '%EMAIL%')                AS MATCH_EMAIL_BY_NAME,
  (SELECT COUNT(DISTINCT SUPPORT_EMAIL) FROM SUPPORT_TICKETS)                  AS DISTINCT_SUPPORT_ADDRESSES,
  (SELECT COUNT(DISTINCT EMAIL_ADDRESS) FROM CUSTOMERS)                        AS DISTINCT_CUSTOMER_EMAILS,
  (SELECT COUNT(*) FROM CUSTOMERS WHERE REF_CODE RLIKE '^QQ[0-9]{6}C$')        AS NI_FORMATTED_VALUES;

SHOW TAGS IN SCHEMA;
SHOW MASKING POLICIES IN SCHEMA;
```

Expected, all exact: `TOTAL_COLUMNS` **24**, `MATCH_EMAIL_BY_NAME` **5**, `DISTINCT_SUPPORT_ADDRESSES` **1**, `DISTINCT_CUSTOMER_EMAILS` **200**, `NI_FORMATTED_VALUES` **200** — plus whatever tags and policies you created. Before you start, both `SHOW` commands return nothing.

## What just happened

**The mechanical part scaled; the judgement did not.** One `ALTER TAG ... SET MASKING POLICY` protected every tagged column and every column that will ever carry the tag. Deciding *which* columns — that a shared inbox is not personal data, that `REF_CODE` is a national insurance number — needed a person looking at values.

**Column names are evidence, not classification.** The schema was built so a name-based rule fails in both directions at once. `COUNT(DISTINCT ...)` settled in one query what the names could not.

**Masking protects queries, not values.** The CTAS copy is the finding to take home: an unauthorised role reading a masked column and writing the result creates a table where the placeholder *is* the data, unrecoverable by anyone. Views inherit the mask and are safe. Materialisations do not and are not.

**Coverage is measurable, correctness is not.** You can query for untagged columns. You cannot query for wrongly tagged ones, which is why a coverage percentage is a starting point for a governance conversation rather than the end of one.

## Take it further

- **Row access policies.** Masking hides values within a row; a row access policy removes rows entirely. Ask CoCo when each is the right tool, and what happens when both apply to one query.
- **Tag inheritance.** Set a tag on a *schema* and see which objects inherit it. `TAG_REFERENCES` reports the `LEVEL` for exactly this reason, and it changes how you would govern a hundred tables.
- **Automatic classification.** Snowflake can propose classifications for you. Run it on `CUSTOMERS` and compare its answer to yours -- particularly on `REF_CODE` and `SUPPORT_EMAIL`.
- **Test the secondary-role bug.** Rewrite the policy with `CURRENT_ROLE()` instead of `IS_ROLE_IN_SESSION()`, then read the column as a user whose `PII_READER` comes through a secondary role. Watch an authorised person get masked.
- **Combine with lab 52.** That lab reviews *who* can do things; this one governs *what* they see. Together they are the two halves of an access review.

## Clean up

```bash
snow sql -f labs/53-governance-at-scale/cleanup.sql -c <your-connection>
```

That drops the lab database and everything in it -- tables, tags, masking policies and tag attachments. **If you created a `PII_READER` role**, drop it yourself: roles live at account level and survive the database. And if you tagged anything outside this database while experimenting, find it through `SNOWFLAKE.ACCOUNT_USAGE.TAG_REFERENCES` and unset it there.
