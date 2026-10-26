# profile.template — versioned sandbox HOME

`runner/run.sh` recreates `profile/` from this template for every invocation.
`HOME` points to that copy; `CLAUDE_CONFIG_DIR` points to its `.claude/`
subdirectory. The runner does not use the caller's real Claude configuration.
This controls configuration discovery, not operating-system filesystem or network
access. Run serially per checkout because the live profile is shared.

## Settings and the Track B invocation

The tracked `.claude/settings.json` deliberately contains only:

- `includeCoAuthoredBy: false`, to avoid generated coauthor trailers;
- `cleanupPeriodDays: 3650`, to retain transcripts during a campaign;
- `permissions.defaultMode: "default"` and empty `permissions.allow` / `deny` lists.

`track_b.py` passes this copied settings file through `--settings`, uses
`--mcp-config` with the repository's empty MCP file and adds `--strict-mcp-config`.
Its default permission mode is `acceptEdits`; standalone callers can select
`--permission-mode`. Empty permission lists are not a deny-all policy or a
workspace boundary. The campaign wrapper does not expose a permission-mode flag.

`run.sh` supplies the sanitized environment, telemetry/update/compaction controls
and pinned effort/thinking values. The live canary and version check validate the
installed harness contract; configuration flags alone do not prove MCP isolation.
See the [operator guide](../../docs/current-operations.md) and the original
[specification](../../docs/ambiente-isolado.md) for the implemented/design boundary.

Transcripts under `.claude/projects/` supply C2 metrics. Retain needed artifacts
securely before the next run recreates the profile: the long cleanup period does
not survive that deletion. Do not add hooks, status lines, MCP servers, subagents
or environment overrides to this template; they would change the benchmark's
configuration inputs.
