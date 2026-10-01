# 32-bit Direct-Mapped L1 Cache Controller (Write-Back, Write-Allocate)


![language](https://img.shields.io/badge/HDL-Verilog--2001-orange)

A synthesizable 32-bit direct-mapped L1 data cache controller written in Verilog. It uses a 7-state FSM with **write-back** and **write-allocate** policies, 128-bit (4-word) cache lines, line-level valid/dirty tracking, an explicit turnaround drain state, and a stall handshake to the CPU during memory transactions.

---

## Overview

The cache sits between a 32-bit CPU interface and a main-memory interface:

| Access type | Behavior |
|---|---|
| **Read hit** | Word is returned from the cache with zero memory access cycles. |
| **Write hit** | Cache line is updated and marked dirty. No memory write occurs. |
| **Miss, clean victim** | The missing line is fetched from main memory and installed (`FILL`). |
| **Miss, dirty victim** | The dirty line is written back to main memory (`MISS_WRITEBACK`), the bus turnaround cycle clears memory handshakes (`WB_DRAIN`), and the new line is fetched (`MISS_WAIT` → `FILL`). |
| **Write miss** | Write-allocate: the line is fetched from memory first, the write is merged into the line, and the line is marked dirty. |

---

## Features

- 32-bit address and data CPU interface
- 128-bit (16-byte, 4-word) cache lines to exploit spatial locality
- Direct-mapped organization (one comparator, no replacement policy overhead)
- Write-back policy with dirty-bit tracking to minimize memory bus traffic
- Write-allocate on write misses
- 7-state FSM sequencing hits, misses, line fills, and dedicated writeback drain
- Integrated hardware performance counters tracking total accesses, hits, and misses
- Ready/stall handshake protocol with CPU and main memory

---

## Cache Configuration

| Parameter | Value | Notes |
|---|---|---|
| Organization | Direct-mapped | 1-way |
| Address width | 32 bits | Byte-addressable |
| CPU data width | 32 bits | Single-word access |
| Line size | 128 bits (16 bytes) | 4 words per line |
| Number of sets | 64 | 64 lines (`NUM_LINES = 64`) |
| Total capacity | 1024 Bytes (1 KB) | 64 lines × 16 bytes |
| Write policy | Write-back | Updates dirty array on write hit |
| Allocation policy | Write-allocate | Fetches block on write miss |

### Address Breakdown

| Bits | Field | Width | Purpose |
|---|---|---|---|
| `[31:10]` | Tag | 22 bits | Compared against the stored tag in `cache_storage` |
| `[9:4]` | Index | 6 bits | Selects 1 of 64 cache lines |
| `[3:2]` | Word offset | 2 bits | Selects 1 of 4 words (32-bit) in the 128-bit line |
| `[1:0]` | Byte offset | 2 bits | Byte alignment within the word |

---

## Architecture

<img width="2560" height="1038" alt="project-architecture" src="https://github.com/user-attachments/assets/a43e3110-4347-41e3-96af-c848f6ac661a" />

- **CPU-side interface:** Latches read/write requests, asserts `cpu_ready` to complete transactions, and returns requested read words.
- **Cache controller (`cache_controller.v`):** FSM that performs tag comparisons, controls datapath multiplexing, drives memory requests, and manages transaction state transitions.
- **Cache storage (`cache_storage.v`):** Tag array, valid array, dirty array, and 128-bit wide SRAM data blocks.
- **Memory interface:** Multi-cycle handshake transactions (`mem_rd_en`, `mem_wr_en`, `mem_ready`) with main memory.

### Finite State Machine

<img width="680" height="560" alt="fsm_diagram" src="https://github.com/user-attachments/assets/0db2565a-ff56-45f6-9e4d-cf4dd916b90f" />


| State | Description |
|---|---|
| `IDLE` | Waits for incoming CPU read (`cpu_rd_en`) or write (`cpu_wr_en`) requests. |
| `COMPARE` | Checks tag equality and inspects valid and dirty status of the indexed line. |
| `HIT` | Serves CPU request. Reads return the requested 32-bit word; writes update the line and set dirty. |
| `MISS_WRITEBACK` | Flushes the dirty victim line back to main memory until `mem_ready` asserts. |
| `WB_DRAIN` | Turnaround cycle: de-asserts `mem_wr_en` to allow `mem_ready` to drop before read requests. |
| `MISS_WAIT` | Asserts memory read request for the target line and waits for `mem_ready`. |
| `FILL` | Installs the 128-bit line into cache storage, updates tag/valid/dirty bits, and releases the CPU with `cpu_ready`. |

### Access Latency

| Case | Typical Latency (Cycles) | State Sequence |
|---|---|---|
| Read / Write hit | 2 cycles | `IDLE` → `COMPARE` → `HIT` → `IDLE` |
| Miss, clean victim | 3 + memory read latency | `IDLE` → `COMPARE` → `MISS_WAIT` → `FILL` → `IDLE` |
| Miss, dirty victim | 5 + memory write + memory read latency | `IDLE` → `COMPARE` → `MISS_WRITEBACK` → `WB_DRAIN` → `MISS_WAIT` → `FILL` → `IDLE` |

---

## Repository Structure

```text
├── rtl/
│   ├── cache_controller.v     # 7-state FSM controller and datapath steering
│   └── cache_storage.v        # Tag, valid, dirty, and 128-bit data array storage
├── tb/
│   ├── main_memory.v          # Behavioral memory model with configurable handshake
│   ├── perf_counters.v        # Hardware performance monitor (accesses, hits, misses)
│   ├── trace_generator.v      # Deterministic/conflict trace stimulus generator
│   └── tb_cache_controller.v  # Top-level testbench
├── docs/                      # Architecture diagrams, FSM charts, and waveforms
├── Makefile                   # Targets for sim, wave, and synth
└── README.md
```

---



## Verification

The testbench (`tb_cache_controller.v`) validates design correctness using directed corner cases followed by an automated conflict-generating trace.

### Directed Scenarios

1. **Compulsory Cold Miss:** Read access to `0x00000000` misses on startup. Memory returns block `128'hDEADBEEF_CAFEF00D_11223344_AABBCCDD`, fills set 0, and returns word `0xAABBCCDD`.
2. **Read Hit:** Subsequent read to `0x00000000` evaluates as a hit in `COMPARE`, serving the word directly from `cache_storage` without accessing memory.
3. **Write Miss & Dirty Eviction:**
   - Write to `0x00000100` with data `0xDEADBEEF`: the controller allocates the missing line from memory, applies the write to the word, and sets dirty to 1.
   - Read to colliding address `0x00000500` (same index `6'd16`, different tag): the controller initiates dirty eviction, writes the modified line back to `0x00000100`, transitions through `WB_DRAIN`, and fetches the line for `0x00000500`.

### Stress Test & Hardware Performance Counters

An automated trace generator (`trace_generator.v`) issues continuous reads and writes across conflicting sets (e.g., indices 0, 4, 8, 12, 16) to verify back-to-back dirty evictions and stall releases under heavy memory bus pressure.

Hardware performance counters (`perf_counters.v`) record access metrics during simulation:

| Metric | Result (Stress Trace) | Notes |
|---|---|---|
| Total Accesses | 40 | Combined manual and trace accesses |
| Cache Hits | 20 | Verified cache hits |
| Cache Misses | 20 | Handled line fills and writebacks |
| Measured Hit Rate | 50.0% | Adversarial trace forcing set collisions |

The 50% hit rate is intentional: the trace generator deliberately addresses colliding sets to keep eviction and writeback logic fully exercised under worst-case conflicts.



## Limitations

- Word-granularity access only (no byte-enable or halfword write support).
- Blocking cache: the CPU stalls for the duration of every miss transaction.
- Direct-mapped structure is subject to conflict misses under alternating colliding addresses.

## Future Work

- Parameterized `NUM_LINES`, `TAG_WIDTH`, and `DATA_WIDTH` at controller top level.
- Byte-enable support for sub-word writes (`cpu_byte_en`).
- 2-way / 4-way set-associative version with pseudo-LRU replacement.
- Non-blocking hit-under-miss operation with Miss Status Holding Registers (MSHRs).
- Standard bus wrapper (AXI4-Lite or Wishbone).
