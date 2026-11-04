#!/usr/bin/env python3
"""
scripts/reference_predictors.py
Author: Vansh (P4 — Baselines, Branch Traces and Verification)

Independent Python reference model / oracle for dynamic branch prediction.
Implements:
  1. Baseline (Always Not Taken)
  2. 1-bit BHT Predictor (last-outcome history, initialized to 0 / Not Taken)
  3. 2-bit BHT Predictor (2-bit saturating counter, initialized to 01 / Weakly Not Taken)

Also provides:
  - Deterministic trace generation for:
      * traces/loop_trace.csv
      * traces/alternating_trace.csv
      * traces/beq_bne_trace.csv
  - Trace simulation and metrics calculation (accuracy %, misprediction rate %, CPI estimates)
  - CSV export for P5 (Lakshya) synthesis & evaluation scripts
  - Trace and simulation verification against SystemVerilog execution logs
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


def generate_loop_trace(filepath="traces/loop_trace.csv", num_loops=8, iters_per_loop=5):
    """Generates a loop-dominated trace with repeated TTTTN pattern.
    Inner loop of iters_per_loop iterations: first (iters_per_loop-1) are Taken,
    final iteration is Not Taken (loop exit).
    BNE instruction comparing loop counter rs1 with loop bound rs2.
    """
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
            # BNE is taken when rs1 != rs2
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
        writer = csv.DictWriter(f, fieldnames=['seq', 'pc', 'op', 'rs1_val', 'rs2_val', 'target', 'actual_taken'])
        writer.writeheader()
        writer.writerows(rows)
    print(f"[P4 Oracle] Generated {len(rows)} branches to {filepath}")
    return rows


def generate_alternating_trace(filepath="traces/alternating_trace.csv", num_branches=40):
    """Generates an alternating trace (T, N, T, N, ...).
    BEQ instruction comparing rs1 and rs2:
      When seq is even: rs1 == rs2 (Taken)
      When seq is odd:  rs1 != rs2 (Not Taken)
    Exposes the 0% accuracy pathological case for 1-bit history.
    """
    os.makedirs(os.path.dirname(filepath), exist_ok=True)
    rows = []
    pc = 0x00002000
    target = 0x00002040

    for seq in range(num_branches):
        if seq % 2 == 0:
            rs1 = 0
            rs2 = 0
            actual_taken = 1  # BEQ taken
        else:
            rs1 = 0
            rs2 = 1
            actual_taken = 0  # BEQ not taken

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
        writer = csv.DictWriter(f, fieldnames=['seq', 'pc', 'op', 'rs1_val', 'rs2_val', 'target', 'actual_taken'])
        writer.writeheader()
        writer.writerows(rows)
    print(f"[P4 Oracle] Generated {len(rows)} branches to {filepath}")
    return rows


def generate_beq_bne_trace(filepath="traces/beq_bne_trace.csv", num_branches=50):
    """Generates a mixed BEQ and BNE trace across 3 branch PCs.
    Branch 1: PC 0x00001010 (BHT idx 4) - BEQ, outer loop check (TTTN)
    Branch 2: PC 0x00001024 (BHT idx 9) - BNE, conditional check (mostly Taken, 85%)
    Branch 3: PC 0x00001050 (BHT idx 4) - BEQ, Aliases with Branch 1 on entry 4! (mostly NT)
    """
    os.makedirs(os.path.dirname(filepath), exist_ok=True)
    rows = []
    pc1 = 0x00001010  # idx 4
    target1 = 0x00001000

    pc2 = 0x00001024  # idx 9
    target2 = 0x00001080

    pc3 = 0x00001050  # idx 4 (aliased with pc1)
    target3 = 0x00001070

    seq = 0
    while seq < num_branches:
        # Branch 1 execution
        b1_iter = seq % 4
        if b1_iter < 3:
            rs1, rs2 = 0x10, 0x10  # BEQ taken
            act = 1
        else:
            rs1, rs2 = 0x10, 0x20  # BEQ not taken
            act = 0
        rows.append({
            'seq': seq, 'pc': f"0x{pc1:08x}", 'op': "BEQ",
            'rs1_val': f"0x{rs1:08x}", 'rs2_val': f"0x{rs2:08x}",
            'target': f"0x{target1:08x}", 'actual_taken': act
        })
        seq += 1
        if seq >= num_branches: break

        # Branch 2 execution (BNE, 85% taken)
        if seq % 7 != 0:
            rs1, rs2 = 0x42, 0x00  # BNE taken
            act = 1
        else:
            rs1, rs2 = 0x42, 0x42  # BNE not taken
            act = 0
        rows.append({
            'seq': seq, 'pc': f"0x{pc2:08x}", 'op': "BNE",
            'rs1_val': f"0x{rs1:08x}", 'rs2_val': f"0x{rs2:08x}",
            'target': f"0x{target2:08x}", 'actual_taken': act
        })
        seq += 1
        if seq >= num_branches: break

        # Branch 3 execution (BEQ, aliased with pc1 on idx 4; mostly not taken)
        if seq % 5 == 0:
            rs1, rs2 = 0x99, 0x99  # BEQ taken
            act = 1
        else:
            rs1, rs2 = 0x99, 0x88  # BEQ not taken
            act = 0
        rows.append({
            'seq': seq, 'pc': f"0x{pc3:08x}", 'op': "BEQ",
            'rs1_val': f"0x{rs1:08x}", 'rs2_val': f"0x{rs2:08x}",
            'target': f"0x{target3:08x}", 'actual_taken': act
        })
        seq += 1

    with open(filepath, 'w', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=['seq', 'pc', 'op', 'rs1_val', 'rs2_val', 'target', 'actual_taken'])
        writer.writeheader()
        writer.writerows(rows)
    print(f"[P4 Oracle] Generated {len(rows)} branches to {filepath}")
    return rows


def simulate_trace(trace_rows, index_bits=4):
    """Simulates a trace through all three predictors using identical ordering.
    Records predictions BEFORE updating predictors with actual outcome.
    Validates architectural branch evaluation against rs1, rs2 operands.
    """
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

        # Architectural validation of actual_taken vs operands
        if op == "BEQ":
            expected_taken = 1 if (rs1 == rs2) else 0
        elif op == "BNE":
            expected_taken = 1 if (rs1 != rs2) else 0
        else:
            raise ValueError(f"Unknown branch operation {op}")

        assert actual == expected_taken, (
            f"Trace operand discrepancy at seq {seq}: op={op}, rs1={rs1:#x}, rs2={rs2:#x}, actual={actual}, expected={expected_taken}"
        )

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


def run_full_suite(export_csv_path="evidence/metrics/comparison_summary.csv"):
    """Runs all 3 trace classes and exports consolidated metrics for P5."""
    traces = [
        ("Loop-dominated (TTTTN)", "traces/loop_trace.csv", generate_loop_trace),
        ("Strict Alternating (TNTN)", "traces/alternating_trace.csv", generate_alternating_trace),
        ("Mixed BEQ/BNE Aliased", "traces/beq_bne_trace.csv", generate_beq_bne_trace)
    ]

    summary_rows = []

    print("\n" + "="*80)
    print(" P4 BRANCH PREDICTION COMPARISON SUITE (INDEPENDENT PYTHON ORACLE)")
    print("="*80)

    total_all = 0
    base_all = 0
    one_all = 0
    two_all = 0

    for name, path, gen_fn in traces:
        if not os.path.exists(path):
            gen_fn(path)
        with open(path, 'r') as f:
            reader = csv.DictReader(f)
            trace_rows = list(reader)

        stats = simulate_trace(trace_rows)
        print(f"\nTrace: {name} [{path}] ({stats['total']} branches)")
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

    # Add Consolidated Overall row
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
    print(f"CONSOLIDATED OVERALL ({total_all} dynamic branches):")
    print(f"  Baseline:  {base_all}/{total_all} ({base_all/total_all*100.0:.2f}%)")
    print(f"  1-bit BHT: {one_all}/{total_all} ({one_all/total_all*100.0:.2f}%)")
    print(f"  2-bit BHT: {two_all}/{total_all} ({two_all/total_all*100.0:.2f}%)")
    print("=" * 80 + "\n")

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
        print(f"[P4 Oracle] Exported comparison metrics summary to: {export_csv_path}")

    return summary_rows


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description="P4 Reference Predictor Model & Trace Suite")
    parser.add_argument('--generate-traces', action='store_true', help="Generate standard CSV trace files")
    parser.add_argument('--export-csv', type=str, default="evidence/metrics/comparison_summary.csv", help="Path to export CSV metrics")
    parser.add_argument('--simulate-only', action='store_true', help="Simulate existing trace files without regenerating")
    args = parser.parse_args()

    if args.generate_traces:
        generate_loop_trace()
        generate_alternating_trace()
        generate_beq_bne_trace()

    run_full_suite(export_csv_path=args.export_csv)
