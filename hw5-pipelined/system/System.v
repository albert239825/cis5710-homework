module MyClockGen (
	input_clk_25MHz,
	clk_proc,
	locked
);
	input input_clk_25MHz;
	output wire clk_proc;
	output wire locked;
	wire clkfb;
	(* FREQUENCY_PIN_CLKI = "25" *) (* FREQUENCY_PIN_CLKOP = "20" *) (* ICP_CURRENT = "12" *) (* LPF_RESISTOR = "8" *) (* MFG_ENABLE_FILTEROPAMP = "1" *) (* MFG_GMCREF_SEL = "2" *) EHXPLLL #(
		.PLLRST_ENA("DISABLED"),
		.INTFB_WAKE("DISABLED"),
		.STDBY_ENABLE("DISABLED"),
		.DPHASE_SOURCE("DISABLED"),
		.OUTDIVIDER_MUXA("DIVA"),
		.OUTDIVIDER_MUXB("DIVB"),
		.OUTDIVIDER_MUXC("DIVC"),
		.OUTDIVIDER_MUXD("DIVD"),
		.CLKI_DIV(5),
		.CLKOP_ENABLE("ENABLED"),
		.CLKOP_DIV(30),
		.CLKOP_CPHASE(15),
		.CLKOP_FPHASE(0),
		.FEEDBK_PATH("INT_OP"),
		.CLKFB_DIV(4)
	) pll_i(
		.RST(1'b0),
		.STDBY(1'b0),
		.CLKI(input_clk_25MHz),
		.CLKOP(clk_proc),
		.CLKFB(clkfb),
		.CLKINTFB(clkfb),
		.PHASESEL0(1'b0),
		.PHASESEL1(1'b0),
		.PHASEDIR(1'b1),
		.PHASESTEP(1'b1),
		.PHASELOADREG(1'b1),
		.PLLWAKESYNC(1'b0),
		.ENCLKOP(1'b0),
		.LOCK(locked)
	);
endmodule
module gp2 (
	gin,
	pin,
	gout,
	pout
);
	input wire [1:0] gin;
	input wire [1:0] pin;
	output wire gout;
	output wire pout;
	assign gout = gin[1] | (pin[1] & gin[0]);
	assign pout = pin[1] & pin[0];
endmodule
module gp4 (
	gin,
	pin,
	cin,
	gout,
	pout,
	cout
);
	input wire [3:0] gin;
	input wire [3:0] pin;
	input wire cin;
	output wire gout;
	output wire pout;
	output wire [2:0] cout;
	wire g_low;
	wire p_low;
	wire g_high;
	wire p_high;
	gp2 gp2_low(
		.gin(gin[1:0]),
		.pin(pin[1:0]),
		.gout(g_low),
		.pout(p_low)
	);
	gp2 gp2_high(
		.gin(gin[3:2]),
		.pin(pin[3:2]),
		.gout(g_high),
		.pout(p_high)
	);
	gp2 gp2_combined(
		.gin({g_high, g_low}),
		.pin({p_high, p_low}),
		.gout(gout),
		.pout(pout)
	);
	assign cout[0] = gin[0] | (pin[0] & cin);
	assign cout[1] = (gin[1] | (pin[1] & gin[0])) | ((pin[1] & pin[0]) & cin);
	assign cout[2] = ((gin[2] | (pin[2] & gin[1])) | ((pin[2] & pin[1]) & gin[0])) | (((pin[2] & pin[1]) & pin[0]) & cin);
endmodule
module gp8 (
	gin,
	pin,
	cin,
	gout,
	pout,
	cout
);
	input wire [7:0] gin;
	input wire [7:0] pin;
	input wire cin;
	output wire gout;
	output wire pout;
	output wire [6:0] cout;
	wire g_lo;
	wire p_lo;
	wire g_hi;
	wire p_hi;
	wire [2:0] c_lo;
	wire [2:0] c_hi;
	wire c4;
	gp4 gp4_lo(
		.gin(gin[3:0]),
		.pin(pin[3:0]),
		.cin(cin),
		.gout(g_lo),
		.pout(p_lo),
		.cout(c_lo)
	);
	assign c4 = g_lo | (p_lo & cin);
	gp4 gp4_hi(
		.gin(gin[7:4]),
		.pin(pin[7:4]),
		.cin(c4),
		.gout(g_hi),
		.pout(p_hi),
		.cout(c_hi)
	);
	assign pout = p_hi & p_lo;
	assign gout = g_hi | (p_hi & g_lo);
	assign cout[2:0] = c_lo;
	assign cout[3] = c4;
	assign cout[6:4] = c_hi;
endmodule
module CarryLookaheadAdder (
	a,
	b,
	cin,
	sum
);
	input wire [31:0] a;
	input wire [31:0] b;
	input wire cin;
	output wire [31:0] sum;
	wire [31:0] g;
	wire [31:0] p;
	wire [31:0] c;
	wire [3:0] block_g;
	wire [3:0] block_p;
	wire [3:0] block_cin;
	wire [2:0] block_cout;
	wire [6:0] cout0;
	wire [6:0] cout1;
	wire [6:0] cout2;
	wire [6:0] cout3;
	wire top_gout;
	wire top_pout;
	assign g = a & b;
	assign p = a | b;
	gp4 gp4_top(
		.gin(block_g),
		.pin(block_p),
		.cin(cin),
		.gout(top_gout),
		.pout(top_pout),
		.cout(block_cout)
	);
	assign block_cin[0] = cin;
	assign block_cin[1] = block_cout[0];
	assign block_cin[2] = block_cout[1];
	assign block_cin[3] = block_cout[2];
	gp8 gp8_0(
		.gin(g[7:0]),
		.pin(p[7:0]),
		.cin(block_cin[0]),
		.gout(block_g[0]),
		.pout(block_p[0]),
		.cout(cout0)
	);
	gp8 gp8_1(
		.gin(g[15:8]),
		.pin(p[15:8]),
		.cin(block_cin[1]),
		.gout(block_g[1]),
		.pout(block_p[1]),
		.cout(cout1)
	);
	gp8 gp8_2(
		.gin(g[23:16]),
		.pin(p[23:16]),
		.cin(block_cin[2]),
		.gout(block_g[2]),
		.pout(block_p[2]),
		.cout(cout2)
	);
	gp8 gp8_3(
		.gin(g[31:24]),
		.pin(p[31:24]),
		.cin(block_cin[3]),
		.gout(block_g[3]),
		.pout(block_p[3]),
		.cout(cout3)
	);
	assign c[0] = cin;
	assign c[7:1] = cout0;
	assign c[8] = block_cin[1];
	assign c[15:9] = cout1;
	assign c[16] = block_cin[2];
	assign c[23:17] = cout2;
	assign c[24] = block_cin[3];
	assign c[31:25] = cout3;
	assign sum = (a ^ b) ^ c;
endmodule
module DividerUnsignedPipelined (
	clk,
	rst,
	stall,
	i_dividend,
	i_divisor,
	o_remainder,
	o_quotient
);
	input wire clk;
	input wire rst;
	input wire stall;
	input wire [31:0] i_dividend;
	input wire [31:0] i_divisor;
	output wire [31:0] o_remainder;
	output wire [31:0] o_quotient;
	reg [31:0] dividend_pipe [0:7];
	reg [31:0] remainder_pipe [0:7];
	reg [31:0] quotient_pipe [0:7];
	reg [31:0] divisor_pipe [0:7];
	wire [31:0] dividend_next [0:7];
	wire [31:0] remainder_next [0:7];
	wire [31:0] quotient_next [0:7];
	divu_4iter stage0(
		.i_dividend(i_dividend),
		.i_divisor(i_divisor),
		.i_remainder(32'd0),
		.i_quotient(32'd0),
		.o_dividend(dividend_next[0]),
		.o_remainder(remainder_next[0]),
		.o_quotient(quotient_next[0])
	);
	genvar _gv_s_1;
	generate
		for (_gv_s_1 = 1; _gv_s_1 <= 7; _gv_s_1 = _gv_s_1 + 1) begin : div_pipeline_stage_loop
			localparam s = _gv_s_1;
			divu_4iter stageN(
				.i_dividend(dividend_pipe[s - 1]),
				.i_divisor(divisor_pipe[s - 1]),
				.i_remainder(remainder_pipe[s - 1]),
				.i_quotient(quotient_pipe[s - 1]),
				.o_dividend(dividend_next[s]),
				.o_remainder(remainder_next[s]),
				.o_quotient(quotient_next[s])
			);
		end
	endgenerate
	integer k;
	always @(posedge clk)
		if (rst)
			for (k = 0; k <= 7; k = k + 1)
				begin
					dividend_pipe[k] <= 32'd0;
					remainder_pipe[k] <= 32'd0;
					quotient_pipe[k] <= 32'd0;
					divisor_pipe[k] <= 32'd0;
				end
		else begin
			for (k = 0; k <= 7; k = k + 1)
				begin
					dividend_pipe[k] <= dividend_next[k];
					remainder_pipe[k] <= remainder_next[k];
					quotient_pipe[k] <= quotient_next[k];
				end
			divisor_pipe[0] <= i_divisor;
			for (k = 1; k <= 7; k = k + 1)
				divisor_pipe[k] <= divisor_pipe[k - 1];
		end
	assign o_remainder = remainder_next[7];
	assign o_quotient = quotient_next[7];
endmodule
module divu_4iter (
	i_dividend,
	i_divisor,
	i_remainder,
	i_quotient,
	o_dividend,
	o_remainder,
	o_quotient
);
	input wire [31:0] i_dividend;
	input wire [31:0] i_divisor;
	input wire [31:0] i_remainder;
	input wire [31:0] i_quotient;
	output wire [31:0] o_dividend;
	output wire [31:0] o_remainder;
	output wire [31:0] o_quotient;
	wire [31:0] dividend [0:4];
	wire [31:0] remainder [0:4];
	wire [31:0] quotient [0:4];
	assign dividend[0] = i_dividend;
	assign remainder[0] = i_remainder;
	assign quotient[0] = i_quotient;
	genvar _gv_i_1;
	generate
		for (_gv_i_1 = 0; _gv_i_1 < 4; _gv_i_1 = _gv_i_1 + 1) begin : iter_loop
			localparam i = _gv_i_1;
			divu_1iter iter(
				.i_dividend(dividend[i]),
				.i_divisor(i_divisor),
				.i_remainder(remainder[i]),
				.i_quotient(quotient[i]),
				.o_dividend(dividend[i + 1]),
				.o_remainder(remainder[i + 1]),
				.o_quotient(quotient[i + 1])
			);
		end
	endgenerate
	assign o_dividend = dividend[4];
	assign o_remainder = remainder[4];
	assign o_quotient = quotient[4];
endmodule
module divu_1iter (
	i_dividend,
	i_divisor,
	i_remainder,
	i_quotient,
	o_dividend,
	o_remainder,
	o_quotient
);
	reg _sv2v_0;
	input wire [31:0] i_dividend;
	input wire [31:0] i_divisor;
	input wire [31:0] i_remainder;
	input wire [31:0] i_quotient;
	output reg [31:0] o_dividend;
	output reg [31:0] o_remainder;
	output reg [31:0] o_quotient;
	reg [31:0] rem_shift;
	always @(*) begin
		if (_sv2v_0)
			;
		rem_shift = {i_remainder[30:0], i_dividend[31]};
		if (rem_shift < i_divisor) begin
			o_quotient = i_quotient << 1;
			o_remainder = rem_shift;
		end
		else begin
			o_quotient = {i_quotient[30:0], 1'b1};
			o_remainder = rem_shift - i_divisor;
		end
		o_dividend = {i_dividend[30:0], 1'b0};
	end
	initial _sv2v_0 = 0;
endmodule
module Disasm (
	insn,
	disasm
);
	parameter signed [7:0] PREFIX = "D";
	input wire [31:0] insn;
	output wire [255:0] disasm;
endmodule
module RegFile (
	rd,
	rd_data,
	rs1,
	rs1_data,
	rs2,
	rs2_data,
	clk,
	we,
	rst
);
	input wire [4:0] rd;
	input wire [31:0] rd_data;
	input wire [4:0] rs1;
	output wire [31:0] rs1_data;
	input wire [4:0] rs2;
	output wire [31:0] rs2_data;
	input wire clk;
	input wire we;
	input wire rst;
	localparam signed [31:0] NumRegs = 32;
	reg [31:0] regs [0:31];
	assign rs1_data = (rs1 == 5'd0 ? 32'd0 : regs[rs1]);
	assign rs2_data = (rs2 == 5'd0 ? 32'd0 : regs[rs2]);
	always @(posedge clk)
		if (rst) begin : sv2v_autoblock_1
			reg signed [31:0] j;
			for (j = 0; j < NumRegs; j = j + 1)
				regs[j] <= 32'd0;
		end
		else if (we && (rd != 5'd0))
			regs[rd] <= rd_data;
endmodule
module DatapathPipelined (
	clk,
	rst,
	pc_to_imem,
	insn_from_imem,
	addr_to_dmem,
	load_data_from_dmem,
	store_data_to_dmem,
	store_we_to_dmem,
	halt,
	trace_completed_pc,
	trace_completed_insn,
	trace_completed_cycle_status
);
	reg _sv2v_0;
	input wire clk;
	input wire rst;
	output wire [31:0] pc_to_imem;
	input wire [31:0] insn_from_imem;
	output reg [31:0] addr_to_dmem;
	input wire [31:0] load_data_from_dmem;
	output reg [31:0] store_data_to_dmem;
	output reg [3:0] store_we_to_dmem;
	output wire halt;
	output wire [31:0] trace_completed_pc;
	output wire [31:0] trace_completed_insn;
	output wire [31:0] trace_completed_cycle_status;
	localparam [6:0] OpcodeLoad = 7'b0000011;
	localparam [6:0] OpcodeStore = 7'b0100011;
	localparam [6:0] OpcodeBranch = 7'b1100011;
	localparam [6:0] OpcodeJalr = 7'b1100111;
	localparam [6:0] OpcodeMiscMem = 7'b0001111;
	localparam [6:0] OpcodeJal = 7'b1101111;
	localparam [6:0] OpcodeRegImm = 7'b0010011;
	localparam [6:0] OpcodeRegReg = 7'b0110011;
	localparam [6:0] OpcodeEnviron = 7'b1110011;
	localparam [6:0] OpcodeAuipc = 7'b0010111;
	localparam [6:0] OpcodeLui = 7'b0110111;
	reg [31:0] cycles_current;
	always @(posedge clk)
		if (rst)
			cycles_current <= 0;
		else
			cycles_current <= cycles_current + 1;
	reg [31:0] f_pc_current;
	wire [31:0] f_insn;
	reg [31:0] f_cycle_status;
	assign pc_to_imem = f_pc_current;
	assign f_insn = insn_from_imem;
	wire [255:0] f_disasm;
	Disasm #(.PREFIX("F")) disasm_0fetch(
		.insn(f_insn),
		.disasm(f_disasm)
	);
	reg [95:0] decode_state;
	wire [4:0] d_insn_rs1 = decode_state[51:47];
	wire [4:0] d_insn_rs2 = decode_state[56:52];
	wire [6:0] d_insn_opcode = decode_state[38:32];
	wire d_uses_rs2 = (d_insn_opcode == OpcodeRegReg) || (d_insn_opcode == OpcodeBranch);
	reg [324:0] execute_state;
	wire d_load_use_stall = ((((execute_state[213-:7] == OpcodeLoad) && (execute_state[260-:32] != 32'd4)) && (execute_state[260-:32] != 32'd8)) && (execute_state[218-:5] != 5'd0)) && ((execute_state[218-:5] == d_insn_rs1) || (d_uses_rs2 && (execute_state[218-:5] == d_insn_rs2)));
	wire d_div_no_dependency = (execute_state[218-:5] == 5'd0) || ((execute_state[218-:5] != d_insn_rs1) && (execute_state[218-:5] != d_insn_rs2));
	wire [2:0] d_insn_funct3 = decode_state[46:44];
	wire [6:0] d_insn_funct7 = decode_state[63:57];
	wire d_is_div = ((((d_insn_opcode == OpcodeRegReg) && (d_insn_funct7 == 7'd1)) && (d_insn_funct3[2] == 1'b1)) && (decode_state[31-:32] != 32'd4)) && (decode_state[31-:32] != 32'd8);
	reg div_retiring;
	reg [3:0] x_div_counter;
	wire x_is_div = ((execute_state[213-:7] == OpcodeRegReg) && (execute_state[206-:7] == 7'd1)) && (execute_state[199] == 1'b1);
	wire d_div_can_feed = ((x_is_div && (((x_div_counter >= 4'd1) && (x_div_counter <= 4'd6)) || ((x_div_counter == 4'd7) && !div_retiring))) && d_is_div) && d_div_no_dependency;
	wire x_div_stall = x_is_div && (x_div_counter < 4'd7);
	wire x_div_stall_upstream = x_div_stall && !d_div_can_feed;
	reg x_branch_taken;
	wire x_flush = (x_branch_taken && (execute_state[260-:32] != 32'd4)) && (((execute_state[213-:7] == OpcodeBranch) || (execute_state[213-:7] == OpcodeJal)) || (execute_state[213-:7] == OpcodeJalr));
	always @(posedge clk)
		if (rst)
			decode_state <= 96'h000000000000000000000004;
		else if (x_flush)
			decode_state <= 96'h000000000000000000000008;
		else if (d_load_use_stall)
			decode_state <= decode_state;
		else if (x_div_stall_upstream)
			decode_state <= decode_state;
		else
			decode_state <= {f_pc_current, f_insn, f_cycle_status};
	wire [255:0] d_disasm;
	Disasm #(.PREFIX("D")) disasm_1decode(
		.insn(decode_state[63-:32]),
		.disasm(d_disasm)
	);
	wire [4:0] d_insn_rd = decode_state[43:39];
	wire [11:0] d_imm_i = decode_state[63:52];
	wire [4:0] d_imm_shamt = decode_state[56:52];
	wire [11:0] d_imm_s;
	assign d_imm_s[11:5] = d_insn_funct7;
	assign d_imm_s[4:0] = d_insn_rd;
	wire [12:0] d_imm_b;
	assign {d_imm_b[12], d_imm_b[10:5]} = d_insn_funct7;
	assign {d_imm_b[4:1], d_imm_b[11]} = d_insn_rd;
	assign d_imm_b[0] = 1'b0;
	wire [20:0] d_imm_j;
	assign {d_imm_j[20], d_imm_j[10:1], d_imm_j[11], d_imm_j[19:12], d_imm_j[0]} = {decode_state[63:44], 1'b0};
	wire [31:0] d_imm_i_sext = {{20 {d_imm_i[11]}}, d_imm_i[11:0]};
	wire [31:0] d_imm_s_sext = {{20 {d_imm_s[11]}}, d_imm_s[11:0]};
	wire [31:0] d_imm_b_sext = {{19 {d_imm_b[12]}}, d_imm_b[12:0]};
	wire [31:0] d_imm_j_sext = {{11 {d_imm_j[20]}}, d_imm_j[20:0]};
	wire [31:0] d_rs1_data_rf;
	wire [31:0] d_rs2_data_rf;
	wire [4:0] w_rd;
	wire [31:0] w_rd_data;
	wire w_we;
	RegFile rf(
		.clk(clk),
		.rst(rst),
		.we(w_we),
		.rd(w_rd),
		.rd_data(w_rd_data),
		.rs1(d_insn_rs1),
		.rs2(d_insn_rs2),
		.rs1_data(d_rs1_data_rf),
		.rs2_data(d_rs2_data_rf)
	);
	wire [31:0] d_rs1_data = ((w_we && (w_rd != 5'd0)) && (w_rd == d_insn_rs1) ? w_rd_data : d_rs1_data_rf);
	wire [31:0] d_rs2_data = ((w_we && (w_rd != 5'd0)) && (w_rd == d_insn_rs2) ? w_rd_data : d_rs2_data_rf);
	reg [2:0] ov_head;
	localparam signed [31:0] DIV_OVERLAP_MAX = 8;
	reg [31:0] ov_insn [0:7];
	reg [31:0] ov_pc [0:7];
	reg [4:0] ov_rd [0:7];
	reg [2:0] ov_tail;
	wire div_overlap_pending = ov_head != ov_tail;
	wire x_div_retire_overlap = (x_is_div && (x_div_counter == 4'd7)) && div_overlap_pending;
	function automatic [31:0] sv2v_cast_32;
		input reg [31:0] inp;
		sv2v_cast_32 = inp;
	endfunction
	always @(posedge clk)
		if (rst)
			execute_state <= 325'h8000000000000000000000000000000000000000000000000000000000;
		else if (x_flush)
			execute_state <= 325'h10000000000000000000000000000000000000000000000000000000000;
		else if (d_load_use_stall)
			execute_state <= 325'h20000000000000000000000000000000000000000000000000000000000;
		else if (x_div_stall)
			execute_state <= execute_state;
		else if (x_div_retire_overlap)
			execute_state <= {ov_pc[ov_head], ov_insn[ov_head], 42'h00000000400, ov_rd[ov_head], OpcodeRegReg, 7'd1, ov_insn[ov_head][14:12], 197'h00000000000000000000000000000000000000000000000000};
		else
			execute_state <= {sv2v_cast_32(decode_state[95-:32]), sv2v_cast_32(decode_state[63-:32]), sv2v_cast_32(decode_state[31-:32]), d_insn_rs1, d_insn_rs2, d_insn_rd, d_insn_opcode, d_insn_funct7, d_insn_funct3, d_rs1_data, d_rs2_data, d_imm_i_sext, d_imm_s_sext, d_imm_b_sext, d_imm_j_sext, d_imm_shamt};
	wire [255:0] x_disasm;
	Disasm #(.PREFIX("X")) disasm_2execute(
		.insn(execute_state[292-:32]),
		.disasm(x_disasm)
	);
	wire [4:0] m_rd;
	wire [31:0] m_alu_result;
	wire m_we;
	wire [31:0] x_rs1_data = ((m_we && (m_rd != 5'd0)) && (m_rd == execute_state[228-:5]) ? m_alu_result : ((w_we && (w_rd != 5'd0)) && (w_rd == execute_state[228-:5]) ? w_rd_data : execute_state[196-:32]));
	wire [31:0] x_rs2_data = ((m_we && (m_rd != 5'd0)) && (m_rd == execute_state[223-:5]) ? m_alu_result : ((w_we && (w_rd != 5'd0)) && (w_rd == execute_state[223-:5]) ? w_rd_data : execute_state[164-:32]));
	reg [31:0] x_alu_result;
	reg x_we;
	reg [31:0] x_branch_target;
	wire signed [31:0] x_rs1_signed = $signed(x_rs1_data);
	wire signed [31:0] x_rs2_signed = $signed(x_rs2_data);
	reg [31:0] x_cla_b;
	reg x_cla_cin;
	wire [31:0] x_cla_sum;
	CarryLookaheadAdder x_cla(
		.a(x_rs1_data),
		.b(x_cla_b),
		.cin(x_cla_cin),
		.sum(x_cla_sum)
	);
	reg [63:0] x_mul_full;
	wire x_start_div = x_is_div && (x_div_counter == 4'd0);
	reg [31:0] div_dividend;
	reg [31:0] div_divisor;
	wire [31:0] div_quotient;
	wire [31:0] div_remainder;
	DividerUnsignedPipelined divider(
		.clk(clk),
		.rst(rst),
		.stall(1'b0),
		.i_dividend(div_dividend),
		.i_divisor(div_divisor),
		.o_remainder(div_remainder),
		.o_quotient(div_quotient)
	);
	reg [31:0] div_saved_rs1;
	reg [31:0] div_saved_rs2;
	reg div_saved_sign_q;
	reg div_saved_sign_r;
	reg div_saved_is_rem;
	reg [31:0] ov_rs1 [0:7];
	reg [31:0] ov_rs2 [0:7];
	reg ov_sign_q [0:7];
	reg ov_sign_r [0:7];
	reg ov_is_rem [0:7];
	always @(posedge clk)
		if (rst) begin
			x_div_counter <= 4'd0;
			div_saved_rs1 <= 0;
			div_saved_rs2 <= 0;
			div_saved_sign_q <= 0;
			div_saved_sign_r <= 0;
			div_saved_is_rem <= 0;
			ov_head <= 3'd0;
			ov_tail <= 3'd0;
			div_retiring <= 1'b0;
		end
		else if (x_flush) begin
			x_div_counter <= 4'd0;
			ov_head <= 3'd0;
			ov_tail <= 3'd0;
			div_retiring <= 1'b0;
		end
		else if (x_is_div && (x_div_counter < 4'd8)) begin
			if (x_div_retire_overlap) begin
				x_div_counter <= 4'd7;
				div_retiring <= 1'b1;
				div_saved_rs1 <= ov_rs1[ov_head];
				div_saved_rs2 <= ov_rs2[ov_head];
				div_saved_sign_q <= ov_sign_q[ov_head];
				div_saved_sign_r <= ov_sign_r[ov_head];
				div_saved_is_rem <= ov_is_rem[ov_head];
				ov_head <= ov_head + 3'd1;
			end
			else if (x_div_counter == 4'd7) begin
				x_div_counter <= 4'd0;
				ov_head <= 3'd0;
				ov_tail <= 3'd0;
				div_retiring <= 1'b0;
			end
			else
				x_div_counter <= x_div_counter + 4'd1;
			if (x_div_counter == 4'd0) begin
				div_saved_rs1 <= x_rs1_data;
				div_saved_rs2 <= x_rs2_data;
				div_saved_sign_q <= !execute_state[197] && (x_rs1_data[31] ^ x_rs2_data[31]);
				div_saved_sign_r <= !execute_state[197] && x_rs1_data[31];
				div_saved_is_rem <= execute_state[198];
			end
			if (d_div_can_feed) begin
				ov_rs1[ov_tail] <= d_rs1_data;
				ov_rs2[ov_tail] <= d_rs2_data;
				ov_sign_q[ov_tail] <= !d_insn_funct3[0] && (d_rs1_data[31] ^ d_rs2_data[31]);
				ov_sign_r[ov_tail] <= !d_insn_funct3[0] && d_rs1_data[31];
				ov_is_rem[ov_tail] <= d_insn_funct3[1];
				ov_rd[ov_tail] <= d_insn_rd;
				ov_pc[ov_tail] <= decode_state[95-:32];
				ov_insn[ov_tail] <= decode_state[63-:32];
				ov_tail <= ov_tail + 3'd1;
			end
		end
		else begin
			x_div_counter <= 4'd0;
			ov_head <= 3'd0;
			ov_tail <= 3'd0;
			div_retiring <= 1'b0;
		end
	always @(*) begin
		if (_sv2v_0)
			;
		if (x_start_div) begin
			div_dividend = (!execute_state[197] && x_rs1_data[31] ? ~x_rs1_data + 32'd1 : x_rs1_data);
			div_divisor = (!execute_state[197] && x_rs2_data[31] ? ~x_rs2_data + 32'd1 : x_rs2_data);
		end
		else if (d_div_can_feed) begin
			div_dividend = (!d_insn_funct3[0] && d_rs1_data[31] ? ~d_rs1_data + 32'd1 : d_rs1_data);
			div_divisor = (!d_insn_funct3[0] && d_rs2_data[31] ? ~d_rs2_data + 32'd1 : d_rs2_data);
		end
		else begin
			div_dividend = 32'd0;
			div_divisor = 32'd0;
		end
	end
	wire div_by_zero = div_saved_rs2 == 32'd0;
	wire div_overflow = (div_saved_sign_q && (div_saved_rs1 == 32'h80000000)) && (div_saved_rs2 == 32'hffffffff);
	wire [31:0] div_corrected_q = (div_saved_sign_q ? ~div_quotient + 32'd1 : div_quotient);
	wire [31:0] div_corrected_r = (div_saved_sign_r ? ~div_remainder + 32'd1 : div_remainder);
	wire [31:0] div_final = (div_by_zero ? (div_saved_is_rem ? div_saved_rs1 : 32'hffffffff) : (div_overflow ? (div_saved_is_rem ? 32'd0 : 32'h80000000) : (div_saved_is_rem ? div_corrected_r : div_corrected_q)));
	always @(*) begin
		if (_sv2v_0)
			;
		x_alu_result = 32'd0;
		x_we = 1'b0;
		x_branch_taken = 1'b0;
		x_branch_target = execute_state[324-:32] + execute_state[68-:32];
		x_cla_b = execute_state[164-:32];
		x_cla_cin = 1'b0;
		x_mul_full = 64'd0;
		case (execute_state[213-:7])
			OpcodeLui: begin
				x_alu_result = {execute_state[292:273], 12'd0};
				x_we = 1'b1;
			end
			OpcodeAuipc: begin
				x_alu_result = execute_state[324-:32] + {execute_state[292:273], 12'd0};
				x_we = 1'b1;
			end
			OpcodeRegImm: begin
				x_we = 1'b1;
				case (execute_state[199-:3])
					3'b000: begin
						x_cla_b = execute_state[132-:32];
						x_cla_cin = 1'b0;
						x_alu_result = x_cla_sum;
					end
					3'b010: x_alu_result = (x_rs1_signed < $signed(execute_state[132-:32]) ? 32'd1 : 32'd0);
					3'b011: x_alu_result = (x_rs1_data < execute_state[132-:32] ? 32'd1 : 32'd0);
					3'b100: x_alu_result = x_rs1_data ^ execute_state[132-:32];
					3'b110: x_alu_result = x_rs1_data | execute_state[132-:32];
					3'b111: x_alu_result = x_rs1_data & execute_state[132-:32];
					3'b001: x_alu_result = x_rs1_data << execute_state[4-:5];
					3'b101:
						if (execute_state[206-:7] == 7'b0100000)
							x_alu_result = $signed(x_rs1_data) >>> execute_state[4-:5];
						else
							x_alu_result = x_rs1_data >> execute_state[4-:5];
					default: x_we = 1'b0;
				endcase
			end
			OpcodeRegReg:
				if ((execute_state[206-:7] == 7'd0) || (execute_state[206-:7] == 7'b0100000)) begin
					x_we = 1'b1;
					case (execute_state[199-:3])
						3'b000:
							if (execute_state[206-:7] == 7'b0100000) begin
								x_cla_b = ~x_rs2_data;
								x_cla_cin = 1'b1;
								x_alu_result = x_cla_sum;
							end
							else begin
								x_cla_b = x_rs2_data;
								x_cla_cin = 1'b0;
								x_alu_result = x_cla_sum;
							end
						3'b001: x_alu_result = x_rs1_data << x_rs2_data[4:0];
						3'b010: x_alu_result = (x_rs1_signed < x_rs2_signed ? 32'd1 : 32'd0);
						3'b011: x_alu_result = (x_rs1_data < x_rs2_data ? 32'd1 : 32'd0);
						3'b100: x_alu_result = x_rs1_data ^ x_rs2_data;
						3'b101:
							if (execute_state[206-:7] == 7'b0100000)
								x_alu_result = $signed(x_rs1_data) >>> x_rs2_data[4:0];
							else
								x_alu_result = x_rs1_data >> x_rs2_data[4:0];
						3'b110: x_alu_result = x_rs1_data | x_rs2_data;
						3'b111: x_alu_result = x_rs1_data & x_rs2_data;
						default: x_we = 1'b0;
					endcase
				end
				else if (execute_state[206-:7] == 7'd1) begin
					x_we = 1'b1;
					case (execute_state[199-:3])
						3'b000: x_alu_result = x_rs1_data * x_rs2_data;
						3'b001: begin
							x_mul_full = {{32 {x_rs1_data[31]}}, x_rs1_data} * {{32 {x_rs2_data[31]}}, x_rs2_data};
							x_alu_result = x_mul_full[63:32];
						end
						3'b010: begin
							x_mul_full = {{32 {x_rs1_data[31]}}, x_rs1_data} * {32'd0, x_rs2_data};
							x_alu_result = x_mul_full[63:32];
						end
						3'b011: begin
							x_mul_full = {32'd0, x_rs1_data} * {32'd0, x_rs2_data};
							x_alu_result = x_mul_full[63:32];
						end
						3'b100, 3'b101, 3'b110, 3'b111: x_alu_result = div_final;
						default: x_we = 1'b0;
					endcase
				end
			OpcodeBranch: begin
				x_we = 1'b0;
				case (execute_state[199-:3])
					3'b000: x_branch_taken = x_rs1_data == x_rs2_data;
					3'b001: x_branch_taken = x_rs1_data != x_rs2_data;
					3'b100: x_branch_taken = x_rs1_signed < x_rs2_signed;
					3'b101: x_branch_taken = x_rs1_signed >= x_rs2_signed;
					3'b110: x_branch_taken = x_rs1_data < x_rs2_data;
					3'b111: x_branch_taken = x_rs1_data >= x_rs2_data;
					default: x_branch_taken = 1'b0;
				endcase
				x_branch_target = execute_state[324-:32] + execute_state[68-:32];
			end
			OpcodeJal: begin
				x_alu_result = execute_state[324-:32] + 4;
				x_branch_target = execute_state[324-:32] + execute_state[36-:32];
				x_branch_taken = 1'b1;
				x_we = 1'b1;
			end
			OpcodeJalr: begin
				x_alu_result = execute_state[324-:32] + 4;
				x_branch_target = (x_rs1_data + execute_state[132-:32]) & 32'hfffffffe;
				x_branch_taken = 1'b1;
				x_we = 1'b1;
			end
			OpcodeLoad: begin
				x_cla_b = execute_state[132-:32];
				x_cla_cin = 1'b0;
				x_alu_result = x_cla_sum;
				x_we = 1'b1;
			end
			OpcodeStore: begin
				x_cla_b = execute_state[100-:32];
				x_cla_cin = 1'b0;
				x_alu_result = x_cla_sum;
				x_we = 1'b0;
			end
			OpcodeEnviron: x_we = 1'b0;
			OpcodeMiscMem: x_we = 1'b0;
			default: x_we = 1'b0;
		endcase
	end
	always @(posedge clk)
		if (rst) begin
			f_pc_current <= 32'd0;
			f_cycle_status <= 32'd1;
		end
		else if (x_flush) begin
			f_pc_current <= x_branch_target;
			f_cycle_status <= 32'd1;
		end
		else if (d_load_use_stall) begin
			f_pc_current <= f_pc_current;
			f_cycle_status <= 32'd1;
		end
		else if (x_div_stall_upstream) begin
			f_pc_current <= f_pc_current;
			f_cycle_status <= 32'd1;
		end
		else begin
			f_pc_current <= f_pc_current + 4;
			f_cycle_status <= 32'd1;
		end
	reg [180:0] memory_state;
	function automatic [4:0] sv2v_cast_5;
		input reg [4:0] inp;
		sv2v_cast_5 = inp;
	endfunction
	function automatic [6:0] sv2v_cast_7;
		input reg [6:0] inp;
		sv2v_cast_7 = inp;
	endfunction
	function automatic [2:0] sv2v_cast_3;
		input reg [2:0] inp;
		sv2v_cast_3 = inp;
	endfunction
	always @(posedge clk)
		if (rst)
			memory_state <= 181'h0000000000000000000000008000000000000000000000;
		else if (x_div_stall)
			memory_state <= 181'h0000000000000000000000004000000000000000000000;
		else
			memory_state <= {sv2v_cast_32(execute_state[324-:32]), sv2v_cast_32(execute_state[292-:32]), sv2v_cast_32(execute_state[260-:32]), sv2v_cast_5(execute_state[218-:5]), sv2v_cast_5(execute_state[223-:5]), sv2v_cast_7(execute_state[213-:7]), sv2v_cast_3(execute_state[199-:3]), x_alu_result, x_rs2_data, x_we};
	wire [255:0] m_disasm;
	Disasm #(.PREFIX("M")) disasm_3memory(
		.insn(memory_state[148-:32]),
		.disasm(m_disasm)
	);
	assign m_rd = memory_state[84-:5];
	assign m_alu_result = memory_state[64-:32];
	assign m_we = memory_state[0];
	wire [31:0] m_rs2_data_bypassed = ((w_we && (w_rd != 5'd0)) && (w_rd == memory_state[79-:5]) ? w_rd_data : memory_state[32-:32]);
	reg [31:0] m_load_data;
	always @(*) begin
		if (_sv2v_0)
			;
		addr_to_dmem = 32'd0;
		store_data_to_dmem = 32'd0;
		store_we_to_dmem = 4'd0;
		if (memory_state[74-:7] == OpcodeLoad)
			addr_to_dmem = {memory_state[64:35], 2'b00};
		else if (memory_state[74-:7] == OpcodeStore) begin
			addr_to_dmem = {memory_state[64:35], 2'b00};
			case (memory_state[67-:3])
				3'b000:
					case (memory_state[34:33])
						2'b00: begin
							store_data_to_dmem = {24'b000000000000000000000000, m_rs2_data_bypassed[7:0]};
							store_we_to_dmem = 4'b0001;
						end
						2'b01: begin
							store_data_to_dmem = {16'b0000000000000000, m_rs2_data_bypassed[7:0], 8'b00000000};
							store_we_to_dmem = 4'b0010;
						end
						2'b10: begin
							store_data_to_dmem = {8'b00000000, m_rs2_data_bypassed[7:0], 16'b0000000000000000};
							store_we_to_dmem = 4'b0100;
						end
						2'b11: begin
							store_data_to_dmem = {m_rs2_data_bypassed[7:0], 24'b000000000000000000000000};
							store_we_to_dmem = 4'b1000;
						end
						default:
							;
					endcase
				3'b001:
					case (memory_state[34:33])
						2'b00: begin
							store_data_to_dmem = {16'b0000000000000000, m_rs2_data_bypassed[15:0]};
							store_we_to_dmem = 4'b0011;
						end
						2'b10: begin
							store_data_to_dmem = {m_rs2_data_bypassed[15:0], 16'b0000000000000000};
							store_we_to_dmem = 4'b1100;
						end
						default:
							;
					endcase
				3'b010: begin
					store_data_to_dmem = m_rs2_data_bypassed;
					store_we_to_dmem = 4'b1111;
				end
				default:
					;
			endcase
		end
	end
	always @(*) begin
		if (_sv2v_0)
			;
		m_load_data = 32'd0;
		if (memory_state[74-:7] == OpcodeLoad)
			case (memory_state[67-:3])
				3'b000:
					case (memory_state[34:33])
						2'b00: m_load_data = {{24 {load_data_from_dmem[7]}}, load_data_from_dmem[7:0]};
						2'b01: m_load_data = {{24 {load_data_from_dmem[15]}}, load_data_from_dmem[15:8]};
						2'b10: m_load_data = {{24 {load_data_from_dmem[23]}}, load_data_from_dmem[23:16]};
						2'b11: m_load_data = {{24 {load_data_from_dmem[31]}}, load_data_from_dmem[31:24]};
						default: m_load_data = 32'd0;
					endcase
				3'b001:
					case (memory_state[34:33])
						2'b00: m_load_data = {{16 {load_data_from_dmem[15]}}, load_data_from_dmem[15:0]};
						2'b10: m_load_data = {{16 {load_data_from_dmem[31]}}, load_data_from_dmem[31:16]};
						default: m_load_data = 32'd0;
					endcase
				3'b010: m_load_data = load_data_from_dmem;
				3'b100:
					case (memory_state[34:33])
						2'b00: m_load_data = {24'b000000000000000000000000, load_data_from_dmem[7:0]};
						2'b01: m_load_data = {24'b000000000000000000000000, load_data_from_dmem[15:8]};
						2'b10: m_load_data = {24'b000000000000000000000000, load_data_from_dmem[23:16]};
						2'b11: m_load_data = {24'b000000000000000000000000, load_data_from_dmem[31:24]};
						default: m_load_data = 32'd0;
					endcase
				3'b101:
					case (memory_state[34:33])
						2'b00: m_load_data = {16'b0000000000000000, load_data_from_dmem[15:0]};
						2'b10: m_load_data = {16'b0000000000000000, load_data_from_dmem[31:16]};
						default: m_load_data = 32'd0;
					endcase
				default: m_load_data = 32'd0;
			endcase
	end
	reg [140:0] writeback_state;
	always @(posedge clk)
		if (rst)
			writeback_state <= 141'h000000000000000000000000800000000000;
		else
			writeback_state <= {sv2v_cast_32(memory_state[180-:32]), sv2v_cast_32(memory_state[148-:32]), sv2v_cast_32(memory_state[116-:32]), sv2v_cast_5(memory_state[84-:5]), sv2v_cast_7(memory_state[74-:7]), sv2v_cast_32((memory_state[74-:7] == OpcodeLoad ? m_load_data : memory_state[64-:32])), memory_state[0]};
	wire [255:0] w_disasm;
	Disasm #(.PREFIX("W")) disasm_4writeback(
		.insn(writeback_state[108-:32]),
		.disasm(w_disasm)
	);
	assign w_rd = writeback_state[44-:5];
	assign w_rd_data = writeback_state[32-:32];
	assign w_we = writeback_state[0];
	assign halt = ((writeback_state[39-:7] == OpcodeEnviron) && (writeback_state[108:84] == 25'd0)) && (writeback_state[76-:32] == 32'd1);
	assign trace_completed_pc = writeback_state[140-:32];
	assign trace_completed_insn = writeback_state[108-:32];
	assign trace_completed_cycle_status = writeback_state[76-:32];
	initial _sv2v_0 = 0;
endmodule
module MemorySingleCycle (
	rst,
	clk,
	pc_to_imem,
	insn_from_imem,
	addr_to_dmem,
	load_data_from_dmem,
	store_data_to_dmem,
	store_we_to_dmem
);
	reg _sv2v_0;
	parameter signed [31:0] NUM_WORDS = 512;
	input wire rst;
	input wire clk;
	input wire [31:0] pc_to_imem;
	output reg [31:0] insn_from_imem;
	input wire [31:0] addr_to_dmem;
	output reg [31:0] load_data_from_dmem;
	input wire [31:0] store_data_to_dmem;
	input wire [3:0] store_we_to_dmem;
	reg [31:0] mem_array [0:NUM_WORDS - 1];
	initial $readmemh("mem_initial_contents.hex", mem_array);
	always @(*)
		if (_sv2v_0)
			;
	localparam signed [31:0] AddrMsb = $clog2(NUM_WORDS) + 1;
	localparam signed [31:0] AddrLsb = 2;
	always @(negedge clk)
		if (rst)
			;
		else
			insn_from_imem <= mem_array[{pc_to_imem[AddrMsb:AddrLsb]}];
	always @(negedge clk)
		if (rst)
			;
		else begin
			if (store_we_to_dmem[0])
				mem_array[addr_to_dmem[AddrMsb:AddrLsb]][7:0] <= store_data_to_dmem[7:0];
			if (store_we_to_dmem[1])
				mem_array[addr_to_dmem[AddrMsb:AddrLsb]][15:8] <= store_data_to_dmem[15:8];
			if (store_we_to_dmem[2])
				mem_array[addr_to_dmem[AddrMsb:AddrLsb]][23:16] <= store_data_to_dmem[23:16];
			if (store_we_to_dmem[3])
				mem_array[addr_to_dmem[AddrMsb:AddrLsb]][31:24] <= store_data_to_dmem[31:24];
			load_data_from_dmem <= mem_array[{addr_to_dmem[AddrMsb:AddrLsb]}];
		end
	initial _sv2v_0 = 0;
endmodule
module SystemDemo (
	external_clk_25MHz,
	btn,
	led,
	gp
);
	input wire external_clk_25MHz;
	input wire [6:0] btn;
	output wire [7:0] led;
	output wire [27:0] gp;
	localparam signed [31:0] MmapGpioStart = 32'hff001000;
	localparam signed [31:0] LastGpioIndex = 27;
	localparam signed [31:0] MmapGpioEnd = MmapGpioStart + LastGpioIndex;
	localparam signed [31:0] MmapLeds = 32'hff002000;
	localparam signed [31:0] MmapButtons = 32'hff003000;
	wire clk_proc;
	wire clk_locked;
	MyClockGen clock_gen(
		.input_clk_25MHz(external_clk_25MHz),
		.clk_proc(clk_proc),
		.locked(clk_locked)
	);
	wire [31:0] pc_to_imem;
	wire [31:0] insn_from_imem;
	wire [31:0] mem_data_addr;
	wire [31:0] mem_data_loaded_value;
	wire [31:0] mem_data_to_write;
	wire [3:0] mem_data_we;
	wire [31:0] trace_writeback_pc;
	wire [31:0] trace_writeback_insn;
	wire [31:0] trace_writeback_cycle_status;
	wire is_gpio_write = (mem_data_we != 0) && ((MmapGpioStart <= mem_data_addr) && (mem_data_addr <= MmapGpioEnd));
	wire is_led_write = (mem_data_we != 0) && (mem_data_addr == MmapLeds);
	wire is_button_read = mem_data_addr == MmapButtons;
	reg [7:0] led_reg;
	reg [27:0] gpio_reg;
	always @(posedge clk_proc)
		if (!clk_locked) begin
			led_reg <= 0;
			gpio_reg <= 0;
		end
		else if (is_gpio_write)
			gpio_reg[mem_data_addr - MmapGpioStart] <= mem_data_to_write[0];
		else if (is_led_write)
			led_reg <= mem_data_to_write[7:0];
	assign gp = gpio_reg;
	assign led = led_reg;
	MemorySingleCycle #(.NUM_WORDS(1024)) memory(
		.rst(!clk_locked),
		.clk(clk_proc),
		.pc_to_imem(pc_to_imem),
		.insn_from_imem(insn_from_imem),
		.addr_to_dmem(mem_data_addr),
		.load_data_from_dmem(mem_data_loaded_value),
		.store_data_to_dmem(mem_data_to_write),
		.store_we_to_dmem((is_gpio_write ? 4'd0 : mem_data_we))
	);
	DatapathPipelined datapath(
		.clk(clk_proc),
		.rst(!clk_locked),
		.pc_to_imem(pc_to_imem),
		.insn_from_imem(insn_from_imem),
		.addr_to_dmem(mem_data_addr),
		.store_data_to_dmem(mem_data_to_write),
		.store_we_to_dmem(mem_data_we),
		.load_data_from_dmem(mem_data_loaded_value),
		.halt(),
		.trace_completed_pc(trace_writeback_pc),
		.trace_completed_insn(trace_writeback_insn),
		.trace_completed_cycle_status(trace_writeback_cycle_status)
	);
endmodule