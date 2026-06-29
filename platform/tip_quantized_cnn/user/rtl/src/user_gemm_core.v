// ****************************************************************************
// RVX prepost - USER_GEMM_CORE  (PROVIDED; students never edit this)
// Thin wrapper that turns the low-level USER_MAC_ARRAY into a high-level
// "feed K operands, get the finished accumulators" block. USER_MAC_ARRAY itself is
// UNCHANGED -- its clear/mac_en/mac_last/sgn_flat/uns_flat -> acc_flat/sigma_in_flat/
// acc_done contract is preserved; this module just generates that low-level
// K-reduction handshake from a higher-level interface, so the GEMM core does not
// have to re-invent the array's usage protocol.
//
// Usage protocol (the caller = GEMM):
//   - pulse  start  for one cycle to begin a K-reduction (this clears acc/sigma_in)
//   - drive  k_len  = the number of K steps for this reduction (stable during it)
//   - each cycle the caller presents a valid K step, assert  step  and put the
//     per-lane operands on sgn_flat/uns_flat (one step per asserted cycle)
//   - the wrapper emits clear at start, mac_en on each presented step, mac_last on
//     the k_len-th step, and raises  done (= the array's acc_done) one cycle after
//     the final step's accumulate.  acc_flat/sigma_in_flat then hold until the next
//     start.  (The caller paces the steps; the array accepts one per asserted cycle.)
//
// NOTE on timing: clear/mac_en/mac_last are REGISTERED from start/step (one cycle of
// latency), matching USER_MAC_ARRAY's sampling; the caller's operands are forwarded
// combinationally and must stay valid through the cycle after each asserted step.
// Verilog-1995, no functions.
// ****************************************************************************
module USER_GEMM_CORE
(
    // clock / reset
    clk,
    rstnn,
    // high-level K-reduction control
    start,
    k_len,
    step,
    // per-step per-lane operands (sgn = signed weight ; uns = unsigned activation)
    sgn_flat,
    uns_flat,
    // finished accumulators (held until next start) + completion
    acc_flat,
    sigma_in_flat,
    done
);
parameter PE_N = 64;
parameter SI_W = 20;

// ---- clock / reset ----
input wire clk;
input wire rstnn;
// ---- high-level K-reduction control ----
input wire start;                       // 1-cycle: begin a K-reduction (clears array)
input wire [15:0] k_len;                // number of K steps (for mac_last generation)
input wire step;                        // 1-cycle: a K step is presented this cycle
// ---- per-step operands ----
input wire [PE_N*8-1:0] sgn_flat;
input wire [PE_N*8-1:0] uns_flat;
// ---- accumulators out + completion ----
output wire [PE_N*32-1:0] acc_flat;
output wire [PE_N*SI_W-1:0] sigma_in_flat;
output wire done;

// ---- low-level array handshake, generated from start/step/k_len ----
reg clear, mac_en, mac_last;
reg [15:0] cnt;                         // K-step counter (0 .. k_len-1)
wire acc_done;

// ---- K-reduction handshake generator concern ----
always @(posedge clk or negedge rstnn)
begin
    if(!rstnn)
    begin
        clear<=1'b0; mac_en<=1'b0; mac_last<=1'b0; cnt<=16'd0;
    end
    else
    begin
        clear    <= start;                                 // clear acc/sigma_in at K-reduction start
        mac_en   <= step;                                  // one MAC per presented step
        mac_last <= step && (cnt == (k_len - 16'd1));       // final step of the K-reduction
        if(start)     cnt <= 16'd0;
        else if(step) cnt <= cnt + 16'd1;
    end
end

// ---- USER_MAC_ARRAY (UNCHANGED black box) ----
USER_MAC_ARRAY #(.PE_N(PE_N), .SI_W(SI_W))
i_mac
(
    .clk           (clk),
    .rstnn         (rstnn),
    .clear         (clear),
    .mac_en        (mac_en),
    .mac_last      (mac_last),
    .sgn_flat      (sgn_flat),
    .uns_flat      (uns_flat),
    .acc_flat      (acc_flat),
    .sigma_in_flat (sigma_in_flat),
    .acc_done      (acc_done)
);

assign done = acc_done;
endmodule
