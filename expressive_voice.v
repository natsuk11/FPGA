// WIDTH_FIX_EX3791
`timescale 1ns/1ps

// V7: one playable voice with thirty-two additive DDS/envelope components.
// X selects a musical base note; Y bends it CONTINUOUSLY by +/-2 semitones
// (or +/-4 in WIDE mode). GT911 contact size scales each voice's volume.
// This does not use pre-recorded PCM samples.
//
// Ratio approx exp(z) ~= 1 + z + z^2/2, z=ln(2)/12 * bend_semitones.
// The Q16 approximation has about 2-7 cents worst-case curve error.
// Phase ACCUMULATOR itself is not reset when the finger moves.
// All DSP stages clock at the existing 35MHz; sample_tick is an enable.
// When note_on goes low, hold last pitch / expression level for ADSR tail.

module expressive_voice #(parameter integer VOICE_INDEX=0) (
    input wire clk,
    input wire rst_n,
    input wire sample_tick,

    input wire [3:0] note_id,
    input wire       note_on,
    input wire signed [10:0] bend_delta_y, // originY-currentY, per TrackID
    input wire [7:0] target_gain,       // continuous size -> gain
    input wire [15:0] raw_touch_size,   // contact size for onset detector
    input wire        voice_start,      // first frame owning TrackID
    input wire        voice_update,     // subsequent frame for same TrackID
    input wire signed [11:0] vibrato_q16,
    input wire [1:0] layer_mode,
    input wire       wide_bend,
    input wire [2:0] timbre_sel,
    input wire [5:0] release_period,
    input wire       enable_velocity,


    input wire diagnostic_mode,
    output wire pcm_valid,output wire [5:0] active_partials,
    input wire [7:0] diagnostic_count,
    output wire signed [15:0] audio_out
);
    wire [31:0] base_inc;
    note_to_phase notes (
        .note_id(note_id),
        .phase_inc(base_inc)
    );

    // Relative bend: the starting location is always the original pitch.
    // First contact: originY=currentY -> delta=0 -> ratio 1.0.
    // Moving UP makes delta positive -> higher pitch; DOWN -> lower pitch.
    // Limit range at +/-180 pixels: BEND +/-2, WIDE +/-4 semitones.
    wire signed [10:0] d_y_clamped =
        (bend_delta_y > 11'sd180)  ? 11'sd180 :
        (bend_delta_y < -11'sd180) ? -11'sd180 :
        bend_delta_y;

    wire signed [8:0] coef = wide_bend ? 9'sd84 : 9'sd42;
    wire signed [20:0] z_q16 = d_y_clamped * coef; // Q16
    wire signed [41:0] z_square = z_q16 * z_q16;
    wire signed [23:0] z_square_term = $signed(z_square[40:17]);
    wire signed [23:0] z_extended = {{3{z_q16[20]}},z_q16};
    wire signed [23:0] ratio_calculated =
        24'sd65536 + z_extended + z_square_term;

    reg [17:0] ratio_q16;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            ratio_q16 <= 18'd65536;
        else if(note_on)
            ratio_q16 <= ratio_calculated[17:0];
    end

    // Shared 5-Hz vibrato LFO adds small signed Q16 ratio modulation.
    // Limit of +/-1265 in Q16 is about +/-33 cents, substantially below
    // the larger finger-controlled Pitch Bend range.
    wire signed [19:0] vib_extended =
        {{8{vibrato_q16[11]}},vibrato_q16};
    wire signed [19:0] ratio_with_vib =
        $signed({2'b00,ratio_q16}) + vib_extended;
    wire [17:0] ratio_combined = ratio_with_vib[17:0];

    // The existing 32x18 multiply is maintained. No new master clock.
    wire [49:0] phase_product = base_inc * ratio_combined;
    reg [31:0] phase_inc_reg;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            phase_inc_reg <= 32'd0;
        else
            phase_inc_reg <= phase_product[47:16];
    end


    wire [7:0] attack_velocity_gain;
    velocity_detector attack_velocity (
        .clk(clk),.rst_n(rst_n),
        .voice_on(note_on),
        .voice_start(voice_start),
        .voice_update(voice_update),
        .contact_size(raw_touch_size),
        .area_gain(target_gain),
        .velocity_gain(attack_velocity_gain)
    );

    wire [7:0] expression_target;
    dynamic_gain combined_expression (
        .area_gain(target_gain),
        .velocity_gain(attack_velocity_gain),
        .enable_velocity(enable_velocity),
        .expression_gain(expression_target)
    );

    // 1/48kHz gain ramp: 0..255 takes <=5.3ms, smooths GT911 frame jumps.
    // Keep the gain when a finger is released so the ADSR tail is audible.
    reg [7:0] gain_smooth;

    // Strong onsets rise faster; GT911 size downshifts still fall slowly.
    // 4/2/1 gain steps per 48kHz sample -> fast velocity-dependent attack.
    wire [7:0] attack_rise_step =
        (attack_velocity_gain >= 8'd200) ? 8'd4 :
        (attack_velocity_gain >= 8'd140) ? 8'd2 : 8'd1;
    wire [7:0] gain_shortfall = expression_target - gain_smooth;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            gain_smooth <= 8'd0;
        else if (voice_start) begin
            gain_smooth <= 8'd0; // fresh attack starts quiet
        end else if (sample_tick && note_on) begin
            if (gain_smooth < expression_target) begin
                if (gain_shortfall <= attack_rise_step)
                    gain_smooth <= expression_target;
                else
                    gain_smooth <= gain_smooth + attack_rise_step;
            end else if (gain_smooth > expression_target)
                gain_smooth <= gain_smooth - 8'd1;
        end
    end

    instrument_voice32 #(.VOICE_INDEX(VOICE_INDEX)) instrument (
        .clk(clk),.rst_n(rst_n),.sample_tick(sample_tick),
        .note_on(note_on),.note_start(voice_start),.phase_inc(phase_inc_reg),
        .timbre_sel(timbre_sel),.layer_mode(layer_mode),
        .release_period(release_period),.expression_gain(gain_smooth),
        .diagnostic_mode(diagnostic_mode),.diagnostic_count(diagnostic_count),
        .audio_data(audio_out),.pcm_valid(pcm_valid),.active_partials(active_partials)
    );
endmodule
