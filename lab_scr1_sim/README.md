# Lab 2 — SCR1 simulation: exception handling, reset vector and trap vector

**Author:** <FULL NAME>, group P4119  **Variant:** 5

## 1. Task (variant 5)

| Item | Value |
|------|-------|
| Exception | Instruction address misaligned |
| Test | `isa/rv32mi/ma_fetch.S` |
| Reset Vector | `0xA000` |
| Trap Vector | `0x8C0` |
| Handler | print the string `misalign` |

Goals: select a single test, change the exception (trap) handler, set the
reset vector and the trap vector of the core, adapt the build so that the test
still starts and finishes correctly, and save the simulation results.

## 2. What was changed

Branch `lab_scr1_sim` of the fork of `syntacore/scr1`. Three files were changed.

### 2.1 `sim/tests/riscv_isa/rv32_tests.inc` — only one test

The list of tests now contains only `isa/rv32mi/ma_fetch.S`:

```make
rv32_isa_tests += isa/rv32mi/ma_fetch.S
```

### 2.2 `src/includes/scr1_arch_description.svh` — vectors of the core

```systemverilog
SCR1_ARCH_RST_VECTOR = 'hA000;   // was 'h200  (start address after reset)
SCR1_ARCH_MTVEC_BASE = 'h8C0;    // was 'h1C0  (reset value of MTVEC.base)
```

`0x8C0` is a multiple of 64 (`0x8C0 = 35 * 64`), as the `mtvec` base field
requires (`SCR1_MTVEC_BASE_WR_BITS = 26`, i.e. the base is 64-byte aligned).

In the same file the `SCR1_RVC_EXT` define of the **custom** configuration is
commented out (see section 4: with the "C" extension this test never traps).
The predefined configurations (`SCR1_CFG_RV32IMC_MAX` and others) are not
affected.

### 2.3 `sim/tests/common/riscv_macros.h` — placement of the vectors and handler

The linker script `link.ld` places the section `.text.init` so that its content
starts at address `0x100` (before it there are only the simulation exit
words `SIM_EXIT = 0xF4`, `SIM_STOP = 0xF8`, which the testbench uses and which
must not move). Inside the macro `RVTEST_CODE_BEGIN` the vectors are placed with
offsets relative to that start, therefore `link.ld` itself does not need to
change, only the offsets in the macro:

| Symbol | Was | Now | Address |
|--------|-----|-----|---------|
| `trap_vector` | `.org 0xC0` | `.org 0x7C0` | `0x100 + 0x7C0 = 0x8C0` |
| `_start` | `.balign 64` after the trap code | `.org 0x9F00` | `0x100 + 0x9F00 = 0xA000` |

The linker relaxation is switched off around this code
(`.option push` / `.option norelax` ... `.option pop`). Without it the linker
shortens some instructions (for example `auipc`+`addi` of `la`) and the
`_start` label ended up at `0x9FC2` instead of `0xA000`.

**Handler.** In `trap_vector`, after the checks for `ecall` (which end the test)
and before the jump to the test's own handler (`mtvec_handler`), the following
was added: if `mcause == 0` (instruction address misaligned), the characters
`m i s a l i g n` and a newline are written byte by byte (`sb`) to the address
`0xF0000000` (`SCR1_SIM_PRINT_ADDR`); the testbench prints every byte written
there to the console. Only the scratch registers `a4` and `a5` are used, they
are already overwritten by `trap_vector` and the test does not rely on them, so
the test logic is not affected.

## 3. Address check

From `results/ma_fetch.dump` (symbol table of the linked test):

```
000008c0 t trap_vector
0000a000 T _start
000000f4 T SIM_EXIT
000000f8 T SIM_STOP
```

## 4. Why a configuration without the "C" extension is used

`ma_fetch.S` jumps to addresses with bit 1 set (for example `jalr t1, 2(t0)`).
With the compressed instructions extension ("C") such an address is legal
(instructions need only 2-byte alignment), so **no exception happens and the
trap handler is never entered**: the test passes, but nothing is printed. This
is the behaviour of the default configuration (`CFG=MAX`, `ARCH=IMC`) — it was
checked, the test passes with the new vectors, with no `misalign` output.

To get the exception, the core is built without "C": the custom configuration
with `SCR1_RVC_EXT` disabled and the test compiled for `rv32im`:

```bash
make run_verilator CFG=CUSTOM ARCH=IM TRACE=1 TARGETS="riscv_isa"
```

## 5. How to run

```bash
git submodule update --init --recursive
export PATH=<riscv-toolchain>/bin:$PATH
make clean
make run_verilator CFG=CUSTOM ARCH=IM TRACE=1 TARGETS="riscv_isa"
```

(Verilator 5.020 and riscv64-unknown-elf-gcc 13.2 were used.)

## 6. Result

Console output of the simulation (`results/sim_results.txt`):

```
---Test:                     ma_fetch.hex
misalign
misalign
misalign
misalign
Test passed

# Summary: 1/1 tests passed
```

The string is printed four times: the test provokes the exception in tests
2, 4, 5 and 6. The trace log `results/tracelog_core_0.log` shows each of them
(`E` = exception, `mcause = 0`, the next PC is the trap vector `0x8C0`,
`mtval` is the misaligned target address):

| Test | Instruction (PC) | `mcause` | `mtval` | Next PC |
|------|------------------|----------|---------|---------|
| 2 | `jalr t1, 2(t0)` (`0xA090`) | 0 | `0xA096` | `0x8C0` |
| 4 | `jalr t1, 3(t0)` (`0xA0C4`) | 0 | `0xA0CA` | `0x8C0` |
| 5 | `jal t1, ...` (`0xA0E0`) | 0 | `0xA0E6` | `0x8C0` |
| 6 | `beqz zero, ...` (`0xA0FC`) | 0 | `0xA102` | `0x8C0` |

The last exception in the log (`mcause = 0xB`, PC `0xA19C`) is the final `ecall`
(environment call from M-mode), which ends the test.

Execution starts at the new reset vector: the first instruction in the trace is
at `0xA000`, and the program writes `0x8C0` to `mtvec` (`t0 = 0x000008C0`,
then `csrw mtvec, t0`).

## 7. Saved files (`results/`)

| File | Content |
|------|---------|
| `test_results.txt` | result of the simulation (`ma_fetch.hex OK PASS`) |
| `sim_results.txt` | console output with the four `misalign` lines |
| `ma_fetch.dump` | disassembly of the test (`objdump -D -w -x -S`) |
| `tracelog_core_0.log` | trace of the core (executed instructions, register writes, CSR writes, exceptions) |

In this version of SCR1 the register and CSR trace is a single file
`tracelog_core_0.log`; the older separate files `trace_mprf_diff` and
`trace_csr` are not produced.
