module MyClockGen (
	input_clk_25MHz,
	clk_proc,
	clk_mem,
	locked
);
	input input_clk_25MHz;
	output wire clk_proc;
	output wire clk_mem;
	output wire locked;
	wire clkfb;
	(* FREQUENCY_PIN_CLKI = "25" *) (* FREQUENCY_PIN_CLKOP = "3.57143" *) (* FREQUENCY_PIN_CLKOS = "3.50932" *) (* ICP_CURRENT = "12" *) (* LPF_RESISTOR = "8" *) (* MFG_ENABLE_FILTEROPAMP = "1" *) (* MFG_GMCREF_SEL = "2" *) EHXPLLL #(
		.PLLRST_ENA("DISABLED"),
		.INTFB_WAKE("DISABLED"),
		.STDBY_ENABLE("DISABLED"),
		.DPHASE_SOURCE("DISABLED"),
		.OUTDIVIDER_MUXA("DIVA"),
		.OUTDIVIDER_MUXB("DIVB"),
		.OUTDIVIDER_MUXC("DIVC"),
		.OUTDIVIDER_MUXD("DIVD"),
		.CLKI_DIV(7),
		.CLKOP_ENABLE("ENABLED"),
		.CLKOP_DIV(113),
		.CLKOP_CPHASE(56),
		.CLKOP_FPHASE(0),
		.CLKOS_ENABLE("ENABLED"),
		.CLKOS_DIV(115),
		.CLKOS_CPHASE(84),
		.CLKOS_FPHASE(5),
		.FEEDBK_PATH("INT_OP"),
		.CLKFB_DIV(1)
	) pll_i(
		.RST(1'b0),
		.STDBY(1'b0),
		.CLKI(input_clk_25MHz),
		.CLKOP(clk_proc),
		.CLKOS(clk_mem),
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
module DividerUnsigned (
	i_dividend,
	i_divisor,
	o_remainder,
	o_quotient
);
	input wire [31:0] i_dividend;
	input wire [31:0] i_divisor;
	output wire [31:0] o_remainder;
	output wire [31:0] o_quotient;
	wire [31:0] remainder [0:32];
	wire [31:0] quotient [0:32];
	wire [31:0] dividend [0:32];
	assign remainder[0] = 32'd0;
	assign quotient[0] = 32'd0;
	assign dividend[0] = i_dividend;
	genvar _gv_i_1;
	generate
		for (_gv_i_1 = 0; _gv_i_1 < 32; _gv_i_1 = _gv_i_1 + 1) begin : div_one_iter_loop
			localparam i = _gv_i_1;
			DividerOneIter div_one_iter(
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
	assign o_remainder = remainder[32];
	assign o_quotient = quotient[32];
endmodule
module DividerOneIter (
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
			reg signed [31:0] i;
			for (i = 0; i < NumRegs; i = i + 1)
				regs[i] <= 32'd0;
		end
		else if (we && (rd != 5'd0))
			regs[rd] <= rd_data;
endmodule
module DatapathSingleCycle (
	clk,
	rst,
	halt,
	pc_to_imem,
	insn_from_imem,
	addr_to_dmem,
	load_data_from_dmem,
	store_data_to_dmem,
	store_we_to_dmem,
	trace_completed_pc,
	trace_completed_insn,
	trace_completed_cycle_status
);
	reg _sv2v_0;
	input wire clk;
	input wire rst;
	output reg halt;
	output wire [31:0] pc_to_imem;
	input wire [31:0] insn_from_imem;
	output reg [31:0] addr_to_dmem;
	input wire [31:0] load_data_from_dmem;
	output reg [31:0] store_data_to_dmem;
	output reg [3:0] store_we_to_dmem;
	output wire [31:0] trace_completed_pc;
	output wire [31:0] trace_completed_insn;
	output wire [31:0] trace_completed_cycle_status;
	wire [6:0] insn_funct7;
	wire [4:0] insn_rs2;
	wire [4:0] insn_rs1;
	wire [2:0] insn_funct3;
	wire [4:0] insn_rd;
	wire [6:0] insn_opcode;
	assign {insn_funct7, insn_rs2, insn_rs1, insn_funct3, insn_rd, insn_opcode} = insn_from_imem;
	wire [11:0] imm_i;
	assign imm_i = insn_from_imem[31:20];
	wire [4:0] imm_shamt = insn_from_imem[24:20];
	wire [11:0] imm_s;
	assign imm_s[11:5] = insn_funct7;
	assign imm_s[4:0] = insn_rd;
	wire [12:0] imm_b;
	assign {imm_b[12], imm_b[10:5]} = insn_funct7;
	assign {imm_b[4:1], imm_b[11]} = insn_rd;
	assign imm_b[0] = 1'b0;
	wire [20:0] imm_j;
	assign {imm_j[20], imm_j[10:1], imm_j[11], imm_j[19:12], imm_j[0]} = {insn_from_imem[31:12], 1'b0};
	wire [31:0] imm_i_sext = {{20 {imm_i[11]}}, imm_i[11:0]};
	wire [31:0] imm_s_sext = {{20 {imm_s[11]}}, imm_s[11:0]};
	wire [31:0] imm_b_sext = {{19 {imm_b[12]}}, imm_b[12:0]};
	wire [31:0] imm_j_sext = {{11 {imm_j[20]}}, imm_j[20:0]};
	localparam [6:0] OpLoad = 7'b0000011;
	localparam [6:0] OpStore = 7'b0100011;
	localparam [6:0] OpBranch = 7'b1100011;
	localparam [6:0] OpJalr = 7'b1100111;
	localparam [6:0] OpMiscMem = 7'b0001111;
	localparam [6:0] OpJal = 7'b1101111;
	localparam [6:0] OpRegImm = 7'b0010011;
	localparam [6:0] OpRegReg = 7'b0110011;
	localparam [6:0] OpEnviron = 7'b1110011;
	localparam [6:0] OpAuipc = 7'b0010111;
	localparam [6:0] OpLui = 7'b0110111;
	wire insn_lui = insn_opcode == OpLui;
	wire insn_auipc = insn_opcode == OpAuipc;
	wire insn_jal = insn_opcode == OpJal;
	wire insn_jalr = insn_opcode == OpJalr;
	wire insn_beq = (insn_opcode == OpBranch) && (insn_from_imem[14:12] == 3'b000);
	wire insn_bne = (insn_opcode == OpBranch) && (insn_from_imem[14:12] == 3'b001);
	wire insn_blt = (insn_opcode == OpBranch) && (insn_from_imem[14:12] == 3'b100);
	wire insn_bge = (insn_opcode == OpBranch) && (insn_from_imem[14:12] == 3'b101);
	wire insn_bltu = (insn_opcode == OpBranch) && (insn_from_imem[14:12] == 3'b110);
	wire insn_bgeu = (insn_opcode == OpBranch) && (insn_from_imem[14:12] == 3'b111);
	wire insn_lb = (insn_opcode == OpLoad) && (insn_from_imem[14:12] == 3'b000);
	wire insn_lh = (insn_opcode == OpLoad) && (insn_from_imem[14:12] == 3'b001);
	wire insn_lw = (insn_opcode == OpLoad) && (insn_from_imem[14:12] == 3'b010);
	wire insn_lbu = (insn_opcode == OpLoad) && (insn_from_imem[14:12] == 3'b100);
	wire insn_lhu = (insn_opcode == OpLoad) && (insn_from_imem[14:12] == 3'b101);
	wire insn_sb = (insn_opcode == OpStore) && (insn_from_imem[14:12] == 3'b000);
	wire insn_sh = (insn_opcode == OpStore) && (insn_from_imem[14:12] == 3'b001);
	wire insn_sw = (insn_opcode == OpStore) && (insn_from_imem[14:12] == 3'b010);
	wire insn_addi = (insn_opcode == OpRegImm) && (insn_from_imem[14:12] == 3'b000);
	wire insn_slti = (insn_opcode == OpRegImm) && (insn_from_imem[14:12] == 3'b010);
	wire insn_sltiu = (insn_opcode == OpRegImm) && (insn_from_imem[14:12] == 3'b011);
	wire insn_xori = (insn_opcode == OpRegImm) && (insn_from_imem[14:12] == 3'b100);
	wire insn_ori = (insn_opcode == OpRegImm) && (insn_from_imem[14:12] == 3'b110);
	wire insn_andi = (insn_opcode == OpRegImm) && (insn_from_imem[14:12] == 3'b111);
	wire insn_slli = ((insn_opcode == OpRegImm) && (insn_from_imem[14:12] == 3'b001)) && (insn_from_imem[31:25] == 7'd0);
	wire insn_srli = ((insn_opcode == OpRegImm) && (insn_from_imem[14:12] == 3'b101)) && (insn_from_imem[31:25] == 7'd0);
	wire insn_srai = ((insn_opcode == OpRegImm) && (insn_from_imem[14:12] == 3'b101)) && (insn_from_imem[31:25] == 7'b0100000);
	wire insn_add = ((insn_opcode == OpRegReg) && (insn_from_imem[14:12] == 3'b000)) && (insn_from_imem[31:25] == 7'd0);
	wire insn_sub = ((insn_opcode == OpRegReg) && (insn_from_imem[14:12] == 3'b000)) && (insn_from_imem[31:25] == 7'b0100000);
	wire insn_sll = ((insn_opcode == OpRegReg) && (insn_from_imem[14:12] == 3'b001)) && (insn_from_imem[31:25] == 7'd0);
	wire insn_slt = ((insn_opcode == OpRegReg) && (insn_from_imem[14:12] == 3'b010)) && (insn_from_imem[31:25] == 7'd0);
	wire insn_sltu = ((insn_opcode == OpRegReg) && (insn_from_imem[14:12] == 3'b011)) && (insn_from_imem[31:25] == 7'd0);
	wire insn_xor = ((insn_opcode == OpRegReg) && (insn_from_imem[14:12] == 3'b100)) && (insn_from_imem[31:25] == 7'd0);
	wire insn_srl = ((insn_opcode == OpRegReg) && (insn_from_imem[14:12] == 3'b101)) && (insn_from_imem[31:25] == 7'd0);
	wire insn_sra = ((insn_opcode == OpRegReg) && (insn_from_imem[14:12] == 3'b101)) && (insn_from_imem[31:25] == 7'b0100000);
	wire insn_or = ((insn_opcode == OpRegReg) && (insn_from_imem[14:12] == 3'b110)) && (insn_from_imem[31:25] == 7'd0);
	wire insn_and = ((insn_opcode == OpRegReg) && (insn_from_imem[14:12] == 3'b111)) && (insn_from_imem[31:25] == 7'd0);
	wire insn_mul = ((insn_opcode == OpRegReg) && (insn_from_imem[31:25] == 7'd1)) && (insn_from_imem[14:12] == 3'b000);
	wire insn_mulh = ((insn_opcode == OpRegReg) && (insn_from_imem[31:25] == 7'd1)) && (insn_from_imem[14:12] == 3'b001);
	wire insn_mulhsu = ((insn_opcode == OpRegReg) && (insn_from_imem[31:25] == 7'd1)) && (insn_from_imem[14:12] == 3'b010);
	wire insn_mulhu = ((insn_opcode == OpRegReg) && (insn_from_imem[31:25] == 7'd1)) && (insn_from_imem[14:12] == 3'b011);
	wire insn_div = ((insn_opcode == OpRegReg) && (insn_from_imem[31:25] == 7'd1)) && (insn_from_imem[14:12] == 3'b100);
	wire insn_divu = ((insn_opcode == OpRegReg) && (insn_from_imem[31:25] == 7'd1)) && (insn_from_imem[14:12] == 3'b101);
	wire insn_rem = ((insn_opcode == OpRegReg) && (insn_from_imem[31:25] == 7'd1)) && (insn_from_imem[14:12] == 3'b110);
	wire insn_remu = ((insn_opcode == OpRegReg) && (insn_from_imem[31:25] == 7'd1)) && (insn_from_imem[14:12] == 3'b111);
	wire insn_ecall = (insn_opcode == OpEnviron) && (insn_from_imem[31:7] == 25'd0);
	wire insn_fence = insn_opcode == OpMiscMem;
	reg [31:0] pcNext;
	reg [31:0] pcCurrent;
	always @(posedge clk)
		if (rst)
			pcCurrent <= 32'd0;
		else
			pcCurrent <= pcNext;
	assign pc_to_imem = pcCurrent;
	reg [31:0] cycles_current;
	reg [31:0] num_insns_current;
	always @(posedge clk)
		if (rst) begin
			cycles_current <= 0;
			num_insns_current <= 0;
		end
		else begin
			cycles_current <= cycles_current + 1;
			if (!rst)
				num_insns_current <= num_insns_current + 1;
		end
	wire [31:0] rs1_data;
	wire [31:0] rs2_data;
	reg [31:0] rd_data;
	reg we;
	RegFile rf(
		.clk(clk),
		.rst(rst),
		.we(we),
		.rd(insn_rd),
		.rd_data(rd_data),
		.rs1(insn_rs1),
		.rs2(insn_rs2),
		.rs1_data(rs1_data),
		.rs2_data(rs2_data)
	);
	reg illegal_insn;
	reg [31:0] alu_result;
	reg [31:0] alu_op1;
	reg [31:0] alu_op2;
	wire [31:0] cla_sum;
	reg cla_cin;
	reg [31:0] cla_b;
	CarryLookaheadAdder cla(
		.a(alu_op1),
		.b(cla_b),
		.cin(cla_cin),
		.sum(cla_sum)
	);
	reg branch_taken;
	wire signed [31:0] rs1_signed = $signed(rs1_data);
	wire signed [31:0] rs2_signed = $signed(rs2_data);
	reg [63:0] product;
	reg [31:0] div_dividend;
	reg [31:0] div_divisor;
	wire [31:0] div_quotient;
	wire [31:0] div_remainder;
	DividerUnsigned divider(
		.i_dividend(div_dividend),
		.i_divisor(div_divisor),
		.o_quotient(div_quotient),
		.o_remainder(div_remainder)
	);
	wire [31:0] addr_load = rs1_data + imm_i_sext;
	wire [31:0] addr_store = rs1_data + imm_s_sext;
	always @(*) begin
		if (_sv2v_0)
			;
		illegal_insn = 1'b0;
		we = 1'b0;
		rd_data = 32'd0;
		alu_result = 32'd0;
		alu_op1 = rs1_data;
		alu_op2 = rs2_data;
		cla_b = rs2_data;
		cla_cin = 1'b0;
		branch_taken = 1'b0;
		halt = 1'b0;
		pcNext = pcCurrent + 4;
		product = 64'd0;
		div_dividend = 32'd0;
		div_divisor = 32'd0;
		addr_to_dmem = 32'd0;
		store_data_to_dmem = 32'd0;
		store_we_to_dmem = 4'd0;
		case (insn_opcode)
			OpLui: begin
				rd_data = {insn_from_imem[31:12], 12'd0};
				we = 1'b1;
			end
			OpAuipc: begin
				rd_data = pcCurrent + {insn_from_imem[31:12], 12'd0};
				we = 1'b1;
			end
			OpRegImm: begin
				we = 1'b1;
				alu_op1 = rs1_data;
				alu_op2 = imm_i_sext;
				if (insn_addi) begin
					cla_b = imm_i_sext;
					cla_cin = 1'b0;
					rd_data = cla_sum;
				end
				else if (insn_slti)
					rd_data = (rs1_signed < $signed(imm_i_sext) ? 32'd1 : 32'd0);
				else if (insn_sltiu)
					rd_data = (rs1_data < imm_i_sext ? 32'd1 : 32'd0);
				else if (insn_xori)
					rd_data = rs1_data ^ imm_i_sext;
				else if (insn_ori)
					rd_data = rs1_data | imm_i_sext;
				else if (insn_andi)
					rd_data = rs1_data & imm_i_sext;
				else if (insn_slli)
					rd_data = rs1_data << imm_shamt;
				else if (insn_srli)
					rd_data = rs1_data >> imm_shamt;
				else if (insn_srai)
					rd_data = $signed(rs1_data) >>> imm_shamt;
				else begin
					illegal_insn = 1'b1;
					we = 1'b0;
				end
			end
			OpRegReg: begin
				we = 1'b1;
				alu_op1 = rs1_data;
				alu_op2 = rs2_data;
				if (insn_add) begin
					cla_b = rs2_data;
					cla_cin = 1'b0;
					rd_data = cla_sum;
				end
				else if (insn_sub) begin
					cla_b = ~rs2_data;
					cla_cin = 1'b1;
					rd_data = cla_sum;
				end
				else if (insn_sll)
					rd_data = rs1_data << rs2_data[4:0];
				else if (insn_slt)
					rd_data = (rs1_signed < rs2_signed ? 32'd1 : 32'd0);
				else if (insn_sltu)
					rd_data = (rs1_data < rs2_data ? 32'd1 : 32'd0);
				else if (insn_xor)
					rd_data = rs1_data ^ rs2_data;
				else if (insn_srl)
					rd_data = rs1_data >> rs2_data[4:0];
				else if (insn_sra)
					rd_data = $signed(rs1_data) >>> rs2_data[4:0];
				else if (insn_or)
					rd_data = rs1_data | rs2_data;
				else if (insn_and)
					rd_data = rs1_data & rs2_data;
				else if (insn_mul)
					rd_data = rs1_data * rs2_data;
				else if (insn_mulh) begin
					product = {{32 {rs1_data[31]}}, rs1_data} * {{32 {rs2_data[31]}}, rs2_data};
					rd_data = product[63:32];
				end
				else if (insn_mulhsu) begin
					product = {{32 {rs1_data[31]}}, rs1_data} * {32'd0, rs2_data};
					rd_data = product[63:32];
				end
				else if (insn_mulhu) begin
					product = {32'd0, rs1_data} * {32'd0, rs2_data};
					rd_data = product[63:32];
				end
				else if (insn_div) begin
					if (rs2_data == 32'd0)
						rd_data = 32'hffffffff;
					else if ((rs1_data == 32'h80000000) && (rs2_data == 32'hffffffff))
						rd_data = 32'h80000000;
					else begin
						div_dividend = (rs1_data[31] ? ~rs1_data + 1 : rs1_data);
						div_divisor = (rs2_data[31] ? ~rs2_data + 1 : rs2_data);
						rd_data = (rs1_data[31] ^ rs2_data[31] ? ~div_quotient + 1 : div_quotient);
					end
				end
				else if (insn_divu) begin
					div_dividend = rs1_data;
					div_divisor = rs2_data;
					rd_data = div_quotient;
				end
				else if (insn_rem) begin
					div_dividend = (rs1_data[31] ? ~rs1_data + 1 : rs1_data);
					div_divisor = (rs2_data[31] ? ~rs2_data + 1 : rs2_data);
					rd_data = (rs1_data[31] ? ~div_remainder + 1 : div_remainder);
				end
				else if (insn_remu) begin
					div_dividend = rs1_data;
					div_divisor = rs2_data;
					rd_data = (rs2_data == 0 ? rs1_data : div_remainder);
				end
				else begin
					illegal_insn = 1'b1;
					we = 1'b0;
				end
			end
			OpBranch: begin
				we = 1'b0;
				if (insn_beq)
					branch_taken = rs1_data == rs2_data;
				else if (insn_bne)
					branch_taken = rs1_data != rs2_data;
				else if (insn_blt)
					branch_taken = rs1_signed < rs2_signed;
				else if (insn_bge)
					branch_taken = rs1_signed >= rs2_signed;
				else if (insn_bltu)
					branch_taken = rs1_data < rs2_data;
				else if (insn_bgeu)
					branch_taken = rs1_data >= rs2_data;
				else
					illegal_insn = 1'b1;
				if (branch_taken)
					pcNext = pcCurrent + imm_b_sext;
			end
			OpJal: begin
				rd_data = pcCurrent + 4;
				pcNext = pcCurrent + imm_j_sext;
				we = 1'b1;
			end
			OpJalr: begin
				rd_data = pcCurrent + 4;
				pcNext = (rs1_data + imm_i_sext) & 32'hfffffffe;
				we = 1'b1;
			end
			OpLoad: begin
				addr_to_dmem = {addr_load[31:2], 2'b00};
				we = 1'b1;
				case (insn_funct3)
					3'b000:
						case (addr_load[1:0])
							2'b00: rd_data = {{24 {load_data_from_dmem[7]}}, load_data_from_dmem[7:0]};
							2'b01: rd_data = {{24 {load_data_from_dmem[15]}}, load_data_from_dmem[15:8]};
							2'b10: rd_data = {{24 {load_data_from_dmem[23]}}, load_data_from_dmem[23:16]};
							2'b11: rd_data = {{24 {load_data_from_dmem[31]}}, load_data_from_dmem[31:24]};
						endcase
					3'b001:
						case (addr_load[1:0])
							2'b00: rd_data = {{16 {load_data_from_dmem[15]}}, load_data_from_dmem[15:0]};
							2'b10: rd_data = {{16 {load_data_from_dmem[31]}}, load_data_from_dmem[31:16]};
							default: rd_data = 32'd0;
						endcase
					3'b010: rd_data = load_data_from_dmem;
					3'b100:
						case (addr_load[1:0])
							2'b00: rd_data = {24'b000000000000000000000000, load_data_from_dmem[7:0]};
							2'b01: rd_data = {24'b000000000000000000000000, load_data_from_dmem[15:8]};
							2'b10: rd_data = {24'b000000000000000000000000, load_data_from_dmem[23:16]};
							2'b11: rd_data = {24'b000000000000000000000000, load_data_from_dmem[31:24]};
						endcase
					3'b101:
						case (addr_load[1:0])
							2'b00: rd_data = {16'b0000000000000000, load_data_from_dmem[15:0]};
							2'b10: rd_data = {16'b0000000000000000, load_data_from_dmem[31:16]};
							default: rd_data = 32'd0;
						endcase
					default: illegal_insn = 1'b1;
				endcase
			end
			OpStore: begin
				addr_to_dmem = {addr_store[31:2], 2'b00};
				case (insn_funct3)
					3'b000:
						case (addr_store[1:0])
							2'b00: begin
								store_data_to_dmem = {24'b000000000000000000000000, rs2_data[7:0]};
								store_we_to_dmem = 4'b0001;
							end
							2'b01: begin
								store_data_to_dmem = {16'b0000000000000000, rs2_data[7:0], 8'b00000000};
								store_we_to_dmem = 4'b0010;
							end
							2'b10: begin
								store_data_to_dmem = {8'b00000000, rs2_data[7:0], 16'b0000000000000000};
								store_we_to_dmem = 4'b0100;
							end
							2'b11: begin
								store_data_to_dmem = {rs2_data[7:0], 24'b000000000000000000000000};
								store_we_to_dmem = 4'b1000;
							end
						endcase
					3'b001:
						case (addr_store[1:0])
							2'b00: begin
								store_data_to_dmem = {16'b0000000000000000, rs2_data[15:0]};
								store_we_to_dmem = 4'b0011;
							end
							2'b10: begin
								store_data_to_dmem = {rs2_data[15:0], 16'b0000000000000000};
								store_we_to_dmem = 4'b1100;
							end
							default:
								;
						endcase
					3'b010: begin
						store_data_to_dmem = rs2_data;
						store_we_to_dmem = 4'b1111;
					end
					default: illegal_insn = 1'b1;
				endcase
			end
			OpEnviron:
				if (insn_ecall)
					halt = 1'b1;
				else
					illegal_insn = 1'b1;
			default: illegal_insn = 1'b1;
		endcase
	end
	assign trace_completed_pc = pcCurrent;
	assign trace_completed_insn = insn_from_imem;
	assign trace_completed_cycle_status = 32'd1;
	initial _sv2v_0 = 0;
endmodule
module MemorySingleCycle (
	rst,
	clock_mem,
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
	input wire clock_mem;
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
	always @(posedge clock_mem)
		if (rst)
			;
		else
			insn_from_imem <= mem_array[{pc_to_imem[AddrMsb:AddrLsb]}];
	always @(negedge clock_mem)
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
`default_nettype none
module debouncer (
	i_clk,
	i_in,
	o_debounced,
	o_debug
);
	parameter NIN = 21;
	parameter LGWAIT = 17;
	input wire i_clk;
	input wire [NIN - 1:0] i_in;
	output reg [NIN - 1:0] o_debounced;
	output wire [30:0] o_debug;
	reg different;
	reg ztimer;
	reg [NIN - 1:0] r_in;
	reg [NIN - 1:0] q_in;
	reg [NIN - 1:0] r_last;
	reg [LGWAIT - 1:0] timer;
	initial q_in = 0;
	initial r_in = 0;
	initial different = 0;
	always @(posedge i_clk) q_in <= i_in;
	always @(posedge i_clk) r_in <= q_in;
	always @(posedge i_clk) r_last <= r_in;
	initial ztimer = 1'b1;
	initial timer = 0;
	always @(posedge i_clk)
		if (ztimer && different) begin
			timer <= {LGWAIT {1'b1}};
			ztimer <= 1'b0;
		end
		else if (!ztimer) begin
			timer <= timer - 1'b1;
			ztimer <= timer[LGWAIT - 1:1] == 0;
		end
		else begin
			ztimer <= 1'b1;
			timer <= 0;
		end
	always @(posedge i_clk) different <= (different && !ztimer) || (r_in != o_debounced);
	initial o_debounced = {NIN {1'b0}};
	always @(posedge i_clk)
		if (ztimer)
			o_debounced <= r_last;
	reg trigger;
	initial trigger = 1'b0;
	always @(posedge i_clk) trigger <= (((!ztimer && !different) && !(|i_in)) && (timer[LGWAIT - 1:2] == 0)) && timer[1];
	wire [30:0] debug;
	assign debug[30] = ztimer;
	assign debug[29] = trigger;
	assign debug[28] = 1'b0;
	generate
		if (NIN >= 14) begin : genblk1
			assign debug[27:14] = o_debounced[13:0];
			assign debug[13:0] = r_in[13:0];
		end
		else begin : genblk1
			assign debug[27:14 + NIN] = 0;
			assign debug[(14 + NIN) - 1:14] = o_debounced;
			assign debug[13:NIN] = 0;
			assign debug[NIN - 1:0] = r_in;
		end
	endgenerate
	assign o_debug = debug;
endmodule
module SystemDemo (
	external_clk_25MHz,
	btn,
	led
);
	input wire external_clk_25MHz;
	input wire [6:0] btn;
	output wire [7:0] led;
	localparam signed [31:0] MmapButtons = 32'hff001000;
	localparam signed [31:0] MmapLeds = 32'hff002000;
	wire rst_button_n;
	wire [30:0] ignore;
	wire clk_proc;
	debouncer #(.NIN(1)) db(
		.i_clk(clk_proc),
		.i_in(btn[0]),
		.o_debounced(rst_button_n),
		.o_debug(ignore)
	);
	wire clk_mem;
	wire clk_locked;
	MyClockGen clock_gen(
		.input_clk_25MHz(external_clk_25MHz),
		.clk_proc(clk_proc),
		.clk_mem(clk_mem),
		.locked(clk_locked)
	);
	wire rst = !rst_button_n || !clk_locked;
	wire [31:0] pc_to_imem;
	wire [31:0] insn_from_imem;
	wire [31:0] mem_data_addr;
	wire [31:0] mem_data_loaded_value;
	wire [31:0] mem_data_to_write;
	wire [3:0] mem_data_we;
	reg [7:0] led_state;
	assign led = led_state;
	always @(posedge clk_mem)
		if (rst)
			led_state <= 0;
		else if ((mem_data_addr == MmapLeds) && (mem_data_we[0] == 1))
			led_state <= mem_data_to_write[7:0];
	MemorySingleCycle #(.NUM_WORDS(1024)) memory(
		.rst(rst),
		.clock_mem(clk_mem),
		.pc_to_imem(pc_to_imem),
		.insn_from_imem(insn_from_imem),
		.addr_to_dmem(mem_data_addr),
		.load_data_from_dmem(mem_data_loaded_value),
		.store_data_to_dmem(mem_data_to_write),
		.store_we_to_dmem((mem_data_addr == MmapLeds ? 4'd0 : mem_data_we))
	);
	wire halt;
	DatapathSingleCycle datapath(
		.clk(clk_proc),
		.rst(rst),
		.pc_to_imem(pc_to_imem),
		.insn_from_imem(insn_from_imem),
		.addr_to_dmem(mem_data_addr),
		.store_data_to_dmem(mem_data_to_write),
		.store_we_to_dmem(mem_data_we),
		.load_data_from_dmem((mem_data_addr == MmapButtons ? {25'd0, btn} : mem_data_loaded_value)),
		.halt(halt)
	);
endmodule