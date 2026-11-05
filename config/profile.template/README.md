# profile.template — versioned sandbox HOME

`runner/run.sh` recreates `profile/` from this template for every invocation.
`HOME` points to that copy; `CLAUDE_CONFIG_DIR` points to its `.claude/`
subdirectory. This selects a separate Claude configuration. It does not confine
the process's filesystem or network access. Run serially per checkout because
the live profile is shared.

## Settings and the Track B invocation

The tracked `.claude/settings.json` contains only:

- `includeCoAuthoredBy: false`, to avoid generated coauthor trailers;
- `cleanupPeriodDays: 3650`, for the client's transcript cleanup policy;
- `permissions.defaultMode: "default"` and empty `permissions.allow` / `deny` lists.

`track_b.py` supplies this copied settings file through `--settings`, uses the
empty MCP file with `--mcp-config` and adds `--strict-mcp-config`. Its explicit
permission-mode argument defaults to `acceptEdits`; standalone callers can
select `--permission-mode`. The campaign wrapper does not expose that flag.
The empty permission lists are not a deny-all policy or a workspace boundary.

`run.sh` supplies the sanitized environment, telemetry/update/compaction controls
and pinned effort/thinking values. The live canary and version check are separate
operator evidence; configuration flags alone do not prove that an installed
harness followed the intended contract. See the
[current operator guide](../../docs/current-operations.md) and the original
[design specification](../../docs/ambiente-isolado.md).

Transcripts under `.claude/projects/` supply C2 metrics. Preserve needed artifacts
securely before the next run recreates the profile: the long cleanup period does
not survive that deletion. Do not add hooks, status lines, MCP servers, subagents
or environment overrides here; each changes the benchmark's configuration inputs.
