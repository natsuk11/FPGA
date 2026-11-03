`timescale 1ns/1ps
// True 512-point, radix-2, in-place complex FFT of the LIVE post-FX PCM stream.
// Bit-reversed input, natural-order output; one butterfly engine (four DSP
// multiplies at most), one operation per memory per clock. 9 stages x 256
// butterflies x 8 clocks = 18,432 clocks, 0.527 ms at nominal 35 MHz.
// A frame is collected in 10.67ms at 48kHz; ~90 live spectra per second.
// Each butterfly scales by 1/2 to prevent 16-bit signed overflow.
// 48 displayed buckets each cover two 93.75Hz bins (0..9kHz at 48kHz).
// This visual FFT is NOT the high-resolution TEST 032 scoring instrument.
module audio_fft512_v83(
    input wire clk, rst_n, pcm_valid,
    input wire signed [15:0] pcm,
    input wire [3:0] wave_shift,
    input wire [5:0] display_column,
    output reg [6:0] bar_height,
    output reg spectrum_ready,
    output reg [6:0] peak_level,
    output reg [6:0] bar_written_peak, bar_read_peak,
    output reg frame_pcm_nonzero
);
    localparam [3:0] CAPTURE=4'd0, READ_A=4'd1, SAVE_A=4'd2,
                     READ_B=4'd3, SAVE_B=4'd4, MULTIPLY=4'd5,
                     COMBINE=4'd6, WRITE_A=4'd7, WRITE_B=4'd8,
                     MAG_READ=4'd9, MAG_APPLY=4'd10;
    reg [3:0] state;
    reg signed [15:0] real_ram [0:511];
    reg signed [15:0] imag_ram [0:511];
    // V8.3.4: Independent front/back 48x7-bit display snapshots.
    // All read selectors below use constant-index FFs, not an inferred RAM
    // with a dynamic read port (which had P/W nonzero, R=0 on the board).
    // The FFT writes ONLY the hidden bank. A completed spectrum atomically
    // becomes visible after the 48th bar has been written.
    reg [6:0] bars_0 [0:47];
    reg [6:0] bars_1 [0:47];
    reg visible_bank;
    reg [8:0] capture_index;
    reg [3:0] stage;
    reg [7:0] butterfly;
    reg [6:0] mag_index;
    reg [6:0] half_peak;
    reg [6:0] scanning_peak;
    reg [6:0] building_bar_peak;
    reg capture_seen_pcm;
    // Separate VISUAL gain compensation. DAC output remains unmodified.
    // V8.3's pcm>>2 plus nine FFT scale stages can hide light touches.
    wire [3:0] norm_shift = (wave_shift >= 4'd9) ?
                            4'd0 : (4'd9-wave_shift);
    wire signed [26:0] pcm_extended = {{11{pcm[15]}},pcm};
    wire signed [26:0] pcm_boosted = pcm_extended <<< norm_shift;
    wire signed [15:0] pcm_normalized =
        (pcm_boosted > 27'sd32767) ? 16'sh7fff :
        (pcm_boosted < -27'sd32768) ? 16'sh8000 :
                                      pcm_boosted[15:0];
    reg signed [15:0] read_re, read_im;
    reg signed [15:0] a_re, a_im, b_re, b_im;
    reg signed [15:0] b_result_re, b_result_im;
    reg signed [15:0] coeff_re, coeff_im;
    reg signed [31:0] product_rr,product_ii,product_ri,product_ir;
    reg signed [17:0] term_re_reg,term_im_reg;

    function [8:0] reverse9;
        input [8:0] value;
        integer k;
        begin
            for(k=0;k<9;k=k+1) reverse9[k]=value[8-k];
        end
    endfunction

    // Conventional iterative decimation-in-time butterfly addressing.
    wire [8:0] low_mask = (9'd1 << stage)-9'd1;
    wire [8:0] group_index = {1'b0,butterfly} >> stage;
    wire [8:0] position_in_group = {1'b0,butterfly} & low_mask;
    wire [8:0] address_a = (group_index << (stage+4'd1)) | position_in_group;
    wire [8:0] address_b = address_a | (9'd1 << stage);
    wire [7:0] twiddle_index = position_in_group[7:0] << (4'd8-stage);
    wire [7:0] sin_index = (twiddle_index <= 8'd128) ?
                             twiddle_index : 8'd0-twiddle_index;
    wire [7:0] cos_index = (twiddle_index <= 8'd128) ?
                             (8'd128-twiddle_index) : (twiddle_index-8'd128);
    wire signed [15:0] raw_sin,raw_cos;
    sine_q14_v83 sin_rom(.index(sin_index),.value(raw_sin));
    sine_q14_v83 cos_rom(.index(cos_index),.value(raw_cos));
    // W = cos(2*pi*k/512) - j*sin(2*pi*k/512).
    wire signed [15:0] tw_cos = (twiddle_index>8'd128) ? -raw_cos : raw_cos;
    wire signed [15:0] tw_sin = -raw_sin;

    wire signed [31:0] mul_rr = $signed(b_re)*$signed(coeff_re);
    wire signed [31:0] mul_ii = $signed(b_im)*$signed(coeff_im);
    wire signed [31:0] mul_ri = $signed(b_re)*$signed(coeff_im);
    wire signed [31:0] mul_ir = $signed(b_im)*$signed(coeff_re);
    wire signed [32:0] weighted_re = $signed({product_rr[31],product_rr}) -
                                     $signed({product_ii[31],product_ii});
    wire signed [32:0] weighted_im = $signed({product_ri[31],product_ri}) +
                                     $signed({product_ir[31],product_ir});
    wire signed [17:0] ar_ext = {{2{a_re[15]}},a_re};
    wire signed [17:0] ai_ext = {{2{a_im[15]}},a_im};
    // Explicit RTL arithmetic widths (EX3791): arithmetic >> 1 then
    // discard upper bits precisely as the previous design intended.
    wire signed [17:0] sum_ar = ar_ext + term_re_reg;
    wire signed [17:0] sum_ai = ai_ext + term_im_reg;
    wire signed [17:0] diff_br = ar_ext - term_re_reg;
    wire signed [17:0] diff_bi = ai_ext - term_im_reg;
    wire signed [15:0] out_ar = sum_ar[16:1];
    wire signed [15:0] out_ai = sum_ai[16:1];
    wire signed [15:0] out_br = diff_br[16:1];
    wire signed [15:0] out_bi = diff_bi[16:1];
    wire signed [32:0] weighted_re_scaled = weighted_re >>> 14;
    wire signed [32:0] weighted_im_scaled = weighted_im >>> 14;

    // |Re|+|Im| avoids a full sqrt; logarithmic-ish buckets preserve
    // quiet harmonics without introducing expensive dividers or multipliers.
    wire [15:0] mag_r = read_re[15] ? -read_re : read_re;
    wire [15:0] mag_i = read_im[15] ? -read_im : read_im;
    wire [16:0] magnitude = {1'b0,mag_r}+{1'b0,mag_i};
    function [6:0] bucket_level;
        input [16:0] mag;
        begin
            if      (mag >= 17'd8192) bucket_level = 7'd112;
            else if (mag >= 17'd4096) bucket_level = 7'd103;
            else if (mag >= 17'd2048) bucket_level = 7'd95;
            else if (mag >= 17'd1024) bucket_level = 7'd87;
            else if (mag >= 17'd512 ) bucket_level = 7'd79;
            else if (mag >= 17'd256 ) bucket_level = 7'd71;
            else if (mag >= 17'd128 ) bucket_level = 7'd63;
            else if (mag >= 17'd64  ) bucket_level = 7'd55;
            else if (mag >= 17'd32  ) bucket_level = 7'd47;
            else if (mag >= 17'd16  ) bucket_level = 7'd39;
            else if (mag >= 17'd8   ) bucket_level = 7'd31;
            else if (mag >= 17'd4   ) bucket_level = 7'd23;
            else if (mag >= 17'd2   ) bucket_level = 7'd12;
            else if (mag >= 17'd1   ) bucket_level = 7'd5;
            else bucket_level=0;
        end
    endfunction
    wire [6:0] curr_level = bucket_level(magnitude);
    wire [6:0] pair_level = (curr_level>half_peak)?curr_level:half_peak;

    // Flip-flop banks: constant physical index and one writer per entry.
    // Neither bank is modified while it is being displayed.
    wire [6:0] selected_bar_masked [0:47];
    genvar bar_no;
    generate
        for (bar_no=0; bar_no<48; bar_no=bar_no+1) begin : FFT_BAR_REGISTERS
            always @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    bars_0[bar_no] <= 7'd0;
                    bars_1[bar_no] <= 7'd0;
                end else if (state==MAG_APPLY && mag_index[0] &&
                             mag_index[6:1]==bar_no) begin
                    if (visible_bank==1'b0)
                        bars_1[bar_no] <= pair_level;
                    else
                        bars_0[bar_no] <= pair_level;
                end
            end
            // A constant-index, one-hot gated read: no dynamic bar RAM port.
            wire [6:0] visible_value = visible_bank ?
                 bars_1[bar_no] : bars_0[bar_no];
            assign selected_bar_masked[bar_no] =
                 visible_value & {7{display_column==bar_no}};
        end
    endgenerate

    // A combinational OR reduction across one-hot column masks.
    // This is a pixel-rate register mux, NOT block-memory inference.
    reg [6:0] selected_bar;
    integer read_col;
    always @(*) begin
        selected_bar=7'd0;
        for (read_col=0;read_col<48;read_col=read_col+1)
            selected_bar=selected_bar | selected_bar_masked[read_col];
    end
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) bar_height<=7'd0;
        else bar_height<=selected_bar;
    end
    // Sticky peak read from the actual display port. If P/W are nonzero
    // but R is zero, the LCD is not retrieving the spectrum bar RAM.
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) bar_read_peak<=7'd0;
        else if(spectrum_ready && bar_height>bar_read_peak)
            bar_read_peak<=bar_height;
    end
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state<=CAPTURE;capture_index<=0;stage<=0;butterfly<=0;visible_bank<=1'b0;
            mag_index<=0;half_peak<=0;scanning_peak<=0;
            building_bar_peak<=0;bar_written_peak<=0;
            capture_seen_pcm<=0;frame_pcm_nonzero<=0;peak_level<=0;
            read_re<=0;read_im<=0;a_re<=0;a_im<=0;b_re<=0;b_im<=0;
            b_result_re<=0;b_result_im<=0;coeff_re<=0;coeff_im<=0;
            product_rr<=0;product_ii<=0;product_ri<=0;product_ir<=0;
            term_re_reg<=0;term_im_reg<=0;spectrum_ready<=0;
        end else begin
            case(state)
                CAPTURE: if(pcm_valid) begin
                    // 1/4 front-end headroom, another 1/2 at every FFT stage.
                    real_ram[reverse9(capture_index)] <= pcm_normalized >>> 2;
                    imag_ram[reverse9(capture_index)] <= 16'sd0;
                    if(capture_index==9'd0) capture_seen_pcm<=(pcm!=16'sd0);
                    else if(pcm!=16'sd0) capture_seen_pcm<=1'b1;
                    if (capture_index == 9'd511) begin
                        frame_pcm_nonzero<=capture_seen_pcm | (pcm!=16'sd0);
                        capture_index<=0;butterfly<=0;stage<=0;
                        state<=READ_A;
                    end else capture_index<=capture_index+9'd1;
                end
                READ_A: begin
                    read_re<=real_ram[address_a];
                    read_im<=imag_ram[address_a];
                    state<=SAVE_A;
                end
                SAVE_A: begin
                    a_re<=read_re;a_im<=read_im;state<=READ_B;
                end
                READ_B: begin
                    read_re<=real_ram[address_b];
                    read_im<=imag_ram[address_b];
                    state<=SAVE_B;
                end
                SAVE_B: begin
                    b_re<=read_re;b_im<=read_im;
                    coeff_re<=tw_cos;coeff_im<=tw_sin;
                    state<=MULTIPLY;
                end
                // DSP multiplier paths end in registers; arithmetic and RAM
                // writeback are split across later clocks for easier P&R.
                MULTIPLY:begin
                    product_rr<=mul_rr;product_ii<=mul_ii;
                    product_ri<=mul_ri;product_ir<=mul_ir;
                    state<=COMBINE;
                end
                COMBINE:begin
                    term_re_reg<=weighted_re_scaled[17:0];
                    term_im_reg<=weighted_im_scaled[17:0];
                    state<=WRITE_A;
                end
                WRITE_A: begin
                    real_ram[address_a]<=out_ar;
                    imag_ram[address_a]<=out_ai;
                    b_result_re<=out_br;b_result_im<=out_bi;
                    state<=WRITE_B;
                end
                WRITE_B: begin
                    real_ram[address_b]<=b_result_re;
                    imag_ram[address_b]<=b_result_im;
                    if (butterfly==8'd255) begin
                        butterfly<=0;
                        if(stage==4'd8)begin
                            mag_index<=0;half_peak<=0;
                            scanning_peak<=0;building_bar_peak<=0;
                            state<=MAG_READ;
                        end else begin stage<=stage+4'd1;state<=READ_A;end
                    end else begin butterfly<=butterfly+8'd1;state<=READ_A;end
                end
                MAG_READ: begin
                    read_re<=real_ram[{2'd0,mag_index}];
                    read_im<=imag_ram[{2'd0,mag_index}];
                    state<=MAG_APPLY;
                end
                MAG_APPLY: begin
                    if(mag_index==7'd0 || curr_level>scanning_peak)
                        scanning_peak<=curr_level;
                    if(!mag_index[0]) half_peak<=curr_level;
                    else begin
                        // Hidden display bank is written by FFT_BAR_REGISTERS.
                        if(pair_level>building_bar_peak)
                            building_bar_peak<=pair_level;
                    end
                    if(mag_index==7'd95) begin
                        peak_level<=(curr_level>scanning_peak) ?
                                       curr_level : scanning_peak;
                        bar_written_peak<=(pair_level>building_bar_peak) ?
                                           pair_level : building_bar_peak;
                        spectrum_ready<=1;visible_bank<=~visible_bank;state<=CAPTURE;
                    end else begin mag_index<=mag_index+7'd1;state<=MAG_READ;end
                end
                default: state<=CAPTURE;
            endcase
        end
    end
endmodule
