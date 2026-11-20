# Facilitation notes

For the hosts of the December 2, 2026 session. Public on purpose: nothing here
is private, and anyone re-running the workshop can use it.

## Roles

| Role | Responsibilities |
|---|---|
| **Presenter** | Slides, live demonstration in CoCo Desktop, pacing. |
| **Co-host / moderator** (required) | Chat, polls and surveys; triages blockers to the right section of `EVENT_GUIDE.md`; flags recurring problems to the presenter; keeps time. |

The event requires a second host in the meeting to run chat, polls and surveys.
**Confirm who is doing it before the day** -- being a listed speaker is not the
same as having agreed to moderate.

## Run of show (Eastern Time)

The session is **90 minutes: 20 presenting, 70 hands-on.** Five labs at their
full length would take about 135-145 minutes, so each lab runs as a checkpoint
of its first steps; the rest is take-home. To make the checkpoints fit, Step 1
of Labs 21, 31 and 32 is a presenter demo of about 2 minutes (attendees watch,
then run Steps 2-3), and their verification prompts ask only for the figure in
"Done when". The per-step minutes are guidance from the lab READMEs, not
measured in a live run; Lab 32 is the tightest block.

| Time | Min | Block | Slides | Poll |
|---|---|---|---|---|
| 12:00 | 12 | Welcome, Part 1 bridge, agenda, possibilities by role, prompt pattern, reusable context, guardrails | 1-7 | -- |
| 12:12 | 4 | Prerequisites and readiness check | 8 | **Readiness** |
| 12:16 | 8 | Lab 10 checkpoint (Steps 1-2) | 9 | -- |
| 12:24 | 15 | Lab 11 checkpoint (Steps 1-3) | 10 | **Confidence** at about 12:35 |
| 12:39 | 16 | Lab 21 checkpoint (Step 1 demo, Steps 2-3) | 11 | -- |
| 12:55 | 15 | Lab 31 checkpoint (Step 1 demo, Steps 2-3) | 12 | **Biggest challenge** |
| 1:10 | 16 | Lab 32 checkpoint (Step 1 demo, Steps 2-3) | 13 | -- |
| 1:26 | 4 | Save context, clean up, signpost the catalog | 14-18 | **Usefulness for your role** |

Blocks total 90 minutes. Polls run inside their blocks; they do not add time.
There is no protected Q&A block: the co-host answers questions in chat
throughout and surfaces the common ones to the presenter between labs. The
catalog slides (15-16) are a ten-second signpost, not narration.

### When running behind

The live schedule has almost no slack, and Labs 31 and 32 back to back are the
heaviest stretch. Cut, in this order:

1. The stretch prompts in Labs 10 and 11 (evidence table, defensibility check,
   audience rewrite).
2. The Lab 32 follow-up "Where did the four-hour figure come from?" -- keep
   the Iberia check.
3. **Switch one of Lab 31 or Lab 32 to a presenter-led demo** from a prepared
   account, and let attendees catch up on the other.

**Never cut** verification steps or the Lab 32 cleanup -- its Cortex Search
service keeps running until it is dropped.

## Polls

1. **Readiness** (slide 8): *On a scale of 1-5, how ready are you to follow
   along hands-on?*
2. **Confidence check** (during Lab 11): *How confident are you guiding CoCo
   through a multi-step data exploration?*
3. **Focus check** (slide 12): *What is the biggest challenge you've
   encountered so far in the lab?*
4. **Closing**: *On a scale of 1-5, how helpful is this content for your role?*

## Readiness gates before the day

These are decisions and checks, not things the materials can do for you.

- [ ] **Account model decided.** Either attendees bring an approved sandbox,
      or accounts are provisioned for them. If provisioned, logins and the
      `COCO_WS_USER` role exist and have been tested before the event.
- [ ] **Prework communicated.** The registration follow-up sends attendees'
      administrators [`shared/00_admin_role_setup.sql`](shared/00_admin_role_setup.sql)
      (base grants only, down to `STOP HERE`), and tells attendees to pre-run
      the shared setup plus the Lab 11, 21, 31 and 32 setups. Without that
      prework, the 90-minute plan does not fit.
- [ ] **Attendee-role rehearsal.** Run prework and every live block as
      `COCO_WS_USER`, not an admin role, in a disposable account. In
      particular, confirm that role can create the Lab 21 dynamic tables and
      the Lab 32 agent on its own schema. Time each checkpoint against the run
      of show.
- [ ] **Presenter fallback captured.** A prepared account with Labs 31 and 32
      already built, plus screenshots of each checkpoint, clearly labelled as
      prepared, for attendees who are blocked or when a lab becomes a demo.
- [ ] **Moderator confirmed.**
- [ ] **Links final.** Registration and on-demand recording URLs added to the
      README once they exist. Scan both QR codes on slide 1 with a phone.
- [ ] **Event copy approved** by the event's legal and marketing review,
      including the change from two hours to 90 minutes.

## Handling blockers in chat

| Symptom | Point them to |
|---|---|
| CoCo does not respond / no model access | Prerequisites; check `COPILOT_USER` and `CORTEX_USER` on the role; watch along for now |
| Connected as `ACCOUNTADMIN` or the wrong account | Readiness check -- switch to `COCO_WS_USER` on the approved account before any setup |
| `does not exist` on a lab object | They pasted `$LAB_DB` or skipped prework; use the names setup printed |
| Cannot create database or warehouse | The admin script was not run, or the role is not selected; watch along, or follow Lab 10 (no SQL) |
| Lab 21 pipeline never refreshes | `TARGET_LAG = DOWNSTREAM` on every table -- ask the guide's follow-up question |
| Lab 31 MRR shows 7,013,085 | The current/active guard is missing from the metric |
| Lab 32 agent states a 24-hour SLA | It assumed a target; ask where the figure came from |
| Lab 32 search returns nothing | The service is still indexing after setup; wait a minute and retry |

## On-demand version and follow-up

The event is converted to on-demand afterwards, so the materials assume a viewer
working alone:

- `EVENT_GUIDE.md` holds every prompt and "done when" criterion; nothing relies
  on something only said aloud.
- Poll moments are marked in the run of show above; viewers can skip them.

Suggested follow-up email content: the repository link, `EVENT_GUIDE.md`, the
[full catalog](LABS.md), the take-home steps of today's five labs, the curated
next steps (41, 61, 71), [Lab 12 diagramming](labs/12-generate-diagrams/README.md),
and a reminder to run each lab's cleanup -- Lab 32 first.
