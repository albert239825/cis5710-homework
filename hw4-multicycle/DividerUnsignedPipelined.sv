/* INSERT NAME AND PENNKEY HERE */
/* ALBERT CHEN 50247874 */

`timescale 1ns / 1ns

// quotient = dividend / divisor
/*
for (int i = 0; i < 32; i++) {
    remainder = (remainder << 1) | ((dividend >> 31) & 0x1);
    if (remainder < divisor) {
        quotient = (quotient << 1);
    } else {
        quotient = (quotient << 1) | 0x1;
        remainder = remainder - divisor;
    }
    dividend = dividend << 1;
}
*/

module DividerUnsignedPipelined (
    input wire clk, rst, stall,
    input  wire  [31:0] i_dividend,
    input  wire  [31:0] i_divisor,
    output logic [31:0] o_remainder,
    output logic [31:0] o_quotient
);

    // TODO: your code here
    // 8 cycle pipelined divider:
    // each cycle:
    //  read intermediate values from register:
    //      - divisor
    //      - remaining Dividend
    //      - running quotient
    //  run 4 iterations of div_one_iter and store new intermediate values in
    //  next set of intermediate registers
    // Lastly, if 7 cycles have finished, have last cycle calculate the remainder
    // and route outputs to the outputs of the module

    // pipeline registers: pipe[s] stores the output of stage s
    logic [31:0] dividend_pipe [0:7];
    logic [31:0] remainder_pipe[0:7];
    logic [31:0] quotient_pipe [0:7];
    logic [31:0] divisor_pipe  [0:7];

    // combinnational next values
    logic [31:0] dividend_next[0:7];
    logic [31:0] remainder_next[0:7];
    logic [31:0] quotient_next[0:7];

    // stage 0: from external inputs
    divu_4iter stage0 (
        .i_dividend(i_dividend),
        .i_divisor(i_divisor),
        .i_remainder(32'd0),
        .i_quotient(32'd0),
        .o_dividend(dividend_next[0]),
        .o_remainder(remainder_next[0]),
        .o_quotient(quotient_next[0])
    );

    // stages 1-7
    genvar s;
    generate
        for (s = 1; s <= 7; s = s + 1) begin : div_pipeline_stage_loop
            divu_4iter stageN (
                .i_dividend(dividend_pipe[s-1]),
                .i_divisor(divisor_pipe[s-1]),
                .i_remainder(remainder_pipe[s-1]),
                .i_quotient(quotient_pipe[s-1]),
                .o_dividend(dividend_next[s]),
                .o_remainder(remainder_next[s]),
                .o_quotient(quotient_next[s])
            );
        end
    endgenerate

    integer k;

    always_ff @(posedge clk) begin
        if (rst) begin
            for (k = 0; k <= 7; k = k + 1) begin
                dividend_pipe[k]  <= 32'd0;
                remainder_pipe[k] <= 32'd0;
                quotient_pipe[k]  <= 32'd0;
                divisor_pipe[k]   <= 32'd0;
            end
        end else begin
            // pipe[s] <= next[s] for all stages
            for (k = 0; k <= 7; k = k + 1) begin
                dividend_pipe[k]  <= dividend_next[k];
                remainder_pipe[k] <= remainder_next[k];
                quotient_pipe[k]  <= quotient_next[k];
            end
            // propagate divisor through the pipeline
            divisor_pipe[0] <= i_divisor;
            for (k = 1; k <= 7; k = k + 1) begin
                divisor_pipe[k] <= divisor_pipe[k-1];
            end
        end
    end

    assign o_remainder = remainder_pipe[7];
    assign o_quotient  = quotient_pipe[7];

endmodule

module divu_4iter (
    input  wire  [31:0] i_dividend,
    input  wire  [31:0] i_divisor,
    input  wire  [31:0] i_remainder,
    input  wire  [31:0] i_quotient,
    output logic [31:0] o_dividend,
    output logic [31:0] o_remainder,
    output logic [31:0] o_quotient
);

    logic [31:0] dividend [0:4];
    logic [31:0] remainder[0:4];
    logic [31:0] quotient [0:4];

    assign dividend[0]  = i_dividend;
    assign remainder[0] = i_remainder;
    assign quotient[0]  = i_quotient;

    genvar i;
    generate
        for (i = 0; i < 4; i = i + 1) begin : iter_loop
            divu_1iter iter (
                .i_dividend(dividend[i]),
                .i_divisor(i_divisor),
                .i_remainder(remainder[i]),
                .i_quotient(quotient[i]),
                .o_dividend(dividend[i+1]),
                .o_remainder(remainder[i+1]),
                .o_quotient(quotient[i+1])
            );
        end
    endgenerate

    assign o_dividend  = dividend[4];
    assign o_remainder = remainder[4];
    assign o_quotient  = quotient[4];

endmodule
module divu_1iter (
    input  wire  [31:0] i_dividend,
    input  wire  [31:0] i_divisor,
    input  wire  [31:0] i_remainder,
    input  wire  [31:0] i_quotient,
    output logic [31:0] o_dividend,
    output logic [31:0] o_remainder,
    output logic [31:0] o_quotient
);

  // TODO: copy your code from HW2A here

    logic [31:0] rem_shift;

    always_comb begin
        rem_shift = {i_remainder[30:0], i_dividend[31]};
        if (rem_shift < i_divisor) begin
            o_quotient = i_quotient << 1;
            o_remainder = rem_shift;
        end else begin
            o_quotient = {i_quotient[30:0], 1'b1};
            o_remainder = rem_shift - i_divisor;
        end
        o_dividend = {i_dividend[30:0], 1'b0};
    end

endmodule
