# Lab 73 -- CoCo in your IDE

| | |
|---|---|
| **Surface** | CoCo in VS Code (or another IDE) -- that is the point of the lab; CoCo Desktop covers step 4 |
| **Surfaces** | ide |
| **Track** | with-coco |
| **Sequence** | 30 |
| **Topic** | Integration |
| **Time** | 20 minutes |
| **Privileges** | `CREATE DATABASE`. Cortex access for CoCo itself. Permission to install an extension on your machine. |
| **Creates** | `COCO_WS_LAB73_DB_<your_user>`, plus local IDE configuration |
| **Tears down with** | `cleanup.sql` -- drops the database, keeps your IDE setup |

> **This lab demonstrates the IDE extension itself.** Desktop is optional for the comparison step. Linux attendees can complete the core walkthrough without Desktop.

## What you will learn

- How to run CoCo inside the IDE you already work in, rather than in a separate window.
- Which direction of integration you actually want: your IDE reaching into CoCo, or CoCo reaching out to your other systems.
- How to prove a connection is real rather than plausible.

## Why this matters

The most common objection to any new development tool is "I already have one". This lab takes that seriously. CoCo does not require you to move out of VS Code, and for a lot of teams that is the difference between adoption and a trial that quietly lapses.

It also settles a question people get wrong: an agent in your IDE and an agent in a separate app are not the same product with a different window. What changes is what the agent can see without being told.

## Which IDE this lab assumes

**VS Code with the official [Snowflake extension](https://marketplace.visualstudio.com/items?itemName=snowflake.snowflake-vsc)**, including on Linux. Desktop is not required and is not available for Linux. Install the extension, sign in through its Snowflake panel, select your workshop role/warehouse, then open the CoCo panel. No separate CoCo CLI installation is required; leave `CoCo: CLI Path` unset unless deliberately overriding it.

[Other documented integrations](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code-in-your-editor) include Cursor with the Snowflake extension, supported ACP editors such as Zed/JetBrains/Neovim, and the Claude Code plugin. Their installation and UI differ; this walkthrough does not assert parity.

If you do not have an IDE installed at all, skip to Step 4 and do the MCP half in CoCo Desktop.

## Two directions, and they are not the same thing

The direction of integration determines what connects to what and which workflow it supports.

| Direction | What it means | Use it when |
|---|---|---|
| **Your IDE reaches into CoCo** | The VS Code extension, the Claude Code plugin, or 30+ other IDEs via Agent Client Protocol. You stay in your IDE and get a CoCo agent that knows your Snowflake account. | You write code in an IDE all day and want Snowflake context in it. |
| **CoCo reaches out to your systems** | CoCo consumes MCP servers, so it can read Jira, GitHub and other internal systems while it works. | The task spans Snowflake *and* something else -- "fix the pipeline described in this ticket". |
| **Something else embeds CoCo** | The Agent SDK, the MCP server and the Async API let your own agents or jobs call CoCo. | You are building automation, not using a chat interface. |

Most people assume the first one is the whole story. The second is usually where the interesting work is.

## Before you start

> **Your object names carry your user name.** Everything this lab creates at
> account level is suffixed with your Snowflake user, so a whole room can run it
> in one account without collisions: your database is
> `COCO_WS_LAB73_DB_<your_user>`. The last query in `setup.sql` prints the exact
> names -- keep them to hand.
>
> Inside the SQL files those names are built with session variables (`$LAB_DB`).
> **CoCo does not see them,** because it runs its own session. So wherever a step
> below asks you to prompt CoCo, paste the real name rather than `$LAB_DB`.

```bash
snow sql -f labs/73-coco-in-your-ide/setup.sql -c <your-connection>
```

Expected: 10 rows, and a top region for 2026 of **Northern Europe at 41,880,500.00**. Both exact -- every value in this table is a hardcoded literal, and `FISCAL_YEAR` 2026 is a literal too, so nothing here goes stale with the calendar.

Note that number. It is fixed and arbitrary, so if your IDE reports it, the connection is very likely reaching Snowflake rather than producing something plausible.

> **One caveat, worth knowing before you trust the test.** The value also sits in this lab's `setup.sql`, and step 3 below asks the agent to read that file. An agent with filesystem access could in principle answer from the file rather than from the account. If you want the check to be airtight, ask it for something that exists only in the account -- the table's row count, its primary key, or `CURRENT_ACCOUNT()` -- and confirm it names the query it ran.

## Steps

### Step 1 -- Pick your direction (about 2 minutes)

From CoCo in Snowsight or your installed VS Code extension:

```
I want to use CoCo inside VS Code rather than only in the Desktop app. What are my
options, what does each one give up, and which would you recommend for someone who
works in VS Code all day against Snowflake?
```

**What good looks like:** the three directions above, distinguished properly, and a straight recommendation for your IDE rather than a list.

### Step 2 -- Install it in your IDE (about 8 minutes)

```
Walk me through installing CoCo in VS Code on this machine. Then tell me exactly
how I verify it is connected to my Snowflake account and not just running as a generic
coding assistant.
```

For VS Code install `snowflake.snowflake-vsc` from the Marketplace. Verify the active account and role in the extension and in the agent's SQL session independently. Snowflake CLI (`snow`) is a separate optional installation for running setup files; it is not the CoCo CLI (`cortex`).

**What good looks like:** a working install, plus a specific verification step -- not "it should work now".

### Step 3 -- Prove it (about 4 minutes)

From inside **your IDE**, not CoCo Desktop:

```
Which sales region had the highest revenue in fiscal year 2026, and how much was it?
Use COCO_WS_LAB73_DB_<your_user>.LAB.REGIONAL_REVENUE.
```

**What good looks like:** Northern Europe, 41,880,500.00.

**If it goes sideways:**

| Symptom | Meaning |
|---|---|
| A plausible but wrong number | It is not reading Snowflake. It invented an answer. The connection is not working. |
| "I cannot access that table" | Connected, but the role or database context is wrong. |
| Exactly 41,880,500.00 | Consistent with the fixture, but not proof of execution: the value is also in this repository. Require the executed SQL and query ID. |

That middle-versus-first distinction is the whole reason this table has arbitrary fixed values. A test where the answer is guessable proves nothing.

Then push on what it knows beyond the query:

```
What are the primary key columns on that table, and where did you get that from?
```

A real connection answers `(REGION_NAME, FISCAL_YEAR)` from the account's metadata.

Worth doing while you are here: ask it something that needs both halves at once, which is the actual reason to run it in the IDE rather than a browser tab.

```
Read the setup.sql in this repository for this lab, then tell me whether the table it
creates matches what is actually in my account right now.
```

Only an agent that can see your working files *and* your account can answer that. That combination is the point of this lab.

### Step 4 -- The other direction: MCP (about 6 minutes)

Optional comparison in CoCo Desktop if available; otherwise stay in your editor and consult its MCP documentation:

```
I want CoCo to be able to read our issue tracker while it works, so I can say "fix the
problem described in ticket X" and it has the context. Explain how MCP support works
here, what I would need to configure, and what CoCo can and cannot see once connected.
```

**What good looks like:** an explanation of MCP servers as the mechanism, what configuration is required, and an honest account of the security boundary -- what credentials are involved and what the agent can reach.

Do not skip that last part. It is the question your security team will ask first, and "it uses MCP" is not an answer.

## Check your work

Two things should now be true:

1. From your IDE, you can ask a question about `COCO_WS_LAB73_DB_<your_user>.LAB.REGIONAL_REVENUE` and get **41,880,500.00** for Northern Europe in 2026.
2. You can explain, without looking it up again, which direction of integration you configured and what the alternative would have given you.

If the second one is shaky, the lab has not landed -- the choice matters more than the install.

## What just happened

You connected CoCo to the IDE you already use, and verified the connection with a number that could not be guessed. That verification habit is worth more than the install: "the assistant answered confidently" and "the assistant read my account" look identical until you check against something arbitrary.

The reason both directions exist is that they solve different problems. An extension in your IDE removes the friction of switching windows, and gives the agent your open files and repository for free. MCP removes the friction of *context* -- the agent can see the ticket, the repo and the warehouse at once, which is the actual shape of most real work.

## Take it further

- Configure an MCP server for a system your team really uses, and try a task that spans it and Snowflake.
- Run the same task in your IDE and in CoCo Desktop. The gap tells you which surface fits which work -- in-IDE wins when the repository matters, Desktop wins when the task is mostly account-side.
- Look at the Agent SDK and ask what it would take to run one of the earlier labs as a scheduled job rather than a conversation.
- Re-run Lab 62 afterwards. Editor integrations use the CLI backend and are recorded as CLI usage; do not assume they have an independent IDE billing surface.

## Clean up

```bash
snow sql -f labs/73-coco-in-your-ide/cleanup.sql -c <your-connection>
```

Drops `COCO_WS_LAB73_DB_<your_user>`. **Your IDE configuration is untouched** -- that is the thing worth keeping. Remove the extension or plugin through your IDE if you want it gone.
