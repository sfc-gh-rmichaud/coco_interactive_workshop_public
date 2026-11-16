# Lab 86 -- Package a team workflow as a plugin

| | |
|---|---|
| **Surface** | CoCo CLI and CoCo Desktop |
| **Surfaces** | cli, desktop |
| **Track** | advanced-coco |
| **Sequence** | 60 |
| **Topic** | Plugin composition, validation and lifecycle |
| **Time** | 40-50 minutes (guidance) |
| **Lifecycle** | local-only |
| **Privileges** | Working CoCo sign-in; Python 3.10+; local plugins/MCP permitted |
| **Creates** | A local plugin in a disposable practice directory |
| **Tears down with** | Disable/unregister the practice plugin, close session, remove practice files |

## What you will learn

- Package a skill, custom reviewer and MCP configuration as one reviewed unit.
- Distinguish manifest validation from actual component activation.
- Test version changes and disable/re-enable behavior without publishing or overwriting global configuration.

## Why this matters

A plugin can start local processes and run hooks. A friendly name or valid JSON does not make its contents safe. Review it like code before loading it.

## The scenario

Build a workshop release desk plugin called `ws-release-desk`. Its command reviews a release, its MCP tools retrieve synthetic tickets, and its reviewer independently checks evidence. You may reuse work from Labs 82-85, but those labs are not prerequisites: starter templates are supplied.

## Before you start

```bash
python3 shared/extension_lab/practice.py init --lab 86 --dest ../coco-lab86
```

Windows: use `py -3`. Read the [practice guide](../../shared/extension_lab/README.md). The initializer creates only inert templates and fixtures, **not** an active plugin. No hooks or global registrations are created. The plugin will live at `plugin/` inside this practice folder.

## Steps

### Step 1 -- Review the components and choose scope

```text
Help me build a local workshop plugin named ws-release-desk in this practice
folder's plugin directory. It contains a release-review skill, a read-only
reviewer agent and the supplied local stdio MCP server. No hooks, publication,
network services or global installation. Use the current plugin-authoring
workflow. Review templates and server.py first. Explain every component and
its permission boundary before creating anything.
```

If the wizard asks scope, choose project scope **in this separate practice project**, not the workshop repository; move/use the resulting path consistently if it differs from `plugin/`. Answer its name/component questions with the requirements above. Do not add hooks merely because the wizard offers them.

**What good looks like:** the plan identifies local process execution, read-only tools, skill prompts versus agent tool restrictions, and the absence of credentials.

### Step 2 -- Assemble the package

Create this structure (the component contents are your exercise):

```text
plugin/
  .cortex-plugin/plugin.json
  skills/release-review/SKILL.md
  skills/release-review/references/release-policy.md
  agents/ws-evidence-reviewer.md
  .mcp.json
```

Use the minimal manifest fields from `templates/plugin.json`: name, description and version. Put component directories beside `.cortex-plugin`, not inside it. Copy the generated `mcp-config.json` to `.mcp.json` only after inspecting its absolute paths; it contains this practice server alone. Its paths make this local test valid, **not portable to teammates**. Before distribution, use a reviewed installer/configuration step that resolves each recipient's interpreter and resource paths.

Author or copy your completed release-review skill and reviewer. In a fresh session the skill must read the policy and evidence, validate the release ID, and return the report schema. Do not create `commands/`: skill-backed invocation is the cross-surface route. CLI legacy command support is a compatibility topic, not a Desktop packaging contract.

### Step 3 -- Validate before activating

```bash
cortex plugin validate <absolute-plugin-path>
python3 shared/extension_lab/practice.py smoke-mcp --dest ../coco-lab86
```

Deliberately change the manifest `name` to an invalid value and run validation. Save the observed failure, then restore `ws-release-desk` and rerun. Do not infer that all versions validate exactly the same fields; use a syntactically invalid JSON copy if your version only warns about naming. Never load the broken copy.

**What good looks like:** the restored package passes validation, and the MCP protocol test passes. These checks still do not prove invocation or tool restriction behavior.

### Step 4 -- Load on the chosen surface

CLI: inspect available flags, then load the local path without installing globally:

```bash
cortex -c <approved-connection> -w <absolute-practice-path> --plugin-dir <absolute-plugin-path> --only-explicit-plugins --only-explicit-mcp-servers
```

Check `/plugin list`, `/plugin info ws-release-desk`, `/skill list` and `/mcp`. If your build does not connect plugin MCP when explicit-only MCP loading is selected, pass the generated config explicitly as in [Lab 84](../84-connect-local-mcp/README.md); do not enable every ambient server. The explicit-only flags are loading controls, not a security sandbox or a guarantee that all bundled skills disappear.

Desktop: **Agent Settings > Plugins > + > Add Local Plugin**, select the reviewed plugin root, inspect its components, then enable it. Record the source/path. Local registration references that folder; it does not publish it. Confirm the contributed skill and reviewer and the MCP connection before use.

Invoke the actual namespaced skill from the picker (`/ws-release-desk:release-review` on Desktop; use the displayed CLI spelling), with `REL-204`. Ask it to call `get_ticket` for `WS-102` and delegate an independent read-only review. Require actual tool/agent traces, not claims in the final answer.

**What good looks like:** all three components actually participate and the saved `review.json` passes:

```bash
python3 shared/extension_lab/practice.py verify --dest ../coco-lab86 --report review.json
```

### Step 5 -- Test lifecycle and a local revision

Desktop: disable only this plugin, refresh and start a new chat. CLI: exit, then restart **without** `--plugin-dir` while retaining `--only-explicit-plugins` and `--no-mcp`. Verify the practice contributions are absent. Do not expect a prompt already injected into an old chat to be erased by disabling its source.

Change the local plugin version and improve one description. Reload/re-enable it, inspect the displayed version/source and rerun the workflow in a new session. CLI `/plugin reload` and Desktop refresh are different controls; use the one your build exposes.

**What good looks like:** active/inactive state changes actual availability, and the revised version has fresh-session evidence. This is a local revision exercise, not a Git/catalog update test.

## Check your work

Keep the manifest, authored components, invalid/valid validator output, component traces and lifecycle record. The plugin contains no secrets, unexpected hooks or machine-specific paths disguised as portable configuration. Do not ship an entire personal CoCo directory as a plugin.

## If it goes sideways

- **Manifest passes, component absent:** inspect active state, conventional directories and actual source; start a fresh session.
- **MCP absent:** inspect its config and administrator policy; do not assume plugin activation overrides policy.
- **Duplicate names:** use a unique workshop namespace and inspect which source won.
- **Read-only agent can execute shell:** correct its actual tool configuration; skill prose does not enforce restrictions.

## What just happened

The plugin packages a reviewed workflow; it does not replace component tests or permission checks.

## Take it further

Write a distribution checklist: version/pinned source, portable paths, tested surfaces, dependencies, no secrets, reviewed hooks, least privilege, rollback and selected recipients. Catalog or Git publication requires a separate explicit destination and audience decision. Do not default to account-wide sharing.

## Clean up

Disable and unregister only this practice plugin in Desktop if added. Close all sessions and confirm the stdio child has exited. CLI path-based loading needs no global uninstall. Preserve your authored work if desired, then delete the practice folder. No Snowflake objects or shares were created.

## Sources

[CLI plugins](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code-plugins), [Desktop plugins](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code-desktop/plugins).
