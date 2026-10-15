# SHVIA-BENCH — Isolated environment for benchmarking coding models

> ⚠️ **Before working on this repository: `git pull`.**

🇧🇷 [Versão em português](README_br.md)

**A reproducible, contamination-controlled harness for benchmarking LLMs on
software-engineering tasks.** Spec: [`docs/ambiente-isolado.md`](docs/ambiente-isolado.md) (v0.2);
operator runbook: [`docs/rodar.md`](docs/rodar.md).

SHVIA-BENCH is **not** a scoring rubric and **not** a task suite. It is the layer
underneath both: the sterile environment and the instrumentation that let you
compare models fairly. It answers *"how do we run the model with zero unfair
information, and measure everything that happened?"* — while a separate project,
the **[LEB / AI-BENCHMARK](https://github.com/samirhvbr/AI-BENCHMARK)**, answers
*"what is the task, and how is the answer scored?"*. SHVIA-BENCH runs LEB
instances (its first task source) inside a controlled sandbox.

## The one principle

> No run may have access to information another run lacks. If an artifact cannot
> be recreated from scratch from the benchmark repository, it does not enter the
> run.

That cuts persistent memory, conversation history, agent context files, local
cache, RAG/indexing and telemetry. See the 18 contamination vectors (V1–V18) in
the spec.

## Two tracks

- **Track A — raw model:** one request, no tools, no filesystem. Measures raw
  single-response capability.
- **Track B — model + harness:** the same task inside a coding agent (e.g. Claude
  Code), in an ephemeral workspace, non-interactive, to completion or limit.
  Measures the *model + harness* pair.

Comparing A vs B of the same model quantifies **harness gain**.

## Why isolation is `HOME` + process env, not the working directory

A CLI started inside `~/bench/task-01/` still reads user settings, MCP config,
inherited env, prior transcripts and a `CLAUDE.md` hierarchy from *outside* that
folder. New folder, old contamination. The real boundary is **`HOME` + process
environment** — so the runner uses `env -i` + a sandbox `HOME` +
`CLAUDE_CONFIG_DIR`, on the same machine, no container, without touching your
real Claude Code install. (See spec §4.0.)

This controls configuration contamination; it is not an OS filesystem or network
sandbox. Runs share a recreated `profile/` in one checkout: execute them serially.

## Layout

```
runner/run.sh        env -i + sandbox HOME + CLAUDE_CONFIG_DIR — sanitized entrypoint (§4.2)
runner/audit.sh      blocking pre-run audit, block A (A1–A14) → audit.json (§11)
runner/canary.sh     A5 tool canary: proves a planted MCP does NOT leak in (live + --selftest)
runner/status.py     SINGLE arbiter of `status` — two orthogonal axes (§10.4)
runner/campaign_leb.sh   one LEB case end-to-end; never overwrites paid results
proxy/logging_proxy.py   passive logging proxy → proxy.jsonl: TTFT, usage, dest allowlist (§4.4)
config/profile.template/ versioned sandbox HOME (minimal, explicit settings)
config/mcp.empty.json    {"mcpServers": {}}
tasks/T-000-noop/        trivial task — measures the harness's fixed context overhead (§10.6)
manifest.schema.json     run manifest (§8.1); a run aborts if audit_passed is false
docs/rodar.md            operator runbook (how to actually run a campaign)
tests/run_all.sh         the whole offline suite in one command
runs/                    WRITE-ONLY for execution. No process that runs a model reads
                         from here — that is what keeps a previous result from feeding
                         a future run (§4.1). Post-run steps (verify patching,
                         reclassify, summaries) do read it: they run after the fact
                         and feed no model.
work/                    retained placeholder; live workspaces default outside this repository
```

**`status` is not a single axis.** `harness_outcome` (did the execution yield a
valid measurement?) and `verification` (did the delivery pass the task's verifier?)
are separate. Only the verifier may emit `failed_verification` — an API/infra error
is `infra_error` and never becomes the model's score. This is enforced structurally
in `runner/status.py`, after a transient API error was once recorded as a benchmark
failure on a paid run that had actually passed.

## Current implementation and acceptance

Source review: October 15, 2026, baseline `872dfab` (`0.9.1`). Both tracks,
collection, the LEB campaign driver, result repair and immutable publication
conventions exist. Only the Claude Code adapter is implemented for Track B;
Kilo, Cline and Cursor entries are templates, not working integrations.

The original phase specification is not a live campaign ledger. The current
[operator guide](docs/current-operations.md) documents commands, artifacts,
readiness gates, spending and isolation limits. The detailed
[runbook](docs/rodar.md) remains available; official publication rules are in
[results/README.md](results/README.md).

Offline checks exercise fake harnesses and local dummy upstreams. They do not
prove a current provider key works, live MCP isolation, model identity, billing
accuracy or a publishable campaign. Live A5, expected harness version and noop
context overhead are required operator inputs before a paid LEB campaign.

## Requirements

`bash`, `python3` (stdlib only — no external deps), `git`, `openssl`; `docker`
only for LEB instances (not for Phase 1). Run `./preflight.sh` to check.

## Secrets

The bench API key lives in `.secrets/anthropic` (gitignored), injected
individually by `run.sh`; the target harness receives it through its environment.
Do not source or version credential files, or pass a real key as a harness option.
The current launcher uses `env KEY=value`, so this does not guarantee absence from
its transient launcher argv; see the [operator limits](docs/current-operations.md).
