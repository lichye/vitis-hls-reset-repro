# Vitis HLS reset reproducer

Vitis HLS 2025.1 generates RTL that can assert `ap_done` after reset before
performing any array write. Loop-exit control registers have no reset or explicit
initialization, and certain initial values cause premature completion.

This repository contains the C source, unmodified HLS RTL, and independent
simulation and bounded model checking reproductions.

## Quick reproduction

`make test` uses **AMD Vivado Simulator (XSim) 2025.1**. Put `xvlog`, `xelab`,
and `xsim` on `PATH`, then clone the repository and run:

```sh
git clone https://github.com/lichye/vitis-hls-reset-repro.git
cd vitis-hls-reset-repro
command -v xvlog xelab xsim
make test
```

Expected output includes:

```text
BUG REPRODUCED: cycles=1 ap_done=1 writes=0 a[0]=0 expected=5
ZERO-SEED CONTROL PASS: cycles=2057 writes=1024 all A[k]=5
```

`make test` succeeds only when both the premature-completion case and the
zero-seed control behave as expected. Counts are measured by the testbench after
reset release. Each run's log, VCD waveform, and XSim waveform database are
written to `build/replay/xsim/seed1.{log,vcd,wdb}` or
`build/replay/xsim/seed0.{log,vcd,wdb}`.

The target compiles and runs this repository's testbench directly against the
unmodified HLS-generated RTL. The
[`--testplusarg` option](https://docs.amd.com/r/2025.1-English/ug900-vivado-logic-simulation/xsim-Executable-Options)
selects the testbench's initial-state seed. Recorded results are in
[xsim-seed1.log](evidence/xsim-seed1.log) and
[xsim-seed0.log](evidence/xsim-seed0.log).

### Optional Icarus Verilog reproduction

The same RTL and testbench also run with Icarus Verilog. This optional target
requires both `iverilog` and `vvp` on `PATH`:

```sh
make test-iverilog
```

It produces the same two expected messages and writes waveforms under
`build/replay/iverilog/seed1/` and `build/replay/iverilog/seed0/`.

### Bounded model checking

With SymbiYosys, Yosys, `yosys-smtbmc`, and Bitwuzla on `PATH`:

```sh
make bmc
```

Expected result: **FAIL at step 4, exit code 2**, with a counterexample in
`build/replay/bmc/engine_0/trace.vcd`. This failure demonstrates the reported
behavior. The assertion, checked outside reset, is:

```systemverilog
assert (!ap_done || saw_write);
```

The counterexample contains no array write, including on the completion edge.
The formal harness never assigns internal DUT registers; the solver chooses
their unspecified initial values while preserving explicit RTL initializations.

## Example and synthesis settings

The [source](source/array_madd.c) computes, for `N = 1024`:

```c
for (int i = 0; i < N; i++) {
    a[i] += b[i] * b[i] + c[i] * c[i];
}
```

The RTL testbench supplies separate arrays with `A[k] = 0`, `B[k] = 1`, and
`C[k] = 2`. These inputs satisfy the source preconditions and do not cause signed
overflow. Every `A[k]` should equal `5` at completion.

| Setting | Value |
| --- | --- |
| Tool | Vitis HLS 2025.1, HLS build 6135595 |
| Flow | Vivado IP flow |
| Top function | `array_madd_top` |
| Target part | `xc7z020clg484-1` |
| Clock constraint | 4 ns |
| Reset configuration | Default; no `config_rtl` override |
| Loop pipeline | Automatic; achieved II = 2, depth = 12 |

The synthesis script uses the source, top function, part, and clock settings
above, with no additional optimization directives.

## Reset sequence and cause

The simulation selects one concrete initial state before the first reset clock
edge. It sets `ap_loop_exit_ready_pp0_iter5_reg` and
`ap_condition_exit_pp0_iter0_stage1_pp0_iter5_reg` to `1`, and the preceding bits
in both exit pipelines to `0`. These values are unspecified in the generated
RTL. The testbench then holds `ap_rst` high for two rising clock edges, releases
reset, and asserts `ap_start`, holding the request until `ap_ready`.

No internal signal is forced during execution. The zero-seed control uses the
same sequence with the exit-pipeline bits initially `0`.

In [array_madd_top.v](rtl/array_madd_top.v),
`ap_loop_exit_ready_pp0_iter5_reg` has no reset branch in its update block
(lines 256–264) and is absent from the initialization block (lines 131–142).
Nevertheless, it directly participates in the completion condition
(lines 358–364), without qualification by `ap_enable_reg_pp0_iter5`.
The flow-control helper passes that indication to `ap_done`.

AMD's [reset documentation for 2025.1](https://docs.amd.com/r/2025.1-English/ug1399-vitis-hls/Controlling-Initialization-and-Reset-Behavior)
states that the default `control` reset covers control registers used in state
machines and I/O protocol generation. This report asks why the loop-exit control
registers are left unreset and whether their completion signals should be
qualified by the pipeline-valid state.

## Regenerate the RTL

To regenerate the RTL and rerun the XSim simulation, put these executables on
`PATH`:

- Vitis HLS 2025.1's `vitis-run`, used by `make synth`.
- Vivado Simulator 2025.1's `xvlog`, `xelab`, and `xsim`, used by `make test`.

```sh
command -v vitis-run xvlog xelab xsim
make synth
make test RTL_DIR=build/hls_project/solution/syn/verilog BUILD=build/replay-fresh
```

`make synth` recreates `build/hls_project/` and retains the supplied `rtl/`
snapshot. Tool executable paths can be overridden, for example
`make synth VITIS=/path/to/vitis-run`. The simulator executables can be
overridden with `XVLOG`, `XELAB`, and `XSIM` in the same way.

On 23 October 2026, this command regenerated all three Verilog modules
byte-for-byte identically to the supplied snapshot, and the fresh RTL reproduced
both simulation results above.

To remove generated synthesis, simulation, and solver output under `build/`:

```sh
make clean
```

The source, supplied RTL snapshot, and recorded files in `evidence/` are retained.

## Files and evidence

| Path | Purpose |
| --- | --- |
| `source/array_madd.c` | Original C source and ACSL annotations |
| `synthesize.tcl` | Standalone HLS synthesis script |
| `rtl/` | Three unmodified HLS-generated Verilog modules |
| `tb_startup.sv` | Concrete failing simulation and zero-seed control |
| `startup_check.sv`, `startup.sby` | Independent startup assertion and BMC task |
| `evidence/` | Synthesis reports, replay logs, hashes, and failing waveforms |

The source and generated RTL retain `N = 1024` and the original address widths.
The [evidence notes](evidence/README.md) describe provenance, tool versions,
and the memory model. The BMC assertion checks startup completion; it does not
establish full functional correctness. Running the reproducer needs no
formal-hls build or Frama-C installation.
