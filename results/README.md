# Official results

Where the official results of paid campaigns live. The owner's decision on 24/09/2026 (panel
card `bench-onde-ficam-resultados`): **a versioned folder in this repository**.

`runs/` is scratch: write-only, ignored by git, and nothing reads from it (spec §4.1). A run
becomes official when it is copied here, once, after its audit is written.

## Layout

```
results/<run_id>/
  manifest.json   the campaign manifest, validated by manifest.schema.json
  run.meta.json   the run's own trace, written by runner/run.sh
  results.jsonl   one line per case, validated by results.schema.json
  proxy.jsonl     one line per model request: timing, usage, host check
  audit.json      the audit of the run
```

These are the files of checklist item C7 in `docs/ambiente-isolado.md`, plus `run.meta.json`,
minus the transcripts (below). `env.snapshot` stays out too: it is the run's process
environment, which has no place in a public repository.

## Rules

- **Immutable.** A folder is never edited after it lands. A correction is a new run with its own
  folder, and its manifest names the run it corrects.
- **Copied, never produced here.** Nothing writes into `results/` while a run executes; the run
  writes to `runs/<run_id>/`, and the copy happens after its `audit.json` exists.
- **No transcripts.** This repository is public, and a transcript carries what the model wrote,
  which for a benchmark is the answer to the task. Publishing it would put the solutions where
  the next models are trained, which is the contamination that `tests/test_leb_offline.py`
  exists to catch on the way in. Where transcripts are archived is still an open question for
  the owner. `proxy.jsonl` stays because it records timing, usage and the destination check,
  never a request or response body (`proxy/logging_proxy.py`).
