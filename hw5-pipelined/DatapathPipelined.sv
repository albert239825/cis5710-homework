
`timescale 1ns / 1ns

// registers are 32 bits in RV32
`define REG_SIZE 31:0

// insns are 32 bits in RV32IM
`define INSN_SIZE 31:0

// RV opcodes are 7 bits
`define OPCODE_SIZE 6:0

`ifndef DIVIDER_STAGES
`define DIVIDER_STAGES 8
`endif

`ifndef SYNTHESIS
`include "../hw3-singlecycle/RvDisassembler.sv"
`endif
`include "../hw2b-cla/CarryLookaheadAdder.sv"
`include "../hw4-multicycle/DividerUnsignedPipelined.sv"
`include "../hw3-singlecycle/cycle_status.sv"

module Disasm #(
    byte PREFIX = "D"
) (
    input wire [31:0] insn,
    output wire [(8*32)-1:0] disasm
);
`ifndef SYNTHESIS
  // this code is only for simulation, not synthesis
  string disasm_string;
  always_comb begin
    disasm_string = rv_disasm(insn);
  end
  // HACK: get disasm_string to appear in GtkWave, which can apparently show only wire/logic. Also,
  // string needs to be reversed to render correctly.
  genvar i;
  for (i = 3; i < 32; i = i + 1) begin : gen_disasm
    assign disasm[((i+1-3)*8)-1-:8] = disasm_string[31-i];
  end
  assign disasm[255-:8] = PREFIX;
  assign disasm[247-:8] = ":";
  assign disasm[239-:8] = " ";
`endif
endmodule

module RegFile (
    input logic [4:0] rd,
    input logic [`REG_SIZE] rd_data,
    input logic [4:0] rs1,
    output logic [`REG_SIZE] rs1_data,
    input logic [4:0] rs2,
    output logic [`REG_SIZE] rs2_data,

    input logic clk,
    input logic we,
    input logic rst
);
  localparam int NumRegs = 32;
  logic [`REG_SIZE] regs[NumRegs];

  // Combinational reads; x0 always returns 0
  assign rs1_data = (rs1 == 5'd0) ? 32'd0 : regs[rs1];
  assign rs2_data = (rs2 == 5'd0) ? 32'd0 : regs[rs2];

  // Synchronous writes; never write to x0
  always_ff @(posedge clk) begin
    if (rst) begin
      for (int j = 0; j < NumRegs; j = j + 1) regs[j] <= 32'd0;
    end else if (we && rd != 5'd0) begin
      regs[rd] <= rd_data;
    end
  end

endmodule

/** state at the start of Decode stage */
typedef struct packed {
  logic [`REG_SIZE] pc;
  logic [`INSN_SIZE] insn;
  cycle_status_e cycle_status;
} stage_decode_t;

module DatapathPipelined (
    input wire clk,
    input wire rst,
    output logic [`REG_SIZE] pc_to_imem,
    input wire [`INSN_SIZE] insn_from_imem,
    // dmem is read/write
    output logic [`REG_SIZE] addr_to_dmem,
    input wire [`REG_SIZE] load_data_from_dmem,
    output logic [`REG_SIZE] store_data_to_dmem,
    output logic [3:0] store_we_to_dmem,

    output logic halt,

    // The PC of the insn currently in Writeback. 0 if not a valid insn.
    output logic [`REG_SIZE] trace_completed_pc,
    // The bits of the insn currently in Writeback. 0 if not a valid insn.
    output logic [`INSN_SIZE] trace_completed_insn,
    // The status of the insn (or stall) currently in Writeback. See the cycle_status.sv file for valid values.
    output cycle_status_e trace_completed_cycle_status
);

  // opcodes - see section 19 of RiscV spec
  localparam bit [`OPCODE_SIZE] OpcodeLoad = 7'b00_000_11;
  localparam bit [`OPCODE_SIZE] OpcodeStore = 7'b01_000_11;
  localparam bit [`OPCODE_SIZE] OpcodeBranch = 7'b11_000_11;
  localparam bit [`OPCODE_SIZE] OpcodeJalr = 7'b11_001_11;
  localparam bit [`OPCODE_SIZE] OpcodeMiscMem = 7'b00_011_11;
  localparam bit [`OPCODE_SIZE] OpcodeJal = 7'b11_011_11;

  localparam bit [`OPCODE_SIZE] OpcodeRegImm = 7'b00_100_11;
  localparam bit [`OPCODE_SIZE] OpcodeRegReg = 7'b01_100_11;
  localparam bit [`OPCODE_SIZE] OpcodeEnviron = 7'b11_100_11;

  localparam bit [`OPCODE_SIZE] OpcodeAuipc = 7'b00_101_11;
  localparam bit [`OPCODE_SIZE] OpcodeLui = 7'b01_101_11;

  // cycle counter, not really part of any stage but useful for orienting within GtkWave
  // do not rename this as the testbench uses this value
  logic [`REG_SIZE] cycles_current;
  always_ff @(posedge clk) begin
    if (rst) begin
      cycles_current <= 0;
    end else begin
      cycles_current <= cycles_current + 1;
    end
  end

  /***************/
  /* FETCH STAGE */
  /***************/

  logic [`REG_SIZE] f_pc_current;
  wire [`REG_SIZE] f_insn;
  cycle_status_e f_cycle_status;

  // program counter — updated in Execute stage below when branch is taken
  // send PC to imem
  assign pc_to_imem = f_pc_current;
  assign f_insn = insn_from_imem;

  // Here's how to disassemble an insn into a string you can view in GtkWave.
  // Use PREFIX to provide a 1-character tag to identify which stage the insn comes from.
  wire [255:0] f_disasm;
  Disasm #(
      .PREFIX("F")
  ) disasm_0fetch (
      .insn  (f_insn),
      .disasm(f_disasm)
  );

  /****************/
  /* DECODE STAGE */
  /****************/

  // this shows how to package up state in a `struct packed`, and how to pass it between stages
  stage_decode_t decode_state;
  always_ff @(posedge clk) begin
    if (rst) begin
      decode_state <= '{pc: 0, insn: 0, cycle_status: CYCLE_RESET};
      // if branch is taken, flush the decode stage
    end else if (x_flush) begin
      decode_state <= '{pc: 0, insn: 0, cycle_status: CYCLE_TAKEN_BRANCH};
    end else if (d_load_use_stall) begin
      // freeze during load-use hazard
      decode_state <= decode_state;
    end else if (x_div_stall_upstream) begin
      // freeze while divider is running
      decode_state <= decode_state;
    end else begin
      decode_state <= '{pc: f_pc_current, insn: f_insn, cycle_status: f_cycle_status};
    end
  end
  wire [255:0] d_disasm;
  Disasm #(
      .PREFIX("D")
  ) disasm_1decode (
      .insn  (decode_state.insn),
      .disasm(d_disasm)
  );

  /* decode stage */

  // instruction fields from decode stage
  wire [6:0] d_insn_funct7 = decode_state.insn[31:25];
  wire [4:0] d_insn_rs2 = decode_state.insn[24:20];
  wire [4:0] d_insn_rs1 = decode_state.insn[19:15];
  wire [2:0] d_insn_funct3 = decode_state.insn[14:12];
  wire [4:0] d_insn_rd = decode_state.insn[11:7];
  wire [6:0] d_insn_opcode = decode_state.insn[6:0];

  // load use stall
  wire d_uses_rs2 = (d_insn_opcode == OpcodeRegReg) || (d_insn_opcode == OpcodeBranch);
  wire d_load_use_stall =
  (execute_state.insn_opcode == OpcodeLoad) &&
  (execute_state.cycle_status != CYCLE_RESET) &&
  (execute_state.cycle_status != CYCLE_TAKEN_BRANCH) &&
  (execute_state.insn_rd != 5'd0) &&
  ((execute_state.insn_rd == d_insn_rs1) ||
   (d_uses_rs2 && execute_state.insn_rd == d_insn_rs2));

  // Immediate generation in decode
  wire [11:0] d_imm_i = decode_state.insn[31:20];
  wire [4:0] d_imm_shamt = decode_state.insn[24:20];
  wire [11:0] d_imm_s;
  assign d_imm_s[11:5] = d_insn_funct7;
  assign d_imm_s[4:0]  = d_insn_rd;
  wire [12:0] d_imm_b;
  assign {d_imm_b[12], d_imm_b[10:5]} = d_insn_funct7;
  assign {d_imm_b[4:1], d_imm_b[11]} = d_insn_rd;
  assign d_imm_b[0] = 1'b0;
  wire [20:0] d_imm_j;
  assign {d_imm_j[20], d_imm_j[10:1], d_imm_j[11], d_imm_j[19:12], d_imm_j[0]} = {
    decode_state.insn[31:12], 1'b0
  };

  wire [`REG_SIZE] d_imm_i_sext = {{20{d_imm_i[11]}}, d_imm_i[11:0]};
  wire [`REG_SIZE] d_imm_s_sext = {{20{d_imm_s[11]}}, d_imm_s[11:0]};
  wire [`REG_SIZE] d_imm_b_sext = {{19{d_imm_b[12]}}, d_imm_b[12:0]};
  wire [`REG_SIZE] d_imm_j_sext = {{11{d_imm_j[20]}}, d_imm_j[20:0]};

  // RegFile reads
  wire [`REG_SIZE] d_rs1_data_rf, d_rs2_data_rf;

  logic [      4:0] w_rd;
  logic [`REG_SIZE] w_rd_data;
  logic             w_we;

  RegFile rf (
      .clk     (clk),
      .rst     (rst),
      .we      (w_we),
      .rd      (w_rd),
      .rd_data (w_rd_data),
      .rs1     (d_insn_rs1),
      .rs2     (d_insn_rs2),
      .rs1_data(d_rs1_data_rf),
      .rs2_data(d_rs2_data_rf)
  );

  // WX bypass: if Writeback stage is writing to a register that Decode reads
  // otherwise, use the data from the register file
  wire [`REG_SIZE] d_rs1_data = (w_we && w_rd != 5'd0 && w_rd == d_insn_rs1) ? w_rd_data : d_rs1_data_rf;
  wire [`REG_SIZE] d_rs2_data = (w_we && w_rd != 5'd0 && w_rd == d_insn_rs2) ? w_rd_data : d_rs2_data_rf;

  /* execute stage */

  typedef struct packed {
    logic [`REG_SIZE]  pc;
    logic [`INSN_SIZE] insn;
    cycle_status_e     cycle_status;
    logic [4:0]        insn_rs1;
    logic [4:0]        insn_rs2;
    logic [4:0]        insn_rd;
    logic [6:0]        insn_opcode;
    logic [6:0]        insn_funct7;
    logic [2:0]        insn_funct3;
    logic [`REG_SIZE]  rs1_data;
    logic [`REG_SIZE]  rs2_data;
    logic [`REG_SIZE]  imm_i_sext;
    logic [`REG_SIZE]  imm_s_sext;
    logic [`REG_SIZE]  imm_b_sext;
    logic [`REG_SIZE]  imm_j_sext;
    logic [4:0]        imm_shamt;
  } stage_execute_t;

  stage_execute_t execute_state;
  always_ff @(posedge clk) begin
    if (rst) begin
      execute_state <= '{
          pc: 0,
          insn: 0,
          cycle_status: CYCLE_RESET,
          insn_rs1: 0,
          insn_rs2: 0,
          insn_rd: 0,
          insn_opcode: 0,
          insn_funct7: 0,
          insn_funct3: 0,
          rs1_data: 0,
          rs2_data: 0,
          imm_i_sext: 0,
          imm_s_sext: 0,
          imm_b_sext: 0,
          imm_j_sext: 0,
          imm_shamt: 0
      };
    end else if (x_flush) begin
      // flush
      execute_state <= '{
          pc: 0,
          insn: 0,
          cycle_status: CYCLE_TAKEN_BRANCH,
          insn_rs1: 0,
          insn_rs2: 0,
          insn_rd: 0,
          insn_opcode: 0,
          insn_funct7: 0,
          insn_funct3: 0,
          rs1_data: 0,
          rs2_data: 0,
          imm_i_sext: 0,
          imm_s_sext: 0,
          imm_b_sext: 0,
          imm_j_sext: 0,
          imm_shamt: 0
      };
    end else if (d_load_use_stall) begin
      execute_state <= '{
          pc: 0,
          insn: 0,
          cycle_status: CYCLE_LOAD2USE,
          insn_rs1: 0,
          insn_rs2: 0,
          insn_rd: 0,
          insn_opcode: 0,
          insn_funct7: 0,
          insn_funct3: 0,
          rs1_data: 0,
          rs2_data: 0,
          imm_i_sext: 0,
          imm_s_sext: 0,
          imm_b_sext: 0,
          imm_j_sext: 0,
          imm_shamt: 0
      };
    end else if (x_div_stall) begin
      execute_state <= execute_state;
    end else if (x_div_retire_overlap) begin
      execute_state <= '{
          pc: ov_pc[ov_head],
          insn: ov_insn[ov_head],
          cycle_status: CYCLE_NO_STALL,
          insn_rs1: 0,
          insn_rs2: 0,
          insn_rd: ov_rd[ov_head],
          insn_opcode: OpcodeRegReg,
          insn_funct7: 7'd1,
          insn_funct3: ov_insn[ov_head][14:12],
          rs1_data: 0,
          rs2_data: 0,
          imm_i_sext: 0,
          imm_s_sext: 0,
          imm_b_sext: 0,
          imm_j_sext: 0,
          imm_shamt: 0
      };
    end else begin
      execute_state <= '{
          pc: decode_state.pc,
          insn: decode_state.insn,
          cycle_status: decode_state.cycle_status,
          insn_rs1: d_insn_rs1,
          insn_rs2: d_insn_rs2,
          insn_rd: d_insn_rd,
          insn_opcode: d_insn_opcode,
          insn_funct7: d_insn_funct7,
          insn_funct3: d_insn_funct3,
          rs1_data: d_rs1_data,
          rs2_data: d_rs2_data,
          imm_i_sext: d_imm_i_sext,
          imm_s_sext: d_imm_s_sext,
          imm_b_sext: d_imm_b_sext,
          imm_j_sext: d_imm_j_sext,
          imm_shamt: d_imm_shamt
      };
    end
  end

  wire [255:0] x_disasm;
  Disasm #(
      .PREFIX("X")
  ) disasm_2execute (
      .insn  (execute_state.insn),
      .disasm(x_disasm)
  );

  wire [4:0] m_rd;
  wire [`REG_SIZE] m_alu_result;
  wire m_we;
  // WX bypass uses w_rd/w_rd_data/w_we which are declared above

  // MX bypass: if Memory stage is writing to a register that Execute reads
  wire [`REG_SIZE] x_rs1_data =
      (m_we && m_rd != 5'd0 && m_rd == execute_state.insn_rs1) ? m_alu_result :
      (w_we && w_rd != 5'd0 && w_rd == execute_state.insn_rs1) ? w_rd_data :
      execute_state.rs1_data;

  wire [`REG_SIZE] x_rs2_data =
      (m_we && m_rd != 5'd0 && m_rd == execute_state.insn_rs2) ? m_alu_result :
      (w_we && w_rd != 5'd0 && w_rd == execute_state.insn_rs2) ? w_rd_data :
      execute_state.rs2_data;

  // execute stage ALU result, branch target, and branch taken signals
  logic [`REG_SIZE] x_alu_result;
  logic x_we;  // whether to write rd
  logic x_branch_taken;
  logic [`REG_SIZE] x_branch_target;

  // signed comparisons
  wire signed [`REG_SIZE] x_rs1_signed = $signed(x_rs1_data);
  wire signed [`REG_SIZE] x_rs2_signed = $signed(x_rs2_data);

  // CLA instantiation for execute stage
  logic [`REG_SIZE] x_cla_b;
  logic x_cla_cin;
  wire [`REG_SIZE] x_cla_sum;
  CarryLookaheadAdder x_cla (
      .a  (x_rs1_data),
      .b  (x_cla_b),
      .cin(x_cla_cin),
      .sum(x_cla_sum)
  );

  // 64-bit product for M-extension mulh* instructions
  logic [63:0] x_mul_full;

  // divider pipeline infrastructure for div/divu/rem/remu
  logic [3:0] x_div_counter;
  wire x_is_div = (execute_state.insn_opcode == OpcodeRegReg) &&
                  (execute_state.insn_funct7 == 7'd1) &&
                  (execute_state.insn_funct3[2] == 1'b1);
  // x_div_stall: true when div result is NOT yet ready → Memory gets CYCLE_DIV bubble
  wire x_div_stall = x_is_div && (x_div_counter < 4'd7);
  wire x_start_div = x_is_div && (x_div_counter == 4'd0);

  // Decode-side: is the instruction in Decode also a div/rem?
  wire d_is_div = (d_insn_opcode == OpcodeRegReg) &&
                  (d_insn_funct7 == 7'd1) &&
                  (d_insn_funct3[2] == 1'b1) &&
                  (decode_state.cycle_status != CYCLE_RESET) &&
                  (decode_state.cycle_status != CYCLE_TAKEN_BRANCH);
  wire d_div_no_dependency =
      (execute_state.insn_rd == 5'd0) ||
      ((execute_state.insn_rd != d_insn_rs1) &&
       (execute_state.insn_rd != d_insn_rs2));
  // Feed an independent Decode div into the divider pipeline at counter cycles 1-7.
  // At counter 7, only feed if not already in retirement phase (div_retiring).
  logic div_retiring;
  wire d_div_can_feed = x_is_div && 
                        ((x_div_counter >= 4'd1 && x_div_counter <= 4'd6) ||
                         (x_div_counter == 4'd7 && !div_retiring)) &&
                        d_is_div && d_div_no_dependency;

  // Stall Fetch/Decode while divider runs, EXCEPT when actively feeding a new independent div
  // (in which case we let the pipeline advance by one so the next div enters Decode).
  wire x_div_stall_upstream = x_div_stall && !d_div_can_feed;

  logic [`REG_SIZE] div_dividend, div_divisor;
  wire [`REG_SIZE] div_quotient, div_remainder;

  DividerUnsignedPipelined divider (
      .clk(clk),
      .rst(rst),
      .stall(1'b0),
      .i_dividend(div_dividend),
      .i_divisor(div_divisor),
      .o_remainder(div_remainder),
      .o_quotient(div_quotient)
  );

  // Saved metadata for the div currently in Execute (captured at counter==0)
  logic [`REG_SIZE] div_saved_rs1, div_saved_rs2;
  logic div_saved_sign_q, div_saved_sign_r;
  logic div_saved_is_rem;

  // Circular buffer of overlapped independent divs fed at counter 1..7.
  localparam int DIV_OVERLAP_MAX = 8;  // power of 2 for easy wrapping
  logic [ `REG_SIZE] ov_rs1   [DIV_OVERLAP_MAX];
  logic [ `REG_SIZE] ov_rs2   [DIV_OVERLAP_MAX];
  logic              ov_sign_q[DIV_OVERLAP_MAX];
  logic              ov_sign_r[DIV_OVERLAP_MAX];
  logic              ov_is_rem[DIV_OVERLAP_MAX];
  logic [       4:0] ov_rd    [DIV_OVERLAP_MAX];
  logic [ `REG_SIZE] ov_pc    [DIV_OVERLAP_MAX];
  logic [`INSN_SIZE] ov_insn  [DIV_OVERLAP_MAX];
  logic [2:0] ov_head, ov_tail;  // head=dequeue, tail=enqueue

  wire div_overlap_pending = (ov_head != ov_tail);

  wire x_div_retire_overlap = x_is_div && (x_div_counter == 4'd7) && div_overlap_pending;

  always_ff @(posedge clk) begin
    if (rst) begin
      x_div_counter    <= 4'd0;
      div_saved_rs1    <= 0;
      div_saved_rs2    <= 0;
      div_saved_sign_q <= 0;
      div_saved_sign_r <= 0;
      div_saved_is_rem <= 0;
      ov_head          <= 3'd0;
      ov_tail          <= 3'd0;
      div_retiring     <= 1'b0;
    end else if (x_flush) begin
      x_div_counter <= 4'd0;
      ov_head       <= 3'd0;
      ov_tail       <= 3'd0;
      div_retiring  <= 1'b0;
    end else if (x_is_div && x_div_counter < 4'd8) begin
      // counter advancement
      if (x_div_retire_overlap) begin
        x_div_counter    <= 4'd7;
        div_retiring     <= 1'b1;
        // Promote head entry as the new saved metadata
        div_saved_rs1    <= ov_rs1[ov_head];
        div_saved_rs2    <= ov_rs2[ov_head];
        div_saved_sign_q <= ov_sign_q[ov_head];
        div_saved_sign_r <= ov_sign_r[ov_head];
        div_saved_is_rem <= ov_is_rem[ov_head];
        // Advance head pointer (dequeue)
        ov_head          <= ov_head + 3'd1;
      end else if (x_div_counter == 4'd7) begin
        x_div_counter <= 4'd0;
        ov_head       <= 3'd0;
        ov_tail       <= 3'd0;
        div_retiring  <= 1'b0;
      end else begin
        x_div_counter <= x_div_counter + 4'd1;
      end

      // Capture Execute div metadata on its first cycle
      if (x_div_counter == 4'd0) begin
        div_saved_rs1    <= x_rs1_data;
        div_saved_rs2    <= x_rs2_data;
        div_saved_sign_q <= !execute_state.insn_funct3[0] &&
                            (x_rs1_data[31] ^ x_rs2_data[31]);
        div_saved_sign_r <= !execute_state.insn_funct3[0] && x_rs1_data[31];
        div_saved_is_rem <= execute_state.insn_funct3[1];
      end

      if (d_div_can_feed) begin
        ov_rs1[ov_tail]    <= d_rs1_data;
        ov_rs2[ov_tail]    <= d_rs2_data;
        ov_sign_q[ov_tail] <= !d_insn_funct3[0] && (d_rs1_data[31] ^ d_rs2_data[31]);
        ov_sign_r[ov_tail] <= !d_insn_funct3[0] && d_rs1_data[31];
        ov_is_rem[ov_tail] <= d_insn_funct3[1];
        ov_rd[ov_tail]     <= d_insn_rd;
        ov_pc[ov_tail]     <= decode_state.pc;
        ov_insn[ov_tail]   <= decode_state.insn;
        ov_tail            <= ov_tail + 3'd1;
      end
    end else begin
      x_div_counter <= 4'd0;
      ov_head       <= 3'd0;
      ov_tail       <= 3'd0;
      div_retiring  <= 1'b0;
    end
  end

  // Feed divider: counter==0 feeds Execute div; counter 1-7 feeds next independent Decode div.
  always_comb begin
    if (x_start_div) begin
      div_dividend = (!execute_state.insn_funct3[0] && x_rs1_data[31])
                     ? (~x_rs1_data + 32'd1) : x_rs1_data;
      div_divisor  = (!execute_state.insn_funct3[0] && x_rs2_data[31])
                     ? (~x_rs2_data + 32'd1) : x_rs2_data;
    end else if (d_div_can_feed) begin
      div_dividend = (!d_insn_funct3[0] && d_rs1_data[31]) ? (~d_rs1_data + 32'd1) : d_rs1_data;
      div_divisor  = (!d_insn_funct3[0] && d_rs2_data[31]) ? (~d_rs2_data + 32'd1) : d_rs2_data;
    end else begin
      div_dividend = 32'd0;
      div_divisor  = 32'd0;
    end
  end

  // Compute final div/rem result from saved metadata + divider output
  wire div_by_zero = (div_saved_rs2 == 32'd0);
  wire div_overflow = div_saved_sign_q &&
                      (div_saved_rs1 == 32'h8000_0000) &&
                      (div_saved_rs2 == 32'hFFFF_FFFF);
  wire [`REG_SIZE] div_corrected_q = div_saved_sign_q ? (~div_quotient + 32'd1) : div_quotient;
  wire [`REG_SIZE] div_corrected_r = div_saved_sign_r ? (~div_remainder + 32'd1) : div_remainder;
  wire [`REG_SIZE] div_final =
      div_by_zero  ? (div_saved_is_rem ? div_saved_rs1 : 32'hFFFF_FFFF) :
      div_overflow ? (div_saved_is_rem ? 32'd0 : 32'h8000_0000) :
      div_saved_is_rem ? div_corrected_r : div_corrected_q;

  always_comb begin
    x_alu_result    = 32'd0;
    x_we            = 1'b0;
    x_branch_taken  = 1'b0;
    x_branch_target = execute_state.pc + execute_state.imm_b_sext;
    x_cla_b         = execute_state.rs2_data;  // default
    x_cla_cin       = 1'b0;
    x_mul_full      = 64'd0;

    case (execute_state.insn_opcode)
      OpcodeLui: begin
        x_alu_result = {execute_state.insn[31:12], 12'd0};
        x_we = 1'b1;
      end

      OpcodeAuipc: begin
        x_alu_result = execute_state.pc + {execute_state.insn[31:12], 12'd0};
        x_we = 1'b1;
      end

      OpcodeRegImm: begin
        x_we = 1'b1;
        case (execute_state.insn_funct3)
          3'b000: begin  // addi
            x_cla_b = execute_state.imm_i_sext;
            x_cla_cin = 1'b0;
            x_alu_result = x_cla_sum;
          end
          3'b010: begin  // slti
            x_alu_result = (x_rs1_signed < $signed(execute_state.imm_i_sext)) ? 32'd1 : 32'd0;
          end
          3'b011: begin  // sltiu
            x_alu_result = (x_rs1_data < execute_state.imm_i_sext) ? 32'd1 : 32'd0;
          end
          3'b100: begin  // xori
            x_alu_result = x_rs1_data ^ execute_state.imm_i_sext;
          end
          3'b110: begin  // ori
            x_alu_result = x_rs1_data | execute_state.imm_i_sext;
          end
          3'b111: begin  // andi
            x_alu_result = x_rs1_data & execute_state.imm_i_sext;
          end
          3'b001: begin  // slli
            x_alu_result = x_rs1_data << execute_state.imm_shamt;
          end
          3'b101: begin
            if (execute_state.insn_funct7 == 7'b0100000) begin  // srai
              x_alu_result = $signed(x_rs1_data) >>> execute_state.imm_shamt;
            end else begin  // srli
              x_alu_result = x_rs1_data >> execute_state.imm_shamt;
            end
          end
          default: x_we = 1'b0;
        endcase
      end

      OpcodeRegReg: begin
        if (execute_state.insn_funct7 == 7'd0 || execute_state.insn_funct7 == 7'b0100000) begin
          x_we = 1'b1;
          case (execute_state.insn_funct3)
            3'b000: begin
              if (execute_state.insn_funct7 == 7'b0100000) begin  // sub
                x_cla_b = ~x_rs2_data;
                x_cla_cin = 1'b1;
                x_alu_result = x_cla_sum;
              end else begin  // add
                x_cla_b = x_rs2_data;
                x_cla_cin = 1'b0;
                x_alu_result = x_cla_sum;
              end
            end
            3'b001:  x_alu_result = x_rs1_data << x_rs2_data[4:0];  // sll
            3'b010:  x_alu_result = (x_rs1_signed < x_rs2_signed) ? 32'd1 : 32'd0;  // slt
            3'b011:  x_alu_result = (x_rs1_data < x_rs2_data) ? 32'd1 : 32'd0;  // sltu
            3'b100:  x_alu_result = x_rs1_data ^ x_rs2_data;  // xor
            3'b101: begin
              if (execute_state.insn_funct7 == 7'b0100000) begin  // sra
                x_alu_result = $signed(x_rs1_data) >>> x_rs2_data[4:0];
              end else begin  // srl
                x_alu_result = x_rs1_data >> x_rs2_data[4:0];
              end
            end
            3'b110:  x_alu_result = x_rs1_data | x_rs2_data;  // or
            3'b111:  x_alu_result = x_rs1_data & x_rs2_data;  // and
            default: x_we = 1'b0;
          endcase
        end else if (execute_state.insn_funct7 == 7'd1) begin
          x_we = 1'b1;
          case (execute_state.insn_funct3)
            3'b000:  x_alu_result = x_rs1_data * x_rs2_data;  // mul (lower 32 bits)
            3'b001: begin  // mulh (signed * signed, upper 32 bits)
              x_mul_full = {{32{x_rs1_data[31]}}, x_rs1_data} * {{32{x_rs2_data[31]}}, x_rs2_data};
              x_alu_result = x_mul_full[63:32];
            end
            3'b010: begin  // mulhsu (signed * unsigned, upper 32 bits)
              x_mul_full   = {{32{x_rs1_data[31]}}, x_rs1_data} * {32'd0, x_rs2_data};
              x_alu_result = x_mul_full[63:32];
            end
            3'b011: begin  // mulhu (unsigned * unsigned, upper 32 bits)
              x_mul_full   = {32'd0, x_rs1_data} * {32'd0, x_rs2_data};
              x_alu_result = x_mul_full[63:32];
            end
            3'b100, 3'b101, 3'b110, 3'b111: begin  // div, divu, rem, remu
              x_alu_result = div_final;
            end
            default: x_we = 1'b0;
          endcase
        end
      end

      OpcodeBranch: begin
        x_we = 1'b0;
        case (execute_state.insn_funct3)
          3'b000:  x_branch_taken = (x_rs1_data == x_rs2_data);  // beq
          3'b001:  x_branch_taken = (x_rs1_data != x_rs2_data);  // bne
          3'b100:  x_branch_taken = (x_rs1_signed < x_rs2_signed);  // blt
          3'b101:  x_branch_taken = (x_rs1_signed >= x_rs2_signed);  // bge
          3'b110:  x_branch_taken = (x_rs1_data < x_rs2_data);  // bltu
          3'b111:  x_branch_taken = (x_rs1_data >= x_rs2_data);  // bgeu
          default: x_branch_taken = 1'b0;
        endcase
        x_branch_target = execute_state.pc + execute_state.imm_b_sext;
      end

      OpcodeJal: begin
        x_alu_result = execute_state.pc + 4;
        x_branch_target = execute_state.pc + execute_state.imm_j_sext;
        x_branch_taken = 1'b1;
        x_we = 1'b1;
      end

      OpcodeJalr: begin
        x_alu_result = execute_state.pc + 4;
        x_branch_target = (x_rs1_data + execute_state.imm_i_sext) & 32'hFFFF_FFFE;
        x_branch_taken = 1'b1;
        x_we = 1'b1;
      end

      OpcodeLoad: begin
        // address computed via adder and result used in Memory stage
        x_cla_b = execute_state.imm_i_sext;
        x_cla_cin = 1'b0;
        x_alu_result = x_cla_sum;  // load address
        x_we = 1'b1;
      end

      OpcodeStore: begin
        // store address = rs1 + imm_s
        x_cla_b = execute_state.imm_s_sext;
        x_cla_cin = 1'b0;
        x_alu_result = x_cla_sum;
        x_we = 1'b0;  // stores don't write rd
      end

      OpcodeEnviron: begin
        x_we = 1'b0;
      end

      OpcodeMiscMem: begin  // fence: treat as NOP
        x_we = 1'b0;
      end

      default: x_we = 1'b0;
    endcase
  end

  // flush: when a branch is taken in Execute, flush Fetch and Decode
  wire x_flush = x_branch_taken &&
                 (execute_state.cycle_status != CYCLE_RESET) &&
                 (execute_state.insn_opcode == OpcodeBranch ||
                  execute_state.insn_opcode == OpcodeJal    ||
                  execute_state.insn_opcode == OpcodeJalr);

  // update Fetch PC
  always_ff @(posedge clk) begin
    if (rst) begin
      f_pc_current   <= 32'd0;
      f_cycle_status <= CYCLE_NO_STALL;
    end else if (x_flush) begin
      // branch taken: next fetch from branch target
      f_pc_current   <= x_branch_target;
      f_cycle_status <= CYCLE_NO_STALL;
    end else if (d_load_use_stall) begin
      f_pc_current   <= f_pc_current;  // freeze during load-use hazard
      f_cycle_status <= CYCLE_NO_STALL;
    end else if (x_div_stall_upstream) begin
      f_pc_current   <= f_pc_current;  // freeze while divider is running
      f_cycle_status <= CYCLE_NO_STALL;
    end else begin
      f_pc_current   <= f_pc_current + 4;
      f_cycle_status <= CYCLE_NO_STALL;
    end
  end

  /* memory stage */

  typedef struct packed {
    logic [`REG_SIZE]  pc;
    logic [`INSN_SIZE] insn;
    cycle_status_e     cycle_status;
    logic [4:0]        insn_rd;
    logic [4:0]        insn_rs2;
    logic [6:0]        insn_opcode;
    logic [2:0]        insn_funct3;
    logic [`REG_SIZE]  alu_result;
    logic [`REG_SIZE]  rs2_data;
    logic              we;
  } stage_memory_t;

  stage_memory_t memory_state;
  always_ff @(posedge clk) begin
    if (rst) begin
      memory_state <= '{
          pc: 0,
          insn: 0,
          cycle_status: CYCLE_RESET,
          insn_rd: 0,
          insn_rs2: 0,
          insn_opcode: 0,
          insn_funct3: 0,
          alu_result: 0,
          rs2_data: 0,
          we: 0
      };
    end else if (x_div_stall) begin
      memory_state <= '{
          pc: 0,
          insn: 0,
          cycle_status: CYCLE_DIV,
          insn_rd: 0,
          insn_rs2: 0,
          insn_opcode: 0,
          insn_funct3: 0,
          alu_result: 0,
          rs2_data: 0,
          we: 0
      };
    end else begin
      memory_state <= '{
          pc: execute_state.pc,
          insn: execute_state.insn,
          cycle_status: execute_state.cycle_status,
          insn_rd: execute_state.insn_rd,
          insn_rs2: execute_state.insn_rs2,
          insn_opcode: execute_state.insn_opcode,
          insn_funct3: execute_state.insn_funct3,
          alu_result: x_alu_result,
          rs2_data: x_rs2_data,
          we: x_we
      };
    end
  end

  wire [255:0] m_disasm;
  Disasm #(
      .PREFIX("M")
  ) disasm_3memory (
      .insn  (memory_state.insn),
      .disasm(m_disasm)
  );

  // m_rd, m_alu_result, m_we are forward-declared above as wires
  assign m_rd         = memory_state.insn_rd;
  assign m_alu_result = memory_state.alu_result;
  assign m_we         = memory_state.we;

  // WM bypass: if W writes the same reg as the store's rs2, use W's value (M's rs2_data is stale).
  wire [`REG_SIZE] m_rs2_data_bypassed =
      (w_we && w_rd != 5'd0 && w_rd == memory_state.insn_rs2) ? w_rd_data : memory_state.rs2_data;

  // memory stage: handle loads/stores
  logic [`REG_SIZE] m_load_data;

  always_comb begin
    addr_to_dmem       = 32'd0;
    store_data_to_dmem = 32'd0;
    store_we_to_dmem   = 4'd0;

    if (memory_state.insn_opcode == OpcodeLoad) begin
      addr_to_dmem = {memory_state.alu_result[31:2], 2'b00};
    end else if (memory_state.insn_opcode == OpcodeStore) begin
      addr_to_dmem = {memory_state.alu_result[31:2], 2'b00};
      case (memory_state.insn_funct3)
        3'b000: begin  // sb
          case (memory_state.alu_result[1:0])
            2'b00: begin
              store_data_to_dmem = {24'b0, m_rs2_data_bypassed[7:0]};
              store_we_to_dmem   = 4'b0001;
            end
            2'b01: begin
              store_data_to_dmem = {16'b0, m_rs2_data_bypassed[7:0], 8'b0};
              store_we_to_dmem   = 4'b0010;
            end
            2'b10: begin
              store_data_to_dmem = {8'b0, m_rs2_data_bypassed[7:0], 16'b0};
              store_we_to_dmem   = 4'b0100;
            end
            2'b11: begin
              store_data_to_dmem = {m_rs2_data_bypassed[7:0], 24'b0};
              store_we_to_dmem   = 4'b1000;
            end
            default: ;
          endcase
        end
        3'b001: begin  // sh
          case (memory_state.alu_result[1:0])
            2'b00: begin
              store_data_to_dmem = {16'b0, m_rs2_data_bypassed[15:0]};
              store_we_to_dmem   = 4'b0011;
            end
            2'b10: begin
              store_data_to_dmem = {m_rs2_data_bypassed[15:0], 16'b0};
              store_we_to_dmem   = 4'b1100;
            end
            default: ;
          endcase
        end
        3'b010: begin  // sw
          store_data_to_dmem = m_rs2_data_bypassed;
          store_we_to_dmem   = 4'b1111;
        end
        default: ;
      endcase
    end
  end

  // select what data goes to writeback for loads
  always_comb begin
    m_load_data = 32'd0;
    if (memory_state.insn_opcode == OpcodeLoad) begin
      case (memory_state.insn_funct3)
        3'b000: begin  // lb
          case (memory_state.alu_result[1:0])
            2'b00:   m_load_data = {{24{load_data_from_dmem[7]}}, load_data_from_dmem[7:0]};
            2'b01:   m_load_data = {{24{load_data_from_dmem[15]}}, load_data_from_dmem[15:8]};
            2'b10:   m_load_data = {{24{load_data_from_dmem[23]}}, load_data_from_dmem[23:16]};
            2'b11:   m_load_data = {{24{load_data_from_dmem[31]}}, load_data_from_dmem[31:24]};
            default: m_load_data = 32'd0;
          endcase
        end
        3'b001: begin  // lh
          case (memory_state.alu_result[1:0])
            2'b00:   m_load_data = {{16{load_data_from_dmem[15]}}, load_data_from_dmem[15:0]};
            2'b10:   m_load_data = {{16{load_data_from_dmem[31]}}, load_data_from_dmem[31:16]};
            default: m_load_data = 32'd0;
          endcase
        end
        3'b010:  m_load_data = load_data_from_dmem;  // lw
        3'b100: begin  // lbu
          case (memory_state.alu_result[1:0])
            2'b00:   m_load_data = {24'b0, load_data_from_dmem[7:0]};
            2'b01:   m_load_data = {24'b0, load_data_from_dmem[15:8]};
            2'b10:   m_load_data = {24'b0, load_data_from_dmem[23:16]};
            2'b11:   m_load_data = {24'b0, load_data_from_dmem[31:24]};
            default: m_load_data = 32'd0;
          endcase
        end
        3'b101: begin  // lhu
          case (memory_state.alu_result[1:0])
            2'b00:   m_load_data = {16'b0, load_data_from_dmem[15:0]};
            2'b10:   m_load_data = {16'b0, load_data_from_dmem[31:16]};
            default: m_load_data = 32'd0;
          endcase
        end
        default: m_load_data = 32'd0;
      endcase
    end
  end

  /*******************/
  /* WRITEBACK STAGE */
  /*******************/

  typedef struct packed {
    logic [`REG_SIZE]  pc;
    logic [`INSN_SIZE] insn;
    cycle_status_e     cycle_status;
    logic [4:0]        insn_rd;
    logic [6:0]        insn_opcode;
    logic [`REG_SIZE]  rd_data;
    logic              we;
  } stage_writeback_t;

  stage_writeback_t writeback_state;
  always_ff @(posedge clk) begin
    if (rst) begin
      writeback_state <= '{
          pc: 0,
          insn: 0,
          cycle_status: CYCLE_RESET,
          insn_rd: 0,
          insn_opcode: 0,
          rd_data: 0,
          we: 0
      };
    end else begin
      writeback_state <= '{
          pc: memory_state.pc,
          insn: memory_state.insn,
          cycle_status: memory_state.cycle_status,
          insn_rd: memory_state.insn_rd,
          insn_opcode: memory_state.insn_opcode,
          rd_data:
          (
          memory_state.insn_opcode == OpcodeLoad
          ) ?
          m_load_data
          :
          memory_state.alu_result,
          we: memory_state.we
      };
    end
  end

  wire [255:0] w_disasm;
  Disasm #(
      .PREFIX("W")
  ) disasm_4writeback (
      .insn  (writeback_state.insn),
      .disasm(w_disasm)
  );

  // writeback to register file
  assign w_rd = writeback_state.insn_rd;
  assign w_rd_data = writeback_state.rd_data;
  assign w_we = writeback_state.we;

  assign halt = (writeback_state.insn_opcode == OpcodeEnviron) &&
                (writeback_state.insn[31:7] == 25'd0) &&
                (writeback_state.cycle_status == CYCLE_NO_STALL);

  assign trace_completed_pc = writeback_state.pc;
  assign trace_completed_insn = writeback_state.insn;
  assign trace_completed_cycle_status = writeback_state.cycle_status;

endmodule

module MemorySingleCycle #(
    parameter int NUM_WORDS = 512
) (
    // rst for both imem and dmem
    input wire rst,

    // clock for both imem and dmem. The memory reads/writes on @(negedge clk)
    input wire clk,

    // must always be aligned to a 4B boundary
    input wire [`REG_SIZE] pc_to_imem,

    // the value at memory location pc_to_imem
    output logic [`REG_SIZE] insn_from_imem,

    // must always be aligned to a 4B boundary
    input wire [`REG_SIZE] addr_to_dmem,

    // the value at memory location addr_to_dmem
    output logic [`REG_SIZE] load_data_from_dmem,

    // the value to be written to addr_to_dmem, controlled by store_we_to_dmem
    input wire [`REG_SIZE] store_data_to_dmem,

    // Each bit determines whether to write the corresponding byte of store_data_to_dmem to memory location addr_to_dmem.
    // E.g., 4'b1111 will write 4 bytes. 4'b0001 will write only the least-significant byte.
    input wire [3:0] store_we_to_dmem
);

  // memory is arranged as an array of 4B words
  logic [`REG_SIZE] mem_array[NUM_WORDS];

`ifdef SYNTHESIS
  initial begin
    $readmemh("mem_initial_contents.hex", mem_array);
  end
`endif

  always_comb begin
    // memory addresses should always be 4B-aligned
    assert (pc_to_imem[1:0] == 2'b00);
    assert (addr_to_dmem[1:0] == 2'b00);
  end

  localparam int AddrMsb = $clog2(NUM_WORDS) + 1;
  localparam int AddrLsb = 2;

  always @(negedge clk) begin
    if (rst) begin
    end else begin
      insn_from_imem <= mem_array[{pc_to_imem[AddrMsb:AddrLsb]}];
    end
  end

  always @(negedge clk) begin
    if (rst) begin
    end else begin
      if (store_we_to_dmem[0]) begin
        mem_array[addr_to_dmem[AddrMsb:AddrLsb]][7:0] <= store_data_to_dmem[7:0];
      end
      if (store_we_to_dmem[1]) begin
        mem_array[addr_to_dmem[AddrMsb:AddrLsb]][15:8] <= store_data_to_dmem[15:8];
      end
      if (store_we_to_dmem[2]) begin
        mem_array[addr_to_dmem[AddrMsb:AddrLsb]][23:16] <= store_data_to_dmem[23:16];
      end
      if (store_we_to_dmem[3]) begin
        mem_array[addr_to_dmem[AddrMsb:AddrLsb]][31:24] <= store_data_to_dmem[31:24];
      end
      // dmem is "read-first": read returns value before the write
      load_data_from_dmem <= mem_array[{addr_to_dmem[AddrMsb:AddrLsb]}];
    end
  end
endmodule

/* This design has just one clock for both processor and memory. */
module Processor (
    input wire clk,
    input wire rst,
    output logic halt,
    output wire [`REG_SIZE] trace_completed_pc,
    output wire [`INSN_SIZE] trace_completed_insn,
    output cycle_status_e trace_completed_cycle_status
);

  wire [`INSN_SIZE] insn_from_imem;
  wire [`REG_SIZE] pc_to_imem, mem_data_addr, mem_data_loaded_value, mem_data_to_write;
  wire [3:0] mem_data_we;

  // This wire is set by cocotb to the name of the currently-running test, to make it easier
  // to see what is going on in the waveforms.
  wire [(8*32)-1:0] test_case;

  MemorySingleCycle #(
      .NUM_WORDS(8192)
  ) memory (
      .rst                (rst),
      .clk                (clk),
      // imem is read-only
      .pc_to_imem         (pc_to_imem),
      .insn_from_imem     (insn_from_imem),
      // dmem is read-write
      .addr_to_dmem       (mem_data_addr),
      .load_data_from_dmem(mem_data_loaded_value),
      .store_data_to_dmem (mem_data_to_write),
      .store_we_to_dmem   (mem_data_we)
  );

  DatapathPipelined datapath (
      .clk(clk),
      .rst(rst),
      .pc_to_imem(pc_to_imem),
      .insn_from_imem(insn_from_imem),
      .addr_to_dmem(mem_data_addr),
      .store_data_to_dmem(mem_data_to_write),
      .store_we_to_dmem(mem_data_we),
      .load_data_from_dmem(mem_data_loaded_value),
      .halt(halt),
      .trace_completed_pc(trace_completed_pc),
      .trace_completed_insn(trace_completed_insn),
      .trace_completed_cycle_status(trace_completed_cycle_status)
  );

endmodule
