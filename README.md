# Elevator Controller — VHDL Digital Design

## The Problem at a Glance

The two diagrams below capture the core logic this project implements — an elevator scheduling algorithm and its state transitions:

![Elevator Algorithm Diagram](https://github.com/user-attachments/assets/318069d6-25bf-408b-a475-d4b10bbb5812)

![Elevator State Diagram](https://github.com/user-attachments/assets/26a7e946-874a-4325-8c5b-4c1ff2a8a8b3)

Looking at these diagrams, implementing this in a conventional programming language such as Python, C, or Java would be straightforward: a class with a list, a loop that scans for the next request, an enum for states, and an integer for the current floor. The entire scheduler could be expressed in a few dozen lines with variables, conditionals, and a sequential event loop that naturally maps to the algorithm's flow.

**VHDL is fundamentally different.** Hardware description is not programming — it is circuit design expressed in code. Every construct you write corresponds to real logic gates, flip-flops, and interconnects that must all operate **concurrently and in sync with a clock**. This project required solving challenges that simply do not exist in software:

- **No sequential variables across time** — VHDL signals update only on the *next* clock edge; reading a signal you just assigned in the same process reads the *old* value. Getting the SCAN scheduler's direction memory (`past_state`) and the FSM state to update and interact correctly across processes demanded a deep understanding of delta cycles and signal scheduling.
- **Concurrent processes with shared state** — three parallel processes (state register, next-state logic, floor movement) all interact. Race conditions between them on signals like `door_closed`, `clear_current_floor_request`, and `enableCounter` are silent — no runtime error, just wrong hardware behaviour.
- **Clock domain and edge sensitivity** — the floor counter runs on a divided 1 Hz clock (`CLK1Sec`) while request handling runs on 50 MHz. Crossing clock domains without metastability required careful enable-gating through `Counter2Sec` rather than a naive second clock register.
- **Avoiding inferred latches** — any combinational process that does not assign every output in every branch synthesises an unintended latch. Every default assignment in the next-state logic process was deliberate to prevent this.
- **No dynamic memory** — request queuing cannot use a list or array with push/pop. Requests are encoded as a 10-bit bitmask (`ReqFloors`) where bit *i* represents a pending call to floor *i*. The SCAN algorithm then operates on this bitmask using synthesisable `for` loops that unroll into combinational logic.

This combination of algorithmic complexity (SCAN scheduling), real-time timing (clock division), multi-process concurrency, and strict hardware semantics makes this project a genuine demonstration of hardware design competence — not just code translation.

---

A fully synthesizable, FPGA-ready **10-floor elevator controller** implemented in VHDL. The design features a SCAN scheduling algorithm, a Finite State Machine (FSM) for elevator operation, a clock-divider for real-time floor timing, and a Seven-Segment Display (SSD) decoder — all verified against a 16-case testbench.

---

## Table of Contents

- [Project Overview](#project-overview)
- [Architecture](#architecture)
  - [Module Hierarchy](#module-hierarchy)
  - [RequestResolver (SCAN Scheduler)](#requestresolver-scan-scheduler)
  - [ElevatorController (Top-Level FSM)](#elevatorcontroller-top-level-fsm)
  - [Counter2Sec (Clock Divider)](#counter2sec-clock-divider)
  - [SSD (Seven-Segment Display Decoder)](#ssd-seven-segment-display-decoder)
- [Signal Descriptions](#signal-descriptions)
- [State Machine](#state-machine)
- [Simulation & Testing](#simulation--testing)
- [File Structure](#file-structure)
- [How to Run](#how-to-run)

---

## Project Overview

This project implements a **hardware elevator controller** targeting an FPGA (50 MHz clock). The elevator manages up to **10 floors (0–9)** and supports:

- **Multi-floor request queuing** — users enter a target floor via 4-bit DIP switches and confirm with an active-low `accept` button.
- **SCAN (Elevator) Scheduling** — requests are served in the current direction of travel before reversing, minimising total travel distance (analogous to disk-arm scheduling).
- **Timed floor movement** — the elevator moves one floor per second using an on-chip clock divider.
- **Door auto-close** — the door remains open for one clock cycle of the divided clock (~1 second) before automatically closing.
- **Active-low reset** — asserting `rst = '0'` clears all pending requests while preserving the physical floor position.
- **Seven-segment display** — the current floor is shown on a 7-segment LED display in real time.

---

## Architecture

### Module Hierarchy

```
ElevatorController  (top-level)
├── RequestResolver      (SCAN scheduling)
├── Counter2Sec          (50 MHz → 1 Hz divider)
└── SSD                  (floor → 7-segment decoder)
```

### RequestResolver (SCAN Scheduler)

**Entity:** `RequestResolver`  
**File:** `elevator_ctrl.vhd`

The resolver receives the 10-bit request vector (`Reqs`), the current floor, and a direction-history signal (`past_state`). On every rising clock edge it resolves the **next target floor** using the SCAN algorithm:

1. If the last movement was **up**: scan upward first; if no higher request exists, reverse and scan downward.  
2. If the last movement was **down**: scan downward first; if no lower request exists, reverse and scan upward.  
3. When `IsMoving = '1'`, the current floor is **excluded** from the scan so the elevator does not stop at a floor it is already passing.

The output `resolved_request` is a 4-bit floor number fed directly into the main FSM.

| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| `clk` | in | 1 | System clock (50 MHz) |
| `Reqs` | in | n (10) | Pending floor requests (bit-per-floor) |
| `current_floor` | in | 4 | Current elevator floor (0–9) |
| `resolved_request` | out | 4 | Next target floor |
| `IsMoving` | in | 1 | High while elevator is in motion |

---

### ElevatorController (Top-Level FSM)

**Entity:** `ElevatorController`  
**File:** `elevator_ctrl.vhd`

The main controller is a Moore FSM with four states. Three concurrent processes implement the standard three-process FSM style:

| Process | Sensitivity | Responsibility |
|---------|-------------|----------------|
| State register | `clk` rising edge | Advances `state_reg ← state_next`; handles reset (clears `ReqFloors`); latches new requests on `accept = '0'` |
| Next-state logic | `state_reg`, `processed_request`, `current_floor`, `door_closed` | Pure combinational; computes `state_next` and drives all outputs |
| Floor movement | `CLK1Sec` falling edge | Increments/decrements `current_floor`; sets `door_closed` flag |

| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| `clk` | in | 1 | 50 MHz system clock |
| `rst` | in | 1 | Active-low reset (clears request queue) |
| `switches` | in | 4 | Floor number input (0–9) |
| `accept` | in | 1 | Active-low: register `switches` as a request |
| `mv_up` | out | 1 | High when elevator moves upward |
| `mv_dn` | out | 1 | High when elevator moves downward |
| `op_door` | out | 1 | High when door is open |
| `floor` | out | 4 | Current floor number |
| `SevenSeg` | out | 7 | 7-segment encoded current floor |

---

### Counter2Sec (Clock Divider)

**Entity:** `Counter2Sec`  
**File:** `elevator_ctrl.vhd`

Divides the 50 MHz system clock down to a 1 Hz tick used for floor stepping and door timing.  
- Configurable via `MAX_COUNT` constant (default `50` for simulation; set to `25_000_000` for real 50 MHz hardware).  
- When `enable = '0'` the counter and output clock are held reset, preventing spurious ticks while the elevator is idle.

---

### SSD (Seven-Segment Display Decoder)

**Entity:** `SSD`  
**File:** `SSD.vhd`

A pure combinational decoder mapping a 4-bit floor number (0–9) to the corresponding **common-anode 7-segment pattern** (active-low segments). Floors outside 0–9 display a dash (`0111111`).

| Floor | Pattern (`gfedcba`) | Display |
|-------|---------------------|---------|
| 0 | `1000000` | **0** |
| 1 | `1111001` | **1** |
| 2 | `0100100` | **2** |
| … | … | … |
| 9 | `0011000` | **9** |
| others | `0111111` | **-** |

---

## Signal Descriptions

| Signal | Type | Description |
|--------|------|-------------|
| `ReqFloors` | `std_logic_vector(9 downto 0)` | Persistent request bitmask; bit *i* = '1' means floor *i* is pending |
| `state_reg` / `state_next` | `state_type` | Current and next FSM state |
| `current_floor` | `std_logic_vector(3 downto 0)` | Physical floor where the elevator is located |
| `processed_request` | `std_logic_vector(3 downto 0)` | SCAN-resolved next target floor |
| `IsMoving` | `std_logic` | '1' while in `move_up` or `move_down` state |
| `door_closed` | `std_logic` | Set after one tick in `door_open` state; triggers return to `idle` |
| `clear_current_floor_request` | `std_logic` | Pulse that clears the arrived floor's bit in `ReqFloors` |
| `CLK1Sec` | `std_logic` | 1 Hz output from `Counter2Sec` |
| `enableCounter` | `std_logic` | Gating signal for `Counter2Sec`; asserted in all non-idle states |

---

## State Machine

![FSM Diagram](https://github.com/user-attachments/assets/01cb3fed-31f9-453a-9741-e949a87e44ec)

- **idle → move_up / move_down**: triggered when `processed_request ≠ current_floor`  
- **move_up / move_down → door_open**: triggered when `processed_request = current_floor` (arrived)  
- **door_open → idle**: triggered when `door_closed = '1'` (one 1 Hz tick has elapsed)  
- On reset: state forced to `idle`; `ReqFloors` cleared; `current_floor` unchanged

---

## Simulation & Testing

The testbench (`elevator_ctrl_tb.vhd`) uses a 50 MHz clock and exercises **16 test cases**:

| # | Scenario |
|---|----------|
| 1 | Basic single request (floor 0 → 3) |
| 2 | Multiple sequential requests (0→5→2→8→4) |
| 3 | Multi-floor SCAN ordering (floors 1, 5, 7 queued simultaneously) |
| 4 | Request added while elevator is in motion |
| 5 | Request for current floor (immediate door open) |
| 6 | Multiple requests in same direction (upward sweep 0→4→6→8) |
| 7 | Mixed direction optimisation (0→1→3→7→9) |
| 8 | Boundary floor tests (0→9 and 9→0) |
| 9 | Reset asserted during active movement |
| 10 | Invalid floor input (floor 10 — must be ignored) |
| 11 | Rapid successive requests while moving |
| 12 | Idle with no requests — verifies no spurious movement |
| 13 | Clock edge sensitivity / setup-hold testing |
| 14 | Door open/close timing verification |
| 15 | End-to-end complex scenario with interleaved requests |
| 16 | SSD display verification for all floors 0–9 |

A state-change monitor process logs every FSM transition to `stdout` in real time.

---

## File Structure

```
Elevator_Controller/
├── elevator_ctrl.vhd      # Main design: RequestResolver + ElevatorController + Counter2Sec
├── SSD.vhd                # Seven-segment display decoder
├── elevator_ctrl_tb.vhd   # 16-case VHDL testbench
└── tcl_script.do          # ModelSim TCL simulation scripts (4 test scenarios)
```

---

## How to Run

### ModelSim / QuestaSim

1. Create a working library and compile all sources:
   ```tcl
   vlib work
   vcom SSD.vhd
   vcom elevator_ctrl.vhd
   vcom elevator_ctrl_tb.vhd
   ```
2. Run the testbench:
   ```tcl
   vsim work.ElevatorController_TB
   add wave *
   run -all
   ```
3. Alternatively, use the provided TCL script for specific scenarios:
   ```tcl
   do tcl_script.do
   ```

### Quartus (FPGA Synthesis)

1. Set `ElevatorController` as the top-level entity.
2. Adjust `MAX_COUNT` in `Counter2Sec` to `25_000_000` for a real 50 MHz board clock.
3. Map ports to physical pins:
   - `clk` → 50 MHz oscillator pin
   - `switches[3:0]` → 4 DIP switches
   - `accept`, `rst` → push-buttons (active-low)
   - `mv_up`, `mv_dn`, `op_door` → LEDs
   - `SevenSeg[6:0]` → 7-segment display
4. Compile and program the FPGA.

---

## Design Notes

- The generic parameter `n` (default 10) controls the number of supported floors and the width of the `ReqFloors` register. The design can be easily scaled.
- `MAX_COUNT = 50` in simulation produces fast ticks; change to `25_000_000` for 1 Hz at 50 MHz in hardware.
- Reset is **non-destructive to position**: the elevator stays on its current floor; only the request queue is flushed. This mirrors real elevator behaviour after a fire-alarm reset.

---

## CV / Portfolio Description

**VHDL Elevator Controller — FPGA Digital Design Project**

Designed and implemented a fully synthesizable 10-floor elevator controller in VHDL targeting an FPGA (50 MHz clock), demonstrating end-to-end hardware design competence from algorithm to verified RTL.

**Key Contributions & Challenges Overcome:**

- **SCAN Scheduling in Hardware** — Translated the SCAN (elevator) disk-scheduling algorithm into synthesisable VHDL. Unlike software where a sorted list and loop suffice, hardware requires the entire algorithm to be expressed as combinational logic operating on a 10-bit request bitmask, with synthesisable `for` loops that unroll into gate-level circuits. The direction-memory state (`past_state`) had to be maintained across clock cycles as a registered signal without relying on any run-time data structures.

- **Multi-Process FSM with Correct Signal Semantics** — Implemented a three-process Moore FSM (state register, next-state logic, floor movement) where all processes execute concurrently. A key difficulty was VHDL's signal-update semantics: a signal assigned in one process is not visible to other processes until the next simulation delta cycle, making interaction between `door_closed`, `clear_current_floor_request`, and the state register non-trivial. Resolved by carefully separating registered (clocked) and combinational processes and using explicit default assignments to prevent inferred latches.

- **Clock Domain Crossing** — The floor movement runs on a 1 Hz divided clock while request handling runs on 50 MHz. Rather than using a second clock domain (which introduces metastability risk), the clock divider is enable-gated: it is held in reset while the elevator is idle, eliminating spurious ticks and keeping all critical control logic in one clock domain.

- **Non-Destructive Reset** — Implemented an active-low reset that clears only the request queue (`ReqFloors`) without altering the physical floor register, correctly modelling real-world elevator behaviour after an emergency reset. This required splitting what would be a single `if rst` branch in software into carefully ordered conditional assignments within the clocked process.

- **Verification** — Authored a 16-case VHDL testbench covering single requests, multi-floor SCAN ordering, mid-motion request injection, boundary conditions (floors 0 and 9), reset during movement, invalid inputs, and full SSD display verification. A state-change monitor process logged every FSM transition to stdout for real-time debugging.

**Technologies:** VHDL · ModelSim / QuestaSim · Quartus Prime · FPGA (DE-series board) · TCL scripting
