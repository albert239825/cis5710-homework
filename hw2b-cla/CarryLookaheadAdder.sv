`timescale 1ns / 1ps

/**
 * @param a first 1-bit input
 * @param b second 1-bit input
 * @param g whether a and b generate a carry
 * @param p whether a and b would propagate an incoming carry
 */
module gp1 (
    input  wire a,
    b,
    output wire g,
    p
);
  assign g = a & b;
  assign p = a | b;
endmodule

/**
 * Computes aggregate generate/propagate signals over a 2-bit window.
 * @param gin incoming generate signals [1:0]
 * @param pin incoming propagate signals [1:0]
 * @param gout group generate
 * @param pout group propagate
 */
module gp2 (
    input wire [1:0] gin,
    pin,
    output wire gout,
    pout
);
  assign gout = gin[1] | (pin[1] & gin[0]);
  assign pout = pin[1] & pin[0];
endmodule

/**
 * Computes aggregate generate/propagate signals over a 4-bit window.
 * @param gin incoming generate signals
 * @param pin incoming propagate signals
 * @param cin the incoming carry
 * @param gout whether these 4 bits internally would generate a carry-out (independent of cin)
 * @param pout whether these 4 bits internally would propagate an incoming carry from cin
 * @param cout the carry outs for the low-order 3 bits
 */
module gp4 (
    input wire [3:0] gin,
    pin,
    input wire cin,
    output wire gout,
    pout,
    output wire [2:0] cout
);

  wire g_low, p_low;
  wire g_high, p_high;

  gp2 gp2_low (
      .gin (gin[1:0]),
      .pin (pin[1:0]),
      .gout(g_low),
      .pout(p_low)
  );

  gp2 gp2_high (
      .gin (gin[3:2]),
      .pin (pin[3:2]),
      .gout(g_high),
      .pout(p_high)
  );

  gp2 gp2_combined (
      .gin ({g_high, g_low}),
      .pin ({p_high, p_low}),
      .gout(gout),
      .pout(pout)
  );

  assign cout[0] = gin[0] | (pin[0] & cin);
  assign cout[1] = gin[1] | (pin[1] & gin[0]) | (pin[1] & pin[0] & cin);
  assign cout[2] = gin[2]
                  | (pin[2] & gin[1])
                  | (pin[2] & pin[1] & gin[0])
                  | (pin[2] & pin[1] & pin[0] & cin);

endmodule

/** Same as gp4 but for an 8-bit window instead */
module gp8 (
    input wire [7:0] gin,
    pin,
    input wire cin,
    output wire gout,
    pout,
    output wire [6:0] cout
);

  wire g_lo, p_lo, g_hi, p_hi;
  wire [2:0] c_lo, c_hi;
  wire c4;

  gp4 gp4_lo (
      .gin (gin[3:0]),
      .pin (pin[3:0]),
      .cin (cin),
      .gout(g_lo),
      .pout(p_lo),
      .cout(c_lo)
  );

  assign c4 = g_lo | (p_lo & cin);

  gp4 gp4_hi (
      .gin (gin[7:4]),
      .pin (pin[7:4]),
      .cin (c4),
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
    input wire [31:0] a,
    b,
    input wire cin,
    output wire [31:0] sum
);

  wire [31:0] g, p, c;
  wire [3:0] block_g, block_p, block_cin;
  wire [2:0] block_cout;
  wire [6:0] cout0, cout1, cout2, cout3;
  wire top_gout, top_pout;

  assign g = a & b;
  assign p = a | b;

  gp4 gp4_top (
      .gin (block_g),
      .pin (block_p),
      .cin (cin),
      .gout(top_gout),
      .pout(top_pout),
      .cout(block_cout)
  );

  assign block_cin[0] = cin;
  assign block_cin[1] = block_cout[0];
  assign block_cin[2] = block_cout[1];
  assign block_cin[3] = block_cout[2];

  gp8 gp8_0 (
      .gin (g[7:0]),
      .pin (p[7:0]),
      .cin (block_cin[0]),
      .gout(block_g[0]),
      .pout(block_p[0]),
      .cout(cout0)
  );
  gp8 gp8_1 (
      .gin (g[15:8]),
      .pin (p[15:8]),
      .cin (block_cin[1]),
      .gout(block_g[1]),
      .pout(block_p[1]),
      .cout(cout1)
  );
  gp8 gp8_2 (
      .gin (g[23:16]),
      .pin (p[23:16]),
      .cin (block_cin[2]),
      .gout(block_g[2]),
      .pout(block_p[2]),
      .cout(cout2)
  );
  gp8 gp8_3 (
      .gin (g[31:24]),
      .pin (p[31:24]),
      .cin (block_cin[3]),
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

  assign sum = a ^ b ^ c;

endmodule
