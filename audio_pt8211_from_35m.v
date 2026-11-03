`timescale 1ns / 1ps
// Tang Mega 138K NEO Dock PT8211-S 16-bit stereo serial DAC
// One clock domain: uses the original LCD/GT911 35MHz oscillator.
// 32 serial BCK rising edges per stereo frame: 16 bits right + 16 left.
// BCK average 1.536MHz, audio frames average 48kHz.
// Fractional-N BCK divider uses edge spacing of 11 or 12 system clocks.
// This is an initial audio/GT911 integration test, NOT a low-jitter
// substitute for a dedicated audio PLL. PT8211 Japanese 16-bit format:
// DATA + WS prepared on BCK falling edge; captured on BCK rising edge.
// V6 sample_tick occurs at frame START, leaving a full frame to compute
// the next PCM. Both channels keep the same latched sample throughout.

module audio_pt8211_from_35m (
    input  wire               clk_35m,
    input  wire               rst_n,
    input  wire signed [15:0] pcm_in,

    output wire               HP_BCK,
    output wire               HP_WS,
    output wire               HP_DIN,
    output reg                sample_tick
);
    // round((2 * 1536000 / 35000000) * 2**32)
    localparam [31:0] BCK_TOGGLE_INC = 32'd376975415;

    reg [31:0] phase_acc;
    wire [32:0] phase_sum =
        {1'b0,phase_acc} + {1'b0,BCK_TOGGLE_INC};

    reg       bck_reg;
    reg       ws_reg;
    reg       din_reg;
    reg [4:0] bit_index;
    reg [15:0] pcm_latched;

    assign HP_BCK = bck_reg;
    assign HP_WS = ws_reg;
    assign HP_DIN = din_reg;

    always @(posedge clk_35m or negedge rst_n) begin
        if (!rst_n) begin
            phase_acc   <= 32'd0;
            bck_reg     <= 1'b1; // First BCK transition will be falling
            ws_reg      <= 1'b0;
            din_reg     <= 1'b0;
            bit_index   <= 5'd0;
            pcm_latched <= 16'd0;
            sample_tick <= 1'b0;
        end else begin
            sample_tick <= 1'b0;
            phase_acc   <= phase_sum[31:0];

            if (phase_sum[32]) begin
                bck_reg <= ~bck_reg;

                if (bck_reg) begin
                    // FALLING edge: present data and WS ahead of sampling.
                    // Index0: take ONE PCM sample for BOTH L and R.
                    ws_reg <= bit_index[4]; // low=R, high=L per PT8211
                    if (bit_index == 5'd0) begin
                        sample_tick <= 1'b1; // compute PCM for the NEXT stereo frame
                        pcm_latched <= pcm_in;
                        din_reg <= pcm_in[15];
                    end else begin
                        din_reg <= pcm_latched[4'd15 - bit_index[3:0]];
                    end
                end else begin
                    // RISING edge: DAC captures bit. Advance after capture.
                    if (bit_index == 5'd31) begin
                        bit_index <= 5'd0;
                    end else begin
                        bit_index <= bit_index + 5'd1;
                    end
                end
            end
        end
    end
endmodule
