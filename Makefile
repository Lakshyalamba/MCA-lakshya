SHELL := /bin/bash
IVERILOG ?= iverilog
VVP ?= vvp
YOSYS ?= yosys
RTL = rtl/branch_history_table.v rtl/predictor_2bit.v rtl/predictor_1bit.v rtl/predictor_top.v
.PHONY: help test test-p1 test-p1-extended demo synth-p1 clean

test: test-p1 test-p1-extended demo

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
		results/p1_synthesis.log

help:
	@echo "Core checks: make test-p1, make test-p1-extended, make demo, make synth-p1"
	@echo "make test runs directed, extended, and synthetic trace demo tests"

test-p1-extended:
	@mkdir -p results
	$(IVERILOG) -g2012 -Wall -s tb_p1_extended -o results/p1_extended_sim rtl/branch_history_table.v rtl/predictor_2bit.v testbench/tb_p1_extended.sv
	@set -o pipefail; $(VVP) results/p1_extended_sim | tee results/p1_extended_test.log
