#!/usr/bin/env python3
"""P5: validate reconciled P4 counts and derive direction accuracy and assumed CPI.

Uses only the Python standard library. SVG output is deterministic and portable.
"""
import argparse
import csv
import hashlib
from html import escape
import io
import math
from pathlib import Path
import sys

PREDICTORS = (("base", "Always NT", "#596579"),
              ("one_bit", "1-bit", "#d48018"), ("two_bit", "2-bit", "#167a93"))
INPUT_FIELDS = ["trace_name", "trace_file", "total_branches"] + [
    f"{prefix}_{suffix}" for prefix, _, _ in PREDICTORS
    for suffix in ("correct", "mispredict", "accuracy_pct")]
OUTPUT_FIELDS = ["trace_name", "trace_file", "predictor", "total_branches", "correct",
                 "mispredict", "accuracy_pct", "misprediction_rate", "illustrative_cpi"]


def load_counts(path):
    with Path(path).open(newline="") as source:
        reader = csv.DictReader(source)
        if reader.fieldnames != INPUT_FIELDS:
            raise ValueError("P4 CSV columns/order do not match the required schema")
        rows = list(reader)
    if len(rows) < 2 or rows[-1].get("trace_file") != "ALL_TRACES":
        raise ValueError("Expected workloads followed by one ALL_TRACES aggregate")
    seen_names, seen_files = set(), set()
    for row in rows:
        if None in row or any(value is None or not value.strip() for value in row.values()):
            raise ValueError("Missing or extra CSV values")
        for field in ("trace_name", "trace_file"):
            row[field] = row[field].strip()
        name, file = row["trace_name"], row["trace_file"]
        if name in seen_names or file in seen_files:
            raise ValueError("Duplicate workload name or trace file")
        seen_names.add(name)
        seen_files.add(file)
        total = int(row["total_branches"])
        if total <= 0:
            raise ValueError("Branch totals must be positive")
        row["total_branches"] = total
        for prefix, _, _ in PREDICTORS:
            correct, misses = int(row[f"{prefix}_correct"]), int(row[f"{prefix}_mispredict"])
            percent = float(row[f"{prefix}_accuracy_pct"])
            if min(correct, misses) < 0 or correct + misses != total:
                raise ValueError("Correct and mispredict counts must sum to total")
            if not math.isfinite(percent) or abs(percent - 100 * correct / total) > 0.011:
                raise ValueError("Published accuracy disagrees with raw counts")
            row[f"{prefix}_correct"], row[f"{prefix}_mispredict"] = correct, misses
    aggregate = rows[-1]
    for field in ["total_branches"] + [f"{p}_{s}" for p, _, _ in PREDICTORS
                                       for s in ("correct", "mispredict")]:
        if aggregate[field] != sum(row[field] for row in rows[:-1]):
            raise ValueError(f"Aggregate does not equal workload sum: {field}")
    return rows


def calculate(rows, ideal, branch_fraction, penalty):
    if (not all(math.isfinite(v) for v in (ideal, branch_fraction, penalty)) or
            ideal <= 0 or not 0 <= branch_fraction <= 1 or penalty < 0):
        raise ValueError("Assumptions require finite ideal CPI > 0, branch fraction in [0,1], penalty >= 0")
    metrics = []
    for row in rows:
        total = row["total_branches"]
        for prefix, label, _ in PREDICTORS:
            correct = row[f"{prefix}_correct"]
            misses = row[f"{prefix}_mispredict"]
            # Compute from integer counts, never from the rounded P4 percentage.
            rate = misses / total
            metrics.append(dict(trace_name=row["trace_name"], trace_file=row["trace_file"],
                                predictor=label, total_branches=total, correct=correct,
                                mispredict=misses, accuracy_pct=f"{100 * correct / total:.6f}",
                                misprediction_rate=f"{rate:.9f}",
                                illustrative_cpi=f"{ideal + branch_fraction * rate * penalty:.6f}"))
    return metrics


def chart(rows):
    height = 100 + 125 * len(rows)
    parts = [f'<svg xmlns="http://www.w3.org/2000/svg" width="1050" height="{height}" viewBox="0 0 1050 {height}" role="img" aria-labelledby="title desc">',
             '<title id="title">Direction accuracy on identical branch traces</title>',
             '<desc id="desc">Percent correct for always not taken, 1-bit and 2-bit predictors. Overall is weighted by dynamic branch count.</desc>',
             '<rect width="100%" height="100%" fill="white"/>',
             '<g font-family="sans-serif" font-size="14" fill="#172733">',
             '<text x="25" y="28" font-size="21">Direction accuracy on identical branch traces</text>',
             '<text x="25" y="51">Synthetic traces; 16 entries; prediction before update; overall weighted by branch count</text>']
    for i, (_, label, color) in enumerate(PREDICTORS):
        parts += [f'<rect x="{25 + i * 180}" y="68" width="14" height="14" fill="{color}"/>',
                  f'<text x="{45 + i * 180}" y="80">{label}</text>']
    for i, row in enumerate(rows):
        y = 112 + i * 125
        parts += [f'<text x="25" y="{y}">{escape(row["trace_name"])}</text>',
                  f'<text x="25" y="{y + 21}" fill="#596579">n = {row["total_branches"]}</text>']
        for tick in range(0, 101, 20):
            x = 320 + tick * 6
            parts += [f'<line x1="{x}" x2="{x}" y1="{y-12}" y2="{y+72}" stroke="#e5e9ed"/>',
                      f'<text x="{x}" y="{y+91}" text-anchor="middle" font-size="11">{tick}%</text>']
        for j, (prefix, label, color) in enumerate(PREDICTORS):
            percent = 100 * row[f"{prefix}_correct"] / row["total_branches"]
            bar_y = y - 10 + 27 * j
            parts += [f'<rect x="320" y="{bar_y}" width="{percent*6:.3f}" height="19" fill="{color}"><title>{label}: {percent:.2f}%</title></rect>',
                      f'<text x="{328+percent*6:.3f}" y="{bar_y+15}">{percent:.2f}%</text>']
    return "\n".join(parts + ['</g></svg>', ''])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, default=Path("evidence/metrics/comparison_summary.csv"))
    parser.add_argument("--output-dir", type=Path, default=Path("evidence/metrics"))
    parser.add_argument("--ideal-cpi", type=float, default=1.0)
    parser.add_argument("--branch-fraction", type=float, default=0.2)
    parser.add_argument("--penalty-cycles", type=float, default=3.0)
    args = parser.parse_args()
    try:
        rows = load_counts(args.input)
        metrics = calculate(rows, args.ideal_cpi, args.branch_fraction, args.penalty_cycles)
        stream = io.StringIO(newline="")
        writer = csv.DictWriter(stream, fieldnames=OUTPUT_FIELDS, lineterminator="\n")
        writer.writeheader()
        writer.writerows(metrics)
        digest = hashlib.sha256(args.input.read_bytes()).hexdigest()
        example = rows[0]
        n = example["total_branches"]
        c = example["two_bit_correct"]
        m = example["two_bit_mispredict"]
        assumptions = f'''# Illustrative CPI assumptions

Source: `{args.input.as_posix()}` (P4 HDL/oracle reconciled counts).
SHA-256: `{digest}`.

Assumed ideal CPI = {args.ideal_cpi:g} cycles/instruction.
Assumed branch fraction = {args.branch_fraction:g} branches/instruction.
Assumed misprediction penalty = {args.penalty_cycles:g} cycles/misprediction.

Accuracy (%) = 100 * correct / total.
Misprediction rate = mispredict / total = 1 - correct / total.
Illustrative CPI = ideal CPI + branch fraction * misprediction rate * penalty cycles.

These parameters are assumptions, not measurements. The branch-only traces do
not measure the fraction of all CPU instructions that are branches. The model
uses direction misses only; BTB target misses, pipeline stalls and other CPU
costs are excluded. It does not establish measured CPU CPI or speedup.
All predictors see identical workloads, with cold starts and 16-entry BHTs.
Overall counts are summed across workloads before computing ratios.

Independent example from {example['trace_name']}: 2-bit correct = {c} of {n},
so accuracy = {100*c/n:g}%, miss rate = {m}/{n} = {m/n:g}. Under the assumptions above,
illustrative CPI = {args.ideal_cpi:g} + {args.branch_fraction:g} * {m/n:g} * {args.penalty_cycles:g}
= {args.ideal_cpi + args.branch_fraction * (m/n) * args.penalty_cycles:.6f}.

Reproduce defaults: `make metrics`. Override with
`python3 scripts/collect_metrics.py --ideal-cpi 1 --branch-fraction 0.2 --penalty-cycles 3`.
Outputs: `accuracy.csv`, `accuracy.svg`, and this assumptions file.
'''
        args.output_dir.mkdir(parents=True, exist_ok=True)
        (args.output_dir / "accuracy.csv").write_text(stream.getvalue())
        (args.output_dir / "accuracy.svg").write_text(chart(rows))
        (args.output_dir / "cpi_assumptions.md").write_text(assumptions)
    except (ValueError, OSError) as error:
        parser.exit(1, f"Metrics error: {error}\n")
    print(f"Validated {len(rows)-1} workloads; wrote {len(metrics)} predictor rows to {args.output_dir}")


if __name__ == "__main__":
    main()
