SHELL := /bin/bash
IVERILOG ?= iverilog
VVP ?= vvp
YOSYS ?= yosys
PYTHON ?= python3
RTL = rtl/branch_history_table.v rtl/predictor_2bit.v rtl/predictor_1bit.v rtl/predictor_top.v
P3_RTL = rtl/next_pc_mux.v rtl/branch_resolution.v
P4_ALL_RTL = $(RTL) rtl/branch_target_buffer.v $(P3_RTL)

.PHONY: help test test-p1 test-p1-extended test-p1-scoreboard verify-p1 demo synth-p1 synth-p1-checked clean
.PHONY: test-p3 test-p3-integrated verify-p3 synth-p3-checked
.PHONY: test-p4 test-p4-unit test-p4-comparison test-p4-oracle test-p4-compare verify-p4 synth-p4-checked check-traces traces waveform-p4

test: test-p1 test-p1-extended test-p1-scoreboard demo test-btb test-p3 test-p3-integrated test-p4

test-p1:
	@mkdir -p results
	$(IVERILOG) -g2012 -Wall -s tb_p1_bht -o results/p1_sim rtl/branch_history_table.v rtl/predictor_2bit.v testbench/tb_p1_bht.sv
	@set -o pipefail; $(VVP) results/p1_sim | tee results/p1_test.log

demo:
	@mkdir -p results
	$(IVERILOG) -g2012 -Wall -s tb_predictor -o results/predictor_sim $(RTL) testbench/tb_predictor.v
	@set -o pipefail; $(VVP) results/predictor_sim | tee results/simulation.log

synth-p1:
	@mkdir -p results
	@set -o pipefail; $(YOSYS) -p 'read_verilog rtl/branch_history_table.v rtl/predictor_2bit.v; synth -top predictor_2bit; stat' | tee results/p1_synthesis.log

clean:
	rm -f results/p1_sim results/p1_bht.vcd results/p1_test.log \
		results/predictor_sim results/predictor.vcd results/simulation.log \
		results/p1_synthesis.log results/p1_extended_sim results/p1_extended.vcd \
		results/p1_extended_test.log results/p1_synthesis_checked.log \
		results/p1_scoreboard_2.log results/p1_scoreboard_4.log results/p1_scoreboard_5.log \
		results/p1_scoreboard_2_sim results/p1_scoreboard_4_sim results/p1_scoreboard_5_sim \
		results/btb_sim results/btb.vcd results/btb_test.log results/btb_param_* results/btb_synthesis_checked.log \
		results/p3_control_sim results/p3_branch_control.vcd results/p3_control_test.log \
		results/p3_integrated_sim results/p3_integrated.vcd results/p3_integrated_test.log \
		results/p3_synthesis_checked.log \
		results/p4_comparison_sim results/p4_comparison.vcd results/p4_comparison_test.log \
		results/p4_predictor_test.log results/p4_synthesis_checked.log \
		results/p4_verilog_summary.csv results/p4_python_summary.csv

help:
	@echo "Core checks: make test-p1, make test-p1-extended, make demo, make synth-p1"
	@echo "P3 checks:   make test-p3, make test-p3-integrated, make verify-p3"
	@echo "P4 checks:   make check-traces, make test-p4-unit, make test-p4-comparison, make test-p4-oracle, make test-p4-compare, make verify-p4"
	@echo "make test runs directed, extended, independent scoreboard, demo, P3, and P4 tests"
	@echo "make verify-p1 adds checked generic synthesis to all P1 tests"
	@echo "make verify-p3 adds checked generic synthesis to all P3 tests"
	@echo "make verify-p4 adds checked generic synthesis to all P4 tests"

test-p1-extended:
	@mkdir -p results
	$(IVERILOG) -g2012 -Wall -s tb_p1_extended -o results/p1_extended_sim rtl/branch_history_table.v rtl/predictor_2bit.v testbench/tb_p1_extended.sv
	@set -o pipefail; $(VVP) results/p1_extended_sim | tee results/p1_extended_test.log

# P1 sign-off: actual Verilog simulation, then Yosys checking.
test-p1-scoreboard:
	@mkdir -p results
	@set -euo pipefail; for bits in 2 4 5; do \
	  echo "=== P1 independent scoreboard: INDEX_BITS=$$bits ==="; \
	  $(IVERILOG) -g2012 -Wall -s tb_p1_scoreboard \
	    -Ptb_p1_scoreboard.INDEX_BITS=$$bits \
	    -o results/p1_scoreboard_$${bits}_sim \
	    rtl/branch_history_table.v rtl/predictor_2bit.v testbench/tb_p1_scoreboard.sv; \
	  $(VVP) results/p1_scoreboard_$${bits}_sim | tee results/p1_scoreboard_$$bits.log; \
	done

synth-p1-checked:
	@mkdir -p results
	@$(YOSYS) -Q -T -l results/p1_synthesis_checked.log -p \
	  'read_verilog rtl/branch_history_table.v rtl/predictor_2bit.v; synth -top predictor_2bit; check -assert; stat' > /dev/null
	@echo "Checked generic synthesis completed; see results/p1_synthesis_checked.log"

verify-p1: test-p1 test-p1-extended test-p1-scoreboard synth-p1-checked
	@echo "P1 VERIFICATION COMMANDS COMPLETED; inspect logs and preserve evidence."

.PHONY: test-btb synth-btb-checked
test-btb:
	mkdir -p results
	iverilog -g2012 -Wall -s tb_btb -o results/btb_sim rtl/branch_target_buffer.v testbench/tb_btb.sv
	vvp results/btb_sim
	for ib in 2 4 5; do \
	  iverilog -g2012 -Wall -s tb_btb_param -P tb_btb_param.INDEX_BITS=$$ib -o results/btb_param_$$ib rtl/branch_target_buffer.v testbench/tb_btb_param.sv || exit 1; \
	  vvp results/btb_param_$$ib || exit 1; \
	done

synth-btb-checked:
	mkdir -p results
	yosys -Q -T -l results/btb_synthesis_checked.log -p 'read_verilog rtl/branch_target_buffer.v; synth -top branch_target_buffer; check -assert; stat'

# P3 Next-PC and branch resolution targets
test-p3:
	@mkdir -p results
	$(IVERILOG) -g2012 -Wall -s tb_branch_control -o results/p3_control_sim rtl/next_pc_mux.v rtl/branch_resolution.v testbench/tb_branch_control.sv
	@set -o pipefail; $(VVP) results/p3_control_sim | tee results/p3_control_test.log

test-p3-integrated:
	@mkdir -p results
	$(IVERILOG) -g2012 -Wall -s tb_integrated -o results/p3_integrated_sim rtl/branch_history_table.v rtl/predictor_2bit.v rtl/branch_target_buffer.v rtl/next_pc_mux.v rtl/branch_resolution.v testbench/tb_integrated.sv
	@set -o pipefail; $(VVP) results/p3_integrated_sim | tee results/p3_integrated_test.log

synth-p3-checked:
	@mkdir -p results
	@$(YOSYS) -Q -T -l results/p3_synthesis_checked.log -p \
	  'read_verilog rtl/next_pc_mux.v; synth -top next_pc_mux; check -assert; stat; read_verilog rtl/branch_resolution.v; synth -top branch_resolution; check -assert; stat' > /dev/null
	@echo "Checked generic synthesis for P3 completed; see results/p3_synthesis_checked.log"

verify-p3: test-p3 test-p3-integrated synth-p3-checked
	@echo "P3 VERIFICATION COMMANDS COMPLETED; inspect logs and preserve evidence."

# ==============================================================================
# P4 Baselines, Branch Traces and Verification Targets (Vansh)
# ==============================================================================
check-traces:
	$(PYTHON) scripts/reference_predictors.py --check-traces

traces:
	@mkdir -p traces
	$(PYTHON) scripts/reference_predictors.py --generate-traces

test-p4-unit:
	@mkdir -p results
	$(IVERILOG) -g2012 -Wall -s tb_predictor -o results/predictor_sim $(RTL) testbench/tb_predictor.v
	@set -o pipefail; $(VVP) results/predictor_sim | tee results/p4_predictor_test.log

test-p4-comparison: check-traces
	@mkdir -p results
	$(IVERILOG) -g2012 -Wall -s tb_comparison -o results/p4_comparison_sim $(P4_ALL_RTL) testbench/tb_comparison.sv
	@set -o pipefail; $(VVP) results/p4_comparison_sim | tee results/p4_comparison_test.log

test-p4-oracle: check-traces
	@mkdir -p results
	$(PYTHON) scripts/reference_predictors.py --export-csv results/p4_python_summary.csv

test-p4-compare: test-p4-comparison test-p4-oracle
	@mkdir -p evidence/metrics
	$(PYTHON) scripts/compare_p4_results.py \
	  --verilog-csv results/p4_verilog_summary.csv \
	  --python-csv results/p4_python_summary.csv \
	  --publish-csv evidence/metrics/comparison_summary.csv

test-p4: test-p4-unit test-p4-comparison test-p4-oracle test-p4-compare

synth-p4-checked:
	@mkdir -p results
	@$(YOSYS) -Q -T -l results/p4_synthesis_checked.log -p 'read_verilog rtl/predictor_1bit.v; synth -top predictor_1bit; check -assert; stat; design -reset; read_verilog rtl/predictor_1bit.v rtl/branch_history_table.v rtl/predictor_2bit.v rtl/predictor_top.v; synth -top predictor_top; check -assert; stat' > /dev/null
	@echo "Checked generic synthesis for P4 completed; see results/p4_synthesis_checked.log"

waveform-p4: test-p4-comparison
	@mkdir -p evidence/waveforms
	@uv run --with matplotlib --with pillow --with numpy python3 scripts/render_p4_waveform.py 2>/dev/null || $(PYTHON) scripts/render_p4_waveform.py

verify-p4: test-p4 synth-p4-checked waveform-p4
	@mkdir -p evidence/p4_logs
	@cp -f results/p4_predictor_test.log evidence/p4_logs/ 2>/dev/null || true
	@cp -f results/p4_comparison_test.log evidence/p4_logs/ 2>/dev/null || true
	@cp -f results/p4_synthesis_checked.log evidence/p4_logs/ 2>/dev/null || true
	@echo "P4 VERIFICATION COMMANDS COMPLETED; inspect logs and preserve evidence."


