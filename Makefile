BUILD ?= build/replay
RTL_DIR ?= rtl
RTL := $(wildcard $(RTL_DIR)/*.v)
XVLOG ?= xvlog
XELAB ?= xelab
XSIM ?= xsim
IVERILOG ?= iverilog
VVP ?= vvp
SBY ?= sby
VITIS ?= vitis-run

.PHONY: test test-iverilog bmc synth clean

test: $(BUILD)/xsim/.elaborated
	rm -f $(BUILD)/xsim/seed1.log $(BUILD)/xsim/seed0.log $(BUILD)/xsim/startup.vcd
	cd $(BUILD)/xsim && $(XSIM) tb_startup_snapshot --runall --onfinish quit --onerror quit --testplusarg seed=1 --log seed1.log --wdb seed1.wdb
	grep -Fq 'BUG REPRODUCED:' $(BUILD)/xsim/seed1.log
	mv $(BUILD)/xsim/startup.vcd $(BUILD)/xsim/seed1.vcd
	cd $(BUILD)/xsim && $(XSIM) tb_startup_snapshot --runall --onfinish quit --onerror quit --testplusarg seed=0 --log seed0.log --wdb seed0.wdb
	grep -Fq 'ZERO-SEED CONTROL PASS:' $(BUILD)/xsim/seed0.log
	mv $(BUILD)/xsim/startup.vcd $(BUILD)/xsim/seed0.vcd

$(BUILD)/xsim/.elaborated: tb_startup.sv $(RTL) Makefile
	mkdir -p $(BUILD)/xsim
	cd $(BUILD)/xsim && $(XVLOG) --sv $(abspath $(RTL) tb_startup.sv)
	cd $(BUILD)/xsim && $(XELAB) work.tb_startup --snapshot tb_startup_snapshot --debug typical --mt 2
	touch $@

test-iverilog: $(BUILD)/iverilog/sim.vvp
	mkdir -p $(BUILD)/iverilog/seed1 $(BUILD)/iverilog/seed0
	cd $(BUILD)/iverilog/seed1 && $(VVP) ../sim.vvp +seed=1
	cd $(BUILD)/iverilog/seed0 && $(VVP) ../sim.vvp +seed=0

$(BUILD)/iverilog/sim.vvp: tb_startup.sv $(RTL)
	mkdir -p $(BUILD)/iverilog
	$(IVERILOG) -g2012 -Wall -s tb_startup -o $@ $^

# Expected FAIL / exit 2: completion precedes every array write.
bmc:
	$(SBY) -f -d $(BUILD)/bmc startup.sby

synth:
	mkdir -p build
	cd build && $(VITIS) --mode hls --tcl $(abspath synthesize.tcl)

clean:
	rm -rf -- build
