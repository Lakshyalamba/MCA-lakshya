#!/usr/bin/env python3
"""
scripts/reference_predictors.py
Author: Vansh (P4 — Baseline Predictors, Branch Traces and Verification)

Independent Python reference model / oracle for dynamic branch prediction.
Implements:
  1. Baseline (Always Not Taken)
  2. 1-bit BHT Predictor (last-outcome history, initialized to 0 / Not Taken)
  3. 2-bit BHT Predictor (2-bit saturating counter, initialized to 01 / Weakly Not Taken)

Capabilities:
  - Strict trace validation (--check-traces): validates schema, sequence numbers,
    opcodes, and operand-derived outcomes of committed CSV traces without regeneration.
  - Intentional trace generation (--generate-traces): creates deterministic CSV traces.
  - Trace simulation (--simulate-only): evaluates all 3 predictors with explicit
    benchmark assertions.
  - Exports independent Python summary to results/p4_python_summary.csv.
  - Aliasing analysis: evaluates 16-entry vs 32-entry BHT on mixed BEQ/BNE trace.
"""

import sys
import os
import csv
import argparse

class BaselinePredictor:
    """Always-Not-Taken predictor: predicts 0 for every conditional branch."""
    def __init__(self):
        self.name = "Baseline (Always Not Taken)"
        self.reset()

    def reset(self):
        pass

    def predict(self, pc):
        return 0

    def update(self, pc, actual_taken):
        pass


class OneBitPredictor:
    """1-bit BHT predictor: stores last observed direction for indexed entry.
    Reset state is 0 (Not Taken). Index extracted from PC[INDEX_BITS+1:2].
    """
    def __init__(self, index_bits=4):
        self.name = f"1-bit BHT ({1 << index_bits} entries)"
        self.index_bits = index_bits
        self.entries = 1 << index_bits
        self.reset()

    def reset(self):
        self.table = [0] * self.entries

    def get_index(self, pc):
        return (pc >> 2) & (self.entries - 1)

    def predict(self, pc):
        idx = self.get_index(pc)
        return self.table[idx]

    def update(self, pc, actual_taken):
        idx = self.get_index(pc)
        self.table[idx] = 1 if actual_taken else 0


class TwoBitPredictor:
    """2-bit saturating counter BHT predictor:
    States:
      00: Strongly Not Taken
      01: Weakly Not Taken (Reset state)
      10: Weakly Taken
      11: Strongly Taken
    Predicts taken if MSB is 1 (state >= 2).
    """
    def __init__(self, index_bits=4):
        self.name = f"2-bit BHT ({1 << index_bits} entries)"
        self.index_bits = index_bits
        self.entries = 1 << index_bits
        self.reset()

    def reset(self):
        # 01 = Weakly Not Taken (P1 contract)
        self.table = [1] * self.entries

    def get_index(self, pc):
        return (pc >> 2) & (self.entries - 1)

    def predict(self, pc):
        idx = self.get_index(pc)
        state = self.table[idx]
        pred = 1 if state >= 2 else 0
        return pred, state

    def update(self, pc, actual_taken):
        idx = self.get_index(pc)
        state = self.table[idx]
        if actual_taken:
            if state < 3:
                self.table[idx] = state + 1
        else:
            if state > 0:
                self.table[idx] = state - 1


# ============================================================================
# Trace Validation (Does NOT regenerate; strictly validates committed data)
# ============================================================================
TRACE_SPEC = {
    "traces/loop_trace.csv": {"expected_rows": 40, "name": "Loop-dominated (TTTTN)"},
    "traces/alternating_trace.csv": {"expected_rows": 40, "name": "Strict Alternating (TNTN)"},
    "traces/beq_bne_trace.csv": {"expected_rows": 50, "name": "Mixed BEQ/BNE Aliased"}
}

EXPECTED_HEADER = ['seq', 'pc', 'op', 'rs1_val', 'rs2_val', 'target', 'actual_taken']

def validate_traces():
    """Validates that all committed trace CSV files exist and adhere to the strict schema.
    Fails with nonzero exit code on any discrepancy.
    """
    print("[P4 Trace Validator] Checking committed trace files...")
    total_validated_branches = 0

    for path, spec in TRACE_SPEC.items():
        if not os.path.exists(path):
            print(f"ERROR: Required trace file '{path}' does not exist!", file=sys.stderr)
            print("Run 'make traces' only if intentional trace generation is needed.", file=sys.stderr)
            sys.exit(1)

        with open(path, 'r', newline='') as f:
            reader = csv.reader(f)
            header = next(reader, None)
            if header != EXPECTED_HEADER:
                print(f"ERROR: Schema mismatch in '{path}'! Expected {EXPECTED_HEADER}, got {header}", file=sys.stderr)
                sys.exit(1)

            rows = list(reader)
            if len(rows) != spec["expected_rows"]:
                print(f"ERROR: Row count mismatch in '{path}'! Expected {spec['expected_rows']}, got {len(rows)}", file=sys.stderr)
                sys.exit(1)

            for i, row in enumerate(rows):
                if len(row) != 7:
                    print(f"ERROR: Row {i} in '{path}' has {len(row)} columns, expected 7: {row}", file=sys.stderr)
                    sys.exit(1)

                seq_str, pc_str, op, rs1_str, rs2_str, target_str, act_str = row
                try:
                    seq = int(seq_str)
                    pc = int(pc_str, 16)
                    rs1 = int(rs1_str, 16)
                    rs2 = int(rs2_str, 16)
                    target = int(target_str, 16)
                    act = int(act_str)
                except ValueError as e:
                    print(f"ERROR: Invalid numeric format in '{path}' row {i}: {e}", file=sys.stderr)
                    sys.exit(1)

                if seq != i:
                    print(f"ERROR: Non-monotonic sequence number in '{path}' row {i}: got seq={seq}, expected {i}", file=sys.stderr)
                    sys.exit(1)

                if pc % 4 != 0:
                    print(f"ERROR: Unaligned branch PC {pc_str} in '{path}' row {i}!", file=sys.stderr)
                    sys.exit(1)

                if op not in ("BEQ", "BNE"):
                    print(f"ERROR: Unsupported branch opcode '{op}' in '{path}' row {i}!", file=sys.stderr)
                    sys.exit(1)

                if act not in (0, 1):
                    print(f"ERROR: Invalid actual_taken '{act}' in '{path}' row {i}!", file=sys.stderr)
                    sys.exit(1)

                # Validate architectural evaluation
                if op == "BEQ":
                    expected_act = 1 if rs1 == rs2 else 0
                else: # BNE
                    expected_act = 1 if rs1 != rs2 else 0

                if act != expected_act:
                    print(f"ERROR: Operand-derived condition mismatch in '{path}' row {i} (seq {seq})! "
                          f"op={op}, rs1={rs1:#x}, rs2={rs2:#x}, actual={act}, expected={expected_act}", file=sys.stderr)
                    sys.exit(1)

            total_validated_branches += len(rows)
            print(f"  ✓ {path}: {len(rows)} branches validated ({spec['name']})")

    print(f"[P4 Trace Validator] ALL TRACES VALID: {total_validated_branches} dynamic branches verified successfully.\n")
    return True


# ============================================================================
# Trace Generation (Used ONLY on explicit demand via 'make traces')
# ============================================================================
def generate_loop_trace(filepath="traces/loop_trace.csv", num_loops=8, iters_per_loop=5):
    os.makedirs(os.path.dirname(filepath), exist_ok=True)
    rows = []
    seq = 0
    pc = 0x00001000
    target = 0x00001000
    loop_bound = iters_per_loop

    for l in range(num_loops):
        for i in range(1, iters_per_loop + 1):
            rs1 = i
            rs2 = loop_bound
            actual_taken = 1 if rs1 != rs2 else 0
            rows.append({
                'seq': seq,
                'pc': f"0x{pc:08x}",
                'op': "BNE",
                'rs1_val': f"0x{rs1:08x}",
                'rs2_val': f"0x{rs2:08x}",
                'target': f"0x{target:08x}",
                'actual_taken': actual_taken
            })
            seq += 1

    with open(filepath, 'w', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=EXPECTED_HEADER)
        writer.writeheader()
        writer.writerows(rows)
    print(f"[P4 Oracle] Generated {len(rows)} branches to {filepath}")
    return rows


def generate_alternating_trace(filepath="traces/alternating_trace.csv", num_branches=40):
    os.makedirs(os.path.dirname(filepath), exist_ok=True)
    rows = []
    pc = 0x00002000
    target = 0x00002040

    for seq in range(num_branches):
        if seq % 2 == 0:
            rs1 = 0
            rs2 = 0
            actual_taken = 1
        else:
            rs1 = 0
            rs2 = 1
            actual_taken = 0

        rows.append({
            'seq': seq,
            'pc': f"0x{pc:08x}",
            'op': "BEQ",
            'rs1_val': f"0x{rs1:08x}",
            'rs2_val': f"0x{rs2:08x}",
            'target': f"0x{target:08x}",
            'actual_taken': actual_taken
        })

    with open(filepath, 'w', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=EXPECTED_HEADER)
        writer.writeheader()
        writer.writerows(rows)
    print(f"[P4 Oracle] Generated {len(rows)} branches to {filepath}")
    return rows


def generate_beq_bne_trace(filepath="traces/beq_bne_trace.csv", num_branches=50):
    os.makedirs(os.path.dirname(filepath), exist_ok=True)
    rows = []
    pc1 = 0x00001010  # idx 4 in 16-entry BHT
    target1 = 0x00001000

    pc2 = 0x00001024  # idx 9 in 16-entry BHT
    target2 = 0x00001080

    pc3 = 0x00001050  # idx 4 in 16-entry BHT (aliased with pc1)
    target3 = 0x00001070

    seq = 0
    while seq < num_branches:
        b1_iter = seq % 4
        if b1_iter < 3:
            rs1, rs2 = 0x10, 0x10
            act = 1
        else:
            rs1, rs2 = 0x10, 0x20
            act = 0
        rows.append({
            'seq': seq, 'pc': f"0x{pc1:08x}", 'op': "BEQ",
            'rs1_val': f"0x{rs1:08x}", 'rs2_val': f"0x{rs2:08x}",
            'target': f"0x{target1:08x}", 'actual_taken': act
        })
        seq += 1
        if seq >= num_branches: break

        if seq % 7 != 0:
            rs1, rs2 = 0x42, 0x00
            act = 1
        else:
            rs1, rs2 = 0x42, 0x42
            act = 0
        rows.append({
            'seq': seq, 'pc': f"0x{pc2:08x}", 'op': "BNE",
            'rs1_val': f"0x{rs1:08x}", 'rs2_val': f"0x{rs2:08x}",
            'target': f"0x{target2:08x}", 'actual_taken': act
        })
        seq += 1
        if seq >= num_branches: break

        if seq % 5 == 0:
            rs1, rs2 = 0x99, 0x99
            act = 1
        else:
            rs1, rs2 = 0x99, 0x88
            act = 0
        rows.append({
            'seq': seq, 'pc': f"0x{pc3:08x}", 'op': "BEQ",
            'rs1_val': f"0x{rs1:08x}", 'rs2_val': f"0x{rs2:08x}",
            'target': f"0x{target3:08x}", 'actual_taken': act
        })
        seq += 1

    with open(filepath, 'w', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=EXPECTED_HEADER)
        writer.writeheader()
        writer.writerows(rows)
    print(f"[P4 Oracle] Generated {len(rows)} branches to {filepath}")
    return rows


# ============================================================================
# Simulation & Explicit Benchmark Assertions
# ============================================================================
def simulate_trace(trace_rows, index_bits=4):
    base = BaselinePredictor()
    one = OneBitPredictor(index_bits=index_bits)
    two = TwoBitPredictor(index_bits=index_bits)

    total = 0
    correct_base = 0
    correct_one = 0
    correct_two = 0

    per_branch_logs = []

    for r in trace_rows:
        seq = int(r['seq'])
        pc = int(r['pc'], 16)
        op = r['op']
        rs1 = int(r['rs1_val'], 16)
        rs2 = int(r['rs2_val'], 16)
        target = int(r['target'], 16)
        actual = int(r['actual_taken'])

        # 1. SAMPLE PREDICTIONS PRE-UPDATE
        p_base = base.predict(pc)
        p_one = one.predict(pc)
        p_two, state_two = two.predict(pc)

        total += 1
        if p_base == actual: correct_base += 1
        if p_one == actual:  correct_one += 1
        if p_two == actual:  correct_two += 1

        per_branch_logs.append({
            'seq': seq, 'pc': pc, 'op': op, 'actual': actual,
            'p_base': p_base, 'p_one': p_one, 'p_two': p_two, 'state_two': state_two
        })

        # 2. UPDATE PREDICTORS POST-LOOKUP
        base.update(pc, actual)
        one.update(pc, actual)
        two.update(pc, actual)

    acc_base = (correct_base / total * 100.0) if total > 0 else 0.0
    acc_one = (correct_one / total * 100.0) if total > 0 else 0.0
    acc_two = (correct_two / total * 100.0) if total > 0 else 0.0

    return {
        'total': total,
        'base_correct': correct_base,
        'base_mispredict': total - correct_base,
        'base_acc': acc_base,
        'one_correct': correct_one,
        'one_mispredict': total - correct_one,
        'one_acc': acc_one,
        'two_correct': correct_two,
        'two_mispredict': total - correct_two,
        'two_acc': acc_two,
        'logs': per_branch_logs
    }


# Fixed benchmark regression truth table
BENCHMARK_EXPECTATIONS = {
    "traces/loop_trace.csv": {"total": 40, "base": 8, "one": 24, "two": 31},
    "traces/alternating_trace.csv": {"total": 40, "base": 20, "one": 0, "two": 0},
    "traces/beq_bne_trace.csv": {"total": 50, "base": 20, "one": 23, "two": 24},
    "CONSOLIDATED": {"total": 130, "base": 48, "one": 47, "two": 55}
}

def run_full_suite(export_csv_path="results/p4_python_summary.csv"):
    # First, validate trace files strictly without regenerating
    validate_traces()

    traces = [
        ("Loop-dominated (TTTTN)", "traces/loop_trace.csv"),
        ("Strict Alternating (TNTN)", "traces/alternating_trace.csv"),
        ("Mixed BEQ/BNE Aliased", "traces/beq_bne_trace.csv")
    ]

    summary_rows = []

    print("=" * 80)
    print(" P4 BRANCH PREDICTION COMPARISON SUITE (INDEPENDENT PYTHON ORACLE)")
    print("=" * 80)

    total_all = 0
    base_all = 0
    one_all = 0
    two_all = 0

    for name, path in traces:
        with open(path, 'r', newline='') as f:
            reader = csv.DictReader(f)
            trace_rows = list(reader)

        stats = simulate_trace(trace_rows)

        # Explicit benchmark regression assertions
        exp = BENCHMARK_EXPECTATIONS[path]
        assert stats['total'] == exp['total'], f"Assertion failure: {path} total branches {stats['total']} != {exp['total']}"
        assert stats['base_correct'] == exp['base'], f"Assertion failure: {path} base_correct {stats['base_correct']} != {exp['base']}"
        assert stats['one_correct'] == exp['one'], f"Assertion failure: {path} one_correct {stats['one_correct']} != {exp['one']}"
        assert stats['two_correct'] == exp['two'], f"Assertion failure: {path} two_correct {stats['two_correct']} != {exp['two']}"

        print(f"\nTrace: {name} [{path}] ({stats['total']} branches) [BENCHMARK ASSERTIONS PASSED]")
        print(f"  Baseline (Always NT): {stats['base_correct']}/{stats['total']} correct "
              f"({stats['base_acc']:.2f}% acc, {stats['base_mispredict']} mispredicts)")
        print(f"  1-bit BHT Predictor:  {stats['one_correct']}/{stats['total']} correct "
              f"({stats['one_acc']:.2f}% acc, {stats['one_mispredict']} mispredicts)")
        print(f"  2-bit BHT Predictor:  {stats['two_correct']}/{stats['total']} correct "
              f"({stats['two_acc']:.2f}% acc, {stats['two_mispredict']} mispredicts)")

        total_all += stats['total']
        base_all += stats['base_correct']
        one_all += stats['one_correct']
        two_all += stats['two_correct']

        summary_rows.append({
            'trace_name': name,
            'trace_file': path,
            'total_branches': stats['total'],
            'base_correct': stats['base_correct'],
            'base_mispredict': stats['base_mispredict'],
            'base_accuracy_pct': f"{stats['base_acc']:.2f}",
            'one_bit_correct': stats['one_correct'],
            'one_bit_mispredict': stats['one_mispredict'],
            'one_bit_accuracy_pct': f"{stats['one_acc']:.2f}",
            'two_bit_correct': stats['two_correct'],
            'two_bit_mispredict': stats['two_mispredict'],
            'two_bit_accuracy_pct': f"{stats['two_acc']:.2f}"
        })

    # Consolidated Overall assertions
    exp_all = BENCHMARK_EXPECTATIONS["CONSOLIDATED"]
    assert total_all == exp_all['total'], f"Overall total {total_all} != {exp_all['total']}"
    assert base_all == exp_all['base'], f"Overall baseline {base_all} != {exp_all['base']}"
    assert one_all == exp_all['one'], f"Overall 1-bit {one_all} != {exp_all['one']}"
    assert two_all == exp_all['two'], f"Overall 2-bit {two_all} != {exp_all['two']}"

    summary_rows.append({
        'trace_name': "Consolidated Overall",
        'trace_file': "ALL_TRACES",
        'total_branches': total_all,
        'base_correct': base_all,
        'base_mispredict': total_all - base_all,
        'base_accuracy_pct': f"{base_all / total_all * 100.0:.2f}",
        'one_bit_correct': one_all,
        'one_bit_mispredict': total_all - one_all,
        'one_bit_accuracy_pct': f"{one_all / total_all * 100.0:.2f}",
        'two_bit_correct': two_all,
        'two_bit_mispredict': total_all - two_all,
        'two_bit_accuracy_pct': f"{two_all / total_all * 100.0:.2f}"
    })

    print("-" * 80)
    print(f"CONSOLIDATED OVERALL ({total_all} dynamic branches) [BENCHMARK ASSERTIONS PASSED]:")
    print(f"  Baseline:  {base_all}/{total_all} ({base_all/total_all*100.0:.2f}%)")
    print(f"  1-bit BHT: {one_all}/{total_all} ({one_all/total_all*100.0:.2f}%)")
    print(f"  2-bit BHT: {two_all}/{total_all} ({two_all/total_all*100.0:.2f}%)")
    print("=" * 80 + "\n")

    # Aliasing sensitivity study (16-entry vs 32-entry BHT)
    with open("traces/beq_bne_trace.csv", "r", newline='') as f:
        bne_rows = list(csv.DictReader(f))
    stats_16 = simulate_trace(bne_rows, index_bits=4)
    stats_32 = simulate_trace(bne_rows, index_bits=5)
    print(f"[Aliasing Study] Mixed BEQ/BNE Trace on BHT Capacity:")
    print(f"  16-entry 2-bit BHT: {stats_16['two_correct']}/50 correct ({stats_16['two_acc']:.2f}% acc) [Aliasing at idx 4]")
    print(f"  32-entry 2-bit BHT: {stats_32['two_correct']}/50 correct ({stats_32['two_acc']:.2f}% acc) [No aliasing: idx 4 vs 20]")
    assert stats_16['two_correct'] == 24 and stats_32['two_correct'] == 37, "Aliasing study assertion failed!"
    print(f"  ✓ Aliasing resolution verified: capacity increase yields +{stats_32['two_acc'] - stats_16['two_acc']:.2f}% accuracy gain\n")

    if export_csv_path:
        os.makedirs(os.path.dirname(export_csv_path), exist_ok=True)
        with open(export_csv_path, 'w', newline='') as f:
            fields = ['trace_name', 'trace_file', 'total_branches',
                      'base_correct', 'base_mispredict', 'base_accuracy_pct',
                      'one_bit_correct', 'one_bit_mispredict', 'one_bit_accuracy_pct',
                      'two_bit_correct', 'two_bit_mispredict', 'two_bit_accuracy_pct']
            writer = csv.DictWriter(f, fieldnames=fields)
            writer.writeheader()
            writer.writerows(summary_rows)
        print(f"[P4 Oracle] Exported Python metrics summary to: {export_csv_path}")

    return summary_rows


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description="P4 Reference Predictor Model & Trace Suite")
    parser.add_argument('--check-traces', action='store_true', help="Validate committed trace files without regenerating")
    parser.add_argument('--generate-traces', action='store_true', help="Explicitly regenerate standard CSV trace files")
    parser.add_argument('--export-csv', type=str, default="results/p4_python_summary.csv", help="Path to export CSV metrics")
    parser.add_argument('--simulate-only', action='store_true', help="Simulate existing trace files without regenerating")
    args = parser.parse_args()

    if args.check_traces:
        validate_traces()
        sys.exit(0)

    if args.generate_traces:
        print("[P4 Oracle] Explicitly generating trace files...")
        generate_loop_trace()
        generate_alternating_trace()
        generate_beq_bne_trace()

    run_full_suite(export_csv_path=args.export_csv)
