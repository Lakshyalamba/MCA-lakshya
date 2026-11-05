#!/usr/bin/env python3
"""Run generic Yosys synthesis; preserve logs/netlists and publish only on success."""
import argparse
from collections import Counter
import hashlib
import json
import os
from pathlib import Path
import subprocess

TOPS = ("predictor_2bit", "predictor_1bit", "branch_target_buffer",
        "next_pc_mux", "branch_resolution", "predictor_top")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path, default=Path("results/synthesis"))
    parser.add_argument("--summary", type=Path, default=Path("evidence/synthesis/summary.md"))
    args = parser.parse_args()
    # Yosys command-language quoting is deliberately avoided for caller paths.
    # Netlists/logs are first written in the fixed generated results directory.
    root = Path(__file__).resolve().parents[1]
    os.chdir(root)
    stage = Path("results/synthesis")
    stage.mkdir(parents=True, exist_ok=True)
    args.summary.unlink(missing_ok=True)  # A failed rerun must not leave stale success evidence.
    yosys = os.environ.get("YOSYS", "yosys")
    version = subprocess.check_output([yosys, "-V"], text=True).strip()
    sources = sorted(Path("rtl").glob("*.v"))
    fingerprints = {str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in sources}
    rows = []
    for top in TOPS:
        commands = ("read_verilog " + " ".join(map(str, sources)) +
                    f"; hierarchy -check -top {top}; synth -flatten -top {top}; "
                    f"check -assert; stat; write_json {stage}/{top}.json")
        log = stage / f"{top}.log"
        subprocess.run([yosys, "-Q", "-T", "-l", str(log), "-p", commands],
                       check=True, stdout=subprocess.DEVNULL)
        netlist = json.loads((stage / f"{top}.json").read_text())
        counts = Counter(cell["type"] for cell in netlist["modules"][top]["cells"].values())
        rows.append((top, sum(counts.values()), dict(sorted(counts.items()))))
    args.output_dir.mkdir(parents=True, exist_ok=True)
    if args.output_dir.resolve() != stage.resolve():
        import shutil
        for top in TOPS:
            for ext in ("log", "json"):
                shutil.copyfile(stage / f"{top}.{ext}", args.output_dir / f"{top}.{ext}")
    metadata = {"yosys": version, "mapping": "generic; synth -flatten; default RTL parameters",
                "rtl_sha256": fingerprints,
                "designs": [{"top": t, "cells": n, "cell_types": c} for t, n, c in rows]}
    (args.output_dir / "manifest.json").write_text(json.dumps(metadata, indent=2) + "\n")
    lines = ["# P5 generic synthesis evidence", "", f"Tool: `{version}`.", "",
             "Command: `make synth-all`. Each top runs in a separate Yosys process with",
             "`hierarchy -check`, `synth -flatten`, `check -assert`, and default RTL parameters.",
             "All six synthesis/check commands succeeded in this run.", "",
             "| RTL top | Generic cells after flattening |", "| --- | ---: |"]
    lines += [f"| `{top}` | {count} |" for top, count, _ in rows]
    lines += ["", "These are generic logic/register cells, not FPGA LUT counts. No device, clock",
              "constraint, placement/routing or timing analysis is included; maximum MHz is unmeasured.",
              "Counts are not additive across tops. `predictor_top` combines direction predictors only;",
              "P1/P2/P3 integration is currently a simulation testbench, not a synthesizable CPU top.",
              "", f"Raw logs, netlists, tool version, per-type counts and RTL SHA-256 hashes: `{args.output_dir}/`.",
              "Generated results are ignored by Git; reproduce locally or download the CI artifact.", ""]
    args.summary.parent.mkdir(parents=True, exist_ok=True)
    args.summary.write_text("\n".join(lines))
    print(f"Synthesized and checked {len(rows)} tops; summary: {args.summary}")


if __name__ == "__main__":
    main()
