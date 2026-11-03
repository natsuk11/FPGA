`timescale 1ns / 1ps
// Shared 5-Hz sine LFO, 32-point LUT, audio sample clock ENABLE.
// Nominal clk=35 MHz, but phase only advances at 48k sample_tick.
// With enable=1, fades in over ~5.3ms to approx +/-33 cents.
// With enable=0, fades out (no sudden global phase-inc jump).

module vibrato_lfo (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        sample_tick,
    input  wire        enable,
    output wire signed [11:0] vibrato_q16
);
    localparam [31:0] LFO_PHASE_INC = 32'd447392; // round(5 * 2^32 / 48000)
    reg [31:0] lfo_phase;
    reg signed [7:0] lfo_sine;
    reg [7:0] depth;

    function signed [7:0] sine32;
        input [4:0] address;
        begin
            case (address)
                5'd0: sine32 = 8'sd0;
                5'd1: sine32 = 8'sd25;
                5'd2: sine32 = 8'sd49;
                5'd3: sine32 = 8'sd71;
                5'd4: sine32 = 8'sd90;
                5'd5: sine32 = 8'sd106;
                5'd6: sine32 = 8'sd117;
                5'd7: sine32 = 8'sd125;
                5'd8: sine32 = 8'sd127;
                5'd9: sine32 = 8'sd125;
                5'd10: sine32 = 8'sd117;
                5'd11: sine32 = 8'sd106;
                5'd12: sine32 = 8'sd90;
                5'd13: sine32 = 8'sd71;
                5'd14: sine32 = 8'sd49;
                5'd15: sine32 = 8'sd25;
                5'd16: sine32 = 8'sd0;
                5'd17: sine32 = -8'sd25;
                5'd18: sine32 = -8'sd49;
                5'd19: sine32 = -8'sd71;
                5'd20: sine32 = -8'sd90;
                5'd21: sine32 = -8'sd106;
                5'd22: sine32 = -8'sd117;
                5'd23: sine32 = -8'sd125;
                5'd24: sine32 = -8'sd127;
                5'd25: sine32 = -8'sd125;
                5'd26: sine32 = -8'sd117;
                5'd27: sine32 = -8'sd106;
                5'd28: sine32 = -8'sd90;
                5'd29: sine32 = -8'sd71;
                5'd30: sine32 = -8'sd49;
                5'd31: sine32 = -8'sd25;
                default: sine32 = 8'sd0;
            endcase
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            lfo_phase <= 32'd0;
            lfo_sine <= 8'sd0;
            depth <= 8'd0;
        end else if (sample_tick) begin
            lfo_phase <= lfo_phase + LFO_PHASE_INC;
            lfo_sine <= sine32(lfo_phase[31:27]);
            if (enable && depth < 8'd255)
                depth <= depth + 8'd1;
            else if (!enable && depth > 8'd0)
                depth <= depth - 8'd1;
        end
    end

    // 127 * 255 * 5 / 128 = 1265, approx 33.5 cents in Q16.
    wire signed [17:0] multiply_gain =
        $signed(lfo_sine) * $signed({1'b0,depth});
    wire signed [19:0] extended =
        {{2{multiply_gain[17]}},multiply_gain};
    wire signed [19:0] scaled = (extended <<< 2) + extended;
    wire signed [19:0] mod_q16 = scaled >>> 7;
    assign vibrato_q16 = mod_q16[11:0];
endmodule
