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
module SystemDemo (
	external_clk_25MHz,
	btn,
	led
);
	reg _sv2v_0;
	input wire external_clk_25MHz;
	input wire [6:0] btn;
	output reg [7:0] led;
	reg [31:0] ab;
	wire [15:0] a;
	wire [15:0] b;
	wire [31:0] expected_sum;
	wire [31:0] actual_sum;
	wire rst = ~btn[0];
	reg error;
	wire [2:0] chunk = ab[31:29];
	reg [7:0] completed;
	CarryLookaheadAdder cla_inst(
		.a(a),
		.b(b),
		.cin(1'b0),
		.sum(actual_sum)
	);
	always @(*) begin
		if (_sv2v_0)
			;
		a = ab[31:16];
		b = ab[15:0];
		expected_sum = a + b;
	end
	always @(posedge external_clk_25MHz)
		if (rst) begin
			ab <= 32'd0;
			error <= 1'b0;
			completed <= 8'd0;
		end
		else if (!error) begin
			if (actual_sum != expected_sum)
				error <= 1'b1;
			else begin
				ab <= ab + 1;
				if (ab[28:0] == 29'h1fffffff)
					completed[chunk] <= 1'b1;
			end
		end
	reg [23:0] blink;
	always @(posedge external_clk_25MHz)
		if (rst)
			blink <= 0;
		else
			blink <= blink + 1;
	always @(*) begin
		if (_sv2v_0)
			;
		if (error)
			led = completed;
		else
			led = completed | ({7'd0, blink[23]} << chunk);
	end
	initial _sv2v_0 = 0;
endmodule