"""Characterization harness for pricing.quote (testing/characterize, golden-master format of
migration/parity-test-generate). Runs quote() on every sampled input and writes one output per
case into $REFRACT_BASELINE_OUT — the directory baseline-capture.sh and behavior-diff.py compare.
An exception is recorded as its type: a case that starts or stops raising is a behaviour change."""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.abspath(os.path.join(HERE, "..", "..", "..")))
from pricing.quote import quote  # noqa: E402

out = os.environ.get("REFRACT_BASELINE_OUT") or os.path.join(HERE, "__golden__")
os.makedirs(out, exist_ok=True)
for name in sorted(os.listdir(os.path.join(HERE, "inputs"))):
    with open(os.path.join(HERE, "inputs", name)) as fh:
        case = json.load(fh)
    try:
        result = {"ok": quote(case["input"])}
    except Exception as e:  # recorded, not swallowed: the error type IS the observed behaviour
        result = {"error": type(e).__name__}
    with open(os.path.join(out, name), "w") as fh:
        json.dump(result, fh, indent=2, sort_keys=True)
        fh.write("\n")
