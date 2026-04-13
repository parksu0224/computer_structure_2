# Class 04: Single-Cycle Datapath

> **Week 04 | Hanyang University ERICA Campus | Department of Robotics**  
> **Computer Architecture Course**

---

## 📚 Learning Objectives

After completing this class, you will be able to:

1. **Understand the datapath concept**: Connect ALU, register file, and memory into a complete execution path
2. **Implement the 5 classic stages**: IF → ID → EX → MEM → WB
3. **Master the role of multiplexers**: Understand `reg_dst`, `alu_src`, `mem_to_reg` control signals
4. **Manually control CPU execution**: Provide control signals via testbench and observe data flow

---

## 🧠 Key Concepts

### Five Stages of Single-Cycle CPU

```
┌─────────┐   ┌─────────┐   ┌─────────┐   ┌─────────┐   ┌─────────┐
│   IF    │──→│   ID    │──→│   EX    │──→│   MEM   │──→│   WB    │
│ (Fetch) │   │(Decode) │   │(Execute)│   │(Memory) │   │(Write)  │
└─────────┘   └─────────┘   └─────────┘   └─────────┘   └─────────┘
```

| Stage | Full Name | Main Operation | Components Used |
|-------|-----------|----------------|-----------------|
| IF | Instruction Fetch | Fetch instruction from memory | PC, Instr Memory |
| ID | Instruction Decode | Read registers, decode instruction | Register File |
| EX | Execute | ALU operation | ALU |
| MEM | Memory Access | Read/write data memory | Data Memory |
| WB | Write Back | Write result to register | Register File |

### Control Signals Overview

| Signal | Width | Function | Value Meaning |
|--------|-------|----------|---------------|
| `reg_dst` | 1 | Select destination register | 0: rt, 1: rd |
| `alu_src` | 1 | Select ALU second operand | 0: register, 1: immediate |
| `mem_to_reg` | 1 | Select writeback data source | 0: ALU result, 1: memory data |
| `reg_write` | 1 | Whether to write register | 0: no, 1: yes |
| `mem_write` | 1 | Whether to write data memory | 0: no, 1: yes |
| `alu_ctrl` | 3 | ALU operation type | See Class 01 |

---

## 📊 Datapath Architecture

```
                                    reg_dst
                                       ↓
  ┌──────────────────────────────── MUX ──┐
  │                                       │
  │    ┌────────┐     ┌─────────────┐     │     ┌─────────────┐
  │    │   PC   │────→│ Instr Mem   │─────┼────→│ Register    │
  │    └───┬────┘     └─────────────┘     │     │   File      │
  │        │                              │     │             │──→ rd1 ──→ ALU ──→ result
  │        ↓                              │     │             │                      │
  │    PC + 4                             └────→│             │──→ rd2 ──→ MUX ─────┤
  │                                             └──────┬──────┘          ↑          │
  │                                                    │            alu_src         │
  │                           ┌────────────────────────┘                            │
  │                           │                                                     │
  │                           ↓                                                     ↓
  │                     sign_extend(imm)                                    ┌─────────────┐
  │                                                                         │ Data Memory │
  │                                                                         └──────┬──────┘
  │                                                                                │
  │                                                        mem_to_reg              │
  │                                                            ↓                   │
  └───────────────────────────────────────────────────────── MUX ←─────────────────┘
                                                               │
                                                               ↓
                                                         Write Back
```

---

## 📁 File Structure

```
class_04/
├── pc.v                    # Program counter
├── instruction_memory.v    # Instruction memory
├── reg_file.v              # Register file
├── alu.v                   # Arithmetic Logic Unit
├── data_memory.v           # Data memory
├── if_stage.v              # Fetch stage wrapper
├── datapath.v              # Datapath top module ⭐
├── datapath_tb.v           # Testbench
├── memfile.dat             # Test program
└── Makefile
```

---

## 💻 Code Walkthrough

### `datapath.v` - Datapath Top Module

```verilog
module datapath (
    input  wire        clk, rst_n,
    // Control signals (this week provided manually by Testbench)
    input  wire        reg_write_en, reg_dst, alu_src,
    input  wire [2:0]  alu_ctrl,
    input  wire        mem_write_en, mem_to_reg,
    output wire [31:0] pc_out, alu_result
);
    // Internal wires
    wire [31:0] instr, rd1, rd2, sign_imm, src_b, result, read_data;
    wire [4:0]  write_reg;

    // 1. Fetch Stage (IF)
    if_stage u_if (.clk(clk), .rst_n(rst_n), 
                   .instr(instr), .current_pc(pc_out));

    // 2. Decode Stage (ID) - Destination register selection
    assign write_reg = (reg_dst) ? instr[15:11] : instr[20:16];
    assign sign_imm = {{16{instr[15]}}, instr[15:0]};  // Sign extension

    reg_file u_reg (.clk(clk), .we3(reg_write_en),
                    .ra1(instr[25:21]), .ra2(instr[20:16]),
                    .wa3(write_reg), .wd3(result),
                    .rd1(rd1), .rd2(rd2));

    // 3. Execute Stage (EX) - ALU source selection
    assign src_b = (alu_src) ? sign_imm : rd2;
    alu u_alu (.src_a(rd1), .src_b(src_b), .alu_ctrl(alu_ctrl),
               .result(alu_result), .zero());

    // 4. Memory Stage (MEM)
    data_memory u_dmem (.clk(clk), .mem_write_en(mem_write_en),
                        .addr(alu_result), .write_data(rd2),
                        .read_data(read_data));

    // 5. Write Back Stage (WB) - Data source selection
    assign result = (mem_to_reg) ? read_data : alu_result;
endmodule
```

---

## 🎯 Design Highlights

### 1. Sign Extension

I-Type instructions have a 16-bit immediate field, but ALU needs 32-bit operands.

```verilog
assign sign_imm = {{16{instr[15]}}, instr[15:0]};
```

- If `instr[15] = 0` (positive): Fill upper 16 bits with 0
- If `instr[15] = 1` (negative): Fill upper 16 bits with 1

**Example**:
- `0x0005` → `0x00000005`
- `0xFFFC (-4)` → `0xFFFFFFFC`

### 2. Three Key Multiplexers

| MUX | Control Signal | Function |
|-----|----------------|----------|
| Destination Register | `reg_dst` | R-Type uses rd, I-Type uses rt |
| ALU Input B | `alu_src` | R-Type uses register, I-Type uses immediate |
| Write Back Data | `mem_to_reg` | ALU result or memory load data |

### 3. Instruction Format Review

**R-Type** (add, sub, and, or, slt):
```
[31:26] [25:21] [20:16] [15:11] [10:6] [5:0]
 opcode    rs      rt      rd    shamt  funct
```

**I-Type** (addi, lw, sw, beq):
```
[31:26] [25:21] [20:16] [15:0]
 opcode    rs      rt    immediate
```

---

## 🧪 Lab Exercise

### Step 1: Write test program (`memfile.dat`)
```
20080005   // addi $t0, $zero, 5    → $t0 = 5
20090003   // addi $t1, $zero, 3    → $t1 = 3
01095020   // add  $t2, $t0, $t1    → $t2 = 8
AD0A0000   // sw   $t2, 0($t0)      → Mem[5] = 8
8D0B0000   // lw   $t3, 0($t0)      → $t3 = Mem[5] = 8
```

### Step 2: Run simulation
```bash
cd class_04
make
```

### Step 3: Observe waveform
- Track `addi` instruction: is `alu_src` = 1?
- Track `add` instruction: is `reg_dst` = 1?
- Track `lw` instruction: is `mem_to_reg` = 1?

---

## 🔍 Think Deeper

### Question 1: Why "single-cycle"?

In this design, **each instruction completes in one clock cycle**. What does this mean?

> **Hint**: The slowest instruction (like `lw`) determines the longest clock period.

### Question 2: Drawback of Single-Cycle CPU

If an `add` instruction only needs IF + ID + EX + WB (no memory access), but the clock period is designed for `lw`, how is resource utilization?

### Question 3: Where do control signals come from?

This week we manually set control signals in the Testbench. Next week, you'll learn how to make the CPU **automatically decode instructions and generate control signals**.

---

## ✅ Checkpoint

Before moving to the next class, make sure you can answer:

- [ ] When `reg_dst = 0`, which instruction field provides the destination register?
- [ ] What control signals need to be 1 for the `lw` instruction?
- [ ] What is the purpose of sign extension?

---

**Previous**: [Class 03 - Memory & PC](../class_03/README.md)  
**Next**: [Class 05 - Control Unit](../class_05/README.md)
