# Run artifacts

Write-only for processes executing a model (spec §4.1). Post-run operator
verification, repairs and summaries may read these artifacts without feeding
results back into the next model execution.

Official results are reviewed and copied to `results/<run_id>/` after the audit;
see [publication rules](../results/README.md) and the
[current artifact map](../docs/current-operations.md#artifacts-and-interpretation).
