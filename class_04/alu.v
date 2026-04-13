`timescale 1ns / 1ps
module alu (
    input  wire [31:0] src_a,      // operand A
    input  wire [31:0] src_b,      // operand B
    input  wire [2:0]  alu_ctrl,   // operation select
    output reg  [31:0] result,     // result
    output wire        zero        // zero flag
);
    always @(*) begin
        case (alu_ctrl) // 아래의 각 3비트는 컴퓨터에게 내릴 오더임
            3'b000: result = src_a & src_b;    //and                    // AND
            3'b001: result = src_a | src_b;    //or                    // OR
            3'b010: result = src_a + src_b;    //add                    // ADD
            3'b110: result = src_a - src_b;    //sub                    // SUB
            3'b111: result = ($signed(src_a) < $signed(src_b)) ? 1 : 0; // SLT
            default: result = 32'd0;
        endcase
    end
    assign zero = (result == 32'd0);
endmodule