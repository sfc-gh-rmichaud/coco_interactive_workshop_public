# Bundled skills: a practical field guide

This is a task map, not an exhaustive inventory or a promise of availability.
Inspect installed descriptions and source badges first. Names below are examples
from the documented/current workshop authoring environment; versions and surfaces
can differ. A user/profile skill with the same name is not automatically bundled.

Desktop: type `/` and select the installed skill. CLI: inspect `/skill list` and
use the displayed invocation or `$skill-name`. In either case verify the actual
loading event. Natural-language routing is useful but should be observed, not
assumed. A skill is a maintained workflow, not permission to perform every step.

| Goal | Skill family to inspect | Safe starter request | Existing workshop route |
|---|---|---|---|
| Learn the interface | cortex-code-guide | Explain commands for this surface; change nothing | 81, 91 |
| Create/audit a skill | skill-development | Audit this local template; do not install or publish | 71, 83 |
| Package extensions | plugin-creator | Plan a local skill/agent/MCP package; no hooks or publishing | 86 |
| Write and verify SQL | sql-author, verification-skill | Review the supplied query and grain; no execution yet | 61, 92 |
| Data quality | data-quality | Propose checks for this fixture; attach no monitors | 23, 92 |
| One-time file load | copy-load | Plan loading this fixed staged batch once | 25, 93 |
| Continuous file ingestion | snowpipe | Compare auto-ingest requirements with a one-time load | 93 |
| Streaming records | snowpipe-streaming | Explain channel/offset checks for a proposed stream | 24 |
| Declarative transformation | dynamic-tables | Review freshness and refresh-mode requirements | 21, 93 |
| Scheduled procedural work | snowflake-tasks | Plan a suspended task and verification; do not resume | 93 |
| dbt as a Snowflake object | dbt-projects-on-snowflake | Explain native deployment prerequisites, not local dbt commands | 22 |
| Python in Snowflake | snowpark-python | Review handler/runtime constraints without deploying | 25, 34 |
| Semantic views and agents | agent-studio | Plan grounding and evaluation cases using synthetic inputs | 31, 32, 33, 95 |
| Choose an AI function | cortex-ai-function-studio | Recommend a function and evaluation plan; no inference execution | 95 |
| One-off document extraction | document-intelligence | Explain extraction checks for a supplied synthetic document | 25 |
| Incremental file AI pipeline | ai-functions-pipeline-builder | Plan stages and reprocessing; create nothing | 25, 93 |
| Cortex Search | search-optimization | Plan a document-search service; do not confuse with SQL SOS | 32 |
| New data app | build-app, selected framework skill | Choose a framework from explicit read/write and UI needs | 41, 42, 95 |
| Streamlit | developing-with-streamlit-in-snowflake or installed equivalent | Review UI states and runtime access before deployment | 41, 43 |
| Notebooks / ML | snowflake-notebooks, machine-learning | Plan reproducible evaluation; do not train or provision compute | 34 |
| Credits and cost evidence | cost-intelligence | Analyze supplied synthetic credits and state missing evidence | 62, 94 |
| Dollar billing | billing | Explain required invoice/rate evidence; do not infer a dollar total | 94 |
| Warehouse configuration | warehouse | Propose a bounded sizing test; do not resize | 61, 94 |
| Query performance / SQL SOS | workload-performance-analysis | Plan spill/pruning/queue diagnostics for a bounded workload | 61 |
| Protect data / access diagnosis | data-governance, access-troubleshooter | Review the fictional grant matrix; grant nothing | 51, 53, 94 |
| Account security | security-investigation, trust-center | Define an authorized scope and evidence plan before scanning | 52 |
| Dependencies and provenance | lineage | Explain a bounded impact-analysis plan; distinguish file and account evidence | 11, 72 |
| Trusted data choice | recommend-object, certified-data-product-discovery | Explain trust signals and certification requirements | 11 |
| Share data | sharing and selected specialist | Compare options; do not publish or grant access | Further study |
| Telemetry / alerts | event-table, alert, notification | Plan evidence and delivery checks; do not send or schedule | 93 |

## Four distinctions to practice

1. **Bundled vs catalog:** built-in workflows need no separate repository install.
   Shared catalog and community skills have separate provenance and access.
2. **Router vs specialist:** an entry skill can select another workflow; record the
   handoff rather than demand every task stay in the first skill.
3. **CoCo subagent vs Cortex Agent:** a delegated coding/research worker is not a
   deployed Snowflake agent over semantic views or search services.
4. **Instructions vs permissions:** a skill describes behavior. Roles, tool
   controls and sandboxing constrain execution. No skill is a grant of authority.

## When a skill is missing

Record surface/version and the missing name. Inspect available descriptions for
an equivalent. If none fits, keep the exercise conceptual and label invocation
unverified; do not fabricate a loading event. Do not install a similarly named
third-party plugin without source review and approval.

## Verification rubric

A completed exercise records the actual skill source/loading event, correct
scope, observed result, an independent check, and cleanup or a clear no-resource
statement. Static file validation, a local fixture run and a real account/UI
walkthrough are different levels of evidence.

[Official bundled catalog](https://docs.snowflake.com/en/user-guide/cortex-code/bundled-skills)
| [Desktop skills](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code-desktop/skills)
| [Practice kit](README.md)
