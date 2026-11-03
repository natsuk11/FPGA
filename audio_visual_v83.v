`timescale 1ns/1ps
// V8.3.4 stable oscilloscope. This pipeline NEVER modifies the DAC PCM.
// A positive-going zero crossing triggers a 256 point capture at 24k points/s.
// Two 256x16 sample banks isolate the LCD from the live write pointer.
// Consequently a sustained periodic note stays still on screen, rather than
// drawing a rotating ring buffer from a randomly chosen phase.
module audio_scope_v83(
    input wire clk, rst_n, pcm_valid,
    input wire signed [15:0] pcm,
    input wire [7:0] read_index,
    output reg signed [15:0] sample,
    output reg signed [15:0] previous_sample,
    output wire ready,
    output reg [3:0] wave_shift,
    output reg [3:0] wave_boost
);
    reg signed [15:0] waveform_0 [0:255];
    reg signed [15:0] waveform_1 [0:255];
    reg draw_bank;             // published stable bank
    reg is_capturing;
    reg [7:0] capture_addr;
    reg capture_divider;
    reg signed [15:0] last_pcm;
    reg [7:0] last_display_index;
    reg [15:0] captured_peak;
    reg [12:0] quiet_samples;
    reg data_ready;
    assign ready = data_ready;

    wire [15:0] abs_pcm = (pcm==16'sh8000) ? 16'h7fff :
                              (pcm[15] ? (~pcm + 16'd1) : pcm);
    wire [15:0] peak_with_new = abs_pcm>captured_peak ? abs_pcm : captured_peak;
    wire positive_crossing = last_pcm[15] && !pcm[15] && (abs_pcm!=16'd0);

    // Aim for approximately +/-40 pixels, with adjustment only once per
    // complete captured frame; allow a picture-only boost for weak tones.
    function [3:0] recommended_shift;
        input [15:0] amplitude;
        begin
            if      (amplitude >= 16'd16384) recommended_shift=4'd9;
            else if (amplitude >= 16'd8192 ) recommended_shift=4'd8;
            else if (amplitude >= 16'd4096 ) recommended_shift=4'd7;
            else if (amplitude >= 16'd2048 ) recommended_shift=4'd6;
            else if (amplitude >= 16'd1024 ) recommended_shift=4'd5;
            else if (amplitude >= 16'd512  ) recommended_shift=4'd4;
            else if (amplitude >= 16'd256  ) recommended_shift=4'd3;
            else if (amplitude >= 16'd128  ) recommended_shift=4'd2;
            else if (amplitude >= 16'd64   ) recommended_shift=4'd1;
            else recommended_shift=4'd0;
        end
    endfunction
    function [3:0] recommended_boost;
        input [15:0] amplitude;
        begin
            if      (amplitude >= 16'd32) recommended_boost=4'd0;
            else if (amplitude >= 16'd16) recommended_boost=4'd1;
            else if (amplitude >= 16'd8 ) recommended_boost=4'd2;
            else if (amplitude >= 16'd4 ) recommended_boost=4'd3;
            else if (amplitude >= 16'd2 ) recommended_boost=4'd4;
            else if (amplitude >= 16'd1 ) recommended_boost=4'd5;
            else recommended_boost=4'd0;
        end
    endfunction

    // The LCD reads exclusively from the last completed frame. The FPGA
    // may infer two 1-read 1-write RAMs; neither is being written while read.
    always @(posedge clk) begin
        sample <= draw_bank ? waveform_1[read_index] : waveform_0[read_index];
        if(read_index!=last_display_index) previous_sample <= sample;
        last_display_index<=read_index;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            draw_bank<=0;
            is_capturing<=0;
            capture_addr<=0;
            capture_divider<=0;
            last_pcm<=0;
            captured_peak<=0;
            quiet_samples<=0;
            data_ready<=0;
            wave_shift<=4'd8;
            wave_boost<=4'd0;
        end else if (pcm_valid) begin
            last_pcm <= pcm;
            if (abs_pcm<=16'd1) begin
                if (quiet_samples<13'd4096) quiet_samples<=quiet_samples+13'd1;
                if (quiet_samples==13'd4095) data_ready<=0;
            end else quiet_samples<=0;

            if (!is_capturing) begin
                // Capture starts on the very first sample after zero crossing.
                if (positive_crossing) begin
                    is_capturing<=1;
                    capture_addr<=8'd1;
                    capture_divider<=0;
                    captured_peak<=abs_pcm;
                    // The opposite bank is the only write target.
                    if (draw_bank==1'b0) waveform_1[0]<=pcm;
                    else waveform_0[0]<=pcm;
                end
            end else begin
                capture_divider<=~capture_divider;
                if(capture_divider==1'b1) begin
                    if (draw_bank==1'b0)
                        waveform_1[capture_addr]<=pcm;
                    else
                        waveform_0[capture_addr]<=pcm;
                    if(abs_pcm>captured_peak) captured_peak<=abs_pcm;
                    if(capture_addr==8'd255) begin
                        // The completed bank becomes immutable until the next
                        // capture; publishing it is an atomic one-bit switch.
                        draw_bank<=~draw_bank;
                        is_capturing<=0;
                        data_ready<=1;
                        if(recommended_shift(peak_with_new)>wave_shift)
                            wave_shift<=wave_shift+4'd1;
                        else if(recommended_shift(peak_with_new)<wave_shift)
                            wave_shift<=wave_shift-4'd1;
                        if(recommended_boost(peak_with_new)>wave_boost)
                            wave_boost<=wave_boost+4'd1;
                        else if(recommended_boost(peak_with_new)<wave_boost)
                            wave_boost<=wave_boost-4'd1;
                    end else capture_addr<=capture_addr+8'd1;
                end
            end
        end
    end
endmodule

// V8.3.4 single-channel delayed phase portrait:
//       X = PCM(t), Y = PCM(t - ~28 samples).
// There is no fake stereo signal. Display-only gain follows WAVE's level.
// 128x64 bitmap is enlarged by the LCD into the 512x128 upper plot area.
module audio_xy_v83(
    input wire clk, rst_n, pcm_valid,
    input wire signed [15:0] pcm,
    input wire [3:0] wave_shift,wave_boost,
    input wire [12:0] pixel_address,
    output reg pixel_on
);
    reg bitmap [0:8191];
    reg signed [15:0] delay_samples [0:7];
    reg [12:0] clear_index;
    reg decay_toggle;
    reg [1:0] lag_decimator;
    reg [6:0] px;
    reg [5:0] py;

    // 26 bits of signed headroom before picture-only gain/shift.
    wire signed [25:0] expanded_x =
        $signed({{10{pcm[15]}},pcm}) <<< wave_boost;
    wire signed [25:0] expanded_y =
        $signed({{10{delay_samples[7][15]}},delay_samples[7]}) <<< wave_boost;
    // Max amplitude is deliberately around 64 horizontal and 32 vertical
    // pixels. Wide intermediates avoid wraparound on saturated samples.
    wire [4:0] y_shift = {1'b0,wave_shift}+5'd1;
    wire signed [25:0] scaled_x = expanded_x >>> wave_shift;
    wire signed [25:0] scaled_y = expanded_y >>> y_shift;
    wire signed [25:0] xx = 26'sd64+scaled_x;
    wire signed [25:0] yy = 26'sd32+scaled_y;
    wire [12:0] hit_addr={py,px};

    always @(*) begin
        if(xx<26'sd0) px=7'd0;
        else if(xx>26'sd127) px=7'd127;
        else px=xx[6:0];
        if(yy<26'sd0) py=6'd0;
        else if(yy>26'sd63) py=6'd63;
        else py=yy[5:0];
    end

    reg [13:0] init_addr;
    integer i;
    always @(posedge clk)
        pixel_on <= (init_addr==14'd8192) ? bitmap[pixel_address] : 1'b0;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clear_index<=0;
            decay_toggle<=0;
            lag_decimator<=0;
            init_addr<=0;
            for(i=0;i<8;i=i+1)delay_samples[i]<=0;
        end else if(init_addr<14'd8192) begin
            bitmap[init_addr[12:0]]<=1'b0;
            init_addr<=init_addr+14'd1;
        end else if(pcm_valid) begin
            lag_decimator<=lag_decimator+2'd1;
            if(lag_decimator==2'd0)begin
                for(i=7;i>0;i=i-1)delay_samples[i]<=delay_samples[i-1];
                delay_samples[0]<=pcm;
            end
            decay_toggle<=~decay_toggle;
            // Deterministic trail: one dot plus one decay scan on alternating
            // samples. No unsynchronized multi-writer inference is needed.
            if(decay_toggle==1'b0)begin
                bitmap[hit_addr]<=1'b1;
            end else begin
                bitmap[clear_index]<=1'b0;
                clear_index<=clear_index+13'd1;
            end
        end
    end
endmodule
