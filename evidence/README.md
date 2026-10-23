# Evidence

## Provenance

The source, generated RTL, and both test harnesses were copied byte-for-byte
from `example/bugs/vitis-reset-sum-of-squares/` in formal-hls, revision
`2cad32b9dff4242005f5a39e12badd367fe50aff`. This repository uses that example's
default synthesis profile. The testbench retains its original, unused
`FRAMEWORK` conditional branch; the build does not enable it.

The supplied RTL was originally generated on 20 October 2026 with Vitis HLS
2025.1. On 23 October 2026, synthesis was rerun from this standalone repository:
all three generated Verilog files were byte-identical to the supplied snapshot.
`hls.log`, `csynth.rpt`, `memory-latency.txt`, and
`interface-memory-latency.txt` record this fresh synthesis. No reset patch,
address-width reduction, trip-count change, or observation ports were applied.

HLS completed successfully and retained its warnings about the achieved II and
effective clock budget. Successful C synthesis does not establish timing
closure.

The synthesis Tcl uses the original settings with its project path changed to
this repository's `build/hls_project/`. The Makefile uses tools from `PATH`,
and the standalone SBY task selects the original default RTL.

Verify the RTL snapshot from the repository root:

```sh
sha256sum -c evidence/rtl-sha256.txt
```

## Replay

| File | Evidence |
| --- | --- |
| `simulation.log` | Default `make test` with XSim: premature completion and zero-seed control |
| `fresh-simulation.log` | XSim reproduction using freshly synthesized RTL |
| `iverilog-simulation.log` | Optional `make test-iverilog` reproduction and control |
| `xsim-seed1.log` | AMD XSim 2025.1 reproduces premature completion |
| `xsim-seed0.log` | AMD XSim 2025.1 passes the zero-seed control |
| `bmc.log` | `make bmc`: assertion failure at step 4 |
| `startup-seed1.vcd` | XSim waveform for the concrete failure |
| `bmc-trace.vcd` | Solver-generated startup counterexample |
| `tool-versions.txt` | Tools used for this repository's replay |

All replay checks listed above were run on 23 October 2026. Both Icarus Verilog
and AMD XSim count 1 cycle after reset release before observing premature
completion, with no writes and `A[0] = 0`. The zero-seed control completes after
2057 cycles with 1024 writes and all elements equal to 5.

The XSim checks compile and elaborate the same unmodified RTL and testbench
with `xvlog` and `xelab`, then select `seed=1` or `seed=0` using `--testplusarg`.
The default `make test` target reproduces these runs; `make test-iverilog`
selects Icarus Verilog.

The formal harness leaves internal DUT state unconstrained except for explicit
initializations in the RTL. It uses constant memory responses representing
uniform arrays `A = 0`, `B = 1`, `C = 2` before their first write. The
counterexample has no write, including on the premature-completion edge.

## Memory model

The simulation uses two-cycle A reads and one-cycle B/C reads, following the
operation schedule. For this default synthesis profile, the generated interface
metadata advertises `READ_LATENCY 0` for A and `READ_LATENCY 1` for B/C; the
relationship between operation latency and interface latency remains unresolved.
Both excerpts are retained here. The original investigation reproduced the
startup failure with one-cycle reads as well.

The startup counterexample precedes every write with uniform input memory. The
zero-seed control validates the supplied input and memory model, without
claiming general correctness of memory-interface timing or a full functional
proof of the kernel.
