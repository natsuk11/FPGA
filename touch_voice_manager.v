// WIDTH_FIX_EX3791
`timescale 1ns / 1ps
// V7.1: TrackID-stable voices with cross-key retriggering.
// Same-key motion updates expression only. Entering a new key changes the
// note and pulses voice_start without releasing or reallocating the voice.
// Y origin resets on each new note; vertical motion within a key bends it.
// Menu contact isolation is still performed by V7 TOP/menu_controller.

module touch_voice_manager #(
    parameter integer FLIP_X = 0,
    parameter integer SLIDE_RETRIGGER = 1,
    parameter integer SLIDE_HYSTERESIS = 3, // enter 3px into new key
    parameter integer KEY_Y0 = 120, // TOP passes 256 for the V7 menu UI
    parameter integer AREA_LOW = 10,
    parameter integer AREA_SHIFT = 6, // span=64, v4 was span=128
    parameter integer GAIN_CURVE = 2  // 0=v5 linear, 1=v5 quadratic, 2=expanded dynamics
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        connected,
    input  wire        frame_valid,
    input  wire [2:0]  touch_count,
    input  wire [39:0] touch_id_all,
    input  wire [79:0] touch_x_all,
    input  wire [79:0] touch_y_all,
    input  wire [79:0] touch_size_all,

    output wire [3:0]  voice_on,
    output wire [15:0] voice_notes,     // 4x note index (C4..C5)
    output wire [31:0] voice_gains,     // 4x per-voice area-expression gain
    output wire [63:0] voice_sizes,     // 4x raw 16bit GT911 size
    output reg [3:0]   voice_start,     // 1-clk pulse: new TrackID assigned
    output reg [3:0]   voice_update,    // 1-clk pulse: existing TrackID updated
    output wire [43:0] voice_deltas,    // 4x signed 11-bit (y_origin - y_now)
    output wire [31:0] voice_track_ids,// debug: voice0 in [7:0]
    output wire [15:0] debug_size,    // GT911 first raw contact size
    output wire [7:0]  debug_gain,    // calibrated area gain
    output reg  [7:0]  keys_down      // only four allocated voices
);

    localparam [15:0] KEY_START = (KEY_Y0 < 0) ? 16'd0 :
        ((KEY_Y0 > 479) ? 16'd479 : KEY_Y0[15:0]);

    localparam [15:0] SLIDE_MARGIN = (SLIDE_HYSTERESIS < 0) ? 16'd0 :
        ((SLIDE_HYSTERESIS > 20) ? 16'd20 : SLIDE_HYSTERESIS[15:0]);

    // Exact integer/bit-packed registries; Gowin-compatible Verilog-2001.
    reg [3:0] active_r;
    reg [31:0] track_r;
    reg [15:0] notes_r;
    reg [39:0] origin_y_r;
    reg [39:0] current_y_r;
    reg [31:0] gain_r;
    reg [63:0] size_r;

    reg [3:0] active_next;
    reg [31:0] track_next;
    reg [15:0] notes_next;
    reg [39:0] origin_y_next;
    reg [39:0] current_y_next;
    reg [31:0] gain_next;
    reg [63:0] size_next;
    reg [3:0] start_next;
    reg [3:0] update_next;

    reg [4:0] claimed_touch;
    reg [3:0] allocated_slot;
    reg [3:0] note_candidate;

    integer v, t;
    integer display_index;

    assign voice_on = active_r;
    assign voice_notes = notes_r;
    assign voice_gains = gain_r;
    assign voice_sizes = size_r;
    assign voice_track_ids = track_r;

    // Per-voice signed difference, converted to semitones in expressive_voice.
    genvar gi;
    generate
        for (gi=0; gi<4; gi=gi+1) begin: RELATIVE_Y
            wire signed [10:0] dy =
                $signed({1'b0,origin_y_r[gi*10 +: 10]}) -
                $signed({1'b0,current_y_r[gi*10 +: 10]});
            assign voice_deltas[gi*11 +: 11] = dy;
        end
    endgenerate

    // Valid keyboard coordinates: used at touch-down and while sliding.
    function [3:0] note_at_touchdown;
        input [15:0] x;
        input [15:0] y;
        reg [15:0] xx;
        begin
            note_at_touchdown = 4'hF; // invalid/control-panel
            xx = (FLIP_X != 0) ? (16'd799 - x) : x;
            if (x < 16'd800 && y >= KEY_START && y < 16'd480) begin
                if      (xx < 16'd100) note_at_touchdown = 4'd0;
                else if (xx < 16'd200) note_at_touchdown = 4'd1;
                else if (xx < 16'd300) note_at_touchdown = 4'd2;
                else if (xx < 16'd400) note_at_touchdown = 4'd3;
                else if (xx < 16'd500) note_at_touchdown = 4'd4;
                else if (xx < 16'd600) note_at_touchdown = 4'd5;
                else if (xx < 16'd700) note_at_touchdown = 4'd6;
                else                    note_at_touchdown = 4'd7;
            end
        end
    endfunction

    // Hysteresis around boundaries prevents alternating notes from jitter.
    function slide_threshold_met;
        input [15:0] raw_x;
        input [3:0] old_note, new_note;
        reg [15:0] xx, left_edge, right_edge;
        begin
            xx = (FLIP_X != 0) ? (16'd799 - raw_x) : raw_x;
            left_edge = {12'd0,new_note} * 16'd100 + SLIDE_MARGIN;
            right_edge = ({12'd0,new_note} + 16'd1) * 16'd100 - SLIDE_MARGIN;
            slide_threshold_met = 1'b0;
            if (new_note > old_note)
                slide_threshold_met = (xx >= left_edge);
            else if (new_note < old_note)
                slide_threshold_met = (xx < right_edge);
        end
    endfunction

    function [9:0] clamp_y;
        input [15:0] yy;
        begin
            if (yy < KEY_START)      clamp_y = KEY_START[9:0];
            else if (yy > 16'd479) clamp_y = 10'd479;
            else                   clamp_y = yy[9:0];
        end
    endfunction

    // 8-bit normalized size, then optional quadratic sensitivity curve.
    // Reduced AREA_SHIFT helps make a modest size change more audible.
    function [7:0] gain_from_size;
        input [15:0] sz;
        reg [15:0] delta;
        reg [31:0] delta_full;
        reg [23:0] norm_shifted;
        reg [23:0] norm_raw;
        reg [8:0]  norm;
        reg [17:0] squared;
        reg [25:0] scaled;
        reg [8:0]  result;
        begin
            delta = 16'd0;
            delta_full = 32'd0;
            norm_shifted = 24'd0;
            norm_raw = 24'd0;
            norm = 9'd0;
            squared = 18'd0;
            scaled = 26'd0;
            result = 9'd0;

            if (sz == 16'd0) begin
                // Some GT911 firmwares do not expose a useful size field.
                gain_from_size = 8'd192;
            end else if (sz <= AREA_LOW) begin
                gain_from_size = (GAIN_CURVE == 2) ? 8'd16 : 8'd48;
            end else if (sz >= (AREA_LOW + (1 << AREA_SHIFT))) begin
                gain_from_size = 8'd255;
            end else begin
                delta_full = {16'd0,sz} - AREA_LOW;
                delta = delta_full[15:0];
                norm_raw = delta * 8'd255;
                norm_shifted = norm_raw >> AREA_SHIFT;
                norm = norm_shifted[8:0]; // 0..254
                if (GAIN_CURVE == 0) begin
                    scaled = norm * 8'd207; // linear
                    result = 9'd48 + scaled[16:8];
                end else if (GAIN_CURVE == 1) begin
                    squared = norm * norm;
                    scaled = squared * 8'd207; // original quadratic (v5)
                    result = 9'd48 + scaled[24:16];
                end else begin
                    // Expanded dynamics: 16 + 239 * (normalized contact)^2.
                    // Raises the ratio between small and large contact sizes.
                    squared = norm * norm;
                    scaled = squared * 8'd239;
                    result = 9'd16 + scaled[24:16];
                end
                gain_from_size = result[7:0];
            end
        end
    endfunction

    assign debug_size =
        (connected && touch_count != 3'd0) ? touch_size_all[15:0] : 16'd0;
    assign debug_gain =
        (connected && touch_count != 3'd0) ? gain_from_size(debug_size) : 8'd0;

    // Match old active voice slots against *all five* new point records
    // by TrackID, regardless of ordering in the GT911 point table.
    //
    // Then allocate NEW touches into slots free AFTER matching this frame.
    // voice_start explicitly retriggers ADSR, including same-frame reuse.
    always @(*) begin
        active_next = active_r;
        track_next = track_r;
        notes_next = notes_r;
        origin_y_next = origin_y_r;
        current_y_next = current_y_r;
        gain_next = gain_r;
        size_next = size_r;
        start_next = 4'd0;
        update_next = 4'd0;

        claimed_touch = 5'd0;
        allocated_slot = 4'd0;
        note_candidate = 4'hF;

        if (frame_valid) begin
            active_next = 4'd0;

            // Stage 1: preserve TrackID ownership; retrigger a crossed key in place.
            for (v=0; v<4; v=v+1) begin
                for (t=0; t<5; t=t+1) begin
                    if (active_r[v] && (t < touch_count) &&
                        !claimed_touch[t] &&
                        (track_r[v*8 +: 8] == touch_id_all[t*8 +: 8])) begin
                        active_next[v] = 1'b1;
                        current_y_next[v*10 +: 10] =
                            clamp_y(touch_y_all[t*16 +: 16]);
                        gain_next[v*8 +: 8] =
                            gain_from_size(touch_size_all[t*16 +: 16]);
                        size_next[v*16 +: 16] = touch_size_all[t*16 +: 16];
                        update_next[v] = 1'b1;
                        note_candidate = note_at_touchdown(
                            touch_x_all[t*16 +:16], touch_y_all[t*16 +:16]);
                        if (SLIDE_RETRIGGER != 0 && note_candidate != 4'hF &&
                            note_candidate != notes_r[v*4 +:4] &&
                            slide_threshold_met(touch_x_all[t*16 +:16],
                                notes_r[v*4 +:4], note_candidate)) begin
                            notes_next[v*4 +:4] = note_candidate;
                            origin_y_next[v*10 +:10] =
                                clamp_y(touch_y_all[t*16 +:16]);
                            start_next[v] = 1'b1;
                            update_next[v] = 1'b0;
                        end
                        claimed_touch[t] = 1'b1;
                    end
                end
            end

            // Stage 2: allocate NEW fingers to unmatched/free voices this frame.
            for (t=0; t<5; t=t+1) begin
                if ((t < touch_count) && !claimed_touch[t]) begin
                    note_candidate = note_at_touchdown(
                        touch_x_all[t*16 +: 16],
                        touch_y_all[t*16 +: 16]
                    );
                    if (note_candidate != 4'hF) begin
                        for (v=0; v<4; v=v+1) begin
                            if (!active_next[v] && !allocated_slot[v] &&
                                !claimed_touch[t]) begin
                                active_next[v] = 1'b1;
                                allocated_slot[v] = 1'b1;
                                claimed_touch[t] = 1'b1;
                                track_next[v*8 +: 8] = touch_id_all[t*8 +: 8];
                                notes_next[v*4 +: 4] = note_candidate;
                                origin_y_next[v*10 +: 10] =
                                    clamp_y(touch_y_all[t*16 +: 16]);
                                current_y_next[v*10 +: 10] =
                                    clamp_y(touch_y_all[t*16 +: 16]);
                                gain_next[v*8 +: 8] =
                                    gain_from_size(touch_size_all[t*16 +: 16]);
                                size_next[v*16 +: 16] = touch_size_all[t*16 +: 16];
                                start_next[v] = 1'b1;
                            end
                        end
                    end
                end
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            active_r <= 4'd0;
            track_r <= 32'd0;
            notes_r <= 16'd0;
            origin_y_r <= {4{10'd300}};
            current_y_r <= {4{10'd300}};
            gain_r <= 32'd0;
            size_r <= 64'd0;
            voice_start <= 4'd0;
            voice_update <= 4'd0;
        end else begin
            voice_start <= 4'd0;
            voice_update <= 4'd0;
            if (!connected || (touch_count == 3'd0)) begin
                active_r <= 4'd0; // note_off, leave ADSR release untouched
            end else if (frame_valid) begin
                active_r <= active_next;
                track_r <= track_next;
                notes_r <= notes_next;
                origin_y_r <= origin_y_next;
                current_y_r <= current_y_next;
                gain_r <= gain_next;
                size_r <= size_next;
                voice_start <= start_next;
                voice_update <= update_next;
            end
        end
    end

    always @(*) begin
        keys_down = 8'd0;
        for (display_index=0; display_index<4; display_index=display_index+1) begin
            if (active_r[display_index] &&
                notes_r[display_index*4 +: 4] < 4'd8)
                keys_down[notes_r[display_index*4 +: 4]] = 1'b1;
        end
    end

endmodule
