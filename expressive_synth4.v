`timescale 1ns / 1ps
// Four independent DDS/ADSR voices, per-voice TrackID controls supplied
// by touch_voice_manager. The old voice_allocator is intentionally removed:
// identity allocation is now bound to GT911 TrackID, NOT a note number.

module expressive_synth4 (
    input wire clk,
    input wire rst_n,
    input wire sample_tick,
    input wire [3:0]   voice_on,
    input wire [15:0]  voice_notes,
    input wire [31:0]  voice_gains,
    input wire [63:0]  voice_sizes,
    input wire [3:0]   voice_start,
    input wire [3:0]   voice_update,
    input wire [43:0]  voice_deltas,
    input wire [2:0]   timbre_sel,
    input wire [5:0]   release_period,
    input wire         wide_bend,
    input wire signed [11:0] vibrato_q16,
    input wire [1:0]   layer_mode,
    input wire         enable_velocity,
    input wire diagnostic_mode,
    output wire pcm_valid,output wire [7:0] active_oscillators,
    input wire [7:0] diagnostic_count,
    output wire signed [15:0] audio_mix
);
    genvar n;
    wire signed [15:0] audio_channels[0:3];
    wire [3:0] valid_voice;wire [5:0] active_count[0:3];
    assign pcm_valid=&valid_voice;
    assign active_oscillators={2'd0,active_count[0]}+{2'd0,active_count[1]}+{2'd0,active_count[2]}+{2'd0,active_count[3]};

    generate
        for (n=0;n<4;n=n+1) begin: GT_VOICE
            expressive_voice #(.VOICE_INDEX(n)) u_voice (
                .clk(clk),
                .rst_n(rst_n),
                .sample_tick(sample_tick),
                .note_id(voice_notes[n*4 +: 4]),
                .note_on(voice_on[n]),
                .bend_delta_y($signed(voice_deltas[n*11 +: 11])),
                .target_gain(voice_gains[n*8 +: 8]),
                .raw_touch_size(voice_sizes[n*16 +: 16]),
                .voice_start(voice_start[n]),
                .voice_update(voice_update[n]),
                .vibrato_q16(vibrato_q16),
                .layer_mode(layer_mode),
                .enable_velocity(enable_velocity),
                .wide_bend(wide_bend),
                .timbre_sel(timbre_sel),
                .release_period(release_period),
                .diagnostic_mode(diagnostic_mode),.diagnostic_count(diagnostic_count),
                .pcm_valid(valid_voice[n]),.active_partials(active_count[n]),
                .audio_out(audio_channels[n])
            );
        end
    endgenerate

    mixer4 sum4 (
        .ch0(audio_channels[0]),
        .ch1(audio_channels[1]),
        .ch2(audio_channels[2]),
        .ch3(audio_channels[3]),
        .audio_out(audio_mix)
    );

endmodule
