`timescale 1ns/1ps
// TouchSynth V8.1: two post-mixer effects using three independent delay memories.
// CHORUS: a slow triangular LFO varies a 5.3-10.6 ms tap at nominal 48kHz.
// REVERB LITE: two recirculating combs of unequal lengths (~31.9/45.9 ms),
// each feedback 3/4, combined conservatively with the dry signal.
// This is a lightweight two-comb approximation, NOT a full Schroeder/FDN reverb.
// Disabled effects are bit-exact pass-through; zero/new/test history is masked.
// Requires one input PCM pulse per frame with >= 4 system clocks between pulses.
module audio_fx_v81 #(
    parameter integer CHORUS_ADDR_BITS=10,
    parameter integer CHORUS_BASE=256,
    parameter integer CHORUS_SWEEP_BITS=8,
    parameter integer REVERB_A_LENGTH=1531,
    parameter integer REVERB_B_LENGTH=2203
)(
    input wire clk,
    input wire rst_n,
    input wire pcm_valid,
    input wire signed [15:0] pcm,
    input wire chorus_enabled,
    input wire reverb_enabled,
    input wire clear_history,
    output reg signed [15:0] pcm_out,
    output reg out_valid
);
    localparam integer CHORUS_LENGTH=(1<<CHORUS_ADDR_BITS);
    reg signed [15:0] chorus_ram[0:CHORUS_LENGTH-1];
    reg signed [15:0] comb_a_ram[0:REVERB_A_LENGTH-1];
    reg signed [15:0] comb_b_ram[0:REVERB_B_LENGTH-1];

    reg [CHORUS_ADDR_BITS-1:0] chorus_ptr;
    reg [CHORUS_ADDR_BITS:0] chorus_filled;
    reg [10:0] comb_a_ptr;
    reg [11:0] comb_b_ptr;
    reg [11:0] comb_a_filled;
    reg [12:0] comb_b_filled;
    reg [23:0] chorus_lfo_phase;
    wire [7:0] triangle=(chorus_lfo_phase[23])?
        ~chorus_lfo_phase[22:15]:chorus_lfo_phase[22:15];
    wire [CHORUS_ADDR_BITS-1:0] moving_tap=triangle >> (8-CHORUS_SWEEP_BITS);
    localparam [CHORUS_ADDR_BITS-1:0] CHORUS_BASE_TAP=CHORUS_BASE;
    wire [CHORUS_ADDR_BITS-1:0] chorus_distance=CHORUS_BASE_TAP+moving_tap;
    wire [CHORUS_ADDR_BITS-1:0] chorus_read_addr=chorus_ptr-chorus_distance;

    reg [1:0] state;
    reg signed [15:0] input_pcm,chorus_tap,comb_a_tap,comb_b_tap,chorus_pcm;
    reg chorus_latched,reverb_latched;
    wire signed [20:0] input_ext={{5{input_pcm[15]}},input_pcm};
    wire signed [20:0] tap_ext={{5{chorus_tap[15]}},chorus_tap};
    wire signed [20:0] chorus_sum=(input_ext<<<1)+input_ext+tap_ext;
    wire signed [20:0] chorus_scaled=chorus_sum>>>2;
    wire signed [20:0] chorus_ext={{5{chorus_pcm[15]}},chorus_pcm};
    wire signed [20:0] a_ext={{5{comb_a_tap[15]}},comb_a_tap};
    wire signed [20:0] b_ext={{5{comb_b_tap[15]}},comb_b_tap};
    wire signed [20:0] reverb_average=(a_ext+b_ext)>>>1;
    wire signed [20:0] reverb_sum=(chorus_ext<<<1)+chorus_ext+reverb_average;
    wire signed [20:0] reverb_scaled=reverb_sum>>>2;
    wire signed [20:0] feedback_a=(chorus_ext+(a_ext<<<1)+a_ext)>>>2;
    wire signed [20:0] feedback_b=(chorus_ext+(b_ext<<<1)+b_ext)>>>2;

    function signed [15:0] saturate16;
        input signed [20:0] value;
        begin
            if(value>21'sd32767) saturate16=16'sh7fff;
            else if(value< -21'sd32768) saturate16=16'sh8000;
            else saturate16=value[15:0];
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            chorus_ptr<=0;chorus_filled<=0;comb_a_ptr<=0;comb_b_ptr<=0;
            comb_a_filled<=0;comb_b_filled<=0;chorus_lfo_phase<=0;
            state<=0;input_pcm<=0;chorus_tap<=0;comb_a_tap<=0;
            comb_b_tap<=0;chorus_pcm<=0;chorus_latched<=0;reverb_latched<=0;
            pcm_out<=0;out_valid<=0;
        end else begin
            out_valid<=0;
            case(state)
                2'd0: if(pcm_valid) begin
                    input_pcm<=pcm;
                    chorus_latched<=chorus_enabled && !clear_history;
                    reverb_latched<=reverb_enabled && !clear_history;
                    // Read registered taps only from filled history. Never reset BRAM in a loop.
                    chorus_tap<=(chorus_enabled && !clear_history &&
                        chorus_filled >= {1'b0,chorus_distance})?
                        chorus_ram[chorus_read_addr]:16'sd0;
                    comb_a_tap<=(reverb_enabled && !clear_history &&
                        comb_a_filled>=REVERB_A_LENGTH)?comb_a_ram[comb_a_ptr]:16'sd0;
                    comb_b_tap<=(reverb_enabled && !clear_history &&
                        comb_b_filled>=REVERB_B_LENGTH)?comb_b_ram[comb_b_ptr]:16'sd0;
                    state<=2'd1;
                end
                2'd1: begin
                    chorus_pcm<=chorus_latched?saturate16(chorus_scaled):input_pcm;
                    state<=2'd2;
                end
                2'd2: begin
                    // Dry immediately on a mode switch. A diagnostic/reset always wins.
                    pcm_out<=clear_history?input_pcm:
                        (reverb_latched?saturate16(reverb_scaled):chorus_pcm);
                    out_valid<=1;
                    state<=2'd0;
                    if(chorus_latched && !clear_history) begin
                        chorus_ram[chorus_ptr]<=input_pcm;
                        chorus_ptr<=chorus_ptr+1'b1;
                        if(chorus_filled<CHORUS_LENGTH)
                            chorus_filled<=chorus_filled+1'b1;
                        chorus_lfo_phase<=chorus_lfo_phase+24'd280;
                    end
                    if(reverb_latched && !clear_history) begin
                        comb_a_ram[comb_a_ptr]<=saturate16(feedback_a);
                        comb_b_ram[comb_b_ptr]<=saturate16(feedback_b);
                        comb_a_ptr<=(comb_a_ptr==REVERB_A_LENGTH-1)?
                            11'd0:comb_a_ptr+11'd1;
                        comb_b_ptr<=(comb_b_ptr==REVERB_B_LENGTH-1)?
                            12'd0:comb_b_ptr+12'd1;
                        if(comb_a_filled<REVERB_A_LENGTH)
                            comb_a_filled<=comb_a_filled+1'b1;
                        if(comb_b_filled<REVERB_B_LENGTH)
                            comb_b_filled<=comb_b_filled+1'b1;
                    end
                end
                default:state<=2'd0;
            endcase
            // Clear indices and validity only: infers synchronous RAM and avoids old tails.
            // The checks at state 0/2 use clear_history combinationally as well.
            if(clear_history || !chorus_enabled) begin
                chorus_ptr<=0;chorus_filled<=0;chorus_lfo_phase<=0;
                chorus_tap<=0;
            end
            if(clear_history || !reverb_enabled) begin
                comb_a_ptr<=0;comb_b_ptr<=0;
                comb_a_filled<=0;comb_b_filled<=0;
                comb_a_tap<=0;comb_b_tap<=0;
            end
        end
    end
endmodule
