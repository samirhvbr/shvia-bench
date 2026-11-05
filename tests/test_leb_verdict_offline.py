#!/usr/bin/env python3
"""Offline test of how leb.py reads the verifier's exit code — no docker, no LEB.

0.9.4 (external review, 26/10/2026): only exit 0 (no regression) and exit 2
(regression) are verdicts. LEB 1.4.0 made a reading that cannot be made exit 3,
"never an approval and never a regression", and a crash exits 1. Until then any
exit but 0 became `passed: False` → `failed_verification`, and the pending marker
was dropped, so the verifier's failure was charged to the model for good.

A fake `harness/leb_harness.py` exits with the code in FAKE_LEB_EXIT, so the real
`leb.verify` and `leb.patch_results` run against it. Stdlib only.
"""
import json
import os
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "runner"))
import leb  # noqa: E402

HARNESS = """import json, os, sys
args = sys.argv
if "--out" in args:
    json.dump({"characterization": {"regression": os.environ["FAKE_LEB_EXIT"] == "2"}, "probes": []},
              open(args[args.index("--out") + 1], "w"))
sys.exit(int(os.environ["FAKE_LEB_EXIT"]))
"""


def fake_leb():
    root = tempfile.mkdtemp(prefix="fake-leb-")
    os.makedirs(os.path.join(root, "harness"))
    os.makedirs(os.path.join(root, "instances", "LEB-X"))
    with open(os.path.join(root, "harness", "leb_harness.py"), "w") as f:
        f.write(HARNESS)
    return root


def verify_with(root, code):
    os.environ["FAKE_LEB_EXIT"] = str(code)
    sub = tempfile.mkdtemp(prefix="fake-sub-")
    return leb.verify(root, "LEB-X", sub)


def patch_with(root, code):
    """One paid record pending verification, patched by a verifier that exits `code`."""
    os.environ["FAKE_LEB_EXIT"] = str(code)
    tmp = tempfile.mkdtemp(prefix="fake-results-")
    ws = os.path.join(tmp, "ws")
    os.makedirs(ws)
    results = os.path.join(tmp, "results.jsonl")
    rec = {"case_id": "c1", "status": "pending_verification", "harness_outcome": "ok",
           "verification": {"passed": None, "pending": "leb", "workspace": ws, "leb_instance": "LEB-X"}}
    with open(results, "w") as f:
        f.write(json.dumps(rec) + "\n")
    done = leb.patch_results(root, results)
    return done, json.loads(open(results).read().splitlines()[0])


def main():
    root = fake_leb()
    v = {code: verify_with(root, code) for code in (0, 2, 3, 1)}
    d3, r3 = patch_with(root, 3)
    d1, r1 = patch_with(root, 1)
    d2, r2 = patch_with(root, 2)
    checks = {
        "exit 0 → passed True": v[0]["passed"] is True,
        "exit 2 → passed False (regression)": v[2]["passed"] is False,
        "exit 3 → no verdict, marked inconclusive": v[3]["passed"] is None and v[3].get("inconclusive") is True,
        "exit 1 (crash) → no verdict": v[1]["passed"] is None,
        "the exit code is kept as evidence": v[3]["exit_code"] == 3 and v[1]["exit_code"] == 1,
        "patch with exit 3: still pending, reverifiable": (
            r3["verification"].get("pending") == "leb" and r3["status"] == "pending_verification" and d3 == 0),
        "patch with exit 1: still pending, not failed_verification": (
            r1["verification"].get("pending") == "leb" and r1["status"] != "failed_verification" and d1 == 0),
        "patch with exit 2: failed_verification, pending gone": (
            r2["status"] == "failed_verification" and "pending" not in r2["verification"] and d2 == 1
            and "inconclusive" not in r2["verification"]),
    }
    print()
    allok = True
    for k, ok in checks.items():
        print(f"  [{'pass' if ok else 'FAIL'}] {k}")
        allok = allok and ok
    print(f"\nLEB VERDICT OFFLINE ({len(checks)} checks):", "ALL PASS" if allok else "FAILURES ABOVE")
    sys.exit(0 if allok else 1)


if __name__ == "__main__":
    main()
