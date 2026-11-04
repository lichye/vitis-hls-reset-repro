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

.PHONY: test test-bug test-ok test-iverilog bmc hls hls-ok clean

test: test-bug test-ok

# Exit registers power up at 1: premature ap_done at cycle 1, array untouched.
test-bug: $(BUILD)/xsim/.elaborated
	cd $(BUILD)/xsim && $(XSIM) tb_startup_snapshot --runall --onfinish quit --onerror quit --testplusarg seed=1 --log seed1.log --wdb seed1.wdb

# Exit registers power up at 0: normal completion at cycle 2057, all A[k]=5.
test-ok: $(BUILD)/xsim/.elaborated
	cd $(BUILD)/xsim && $(XSIM) tb_startup_snapshot --runall --onfinish quit --onerror quit --testplusarg seed=0 --log seed0.log --wdb seed0.wdb

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

hls:
	mkdir -p build
	cd build && $(VITIS) --mode hls --tcl $(abspath synthesize.tcl)
	mkdir -p rtl
	cp build/hls_project/solution/syn/verilog/*.v rtl/

# Same synthesis with config_rtl -reset all; RTL goes to rtl-ok/.
# Then: make test-bug RTL_DIR=rtl-ok BUILD=build/replay-ok
hls-ok:
	mkdir -p build
	cd build && $(VITIS) --mode hls --tcl $(abspath synthesize_reset_all.tcl)
	mkdir -p rtl-ok
	cp build/hls_project_ok/solution/syn/verilog/*.v rtl-ok/

clean:
	rm -rf -- build
