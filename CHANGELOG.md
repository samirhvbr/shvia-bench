# Changelog

## 0.9.5 - Point the agent instructions at the current operator guide

`CLAUDE.md` and `AGENTS.md` sent agents to the spec and to a progress log last
updated on August 16, 2026, but not to `docs/current-operations.md`. They now link
it, date the log, and list the campaign driver's `--dry-run` next to the other
commands, with a warning that without it the driver spends money. The two files
stay identical below the H1.

## 0.9.5 - Add lag notices to the Portuguese README and the v0.2 specification

`README_br.md` still described `work/` as the live workspace and carried an old
phase checklist; a note at its top says it lags behind `README.md` and names the
differences. `docs/ambiente-isolado.md` gains a note that its file names are the
plan rather than the repository, and that of §11 only block A runs as a blocking
audit. Neither page's body was rewritten.

## 0.9.5 - Correct the runbook's canary, noop and Linux-support instructions

`docs/rodar.md` said the suite runs on Linux since 0.8.4; the `mktemp` fix landed in
0.8.7 (`16d573b`). Its readiness table described `CANARY_RESULT` as inline JSON and
`canary.sh --live` without `--out`; the audit reads a file, and only `--out` writes
one. The table now says the proxy must be running, that the version check is a
substring match, and that no script computes the noop overhead. The manual Track B
gotchas gain the explicit `--leb-root`.

## 0.9.5 - Re-verify the README and operator guide against the current runners

Checked against `1317151` (`0.9.3`). The README's layout now names the runners
that were missing (`track_a.py`, `track_b.py`, `collect.py`, `leb.py`), the
configuration files, `results/`, the results schema, the operator guide,
`tools/` and `.claude/`. Its requirements add what Track B and the suite need
(`claude`, `nc`, `timeout` or `perl`).

The operator guide says how to produce the three readiness inputs: `CANARY_RESULT`
is a file written by `canary.sh --live --out`, which needs the proxy running and
`claude` on the sanitized PATH, and whose verdict should be read with its output.
`EXPECT_CLAUDE_VERSION` is a substring match. No runner computes `NOOP_OVERHEAD`.
It also notes the suite's watchdog and that a hand-run `track_b.py` needs an
explicit `--leb-root`. No runner, schema, configuration or result was changed.

## 0.9.3 - Keep missing Track A usage unknown when accounting for requests

A finished API response without usage was recorded with zero cost and throughput,
even though its token counts were unknown. The repetition budget then counted the
request as free instead of using its existing estimate, allowing more calls than
the configured ceiling intended.

Require input and output counts for total tokens and computed cost, preserve
unknown throughput when output is absent, and only claim an API usage source when
a token counter was measured. Explicit zeros stay zero. Loopback HTTP regressions
cover both API formats with absent, empty, null, partial and zero usage; the real
repetition loop now stops at the budget estimate when the server omits usage.
An Anthropic stream's initial output count is not mistaken for its final count
when the closing usage update is missing.
No historical results, price tables or scoring rules are changed.

## 0.9.2 - Document current benchmark execution and acceptance boundaries

Add an operator guide for implemented tracks, isolation, serial execution,
readiness, effective limits, artifacts and official publication. Reconcile
README status and distinguish post-run reads from model execution. Correct
proxy/result output paths and the unsupported campaign budget example without
changing runners, schemas, configuration or paid results.

Entries in the commit-message format (`version - short description in English`),
newest first. **Each `##` heading is literally the commit subject** — the entry
is written *before* the commit, so the sentence that lands in `git log` is one
that was weighed rather than improvised at `git commit` time.

Bodies are narrative: what changed, why, and what was measured. This file is
never rewritten.

> **The record starts here.** This file was created after the repository was:
> earlier versions are in `git log` and are deliberately not back-filled, because
> reconstructing them now would produce a plausible history rather than a true
> one.


## 0.9.1 - the echo blocks are regenerated from repodocs

The marked rules in `CLAUDE.md` and `AGENTS.md` are rewritten from the single
source at [samirhvbr/repodocs](https://github.com/samirhvbr/repodocs):
`QUEUE-RULE`, `RELEASES-RULE`, `LANGUAGE-RULE`, `COMMIT-RULE` and `CICD-RULE`.
A block is replaced whole between its markers, heading included — which is what
stops a local edit from surviving a regeneration and confusing the next reader.

`QUEUE-RULE` is new and arrives here for the first time: `.continue/` holds work
that does not exist yet, and a document leaves it when — and only when — the
thing it describes **exists**. Length, language and untidiness are not exit
conditions. **Never empty that folder as tidying.**
