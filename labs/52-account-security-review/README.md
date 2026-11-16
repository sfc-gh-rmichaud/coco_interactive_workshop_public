# Lab 52 -- Review an account against security best practice

| | |
|---|---|
| **Surface** | CoCo in Snowsight (recommended) -- also CoCo Desktop |
| **Track** | governance |
| **Sequence** | 20 |
| **Topic** | Governance and security |
| **Time** | 30 minutes |
| **Privileges** | `CREATE DATABASE` for the seeded half. The review half needs `IMPORTED PRIVILEGES` on `SNOWFLAKE` (i.e. read access to `ACCOUNT_USAGE`), which most analyst roles do not have -- ask, or run that half with an admin watching. |
| **Creates** | `COCO_WS_LAB52_DB_<your_user>` -- seeded audit tables only. **Nothing outside it, and nothing is changed.** |
| **Tears down with** | `cleanup.sql` |

> **This lab is read-only against your account.** It creates no user, grants and revokes nothing, attaches no policy and changes no parameter. It reads `ACCOUNT_USAGE` and tells you what it sees. Any remediation is a decision for whoever owns that account, taken deliberately and outside this lab.

> **Choose your surface:** follow this lab's Surface row. Desktop is macOS/Windows only; Linux attendees should consult the VS Code/CLI routes in the prerequisites. Lab 74 specifically demonstrates Snowsight Workspaces.

## What you will learn

- How to write the handful of queries a Snowflake security review actually rests on, and check them against a known answer before trusting them.
- Why "who has ACCOUNTADMIN?" answered by direct grant is wrong by more than half, and how to answer it properly.
- The four ways an `ACCOUNT_USAGE`-based audit quietly produces wrong findings, all of which look like clean output.
- How to turn a list of findings into something someone will act on rather than file.

## Why this matters

Security review is a genre with a specific failure mode: **the report looks the same whether it is right or wrong.** A query that misses inherited privileges returns rows, sorted, with plausible names in them. A query that forgets deleted users returns *more* rows, which feels like thoroughness. Nobody reading the output can tell.

The only defence is to check your queries against data whose answers you already know. So this lab gives you that: seeded audit tables that mirror the real `ACCOUNT_USAGE` views, shape for shape, with findings planted at known counts. You get the queries right there — then point them at your own account, where nobody knows the answer.

## Before you start

> **Your object names carry your user name.** Everything this lab creates at
> account level is suffixed with your Snowflake user, so a whole room can run it
> in one account without collisions: your database is
> `COCO_WS_LAB52_DB_<your_user>`. The last query in `setup.sql` prints the exact
> names.
>
> Inside the SQL files those names are built with session variables (`$LAB_DB`).
> **CoCo does not see them,** because it runs its own session.

```bash
snow sql -f labs/52-account-security-review/setup.sql -c <your-connection>
```

Setup creates four seeded tables — `AUDIT_USERS`, `AUDIT_ROLE_GRANTS`, `AUDIT_ROLE_HIERARCHY`, `AUDIT_LOGIN_HISTORY` — that mirror the real views' columns *and their awkward semantics*: `DELETED_ON` is populated, `TYPE` separates people from service identities, and `HAS_MFA` is `NULL` rather than `FALSE` for service users. A query written against a friendlier fake would not survive contact with the real thing.

The confirm queries print the answer key. Everything here is **exact**:

| Seeded figure | Value |
|---|---|
| user rows, all | 27 |
| user rows, live (`DELETED_ON IS NULL`) | 21 |
| user rows, deleted | 6 |
| role grants, live | 19 |
| login events | 196 |

And the planted findings, all **exact**:

| Finding | Correct count | What a careless query returns |
|---|---|---|
| People with a password and no MFA | **5** | 7, if `DELETED_ON` is ignored |
| Service identities on a password | **2** | -- |
| Disabled but not removed | **1** | -- |
| Dormant (90 days or never) | **4** | -- |
| Holders of ACCOUNTADMIN | **5** | **2**, by direct grant only |

> **Reading the Precision column.** *exact* means that number to the digit, on any
> date and in any account. *within n%* means the figure comes from a hash-based
> sample and moves slightly; anything inside the band is healthy. *guidance* means
> not reproducible -- an order of magnitude, not a target.

Those two right-hand numbers are the lab. Look at the ACCOUNTADMIN row in particular: the obvious query returns 2 and the truth is 5.

## Steps

### Step 1 -- Have CoCo write the user checks, then check the checker (about 8 minutes)

```
COCO_WS_LAB52_DB_<your_user>.LAB has AUDIT_USERS, AUDIT_ROLE_GRANTS, AUDIT_ROLE_HIERARCHY and
AUDIT_LOGIN_HISTORY. They mirror the columns and semantics of the SNOWFLAKE.ACCOUNT_USAGE views of
the same names. Write me the user-hygiene half of a security review: people without MFA, service
identities authenticating by password, accounts that are disabled but not removed, and dormant
accounts. Give me one query per finding with a count, and explain any column whose semantics you had
to be careful about.
```

**What good looks like:** four queries, and — this is the part to grade hardest — an explicit mention of two things.

- **`DELETED_ON IS NULL` on every query.** `ACCOUNT_USAGE` retains dropped objects. Without that filter the MFA finding returns **7** instead of 5, and two of the people in your report left the company months ago. This is not a small effect in the wild: on the account this lab was written against, `ACCOUNT_USAGE.USERS` held 101 rows of which **18** were live. An audit there without the filter would have been 82% noise, and every one of those false findings costs someone an hour of chasing.
- **Service identities cannot enrol in MFA.** `HAS_MFA` is `NULL` for them, so `NOT HAS_MFA` silently excludes them (three-valued logic) while `NOT COALESCE(HAS_MFA, FALSE)` includes them — as false positives. There are 4 live service identities here, and flagging them for missing MFA is the fastest way to teach a security team to ignore your report. The right finding for a service identity is a **password where a key pair should be**, which is a different query.

Check every count against the answer-key table above. If a number is off, the query is wrong — that is the whole point of starting here.

**If it goes sideways:** if CoCo returns 7 for the MFA finding and defends it, ask directly: `How many of those users still exist?`

### Step 2 -- The ACCOUNTADMIN question (about 8 minutes)

Ask the question the way an auditor would, without hinting at the answer:

```
Using the same seeded tables, tell me exactly which users hold ACCOUNTADMIN. I want the complete
list, and I want to know how confident you are that it is complete.
```

**What good looks like:** **5 users**, and an explanation that includes both paths. `AUDIT_ROLE_GRANTS` has ACCOUNTADMIN granted directly to 2 users. But `AUDIT_ROLE_HIERARCHY` has `ACCOUNTADMIN` granted *to the role* `DATA_ADMIN`, and 4 users hold `DATA_ADMIN` — so they hold ACCOUNTADMIN too, and appear nowhere in a direct-grant query.

There are three ways to get this wrong, and the seed is built so each produces a different number:

| Approach | Result | Why it is wrong |
|---|---|---|
| Direct grants only | 2 | Misses everyone who inherits it |
| Direct + inherited, added together | 6 | One person holds it both ways and is counted twice |
| Direct + inherited, `UNION` | **5** | Correct |
| Any of the above without `DELETED_ON IS NULL` | one higher | Counts a grant revoked 132 days ago |

If CoCo answers 2, push:

```
Is ACCOUNTADMIN granted to any ROLE rather than directly to a user? What does that mean for your list?
```

**And then ask the harder question**, because the seed only goes one level deep and reality does not:

```
My seeded hierarchy is one level deep. In a real account roles nest several levels. How would you
answer this question if ACCOUNTADMIN were three roles away, and what does that do to your query?
```

**What good looks like:** a recursive CTE over the role graph, and ideally a mention that Snowflake will do this for you — `SHOW GRANTS TO USER` resolves the hierarchy, and the account-level `SYSTEM$` privilege helpers exist precisely because hand-rolling transitive closure over grants is easy to get subtly wrong.

### Step 3 -- The login patterns (about 5 minutes)

```
From AUDIT_LOGIN_HISTORY, find anything that looks like credential abuse or a misconfigured client.
For each pattern, tell me what benign explanation I should rule out before treating it as an incident.
```

**What good looks like:** two patterns found, both **exact**:

- **40 failed logins against `IKOVACS`** from a single IP inside one hour. Note `IS_SUCCESS` is the string `'YES'`/`'NO'`, not a boolean — a `WHERE NOT IS_SUCCESS` gets a type error, and `WHERE IS_SUCCESS = FALSE` silently matches nothing.
- **`SVC_ADHOC` authenticating from 12 distinct IPs** in a day. For a service account that is either a container fleet with no fixed egress, or credentials that have escaped.

The benign explanations matter as much as the findings, and a good answer volunteers them: a rotating NAT pool explains the IPs, and a stale saved password in a scheduled job explains the failures. A review that reports both as incidents without that framing gets ignored the second time.

### Step 4 -- Point it at your real account (about 8 minutes)

**Read-only from here.** These queries look; they change nothing.

```
Now run the same review against SNOWFLAKE.ACCOUNT_USAGE for this account -- USERS, GRANTS_TO_USERS,
GRANTS_TO_ROLES and LOGIN_HISTORY. Read only: do not generate any GRANT, REVOKE, ALTER or CREATE.
Give me the findings with counts, and separate what is genuinely a risk from what is normal for a
demo or development account.
```

**What good looks like:** the same checks, the same `DELETED_ON` discipline, and — importantly — proportion. A sandbox account where everyone is ACCOUNTADMIN is not a finding, it is a sandbox. The judgement about which findings matter is the deliverable, not the row count.

Two things to establish before you believe any number:

- **`ACCOUNT_USAGE` is not live.** Latency varies by view and runs up to about two hours. A change made this morning may not appear, so "I already fixed that" and "your report is wrong" are indistinguishable unless you know the lag. `SHOW GRANTS` is current; `ACCOUNT_USAGE` is not.
- **Check the live-to-total ratio first.** Run `SELECT COUNT(*), COUNT_IF(DELETED_ON IS NULL) FROM SNOWFLAKE.ACCOUNT_USAGE.USERS` before anything else. If those numbers are far apart — and on a long-lived account they will be — you have just measured how wrong a `DELETED_ON`-blind audit would have been on *your* data.

Then ask for the artefact that actually travels:

```
Turn this into a one-page summary for an account administrator who has twenty minutes. Order by risk,
not by finding type. For each item give the evidence, the remediation, and what breaks if they do it.
Do not write the remediation SQL -- I want them to decide.
```

**What good looks like:** risk-ordered rather than grouped by check, with a named blast radius per item. "Revoke ACCOUNTADMIN from 3 users" is not actionable until someone knows what those users do all day. The reason not to hand over ready-to-run `REVOKE` statements is the same reason this lab is read-only: privilege removal breaks pipelines, and the person who owns the account is the one who knows which.

## Check your work

```sql
SET NS     = (SELECT REGEXP_REPLACE(CURRENT_USER(), '[^A-Za-z0-9]', '_'));
SET LAB_DB = 'COCO_WS_LAB52_DB_' || $NS;
USE DATABASE IDENTIFIER($LAB_DB);
USE SCHEMA LAB;

-- The DELETED_ON gap, both ways round.
SELECT
  COUNT(*)                                              AS ALL_ROWS,
  COUNT_IF(DELETED_ON IS NULL)                          AS LIVE_ROWS,
  COUNT_IF(TYPE = 'PERSON' AND NOT DISABLED AND HAS_PASSWORD
           AND NOT COALESCE(HAS_MFA, FALSE)
           AND DELETED_ON IS NULL)                      AS MFA_FINDINGS_RIGHT,
  COUNT_IF(TYPE = 'PERSON' AND NOT DISABLED AND HAS_PASSWORD
           AND NOT COALESCE(HAS_MFA, FALSE))            AS MFA_FINDINGS_WRONG
FROM AUDIT_USERS;

-- Effective ACCOUNTADMIN, done properly.
WITH direct AS (
  SELECT GRANTEE_NAME FROM AUDIT_ROLE_GRANTS
  WHERE ROLE = 'ACCOUNTADMIN' AND DELETED_ON IS NULL
),
inherited AS (
  SELECT g.GRANTEE_NAME
  FROM AUDIT_ROLE_GRANTS g
  JOIN AUDIT_ROLE_HIERARCHY h ON h.GRANTEE_ROLE = g.ROLE
  WHERE h.ROLE = 'ACCOUNTADMIN' AND h.DELETED_ON IS NULL AND g.DELETED_ON IS NULL
)
SELECT (SELECT COUNT(*) FROM direct)    AS DIRECT_ONLY,
       (SELECT COUNT(*) FROM inherited) AS INHERITED,
       (SELECT COUNT(*) FROM (SELECT * FROM direct UNION SELECT * FROM inherited)) AS EFFECTIVE;
```

Expected, all exact: `ALL_ROWS` **27**, `LIVE_ROWS` **21**, `MFA_FINDINGS_RIGHT` **5**, `MFA_FINDINGS_WRONG` **7**, `DIRECT_ONLY` **2**, `INHERITED` **4**, `EFFECTIVE` **5**.

## What just happened

You wrote a security review and then established that it was correct, in that order.

**Every wrong answer here looked right.** 2 ACCOUNTADMINs, 7 MFA findings, service accounts flagged for a control they cannot have — all of those come back as tidy result sets. The seeded data is the only reason you could tell. When you point these queries at a real account you lose that safety net, which is precisely why you check them first.

**Inherited privilege is the finding people miss.** Not because it is subtle, but because the obvious query answers a slightly different question than the one asked. "Who was granted ACCOUNTADMIN" and "who has ACCOUNTADMIN" are different, and only one of them is what an auditor means.

**Findings overlap, and reports that assume otherwise waste people's time.** One person in the seed is both an MFA finding and a dormant one. Chasing them twice is how a review loses credibility.

**Read-only was a deliberate constraint, not a limitation.** The output of a review is a decision someone else has to make with context you do not have. Handing over `REVOKE` statements skips that, and the pipeline that breaks at 3am was depending on the grant you removed.

## Take it further

- **Recursive role closure.** The seed nests one level. Ask CoCo for a recursive CTE over `GRANTS_TO_ROLES` that finds every user with a path to ACCOUNTADMIN at any depth, and compare it against `SHOW GRANTS TO USER` for one person.
- **Trust Center.** Snowflake ships scanner packages that cover much of this, on a schedule, with a UI. Run it, then compare its findings to yours — where it is stronger, and what it does not know about your organisation.
- **Turn a check into a monitor.** One of these findings is worth knowing about the day it appears, not at the next review. Lab 23's data metric functions and a Snowflake alert are the mechanism.
- **Authentication policies.** The durable fix for the MFA finding is not chasing 5 users, it is an authentication policy that makes the state unreachable. That is a change, so it belongs outside this lab -- but it is the right conversation to have next.
- **Compare two accounts.** Run the review against a development and a production account and diff the findings. The gap is usually more informative than either list.

## Clean up

```bash
snow sql -f labs/52-account-security-review/cleanup.sql -c <your-connection>
```

That drops the lab database and the seeded audit tables. There is nothing else to undo — no user, grant, policy or parameter was changed anywhere in this lab.
