# Full lab catalog

**26 labs across 7 tracks.** All are included for continued practice after the webinar.

The two-hour [live guide](EVENT_GUIDE.md) remains curated: **10, 11, 41 and 62**.
The original next-step recommendations (**21, 61, 71**) are still highlighted below.
**Lab 12 -- diagramming** is also included: turn schema metadata into ER and data-flow diagrams, then export a shareable artifact.

## Before choosing a lab

- All duration estimates below are **guidance for the full lab**, not extra time in the webinar.
- Read the lab's prerequisites, supported surface and cleanup before starting; Desktop is not the right surface for every lab.
- Data labs use disposable sample resources. Run only the setup required by your chosen guide.
- Lab 10 is research-only. Lab 74 works in a private Snowsight workspace and has separate file cleanup.
- **Lab 42 is a 90-120 minute stretch project**, with elevated privileges, feature-availability restrictions and resources that can keep billing while idle. Read its warnings first.
- Follow each lab's cleanup. Shared SQL cleanup does not remove local extensions, workspace files or all administrative resources.
- Inclusion is not a claim of live validation on your account or installed build. Check feature access and permissions; record incomplete steps honestly.

## Discover and understand

Research technical questions, then explore unfamiliar data and explain its structure.

| Lab | Exercise | Full-lab time (guidance) | Session role |
|---|---|---|---|
| 10 | [Answer architecture, technology and feature questions](labs/10-ask-architecture-questions/README.md) | 25-35 minutes (guidance); choose one complex scenario | Live checkpoint |
| 11 | [Explore a schema you have never seen](labs/11-explore-unfamiliar-schema/README.md) | 20 minutes | Live core |
| 12 | [Generate ER and data-flow diagrams](labs/12-generate-diagrams/README.md) | 20 minutes | Take-home - diagramming |

## Data engineering

Build and defend pipelines, from a plain-English spec to a tested, scheduled project.

| Lab | Exercise | Full-lab time (guidance) | Session role |
|---|---|---|---|
| 21 | [Build a pipeline from a plain-English spec](labs/21-build-a-pipeline/README.md) | 30 minutes | Curated take-home |
| 22 | [The same pipeline, as a dbt project on Snowflake](labs/22-build-a-pipeline-with-dbt/README.md) | 35 minutes | Take-home |
| 23 | [Data quality checks that persist](labs/23-data-quality-checks/README.md) | 20 minutes | Take-home |
| 24 | [Stream IoT telemetry in, and watch it live](labs/24-realtime-iot-telemetry/README.md) | 40 minutes | Take-home |
| 25 | [Files into raw tables](labs/25-ingest-files/README.md) | 35-45 minutes (guidance) | Take-home |

## AI and agents

Model the semantics, put an agent on it, then measure whether the agent is actually right.

| Lab | Exercise | Full-lab time (guidance) | Session role |
|---|---|---|---|
| 31 | [Build a semantic view, then evaluate it](labs/31-build-a-semantic-view/README.md) | 30 minutes | Take-home |
| 32 | [A Cortex Agent over structured and unstructured data](labs/32-cortex-agent/README.md) | 30 minutes | Take-home |
| 33 | [Evaluate a Cortex Agent, then make it measurably better](labs/33-evaluate-a-cortex-agent/README.md) | 35 minutes | Take-home |
| 34 | [Forecast in a notebook with Snowflake ML](labs/34-notebook-forecasting/README.md) | 30 minutes | Take-home |

## App development

Ship something a user can open, from a Streamlit page to a full-stack app on SPCS.

| Lab | Exercise | Full-lab time (guidance) | Session role |
|---|---|---|---|
| 41 | [Ship a Streamlit app into Snowflake](labs/41-ship-a-streamlit-app/README.md) | 30 minutes | Live checkpoint |
| 42 | [A full-stack React app on SPCS, over Snowflake Postgres](labs/42-fullstack-app-on-spcs/README.md) | 90-120 minutes | Take-home stretch |
| 43 | [Build an account usage dashboard](labs/43-account-usage-dashboard/README.md) | 40-60 minutes (guidance) | Take-home |

## Governance and security

Find what is sensitive, protect it at scale, and check the account against best practice.

| Lab | Exercise | Full-lab time (guidance) | Session role |
|---|---|---|---|
| 51 | [Find PII and mask it](labs/51-find-and-mask-pii/README.md) | 25 minutes | Take-home |
| 52 | [Review an account against security best practice](labs/52-account-security-review/README.md) | 30 minutes | Take-home |
| 53 | [Govern a hundred columns without touching a hundred columns](labs/53-governance-at-scale/README.md) | 35 minutes | Take-home |

## Performance and cost

Diagnose a slow query, control what data costs to keep, and attribute the spend.

| Lab | Exercise | Full-lab time (guidance) | Session role |
|---|---|---|---|
| 61 | [Fix a deliberately bad query](labs/61-fix-a-slow-query/README.md) | 25 minutes | Curated take-home |
| 63 | [Make old data cost less, on purpose](labs/63-storage-lifecycle/README.md) | 30 minutes | Take-home |
| 62 | [What did today actually cost? (capstone)](labs/62-cost-and-usage-capstone/README.md) | 25 minutes | Live checkpoint |

## Working with CoCo

Make CoCo yours: reusable skills, a change through CI, and CoCo inside your IDE.

| Lab | Exercise | Full-lab time (guidance) | Session role |
|---|---|---|---|
| 71 | [Turn a recurring task into a reusable skill](labs/71-author-a-coco-skill/README.md) | 25 minutes | Curated take-home |
| 72 | [Put a SQL change through CI](labs/72-sql-change-through-ci/README.md) | 25 minutes | Take-home |
| 73 | [CoCo in your IDE](labs/73-coco-in-your-ide/README.md) | 20 minutes | Take-home |
| 74 | [Organize an unnamed Snowflake workspace](labs/74-organize-a-workspace/README.md) | 15-20 minutes (guidance) | Take-home |
| 75 | [Build a real Cortex Agent terminal client](labs/75-build-terminal-tools/README.md) | 45-60 minutes for one language; porting is a stretch (guidance) | Take-home |
