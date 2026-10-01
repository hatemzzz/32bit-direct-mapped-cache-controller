# 🖥️ 32-bit Direct-Mapped L1 Cache Subsystem with Write-Back Architecture

A synthesizable 32-bit Direct-Mapped L1 Cache Subsystem implemented in Verilog HDL. The design integrates a 6-state control FSM with write-back and write-allocate policies, multi-word line support (128-bit / 16-byte blocks), dirty-line tracking, and deterministic bus-stall handshaking.

---


## 📖 Project Overview

This project implements an L1 data cache subsystem designed to bridge the core processor and off-chip memory hierarchy:
- **Cache Read Hit:** The requested word is returned directly to the CPU with zero memory stall cycles.
- **Cache Write Hit:** Data updates the cache line directly and asserts the **Dirty** bit without stalling for off-chip writes.
- **Cache Miss (Clean Line):** The controller fetches the missing line directly from main memory into the cache storage.
- **Cache Miss (Dirty Line):** The modified line is evicted back to memory (`MISS_WRITEBACK`) before loading the new block (`FILL`).

---

## ✨ Features

- ✔️ **32-bit CPU Architecture:** Native 32-bit address and data CPU interface.
- ✔️ **Multi-Word Cache Line:** 128-bit (16-byte / 4-word) line size to exploit spatial locality.
- ✔️ **Direct-Mapped Organization:** Fast single-cycle lookups and tag checks.
- ✔️ **Write-Back Policy:** Employs dirty-bit tracking to minimize external memory traffic.
- ✔️ **Write-Allocate Policy:** Fetches missing blocks on write misses.
- ✔️ **Deterministic 6-State FSM:** Sequences hit paths, memory stalls, and dirty-line writebacks.
- ✔️ **Hardware Handshake:** Drives wait/stall controls to the core during off-chip memory operations.

---

## 🏗️ Cache Configuration

| Parameter | Specification | Details |
| :--- | :--- | :--- |
| **Cache Architecture** | Direct-Mapped | 1 block per set |
| **Address Width** | 32 bits | Byte-addressable address space |
| **CPU Data Bus** | 32 bits | Word-level transactions |
| **Line / Block Size** | 128 bits (16 Bytes) | 4 words per cache block |
| **Block Offset Bits** | 4 bits | Byte indexing within line (`[3:0]`) |
| **Write Policy** | Write-Back | Flushes data to memory only on dirty block eviction |
| **Allocation Policy** | Write-Allocate | Fetches block from memory on write misses |

---

## 🧩 Subsystem Architecture

<img width="2560" height="1038" alt="architecture" src="https://github.com/user-attachments/assets/66c8559b-2901-465a-ac64-07230b94c901" />


The subsystem separates control sequencing from datapath flow:
- **CPU Side Interface:** Latches read/write commands, drives wait/stall signals, and returns read data.
- **Cache System Controller:** Central FSM managing tag comparisons, multiplexer steering, and memory requests.
- **Cache Storage:** Tag/status array (tag, valid, dirty) and high-density data memory array.
- **Main Memory Interface:** Handles multi-cycle bus transactions with external DRAM.

---

## ⚙️ Finite State Machine (FSM)

<img width="680" height="560" alt="fsm_diagram" src="https://github.com/user-attachments/assets/9ac31dca-d1ba-4c80-9527-109f7ea2e332" />


The controller transitions across 6 dedicated states:

- 🔹 **`IDLE`**: Waits for an active CPU memory request.
- 🔹 **`COMPARE`**: Compares the incoming address tag against the stored tag and checks valid/dirty status.
- 🔹 **`HIT`**: Services the core directly; reads return immediately, writes mark the line dirty.
- 🔹 **`MISS_WRITEBACK`**: Flushes modified lines to main memory upon a conflict miss until `mem_ready` asserts.
- 🔹 **`MISS_WAIT`**: Stalls the CPU while fetching the requested line from external memory.
- 🔹 **`FILL`**: Loads the 128-bit block into the data array, sets valid, clears dirty, and services the CPU.

---

## 📦 Module Descriptions

- 🔹 **`cache_controller.v`**: FSM control path orchestrating hits, misses, bus stalls, and line fill logic.
- 🔹 **`tag_array.v`**: Stores tag fields, valid bits, and dirty status bits.
- 🔹 **`data_array.v`**: Implements 128-bit storage lines with word-level access logic.
- 🔹 **`memory_model.v`**: Behavioral DRAM model generating memory-ready handshakes and simulated access latency.
- 🔹 **`cache_top.v`**: Top-level integration uniting the controller, storage arrays, and bus multiplexers.
- 🔹 **`cache_top_tb.v`**: Testbench executing directed corner-case scenarios and pseudorandom stress traces.

---

## 🧪 Simulation Scenarios & Verification

Verified using **ModelSim** through targeted corner-case testing followed by an automated memory trace generator:

### 🔹 Directed Verification Scenarios
* **Scenario 1 — Compulsory Cold Miss:**
  - Reading uninitialized address `0x00000000` triggers a cold miss at `t = 105`.
  - Memory responds with block data, loading `0xAABBCCDD` into the cache line.
* **Scenario 2 — Read Hit Latency:**
  - Reading address `0x00000000` again at `t = 145`.
  - Tag matches; data `0xAABBCCDD` is served immediately with zero wait states.
* **Scenario 3 — Write Hit & Dirty Line Eviction:**
  - `WRITE addr=00000100 <- data=deadbeef` at `t = 205` modifies the line and flags it as dirty.
  - Subsequent read to conflicting address `0x00000500` triggers an eviction at `t = 245`.
  - Controller executes writeback of dirty line (`0x000000000000000000000000deadbeef`) to memory address `0x00000100` before filling the new block.

---

### 🔹 Trace Generator Stress Test
An automated trace generator executed a continuous stream of reads and writes targeting conflicting set indices (0, 4, 8, 12, 16):
- Validated consecutive 128-bit dirty block evictions (e.g., writing back modified block `deadbeefcafef00d1122334400000000` to `mem_addr = 0x00000000`).
- Confirmed deterministic memory handshakes and stall releases under heavy bus pressure.

---

## 📊 Verification Metrics (ModelSim)

| Metric | Result | Analysis |
| :--- | :---: | :--- |
| **Total Memory Accesses** | `40` | Directed scenarios + pseudorandom trace sequence |
| **Total Cache Hits** | `20` | Serviced immediately without memory stalls |
| **Total Cache Misses** | `20` | Cold misses and conflict evictions |
| **Overall Hit Rate** | **`50.0%`** | High-conflict stress trace verifying eviction logic |

---

## 🛠️ Tools Used

- **HDL:** Verilog HDL (IEEE 1364-2001)
- **Simulation:** ModelSim / QuestaSim
- **Waveform Inspection:** ModelSim Wave Viewer

---

## 🚀 Future Improvements

- Parameterized associativity (2-Way / 4-Way Set-Associative) with pseudo-LRU replacement.
- Non-blocking cache design supporting hit-under-miss using Miss Status Holding Registers (MSHR).
- AXI4-Lite / Avalon-MM standard bus wrappers for SoC bus integration.
