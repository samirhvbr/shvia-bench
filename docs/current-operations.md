# Current operator guide

Reviewed October 15, 2026 against `872dfab` (`0.9.1`). This guide describes the
implemented command paths; the [original specification](ambiente-isolado.md)
contains design choices and the [detailed runbook](rodar.md) has further examples.
No paid run, live canary or provider acceptance was performed for this review.

## What exists

| Component | Implemented behavior |
|---|---|
| Track A | Streaming Anthropic and OpenAI-compatible API requests, configured model aliases, cost computation and repetitions |
| Track B | Claude Code headless adapter, subprocess timeout/budget/turn limits and C1/C2/C3 collection |
| Other harnesses | Registry templates only; unsupported adapters are refused |
| LEB integration | Copy the instance's `code/`, isolate each campaign repetition, then run the LEB verifier after model execution |
| Post-run maintenance | `patch-results` for pending verification; `reclassify` for legacy taxonomy, with provenance |
| Publication | Operator-reviewed copy into `results/<run_id>/`; no automatic official publication |

`config/models.json` and `config/gateways.json` are versioned configuration, not
proof that a dated model still exists or a price matches a current invoice.
`config/harness-matrix.md` records the previously tested CLI surface. Revalidate
that contract before using another installed harness version.

## Local checks without spending

Requires Bash, Python standard library, Git and OpenSSL. The campaign additionally
needs the selected harness, `node` when required by that harness, `nc` and Docker
for LEB verification. `preflight.sh` reports available prerequisites.

```bash
./preflight.sh
LEB_ROOT=/absolute/path/to/ai-benchmark BENCH_SKIP_MAX=0 bash tests/run_all.sh
```

The suite uses local dummy HTTP servers and fake harnesses. `LEB_ROOT` must name a
checkout of the task source; without it the LEB suite may skip. Locally the default
`BENCH_SKIP_MAX=-1` permits skips with a warning, while CI clones the public task
source and enforces `BENCH_SKIP_MAX=0`. Inspect skips, not only exit status.

## Execution boundary

`runner/run.sh --task <id> [--golden <directory>] -- <command...>` prepares a
fresh workspace, recreates `profile/` from the tracked template and executes the
command with `env -i`, sandbox HOME/XDG/Claude configuration and an explicit PATH.
The live workspace defaults to a temporary directory **outside this repository**,
so repository agent instructions do not contaminate the task by parent lookup.
Use absolute script/output paths because the runner changes the working directory.
`--audit-only` prepares and audits without executing the model command.

The process still runs as the invoking operating-system user. The passive proxy
observes only routed API requests; it is not a network firewall. Neither
configuration sanitization nor the destination log proves arbitrary filesystem
or network access is blocked.

**One run at a time per checkout.** `profile/` is shared and deleted/recreated
for each invocation. The default proxy also uses port `8787`. A distinct task
workspace does not make overlapping campaigns safe. `--reps` in standalone Track
B reuses its current workspace/profile; the campaign driver instead invokes the
runner separately for each repetition. Use that driver for independent LEB reps.

Secrets live in ignored `.secrets/<vendor>` files and are injected individually.
The target harness receives them through its environment; avoid secret-valued CLI
options and never source a credential file. The launcher currently executes
`env KEY=value ...`, which can expose values in transient launcher argv; this is
not an argv-secrecy guarantee. The snapshot is built with redacted placeholders. Review all artifacts before publication: configuration
redaction does not prove that a model response or transcript contains no secret.

## Track A and the proxy

Use a different file for proxy records and result records. Mixing them creates
one JSONL file containing two incompatible record types. For an Anthropic run,
start the proxy in a separate terminal, then run the model command:

```bash
# Terminal 1, from the repository root; this process stays in the foreground.
python3 proxy/logging_proxy.py --upstream https://api.anthropic.com \
  --allow api.anthropic.com --log "$PWD/runs/track-a-proxy.jsonl"
```

```bash
# Terminal 2; this command makes paid API requests when the key is configured.
./runner/run.sh --task T-000-noop -- \
  python3 "$PWD/runner/track_a.py" --model M-opus48 --task T-000-noop \
  --reps 1 --max-spend-usd 2 --out "$PWD/runs/track-a-results.jsonl"
```

Track A defaults to a **US$2 ceiling per invocation**, not per repetition.
It estimates the worst next request before starting it. This is not an external
billing cap: prices and prompt estimates must be valid. Missing prices are refused
unless the operator explicitly disables the ceiling with `--max-spend-usd 0`.

A successful response can omit usage. Missing input or output counts leave the
total token count and computed cost `null`; missing output also leaves throughput
`null`. Explicit zero counts remain zero. With no measured token counters,
`cost.usage_source` is `null`. The spend ceiling accounts for a request with unknown cost
using its existing estimate, without publishing that estimate as measured cost.
This affects newly collected records only; historical paid results are not rewritten.
For Anthropic streams, the initial output count in `message_start` is provisional;
the final output count comes from [`message_delta` usage](https://platform.claude.com/docs/en/build-with-claude/streaming).
If that count is absent, output-dependent metrics stay unknown.

`run.sh` forwards `ANTHROPIC_BASE_URL` to its proxy, but does not forward arbitrary
vendor base-URL variables through `env -i`. Other vendors can run directly with
their configured keys; do not claim C3 coverage just because the proxy is running.
To route a vendor through C3, use a reviewed gateway configuration passed with
`--gateways` whose base URL points to the appropriately configured local proxy.
Keep that routing and any `proxy_bypassed` flag in the interpretation of results.

## Track B readiness and resumption

```bash
LEB_ROOT=/absolute/path/to/ai-benchmark \
  runner/campaign_leb.sh M-opus48 LEB-100-A 3 claude-code --dry-run
```

The dry run does not call a model. It reports readiness but exits `0` even when
it prints that the paid campaign would be refused; it is a plan, not a readiness
exit-code gate. Supply `CANARY_RESULT`, `EXPECT_CLAUDE_VERSION` and
`NOOP_OVERHEAD` from real operator evidence before a paid invocation. The driver
refuses missing readiness inputs with exit `4`; each rep then runs the audit in
strict mode, including proxy availability.

The driver does not accept a `--budget` flag. Standalone `track_b.py` does; the
campaign currently uses its defaults of US$2, 900 seconds and 30 turns per rep
after environment sanitization.
Likewise, host variables that are not forwarded are not effective Track B limits.
Check actual argv and recorded options instead of assuming a host variable won.

A new campaign refuses an existing nonempty results path. The operator explicitly
selects `--from-rep N` for append, or `--out <new-path>` for another campaign.
Inspect the existing ledger after execution; the driver must not infer model
control flow from it. Never reuse a repetition number already paid for.

## Artifacts and interpretation

`runs/<run_id>/` contains runner metadata, audit and redacted environment snapshot.
Campaign result and proxy JSONL files can be siblings under `runs/`; the driver
prints their paths. Workspaces are recorded in verification metadata. Do not
assume every artifact is automatically grouped under one run directory.

`runs/` is write-only **for model execution**. Operator post-run verification,
repair and summaries may read it. `profile/` is transient; archive required
transcripts securely before the next run recreates it. Official publication is a
separate reviewed copy governed by [results/README.md](../results/README.md).
The manifest schema exists, but schema files alone do not mean every CLI output
was automatically validated or a complete official manifest was generated.

For Track B, keep `harness_outcome` separate from `verification`. A pending verdict
is not a pass; an API error is not a model failure. `runner/status.py` arbitrates
status. Its collector prefers C3 cost only with complete coverage, then deduplicated
C2, then C1; no usable source means `null`, not zero. Read coverage and
`cost.usage_source` before comparing cost deltas. Track A computes usage directly
from the API response and records `a_api_response`; starting a proxy does not
make its cost collector use the Track B precedence. A zero exit from a maintenance
step does not prove a campaign passed its task verifier.

## Findings for a separate code decision

This documentation change does not modify runners or the proxy. Follow-ups:

- Isolate `profile/` and proxy ports per run before concurrent campaigns.
- Expose and forward campaign limits explicitly; the current wrapper's sanitized
  environment does not carry all Track B limit variables.
- Consider a machine-readable readiness result and stricter dry-run exit semantics.
- Avoid secret-valued assignments in the external `env` launcher's argv if the
  requirement is that credentials never appear in any process arguments.

The current safe operating procedure is serial campaigns, explicit readiness
inspection and preserved, reviewed artifacts. These findings are from source
inspection, not a newly executed paid campaign.
