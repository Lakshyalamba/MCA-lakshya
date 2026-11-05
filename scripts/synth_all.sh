#!/usr/bin/env bash
# P5: independent, checked generic synthesis of every synthesizable RTL top.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
exec "${PYTHON:-python3}" scripts/synth_all.py "$@"
