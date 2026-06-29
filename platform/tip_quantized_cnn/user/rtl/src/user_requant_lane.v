// ****************************************************************************
// USER_REQUANT_LANE - STEP 2 student module (20 pt; per-element requant).
// Contract (what to compute): sw_requant in user/api/user_sw_ref.c.
// Ports below are FROZEN. RTL gotcha not in the C: the right shift is ARITHMETIC (signed);
// match the fixed pipeline latency so valid_out tracks valid_in.
// ****************************************************************************
module USER_REQUANT_LANE
(
    clk,
    rstnn,
    valid_in,
    mm,
    sigma_in,
    m0,
    right_shift,
    bias_eff,
    sigma_w,
    kernel_zp,
    in_zp,
    out_zp,
    q,
    valid_out
);
parameter SI_W = 20;            // Sigma_in width

input wire clk;
input wire rstnn;
input wire valid_in;                    // this element's operands are valid this cycle
input wire [31:0]     mm;               // MAC accumulator (int32)
input wire [SI_W-1:0] sigma_in;         // Sum of activations
input wire [31:0]     m0;               // requant multiplier M0
input wire [7:0]      right_shift;      // requant right shift
input wire [31:0]     bias_eff;         // folded bias (raw_bias + N*in_zp*kernel_zp)
input wire [31:0]     sigma_w;          // Sum of the output's weights
input wire [31:0]     kernel_zp;        // kernel zero-point
input wire [31:0]     in_zp;            // layer input zero-point
input wire [7:0]      out_zp;           // layer output zero-point
output reg [7:0]      q;                // requantized uint8
output reg            valid_out;        // q valid (valid_in delayed by the pipe)

// Skeleton: outputs tied inert -> FAILs. Implement the requant pipeline; delete this block.
always @(posedge clk or negedge rstnn)
begin
    if(!rstnn) begin q <= 8'd0; valid_out <= 1'b0; end
    else       begin q <= 8'd0; valid_out <= 1'b0; end
end
endmodule
