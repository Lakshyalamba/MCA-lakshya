"""Verify P5 calculations against raw integers and reject corrupt evidence."""
import copy
import csv
import importlib.util
import math
from pathlib import Path
import tempfile
import unittest
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("metrics", ROOT / "scripts/collect_metrics.py")
metrics = importlib.util.module_from_spec(spec)
spec.loader.exec_module(metrics)


class MetricsTests(unittest.TestCase):
    def setUp(self):
        self.source = ROOT / "evidence/metrics/comparison_summary.csv"
        with self.source.open(newline="") as f:
            self.raw = list(csv.DictReader(f))

    def read_modified(self, rows, fields=None):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "input.csv"
            with path.open("w", newline="") as f:
                writer = csv.DictWriter(f, fieldnames=fields or metrics.INPUT_FIELDS)
                writer.writeheader()
                writer.writerows(rows)
            return metrics.load_counts(path)

    def test_independent_loop_example(self):
        rows = metrics.calculate(metrics.load_counts(self.source), 1, .2, 3)
        loop_two = rows[2]
        self.assertEqual(loop_two['correct'], 31)
        self.assertEqual(float(loop_two['accuracy_pct']), 77.5)
        self.assertEqual(float(loop_two['misprediction_rate']), .225)
        self.assertEqual(float(loop_two['illustrative_cpi']), 1.135)

    def test_weighted_overall_uses_counts(self):
        overall = metrics.calculate(metrics.load_counts(self.source), 1, .2, 3)[-1]
        self.assertEqual(overall['total_branches'], 130)
        self.assertAlmostEqual(float(overall['accuracy_pct']), 100 * 55/130, places=5)
        self.assertAlmostEqual(float(overall['illustrative_cpi']), 1 + .2 * (75/130) * 3, places=5)

    def test_rejects_column_reordering(self):
        with self.assertRaises(ValueError):
            self.read_modified(self.raw, list(reversed(metrics.INPUT_FIELDS)))

    def test_rejects_invalid_counts(self):
        for field, value in [('total_branches', '0'), ('base_correct', '-1'),
                             ('one_bit_mispredict', '99'), ('two_bit_correct', 'x')]:
            with self.subTest(field=field):
                rows = copy.deepcopy(self.raw)
                rows[0][field] = value
                with self.assertRaises(ValueError):
                    self.read_modified(rows)

    def test_rejects_inconsistent_or_nonfinite_percent(self):
        for value in ('nan', 'inf', '20.2'):
            rows = copy.deepcopy(self.raw)
            rows[0]['base_accuracy_pct'] = value
            with self.assertRaises(ValueError):
                self.read_modified(rows)

    def test_rejects_duplicate_workloads(self):
        with self.assertRaises(ValueError):
            self.read_modified([self.raw[0], self.raw[0], self.raw[-1]])

    def test_requires_aggregate(self):
        with self.assertRaises(ValueError):
            self.read_modified(self.raw[:-1])

    def test_checks_aggregate_against_workloads(self):
        rows = copy.deepcopy(self.raw)
        rows[-1]['base_correct'] = '49'
        rows[-1]['base_mispredict'] = '81'
        rows[-1]['base_accuracy_pct'] = str(100 * 49 / 130)
        with self.assertRaisesRegex(ValueError, 'Aggregate'):
            self.read_modified(rows)

    def test_assumption_limits(self):
        rows = metrics.load_counts(self.source)
        for args in ((0, .2, 3), (1, -1, 3), (1, 1.1, 3), (1, .2, -1),
                     (math.nan, .2, 3), (1, math.inf, 3)):
            with self.subTest(args=args), self.assertRaises(ValueError):
                metrics.calculate(rows, *args)
        self.assertTrue(all(float(r['illustrative_cpi']) == 1 for r in metrics.calculate(rows, 1, 0, 3)))

    def test_svg_escapes_workload_names(self):
        rows = metrics.load_counts(self.source)
        rows[0]['trace_name'] = '<script>& workload'
        svg = metrics.chart(rows)
        ET.fromstring(svg)
        self.assertIn('&lt;script&gt;&amp; workload', svg)
        self.assertNotIn('<script>', svg)


if __name__ == '__main__':
    unittest.main()
