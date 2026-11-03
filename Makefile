SHELL := /bin/bash
IVERILOG ?= iverilog
VVP ?= vvp
YOSYS ?= yosys
RTL = rtl/branch_history_table.v rtl/predictor_2bit.v rtl/predictor_1bit.v rtl/predictor_top.v
.PHONY: help test test-p1 test-p1-extended test-p1-scoreboard verify-p1 demo synth-p1 synth-p1-checked clean

test: test-p1 test-p1-extended test-p1-scoreboard demo

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
		results/p1_scoreboard_2_sim results/p1_scoreboard_4_sim results/p1_scoreboard_5_sim

help:
	@echo "Core checks: make test-p1, make test-p1-extended, make demo, make synth-p1"
	@echo "make test runs directed, extended, independent scoreboard, and demo tests"
	@echo "make verify-p1 adds checked generic synthesis to all P1 tests"

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
