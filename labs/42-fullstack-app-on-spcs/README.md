# Lab 42 -- A full-stack React app on SPCS, over Snowflake Postgres

> **Stretch lab. Do not attempt this during the session.** Reserve 90-120 minutes
> and time for cleanup. Other labs also have prerequisites and ongoing costs;
> none should be assumed safe to abandon without checking its lifecycle.
> It is here for the people who finish early, ask "how far does this actually go",
> and want to spend an evening finding out.
>
> **Historical walkthrough, not a fresh account certification.** The source guide
> records observations from an earlier deployment. This public export has not been
> re-run end to end. Verify current feature availability, commands, permissions
> and network requirements in your approved sandbox before proceeding.

| | |
|---|---|
| **Surface** | CoCo Desktop -- its integrated terminal runs the `snow` and `node` commands |
| **Stretch** | yes |
| **Deck label** | A full-stack React app on SPCS |
| **Track** | app-dev |
| **Sequence** | 20 |
| **Topic** | App dev, end to end |
| **Time** | 90 minutes to 2 hours. It was 2-3 hours to work out the first time; this file hands you the answers |
| **Privileges** | `ACCOUNTADMIN` in practice: `CREATE POSTGRES INSTANCE`, `CREATE APPLICATION SERVICE`, `CREATE EXTERNAL ACCESS INTEGRATION`, `CREATE NETWORK POLICY`, `CREATE SECRET` |
| **Creates** | `COCO_WS_LAB42_DB_<your_user>`, a Snowflake Postgres instance, an application service, an EAI, a network rule, a network policy and a secret |
| **Tears down with** | `snow app teardown --force`, then `cleanup.sql` |

> **Choose your surface:** follow this lab's Surface row. Desktop is macOS/Windows only; Linux attendees should consult the VS Code/CLI routes in the prerequisites. Lab 74 specifically demonstrates Snowsight Workspaces.

## Read this before you start

**Two of the objects in this lab bill while you are not looking at them.**

- A **Snowflake Postgres instance has no auto-suspend.** There is no `AUTO_SUSPEND_SECS`
  to set. It bills compute from the moment it reaches Ready until you suspend or drop it.
- An **application service** bills until suspended, and `AUTO_SUSPEND_SECS` defaults to
  `0`, which means auto-suspend is **off**. Set it to `300` when you deploy.

If you walk away from this lab half-finished, run `cleanup.sql` first. It is written to
work at any point of partial progress.

**Snowflake App Runtime is in public preview**, and it is **not available on trial
accounts**. If you are running the workshop in a trial, you can do Steps 1 to 4 (Postgres
plus a React app on your laptop) and stop before the deploy. That is still most of the
value.

## What you will learn

- What it feels like to hand an agent a whole stack rather than a single file: schema, migration, API, UI, deployment and networking in one conversation.
- Where Snowflake Postgres fits next to Snowflake proper, and why "just use a table" is sometimes the wrong answer.
- How much the specificity of your prompt decides the outcome -- naming the interaction pattern, the theme and the behaviour up front gets you there in one pass instead of four.
- How to make an agent useful on a problem where the documentation runs out -- which is the real skill this lab is testing.

## Why this matters

Every other lab here has a tidy, documented answer. This one has two steps where the
documentation runs out or actively misleads you, and that is the reason it exists. Ask
anyone who has shipped an internal tool what the hard part was and they will not say the
React components. They will say the twenty minutes where the app worked on their laptop and
returned a connection timeout in production.

That is the part worth practising with an agent, because it is the part where an agent is
either a real collaborator or a confident liar, and you find out which very quickly.

This lab has been run to completion, so the answers are written down here. You will still
have to find them in your own account -- the addresses and the timings are yours, not
mine -- but you are not being sent into a dead end.

## What you are building

A service-request queue. `setup.sql` gives you 24 rows in Snowflake; you move them into
Postgres, put a React front end on them, and deploy it.

The three tiers, and why each one is where it is:

| Tier | Where | Why not somewhere else |
|---|---|---|
| Analytics source | Snowflake table and view | It is where the data is generated and where the history lives. |
| Application state | Snowflake Postgres | Row-level reads and single-row updates at low latency. A warehouse is the wrong tool for `UPDATE ... WHERE request_id = 100203`. |
| Web app | Application service on SPCS | It needs a URL, a session and Node.js. Streamlit-in-Snowflake (Lab 41) would be the right call if it did not. |

The comparison with **Lab 41** is the point. Lab 41 ships a Streamlit app in about thirty
minutes because Snowflake hosts the whole thing for you. This lab takes an evening
because you asked for a real web application with its own transactional database. Both
answers are correct; the lab teaches you which question you are actually asking.

## Before you start

> **Your object names carry your user name.** Everything this lab creates at
> account level is suffixed with your Snowflake user, so a whole room can run it
> in one account without collisions: your database is
> `COCO_WS_LAB42_DB_<your_user>`. The last query in `setup.sql` prints the exact
> names -- keep them to hand.
>
> Inside the SQL files those names are built with session variables (`$LAB_DB`).
> **CoCo does not see them,** because it runs its own session. So wherever a step
> below asks you to prompt CoCo, paste the real name rather than `$LAB_DB`.

You need, on your machine:

- **Node.js 22 or later** -- `node --version`
- **Snowflake CLI 3.19 or later** -- `snow --version`
- CoCo Desktop, signed in

Then:

```bash
snow sql -f labs/42-fullstack-app-on-spcs/setup.sql -c <your-connection>
```

Expected, all **exact**: **24 rows** loaded, and open requests of 5 for Harbour West, 5 for Old Quarter,
3 for Northfield and 3 for Riverside. These are literal seed rows, so they do not vary.

`setup.sql` deliberately does **not** create the Postgres instance. The admin password is
shown exactly once, at create time, and a script that swallows it is worse than useless.
You create it in Step 2.

The last three statements are a **preflight report**. Read them:

1. `SHOW POSTGRES INSTANCES` -- success with zero rows is correct. An error means Postgres
   is not enabled on this account and the lab stops here.
2. `SHOW PARAMETERS LIKE 'DEFAULT_SNOWFLAKE_APPS%'` -- all six empty is normal. Your app
   will be created in your personal database `USER$<login_name>` on a Snowflake-managed
   compute pool. Apps in a personal database **cannot be shared with other roles**, which
   is fine for a solo lab. Want a shareable app? An ACCOUNTADMIN sets
   `DEFAULT_SNOWFLAKE_APPS_DESTINATION_DATABASE` first.
3. The role check -- `HAS_ACCOUNTADMIN` should be `True`.

## Steps

Use these exact object names throughout. `cleanup.sql` looks for them.

| Object | Name |
|---|---|
| Postgres instance | `COCO_WS_LAB42_PG_<your_user>` |
| Network policy (Postgres ingress) | `COCO_WS_LAB42_PG_INGRESS_<your_user>` |
| External access integration | `COCO_WS_LAB42_PG_EAI_<your_user>` |
| Network rule (app egress) | `COCO_WS_LAB42_DB_<your_user>.LAB.COCO_WS_LAB42_PG_EGRESS_<your_user>` |
| Secret | `COCO_WS_LAB42_DB_<your_user>.LAB.COCO_WS_LAB42_PG_CREDS_<your_user>` |
| Application service | `COCO_WS_LAB42_APP_<your_user>` |

### Step 1 -- Get a plan before you get code (about 15 minutes)

Do not start by asking for an app. Start by making CoCo tell you the shape of the thing,
so you can disagree with it while it is still cheap.

```
I want to build a full-stack web app on Snowflake and I want to plan it before we write
anything. The stack is: a React front end and API deployed as a Snowflake App on SPCS,
with Snowflake Postgres as the transactional database, seeded from
COCO_WS_LAB42_DB_<your_user>.LAB.SERVICE_REQUESTS.

Before any code: read that table and view, then give me the build order, the Snowflake
objects I will need to create and in what sequence, and the three places this is most
likely to fail. Be specific about which steps are documented and which are not.
```

**What good looks like:** a sequence that puts the Postgres instance before the app,
identifies that the app needs an external access integration to reach Postgres, and
flags the network path as the risky part. It should have read the actual table.

**If it goes sideways:** if it starts generating React components immediately, stop it and
ask for the plan again. An agent that skips to code on a task this size will produce
something that looks finished and is not.

### Step 2 -- Create the Postgres instance (about 5 minutes)

```
Create a Snowflake Postgres instance called COCO_WS_LAB42_PG_<your_user> using the smallest
documented compute family and 10 GB of storage. Show me the SQL before you run it, tell
me what it will cost per hour in credit terms, and tell me exactly what I have to capture
from the output and why I cannot get it back later.
```

The smallest documented family is **`BURST_S`**. Measured time to Ready was **2.5 to 3
minutes**, moving Creating &rarr; Finalizing &rarr; Ready.

Two things the docs do not tell you:

- **`AUTHENTICATION_AUTHORITY` is mandatory.** Leaving it out is a compile error,
  `Missing option(s): [AUTHENTICATION_AUTHORITY]`.
- **`604032 ... Internal error occurred during operation` has two causes, and one
  of them is nothing you did.** `AUTHENTICATION_AUTHORITY = POSTGRES` produced it
  twice on this account while `POSTGRES_OR_SNOWFLAKE` succeeded immediately, so
  that setting is one cause. But a later run hit the same error with
  `POSTGRES_OR_SNOWFLAKE` already in place, and **re-running the identical
  statement worked** -- the failure was transient and provisioning left nothing
  behind (`SHOW POSTGRES INSTANCES` returned no rows). So: retry once before you
  change anything, and only then switch the authority. Debugging your own SQL
  first is the trap here, because the error names your instance and reads like a
  statement problem.

**Capture the admin password now.** It is displayed once. The default user is
`snowflake_admin` and the default database is `postgres`. `DESCRIBE POSTGRES INSTANCE
COCO_WS_LAB42_PG_<your_user>` gives you the host afterwards, but never the password.

> **Do not run this statement on a shared screen.** `CREATE POSTGRES INSTANCE` returns
> the credentials in its ordinary output, so they land in your terminal scrollback, and
> in the transcript of whatever tool ran it.

**What good looks like:** an instance in state Ready, and a connection string of the shape
`postgresql://snowflake_admin:<pw>@<host>:5432/postgres?sslmode=require`. TLS is not
optional -- `sslmode=disable` is refused outright with `no pg_hba.conf entry ... no
encryption`. `sslmode=require` is sufficient; you do **not** need the per-instance
`certificate` that `DESCRIBE` exposes, though you can pin it if you want `verify-full`.

### Step 3 -- Move the data across (about 20 minutes)

```
Migrate COCO_WS_LAB42_DB_<your_user>.LAB.SERVICE_REQUESTS into COCO_WS_LAB42_PG_<your_user>. Design the Postgres
schema properly rather than copying Snowflake's types verbatim -- I want real constraints,
a check on status, an index on whatever the app will filter by, and an explanation of each
place your Postgres DDL differs from the Snowflake DDL and why.
```

**What good looks like:** DDL that is native Postgres rather than transliterated Snowflake.
An enum or a check constraint on `status`, a real `timestamptz` decision it can defend, an
index that matches the query the app will actually run.

Ask it the follow-up, because this is the interesting part:

```
This is 24 rows so anything works. If it were 24 million rows arriving continuously, what
would you change about this migration, and at what point would you tell me to keep the
data in Snowflake and not use Postgres at all?
```

An agent worth trusting will draw that line rather than telling you Postgres is fine.

### Step 4 -- Build the app and run it on your laptop first (about 30 minutes)

Local before deployed. Always. Debugging a React app and debugging an SPCS network path
at the same time is how an evening disappears.

> **Be specific about the UI, or you will pay for it in round trips.** This is the single
> biggest lever you have on how fast this step goes. An agent asked for "a detail view where
> I can change the status" will build something that works and looks like a developer's
> first draft -- a panel that appears below the table, no transitions, default typography.
> Nothing is wrong with it, so there is nothing to point at; you just end up iterating three
> or four times to get to what you actually pictured.
>
> Name the interaction pattern, the visual treatment and the behaviour up front. "A modal",
> "a right-hand drawer", "inline editing in the table row" are three genuinely different
> applications, and the agent cannot read your mind about which one you meant. The same
> goes for density, empty states, loading behaviour, whether errors are toasts or inline,
> and whether it should follow a theme.
>
> The prompt below is deliberately over-specified compared to how most people write their
> first one. Compare it against what you would have typed, and notice the gap -- that gap
> is the iterating you would have done.

```
Scaffold the Snowflake App now. React front end, an API layer that talks to
COCO_WS_LAB42_PG_<your_user> with node-postgres.

Screens and interactions, specifically:

  1. A summary strip at the top: open requests grouped by district and priority, as
     compact cards, each showing the count and the age of the oldest item in days.
  2. A dense, sortable table of all requests below it, with dropdown filters for
     district and status in a toolbar above the table. Show status as a coloured
     pill, not plain text.
  3. Editing status: use a right-hand drawer that slides over the table when I click a
     row, showing the full request detail and the status controls. The table stays
     visible behind it. Close on Escape and on clicking outside.
  4. Also allow inline status editing directly in the table row, so the common case
     needs no drawer at all.

Behaviour I care about:
  - Optimistic update on a status change, rolled back with an inline error if the
    write fails. Do not silently swallow a failed write.
  - Skeleton rows while the table loads, never a layout jump.
  - A real empty state when the filters match nothing, not a blank table.
  - Keyboard accessible: the drawer traps focus and returns it to the row on close.

Visual direction: clean and data-dense rather than marketing-flashy, Snowflake blue as
the single accent colour, works in both light and dark mode, system font stack.

Read the credentials from environment variables, not from source. Get it running with
npm run dev against the Postgres instance, and tell me the URL.
```

**What good looks like:** `npm run dev` serves a working app on localhost that reads and
writes real rows in Postgres. Change a status in the UI, then confirm it with `psql` or a
`SELECT` -- do not take the UI's word for it.

Then do the comparison that makes this step worth the time:

```
I gave you a detailed UI specification. Show me which parts of it you implemented
literally, which parts you interpreted, and which parts you quietly dropped. For anything
you dropped or changed, tell me why.
```

That question is more useful than it looks. Where an agent silently reinterprets a
specific instruction is exactly where you will need to be more explicit next time.

**If it goes sideways:** the overwhelmingly likely cause is the ingress network policy, not
your code. Read the box below before you debug anything else.

> **The laptop trap, and it cost real time here.** You allowlist your own IP with
> `SELECT CURRENT_IP_ADDRESS()`, and you are still refused. That function returns the
> address Snowflake's control plane sees for your HTTPS session. If you are behind a
> corporate VPN or proxy, a direct TCP connection to port 5432 can leave from a
> *different* address, so the IP you allowlisted is not the IP Postgres sees. On the
> machine used to write this lab the reported address also rotated between three
> unrelated `/8`s within twenty minutes, so chasing it one `/32` at a time never
> converged.
>
> If that is your situation, do not fight it. Either run `psql` from somewhere with a
> stable egress address, or skip ahead: the deployed app has its own path to Postgres and
> Step 5 sets it up. The app can create the schema and load the rows itself.

### Step 5 -- The two walls between the app and the database (about 20 minutes)

This is the step this lab exists for. It **does** work, and the interesting part is that
the answer is not the one the documentation leads you to.

Your app worked on your laptop. Now it has to work from inside SPCS, and there are **two
separate walls** between it and Postgres, in opposite directions:

| Direction | Mechanism | Documented? |
|---|---|---|
| App **out** to Postgres | External access integration over a network rule with `MODE = EGRESS`, `TYPE = HOST_PORT`, value `<pg-host>:5432`. Credentials mounted from a Snowflake secret. | **Yes.** `app.yml` names Snowflake Postgres explicitly as a use case for `external_access_integrations`, and `secrets` mounts a `PASSWORD` secret at `/secrets/<name>/username` and `/secrets/<name>/password`. |
| Postgres **in** from the app | A network policy whose rules use `MODE = POSTGRES_INGRESS`, `TYPE = IPV4`. **IPv4 CIDRs only** -- no hostname, no service identity. | **No.** There is no published source range for application service egress, and no page describing the SPCS-to-Postgres hop. |

Give CoCo the problem honestly, including what is not written down:

```
My app is deployed on SPCS and needs to reach Snowflake Postgres instance
COCO_WS_LAB42_PG_<your_user>. The egress side I understand: an external access integration over a
network rule to the Postgres host on 5432, and a secret for the credentials.

The ingress side I do not. A Postgres network policy takes MODE = POSTGRES_INGRESS rules
with IPV4 CIDRs only, and I cannot find a documented source range for application service
egress. I do not want to open it to 0.0.0.0/0. How do I discover the actual source
address my app presents, without first allowing everything?
```

**What good looks like:** a way to *observe* the address rather than guess it. The trick
used here: the app already has an egress integration, so add a harmless IP-echo host to
the same network rule and have the app log its own address at boot. That reveals the
source range without ever opening Postgres wide.

```sql
-- Add an echo host alongside Postgres, temporarily.
ALTER NETWORK RULE COCO_WS_LAB42_DB_<your_user>.LAB.COCO_WS_LAB42_PG_EGRESS_<your_user>
  SET VALUE_LIST = ('<pg-host>:5432', 'api.ipify.org:443');
```

Then log it from a boot hook -- Next.js `instrumentation.ts`, or whatever your framework
calls it -- and read it back with `snow app events`. Do **not** try to verify this through
the browser: the app endpoint sits behind Snowflake OAuth, so an interactive login is the
only way in, and the service log is the only headless view of what the container can reach.

#### Historical observations are not a reusable network allowlist

In the earlier walkthrough, the observed source address changed after a restart,
and an external echo service reported a different address from the one the database
saw. A single observed address therefore did not establish a stable network policy.
The original addresses and account-specific rule are intentionally omitted here.

Do not copy an address range from a different deployment or infer an approved CIDR
from a few observations. Ask your administrator to confirm the supported network
path and narrowly scoped allowlist for your account and region. If that cannot be
established, stop this checkpoint and record the blocker rather than widening access.
Never use `0.0.0.0/0` as a troubleshooting shortcut.

#### Two more things that will bite

- **Network policy changes are slow to take effect, and the error is a lie.** Expect one
  to three minutes, and during that window the failure reads
  `server closed the connection unexpectedly ... SSL SYSCALL error: Connection reset by
  peer` -- which looks like a broken server, not a denied connection. Do not go debugging
  TLS. Wait, then retry.
- **`CREATE OR REPLACE NETWORK RULE` is refused** once the rule is attached to a policy.
  Use `ALTER NETWORK RULE ... SET VALUE_LIST = (...)`, which replaces the whole list.

Name the objects `COCO_WS_LAB42_PG_EAI_<your_user>`, `COCO_WS_LAB42_DB_<your_user>.LAB.COCO_WS_LAB42_PG_EGRESS_<your_user>`,
`COCO_WS_LAB42_DB_<your_user>.LAB.COCO_WS_LAB42_PG_CREDS_<your_user>` and `COCO_WS_LAB42_PG_INGRESS_<your_user>` so cleanup
finds them.

### Step 6 -- Deploy (about 20 minutes)

```
Deploy this app. Set the application service AUTO_SUSPEND_SECS to 300 so it does not
bill overnight, and name the service COCO_WS_LAB42_APP_<your_user>. Then show me the URL and the
service logs.
```

The commands, so you can recognise them:

```bash
snow app setup --app-name="COCO_WS_LAB42_APP_<your_user>" --dry-run   # see what it will write
snow app setup --app-name="COCO_WS_LAB42_APP_<your_user>"             # writes snowflake.yml
snow app deploy --verbose                                 # upload, build, deploy
snow app open                                             # or --print-only for the URL
snow app events --last 500                                # what the service is doing
```

Note that `snow app deploy` needs no compute pool from you: the build runs as an ephemeral
SPCS job on a Snowflake-managed pool, and the application service manages its own compute.
The npm build has egress to `registry.npmjs.org` pre-allowlisted, so a plain `npm ci`
needs no EAI of its own.

Measured timings: first create about **3 to 4 minutes**, an upgrade in place about **100
seconds**, most of it endpoint provisioning.

#### The `app.yml` trap that will waste your afternoon

The integration and the secret are attached through `app.yml`, and **a single malformed key
makes Snowflake silently ignore the whole manifest**. No build failure, no warning -- the
app deploys, runs, and simply has no egress and no credentials.

The one that caught us: `environment_variables` must be a **list of `name`/`value`
objects**, not a mapping.

```yaml
# WRONG -- looks perfectly reasonable, silently discards the entire manifest
environment_variables:
  PGHOST: my-instance.aws.postgres.snowflake.app

# RIGHT
environment_variables:
  - name: PGHOST
    value: "my-instance.aws.postgres.snowflake.app"
```

**Verify rather than assume**, every time you change `app.yml`:

```sql
DESCRIBE APPLICATION SERVICE <db>.<schema>.COCO_WS_LAB42_APP_<your_user>;
```

`external_access_integrations` must list your EAI. If it shows `[]`, the manifest was
ignored -- go and find the malformed key. `additional_properties` should also carry your
`profile` label, which is a second cheap signal that the manifest was read.

Two related facts worth knowing:

- **`ALTER APPLICATION SERVICE ... SET EXTERNAL_ACCESS_INTEGRATIONS = (...)` works**, so you
  can attach an integration to a running service without redeploying.
- **`SECRETS` is not a valid property on `ALTER APPLICATION SERVICE`.** Secrets can only
  come from `app.yml`, and only at creation, so changing them means
  `snow app teardown --force` followed by a fresh `snow app deploy`.

**What good looks like:** a URL that loads the app in a browser and shows real Postgres
rows. Not a healthy service with an empty screen -- that is the egress wall.

**If it goes sideways:** `snow app events --last 500` is the first thing to read, every
time. A connection timeout in those logs is Step 5, not Step 6. If the log says no
credentials were found at `/secrets/`, it is the `app.yml` trap above, not Step 5.

> **You cannot verify this app with `curl`.** The endpoint is behind Snowflake OAuth, so an
> interactive browser login is the only way to reach it. To check the deployment headlessly,
> report only non-sensitive status from a boot hook and read it with `snow app events`.
> Check independently: whether required environment variables are present, whether
> the expected secret files exist and are readable, whether the outbound request
> succeeds, and whether a minimal query succeeds. Log booleans or sanitized error
> categories only -- never environment dumps, secret-file contents, passwords,
> tokens, connection strings or returned customer data.

## Check your work

1. `SHOW POSTGRES INSTANCES` lists `COCO_WS_LAB42_PG_<your_user>` in state Ready.
2. `DESCRIBE APPLICATION SERVICE ...` shows your EAI in `external_access_integrations`,
   not `[]`.
3. `snow app events` shows the container reading `/secrets/PG`, reaching Postgres, and
   counting **24** rows in `service_requests`.
4. `snow app open --print-only` returns a URL, and that URL loads the app after you sign in.
5. Changing a request's status in the browser changes the row in Postgres, confirmed by a
   query rather than by the UI.
6. You can say in one sentence why the app state lives in Postgres and not in a Snowflake
   table.

If your laptop could never reach Postgres because of the address problem in Step 4, items
1 to 3 plus 6 are a complete pass. The deployed app is the thing that matters, and item 3
proves it.

## What just happened

You gave an agent a whole stack instead of a file, and none of the hard parts were in the
code. They were in the network path and in a YAML key -- which is where real projects
actually stall.

The two failures worth remembering both looked like something they were not. A blocked
network policy reports itself as `server closed the connection unexpectedly`, which reads
as a broken server. A malformed `app.yml` key reports itself as nothing at all: the app
deploys clean and simply has no credentials. In both cases the error message points away
from the cause, and the only way through is to check the thing directly rather than believe
the message.

That is the habit this lab is really teaching, and it is the same habit that tells you
whether to trust an agent. Watch what CoCo does when the documentation runs out. Schema
design, migration, React and the deploy sequence are well-trodden and it moves fast there.
The ingress question is genuinely unwritten, and the useful answer was not a fact it could
recall -- it was a *method*: use the egress you already have to observe the address, rather
than guessing a CIDR or opening everything. An agent that reaches for a way to measure,
instead of asserting a plausible range, is one you can work with.

The other lesson is cheaper to learn and applies to every prompt you will write after
today. **The UI you get is the UI you described.** An under-specified request does not
produce a bad app -- it produces a *defensible* one, which is worse, because there is
nothing obviously wrong to point at and you end up iterating your way toward what you
already had in mind. "A detail view where I can change the status" and "a right-hand drawer
that slides over the table, with inline editing in the row for the common case" cost the
same to type. Only one of them saves you three rounds of "actually, can you make it...".

The general rule: spend the extra sentence on **interaction pattern, visual direction and
behaviour** -- modal or drawer or inline, dense or spacious, what a failed write looks like,
what an empty state says, whether it respects a theme. Those are the decisions an agent has
to guess at, and guessing is where the round trips come from. Constraints are not
micromanagement here; they are the fastest path to the thing you actually wanted.

### Then stop typing it every time

Specifying the UI in each prompt works, and it does not scale. Nobody retypes their
company's design system into every conversation, and if they try, two people will do it
differently and a third will forget the accessibility requirements entirely.

That is exactly what a skill is for. **Encode your house UX standards once as a skill**,
and every app anyone on the team asks CoCo for starts from them. Lab 71 shows the mechanics
using a table-standards skill; a UI skill is the same shape with different rules, and it is
the more valuable one because UI decisions are where agents diverge most from what a team
already agreed.

What belongs in it -- roughly the questions you had to answer by hand in Step 4:

| Category | Examples of what to encode |
|---|---|
| **Component vocabulary** | Which library or design system. Which primitives are approved and which are banned. "Use our `<DataTable>`, never a raw `<table>`." |
| **Interaction patterns** | Editing is a drawer, or a modal, or inline -- pick one and say so. Destructive actions need confirmation. Where filters live. |
| **Visual system** | Brand colours and the one accent. Type scale, spacing scale, density. Light and dark handling. What is *not* allowed: gradients, drop shadows, custom fonts. |
| **Behaviour and states** | Loading is skeletons not spinners. Empty states must explain and offer an action. Errors inline, not toasts. Optimistic writes must roll back visibly. |
| **Accessibility** | Contrast floor, focus management, keyboard paths, minimum target size, what must have a label. Usually the first thing dropped and the hardest to retrofit. |
| **Content and tone** | Sentence case not title case. Date and number formats. No exclamation marks. Terms of art your product uses. |
| **The escape hatch** | When *not* to follow the standard, and who to ask. A standard with no exceptions gets ignored wholesale the first time it does not fit. |

Two things make the difference between a skill people use and one that sits in a directory:

- **Write the rules as checkable statements, not aspirations.** "Accessible" is not a rule.
  "All interactive elements reach WCAG AA contrast and are reachable by keyboard in DOM
  order" is. If you cannot tell whether output complies, neither can an agent.
- **Include a worked example and a counter-example.** One correct component and one that
  violates three rules, with the violations named. Agents generalise from examples far more
  reliably than from prose, which is the same reason Lab 71 has a compliant table sitting
  among the broken ones.

Then test it the way Lab 71 tests its skill: ask for a screen you have not described in
detail and see whether the house rules come through unprompted. If they do not, the
description field is usually the problem rather than the rules -- a skill that never gets
selected is indistinguishable from one that does not exist.

## Take it further

- **Run the specificity experiment properly.** Start a fresh conversation and ask for the same app with the vague three-line brief -- "a detail view where I can change the status" -- then diff the result against what the detailed prompt produced, and count the follow-up messages each one needed to reach something you would show a colleague. It is the most transferable thing in this lab and it takes fifteen minutes.
- Push the UI further with the same discipline: ask for a command palette for filtering, or optimistic reordering when priority changes. Name the pattern you want, then see how close the first attempt lands.
- **Turn the UI specification into a skill** using the technique from Lab 71, then rebuild a screen without describing the design at all and see whether the house rules come through unprompted. That is the version of this lesson that survives contact with a real team -- and if your organisation already has a design system or an accessibility standard, encoding it is the single highest-leverage skill you can write.
- Put the Snowflake-to-Postgres migration on a schedule with a task, so the app's queue reflects new analytics rows. Then ask CoCo which direction the sync should really run in.
- Add authentication. Ask what the app can know about the calling Snowflake user and what it cannot.
- Rebuild screen 1 as a Streamlit app (Lab 41) and time both. The honest comparison of effort against control is worth more than either app.
- Re-run Lab 62 afterwards. This lab generates a genuinely different cost shape from every other one -- continuous Postgres compute rather than bursty warehouse credits.

## Clean up

**Do this even if the lab did not finish.** The Postgres instance has no auto-suspend.

From the app directory, if you got as far as deploying:

```bash
snow app teardown --force
```

Then, always:

```bash
snow sql -f labs/42-fullstack-app-on-spcs/cleanup.sql -c <your-connection>
```

That drops the application service, the Postgres instance, the external access
integration, the network policy, the network rule, the secret and `COCO_WS_LAB42_DB_<your_user>`, and
then prints four `SHOW` statements. Read all four.

The fourth one, `SHOW APPLICATION SERVICES IN ACCOUNT`, is the one that matters. If your
account left `DEFAULT_SNOWFLAKE_APPS_DESTINATION_DATABASE` empty, the app was created in
your personal database rather than the lab database, so nothing above dropped it -- and an
application service bills until it is suspended or dropped. If `COCO_WS_LAB42_APP_<your_user>` shows up
in that list, remove it by the fully qualified name from the output:

```sql
DROP APPLICATION SERVICE IF EXISTS <database>.<schema>.COCO_WS_LAB42_APP_<your_user>;
```

`UNDROP APPLICATION SERVICE` does not exist, and dropping the Postgres instance discards
its backups. Neither is a loss here -- everything in this lab is reproducible from
`setup.sql` and one conversation.

To remove every trace of the whole workshop, run `shared/99_workshop_cleanup.sql`.
