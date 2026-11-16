# Local extension practice kit

Used by Labs 81-86, 92 and 94. Labs 91, 93 and 95 need only a fresh chat and a
place to save notes. This kit contains synthetic data only. CoCo inference can
incur AI charges; these scripts themselves never connect to Snowflake or the
internet, install software, register extensions or modify global configuration.

## Requirements and surface contract

- Python 3.10+; standard library only. On Windows substitute `py -3` for `python3`.
- An approved CoCo connection. CLI examples were checked against installed v1.2.8
  help on 2026-10-14; run your own `cortex --version` and `--help`.
- Desktop is optional for CLI exercises and has distinct controls. Use the
  [official platform prerequisites](../../docs/PREREQUISITES.html).
- MCP, plugins and custom agents may be restricted by organizational policy.
  Record an unavailable feature; do not bypass policy to complete a lab.

| Item | CLI | Desktop |
|---|---|---|
| Launch | `cortex -c <connection> -w <practice>` | Open practice folder; `coco <path>` is the optional editor launcher |
| Skill inventory | `/skill list` inside the session | Agent Settings > Skills, source groups |
| Explicit skill | `$name` or installed picker; verify version-specific slash spelling | `/` picker; select actual skill, including plugin namespace |
| Project skill | `.cortex/skills/<name>/SKILL.md` | `.snowflake/cortex/skills/<name>/SKILL.md`, or registered local parent folder |
| Project agent | `.cortex/agents/<name>.md` | Subagents interface; inspect saved source and runtime tools |
| MCP | Explicit `--mcp-config` JSON; see Lab 84 | MCP interface or workspace `.cortex/mcp.json` |
| Plugin | `--plugin-dir <path>` for session-local loading | Add Local Plugin by reference |
| Reload | Use installed `/plugin reload` or restart | Plugins refresh and fresh chat |

Use actual runtime tool IDs in custom agents, such as `read`, `glob`, `grep`.
Do not copy capitalized permission aliases into agent tool lists. Skills are
instructions, not permission enforcement; an agent tool list is not filesystem
isolation. Keep approvals enabled. `--sql-read-only` would constrain the SQL
tool, not every shell or MCP operation; it is not used as a universal safety claim.

The lab templates use skill-backed commands. Legacy CLI command files are not
assumed to load in Desktop. Installed skill names and routing vary by version;
record the loaded source, especially when a user/profile skill shadows a bundle.

## Initialize and verify

Run commands from the workshop root, including from an unzipped customer package:

```bash
python3 shared/extension_lab/practice.py init --lab 84 --dest ../coco-lab84
python3 shared/extension_lab/practice.py smoke-mcp --dest ../coco-lab84
```

The parent must exist and destination must not exist. Existing directories and
symlinks are refused. Choose a fresh path for a rerun; nothing is overwritten.
The script prints absolute paths and writes a practice marker. Config paths are
machine-local; regenerate them on a different machine instead of sharing them.
No template is installed automatically. Complete TODOs and review code before
copying a skill/agent/plugin into a discoverable location.

The report verifier accepts only the original release fixture, checking the JSON
shape, decision, required rule coverage and source filenames. It deliberately
refuses modified fixtures, because its oracle does not implement a general
release policy. It cannot prove that evidence prose is truthful or that an agent
actually called a tool; inspect the transcript separately.

```bash
python3 shared/extension_lab/practice.py verify --dest ../coco-lab84 --report review.json
```

The SQL exercise uses SQLite **in memory** over the synthetic CSVs. Its independent
Python oracle includes NULL statuses, excludes cancelled orders, and counts each
order once. Empty eligible input must return zero count and zero revenue. Tests
also add a duplicate event and a distinct order with the same amount. The checker
allows only bounded reads/functions on its fixture tables; it rejects writes and
external database attachment. It is **not Snowflake compilation or account proof**.

```bash
python3 shared/extension_lab/practice.py sql-check --dest ../coco-lab92 --query corrected-query.sql
```

## Evidence log

For every actual session, save a small local record:

| Field | Record |
|---|---|
| Surface/version/model | Observed values, not another attendee's defaults |
| Scope | Absolute practice path and explicitly chosen connection; never secrets |
| Input | Prompt/case and fixture revision |
| Invocation | Actual skill/tool/agent name and source from trace |
| Result | Observed output or precise failure |
| Check | Command/status; separate protocol, static, model and live-account checks |
| Cleanup | Registration removed/process stopped/files reviewed |

Do not publish logs, session exports or config files without reviewing them and
choosing a destination/audience. Raw traces may include private paths or inputs.
An unavailable feature, an untested surface and a failed exercise are different
states. The workshop validation notes report what the author actually ran.

## Cleanup

No recursive delete command is provided. Close sessions and stop lab agents/MCP
children first. Unregister only the lab-owned entries you added through the UI.
If editing config, remove only your named entry and preserve unrelated content.
Then inspect/delete the dedicated practice folder in your file manager. Keep
anything you authored if desired. Never delete `~/.snowflake/cortex`, credentials,
other registrations or history as workshop cleanup.

## Sources

- [CLI reference](https://docs.snowflake.com/en/user-guide/cortex-code/cli-reference)
- [CLI extensibility](https://docs.snowflake.com/en/user-guide/cortex-code/extensibility)
- [CLI plugins](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code-plugins)
- [CLI MCP](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code-mcp)
- [Desktop skills](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code-desktop/skills)
- [Desktop plugins](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code-desktop/plugins)
