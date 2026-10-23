# Changelog

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
