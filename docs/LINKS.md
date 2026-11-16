# Links

Everything cited in the deck, plus the useful reference pages. The final slide of the presentation repeats this list so nobody has to photograph the screen.

Setting up a machine from scratch? [`PREREQUISITES.html`](PREREQUISITES.html) in this folder is the step-by-step version, for macOS, Windows, and Linux.

- [Snowflake extension in VS Code](https://docs.snowflake.com/en/user-guide/vscode-ext)
- [Official Snowflake extension Marketplace listing](https://marketplace.visualstudio.com/items?itemName=snowflake.snowflake-vsc)
- [CoCo editor integrations](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code-in-your-editor)
- [Snowflake database roles and view access](https://docs.snowflake.com/en/sql-reference/snowflake-db-roles)
- [Organize files in Workspaces](https://docs.snowflake.com/en/user-guide/ui-snowsight/workspaces-working)

## Advanced CoCo and bundled skills

- [CLI command reference](https://docs.snowflake.com/en/user-guide/cortex-code/cli-reference)
- [CLI extensibility: skills and subagents](https://docs.snowflake.com/en/user-guide/cortex-code/extensibility)
- [CLI plugins](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code-plugins)
- [CLI MCP](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code-mcp)
- [Desktop skills](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code-desktop/skills)
- [Desktop plugins and compatibility](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code-desktop/plugins)
- [Desktop MCP](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code-desktop/mcp-support)
- [Bundled skill catalog](https://docs.snowflake.com/en/user-guide/cortex-code/bundled-skills)
- [CLI changelog](https://docs.snowflake.com/en/user-guide/cortex-code/changelog)

Check installed help and source badges before following a version-specific example. The bundled inventory and command spellings can differ by surface and build.

## Product and getting started

- [Snowflake CoCo product page](https://www.snowflake.com/en/product/snowflake-coco/) -- overview, and the download links for Desktop and the CLI install command
- [Documentation home](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code) -- note the docs URLs still use the `cortex-code` path
- [CoCo CLI](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code-cli)
- [CoCo Agent SDK](https://docs.snowflake.com/en/user-guide/cortex-code-agent-sdk/cortex-code-agent-sdk)
- [CoCo plugin for Claude Code](https://claude.com/plugins/snowflake-cortex-code)

## Setup and prerequisites

The pages behind slide 14 and behind `PREREQUISITES.html`.

- [Cross-region inference](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cross-region-inference) -- the `CORTEX_ENABLED_CROSS_REGION` parameter, every accepted value, and the data-residency answer for a security review. **CoCo requires this, and it is `DISABLED` by default in most accounts.**
- [BCR 2376, bundle 2026_06](https://docs.snowflake.com/en/release-notes/bcr-bundles/2026_06/bcr-2376) -- sets a same-cloud default for eligible commercial accounts that never configured the parameter. Explains why some accounts now work without anyone touching them, and which account types are excluded
- [Installing the Snowflake CLI](https://docs.snowflake.com/en/developer-guide/snowflake-cli/installation/installation) -- Homebrew, platform installers, and `uv`/`pipx`/`pip`
- [Managing Snowflake connections](https://docs.snowflake.com/en/developer-guide/snowflake-cli/connecting/configure-connections) -- `snow connection add`, `test` and `set-default`
- [Multi-factor authentication](https://docs.snowflake.com/en/user-guide/security-mfa) -- MFA caching, which you want before running a workshop on an MFA-enforced account
- [Models and regional availability](https://docs.snowflake.com/en/user-guide/snowflake-cortex/aisql-regional-availability) -- which models exist natively in a region and which need cross-region inference

## Cost and usage

These are the pages behind slide 12, and behind Lab 62.

- [Cost controls for CoCo](https://docs.snowflake.com/en/user-guide/cortex-code/credit-usage-limit) -- the per-surface daily credit limit parameters, what `-1`, `0` and positive values do, and how account-level and user-level settings interact
- [Per-user quotas](https://docs.snowflake.com/en/user-guide/budgets/per-user-quotas) -- the `SNOWFLAKE.CORE.QUOTA` object behind slide 12: monthly and daily per-user limits, the `CORTEX CODE` domain, notification thresholds, and block enforcement
- [`CORTEX_CODE_CLI_USAGE_HISTORY`](https://docs.snowflake.com/en/sql-reference/account-usage/cortex_code_cli_usage_history)
- [`CORTEX_CODE_SNOWSIGHT_USAGE_HISTORY`](https://docs.snowflake.com/en/sql-reference/account-usage/cortex_code_snowsight_usage_history)
- [`CORTEX_CODE_DESKTOP_USAGE_HISTORY`](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code-desktop/cortex-code-desktop-usage-history-view)
- [Account Usage reference](https://docs.snowflake.com/en/sql-reference/account-usage) -- the latency table, which is the single most useful page for anyone doing cost work

## Reference pages the labs rely on

- [Set up data metric functions with SQL](https://docs.snowflake.com/en/user-guide/data-quality-working) -- Lab 23
- [Data metric function tutorial](https://docs.snowflake.com/en/user-guide/tutorials/data-quality-tutorial-start) -- Lab 23
- [Data quality checks by group](https://docs.snowflake.com/en/user-guide/data-quality-group-by) -- the `WITHIN GROUP` extension in Lab 23
- [`WAREHOUSE_METERING_HISTORY` table function](https://docs.snowflake.com/en/sql-reference/functions/warehouse_metering_history) -- zero latency, Lab 62
- [`WAREHOUSE_LOAD_HISTORY` table function](https://docs.snowflake.com/en/sql-reference/functions/warehouse_load_history) -- Lab 62
- [About Snowflake App Runtime](https://docs.snowflake.com/en/developer-guide/snowflake-app-runtime/about-snowflake-app-runtime) -- Lab 42. Public preview, and not available on trial accounts
- [App Runtime getting started](https://docs.snowflake.com/en/developer-guide/snowflake-app-runtime/getting-started) -- Lab 42, the `snow app setup` / `deploy` / `teardown` sequence
- [`app.yml` reference](https://docs.snowflake.com/en/developer-guide/snowflake-app-runtime/app-yml) -- Lab 42. Names Snowflake Postgres explicitly as a use case for `external_access_integrations`, and documents how `secrets` are mounted
- [`CREATE POSTGRES INSTANCE`](https://docs.snowflake.com/en/sql-reference/sql/create-postgres-instance) -- Lab 42
- [Snowflake Postgres instance sizes](https://docs.snowflake.com/en/user-guide/snowflake-postgres/postgres-instance-sizes) -- Lab 42. `BURST_S` is the smallest documented family
- [Connecting to Snowflake Postgres](https://docs.snowflake.com/en/user-guide/snowflake-postgres/connecting-to-snowflakepg) -- Lab 42. TLS is required

## Blogs

- [CoCo and the modern data stack](https://www.snowflake.com/en/blog/snowflake-coco-ai-coding-agent-modern-data-stack/)
- [Built to scale enterprise AI](https://www.snowflake.com/en/blog/snowflake-coco-built-to-scale-enterprise-ai/)
- [Data development as simple as a prompt](https://www.snowflake.com/en/blog/data-development-simple-as-prompt)
- [Agentic ML and predictive insights](https://www.snowflake.com/en/blog/agentic-ml-snowflake-predictive-insights/)

## Announcements

- [Summit 26 announcement](https://www.snowflake.com/en/news/press-releases/snowflake-coco-redefines-enterprise-ai-development-as-the-coding-agent-built-for-faster-easier-and-more-powerful-innovation-anywhere/) -- where Cortex Code became CoCo (2 June 2026), and where Automations, Cloud Agents, the Skill Catalog and the editor extensions were announced

## Naming, for anyone confused by search results

The product was renamed from **Cortex Code** to **Snowflake CoCo** at Snowflake Summit on 2 June 2026. Same product, same architecture. Documentation URLs, the `CORTEX_CODE_*` parameters and the `CORTEX_CODE_*_USAGE_HISTORY` views all still use the old name, so you will see both spellings for a while. The deck flags this on the title slide.
