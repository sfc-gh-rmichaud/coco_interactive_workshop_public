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

| Time | Min | Block | Slides | Poll |
|---|---|---|---|---|
| 12:00 | 10 | Welcome, Part 1 bridge, agenda, possibilities by role, prompt pattern, reusable context, guardrails | 1-7 | -- |
| 12:10 | 10 | Readiness check | 8 | **Pace** at about 12:18 |
| 12:20 | 10 | Lab 10 checkpoint | 9 | -- |
| 12:30 | 25 | Lab 11 core + audience rewrite | 10 | **Confidence** at about 12:35-12:40 |
| 12:55 | 5 | Catch-up and stretch | -- | -- |
| 1:00 | 30 | Lab 41 checkpoint | 11 | **Biggest challenge**, after the deployment demo |
| 1:30 | 13 | Lab 62 checkpoint | 12 | -- |
| 1:43 | 8 | Save context, clean up | 13 | -- |
| 1:51 | 9 | Q&A, next steps and a brief catalog signpost | 14-16 | **Usefulness for your role** |

Blocks total 120 minutes. Polls run inside their blocks; they do not add time.
The two catalog slides are a brief take-home signpost, not additional live
exercises. Skip their narration if necessary to protect Q&A; attendees have
[the full catalog](LABS.md).

### When running behind

Cut, in this order: the Lab 41 extras (styling, extra charts), the Lab 10
follow-up prompt, then the Lab 11 audience rewrite (assign it as take-home).
**Never cut** verification steps, cleanup or protected Q&A.

## Polls

1. **Pace check** (about minute 15-20): *On a scale of 1-5, how is the current pace of the lab section?*
2. **Confidence check** (about minute 30-40): *How confident are you guiding CoCo through a multi-step data exploration?*
3. **Focus check** (after the Lab 41 demo): *What is the biggest challenge you've encountered so far in the lab?*
4. **Closing**: *On a scale of 1-5, how helpful is this content for your role?*

## Readiness gates before the day

These are decisions and checks, not things the materials can do for you.

- [ ] **Account model decided.** Either attendees bring an approved sandbox,
      or accounts are provisioned for them. If provisioned, logins and the
      attendee role exist and have been tested before the event.
- [ ] **Attendee-role rehearsal.** Run prework and every live block as a
      non-admin attendee role in a disposable account. In particular, confirm
      that role can create and **open** the Lab 41 Streamlit app. If it cannot
      and the fix is not possible in time, swap the Lab 41 slot for Lab 21
      (pipeline, about 30 minutes) and update slides 3 and 11.
- [ ] **Presenter fallback captured.** A pre-built Lab 41 app and screenshots
      of each checkpoint, clearly labelled as prepared, for attendees who are
      blocked.
- [ ] **Moderator confirmed.**
- [ ] **Links final.** Registration and on-demand recording URLs added to the
      README once they exist.
- [ ] **Event copy approved** by the event's legal and marketing review.

## Handling blockers in chat

| Symptom | Point them to |
|---|---|
| CoCo does not respond / no model access | Prerequisites; watch along for now |
| Connected to the wrong account | Readiness check -- switch connection before any setup |
| `does not exist` on a lab object | They pasted `$LAB_DB` or skipped prework; use the names setup printed |
| Cannot create database or warehouse | Role lacks privileges; watch along, or follow Lab 10 (no SQL) |
| Streamlit app will not deploy or open | Mark incomplete, keep the screen design, watch the demo |

## On-demand version and follow-up

The event is converted to on-demand afterwards, so the materials assume a viewer
working alone:

- `EVENT_GUIDE.md` holds every prompt and "done when" criterion; nothing relies
  on something only said aloud.
- Poll moments are marked in the guide-independent run of show above; viewers
  can skip them.

Suggested follow-up email content: the repository link, `EVENT_GUIDE.md`, the
[full catalog](LABS.md), the curated next steps (21, 61, 71),
[Lab 12 diagramming](labs/12-generate-diagrams/README.md), and a reminder to follow
the chosen lab's cleanup.
