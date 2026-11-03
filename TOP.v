`timescale 1ns / 1ps

// Tang Mega 138K NEO Dock, GW5AST-LV138PG484AC1/I0, revision C.
// LCD: 800 x 480, 40-pin RGB interface.
//
// IMPORTANT:
// This NEO Dock has only RGB666 (18 connected color GPIO signals).
// The LCD panel itself accepts 24-bit RGB888 (8 bits per color), but
// its lower two bits per color are connected to GND on this Dock.
// The piano UI generates RGB888 internally and outputs through the
// same registered 18-bit RGB666 physical connection.
// DO NOT change r_out/g_out/b_out to [7:0] without a new hardware mapping.
//
// V5.2 adds pseudo-velocity, shared Vibrato LFO, and 1/2/3 DDS layer mode.
// V8.2: time-shared 32-component core, optional postmix Chorus/Reverb Lite.
// Both new effects default OFF; TEST modes bypass them, and silence clears tails.

module TOP #(
    parameter integer DAC_FORMAT = 0, // 0=board PT8211, 1=external I2S DAC
    parameter integer UI_THEME = 0, // 0=dark stage, 1=ivory, 2=voice feedback
    parameter integer TOUCH_FLIP_X = 0, // 0=normal 1=mirror X
    parameter integer AREA_LOW = 10, // calibrate using raw hex size on LCD
    parameter integer AREA_SHIFT = 6,  // 2^6 = 64 raw contact-size units
    parameter integer GAIN_CURVE = 2,  // 0=v5 linear, 1=v5 quadratic, 2=expanded dynamics
    parameter integer ENABLE_VELOCITY = 1, // change to 0 for size-only A/B test
    parameter integer MASTER_GAIN_BOOST = 1, // 1=unity; 0=old -6dB
    parameter integer ENABLE_V82_FX = 1, // 0=omit all new FX hardware; 1=Chorus/Reverb enabled
    parameter integer TOUCH_FAST = 1, // 0=100kHz/10ms 1=fast I2C/2ms
    parameter integer ENABLE_FFT_V83 = 1, // 0=leave spectrum hardware out (A/B fallback)
    parameter integer ENABLE_XY_V83 = 1, // 0=leave XY persistence buffer out
    parameter integer FFT_SELF_TEST = 0, // 1=750Hz display-only diagnostic; DAC unchanged
    parameter integer FFT_RENDER_TEST = 0, // 1=pattern bars, independent of FFT RAM and synthesis
    parameter integer GUIDE_LED_REVERSE = 0 // 1=reverse eight LED order
)(
    input  wire       rst_n,

    output wire [5:0] r_out,
    output wire [5:0] g_out,
    output wire [5:0] b_out,

    output wire       sc_clk,
    output wire       sc_hs,
    output wire       sc_vs,
    output wire       sc_de,
    output wire       lcd_bl,

    // GT911 CTP six-pin connector; VCC/GND powered from the Dock.
    output wire       ctp_rst_n,
    inout  wire       ctp_int,
    inout  wire       ctp_sda,
    inout  wire       ctp_scl,

    output wire       HP_BCK,
    output wire       HP_WS,
    output wire       HP_DIN,
    output wire       PA_EN,
    // One Sipeed PMOD-LEDx8 at the first official example PMOD connector.
    output wire [7:0] guide_led_n,
    // Optional HC-05 on two pins of the second PMOD connector.
    input  wire       hc05_rx,
    output wire       hc05_tx
);

    localparam integer UI_KEY_Y0=256;

    // Preserve the raster timing values from the previously working test.
    // All values are explicitly sized to avoid 32->11/10 truncation warnings.
    localparam [10:0] H_SYNC   = 11'd20;
    localparam [10:0] H_BACK   = 11'd46;
    localparam [10:0] H_ACTIVE = 11'd800;
    localparam [10:0] H_FRONT  = 11'd210;
    localparam [10:0] H_TOTAL  = H_SYNC + H_BACK + H_ACTIVE + H_FRONT;
    localparam [10:0] H_START  = H_SYNC + H_BACK;

    localparam [9:0] V_SYNC   = 10'd3;
    localparam [9:0] V_BACK   = 10'd23;
    localparam [9:0] V_ACTIVE = 10'd480;
    localparam [9:0] V_FRONT  = 10'd22;
    localparam [9:0] V_TOTAL  = V_SYNC + V_BACK + V_ACTIVE + V_FRONT;
    localparam [9:0] V_START  = V_SYNC + V_BACK;

    // Original source: Gowin internal OSC, nominal 210 MHz / 6 = 35 MHz.
    wire pix_clk;
    OSC lcd_osc (.OSCOUT(pix_clk));
    defparam lcd_osc.FREQ_DIV = 6;

    reg [10:0] h_count;
    reg [9:0]  v_count;

    wire in_active_area =
        (h_count >= H_START) &&
        (h_count < H_START + H_ACTIVE) &&
        (v_count >= V_START) &&
        (v_count < V_START + V_ACTIVE);

    // Width-matched subtraction; coordinates valid only if in_active_area.
    wire [10:0] x = h_count - H_START;
    wire [9:0]  y = v_count - V_START;


    // Touch logic shares the existing pixel clock but never drives LCD timing.
    // Status/probe is read-only (GT911 product ID @ 0x8140).
    wire        gt_connected;
    wire        gt_error;
    wire [6:0]  gt_addr;
    wire [31:0] gt_product_id;
    wire [2:0]  gt_count;
    wire [79:0] gt_all_x;
    wire [79:0] gt_all_y;

    wire [79:0] gt_size_all;
    wire [39:0] gt_id_all;
    wire        gt_frame_valid;

    gt911_reader #(
        .CLK_HZ(35000000),
        .READ_COORDS(1),
        .I2C_HZ((TOUCH_FAST != 0) ? 400000 : 100000),
        .POLL_US((TOUCH_FAST != 0) ? 2000 : 10000)
    ) gt0 (
        .clk(pix_clk),
        .rst_n(rst_n),
        .ctp_scl(ctp_scl),
        .ctp_sda(ctp_sda),
        .ctp_int(ctp_int),
        .ctp_rst_n(ctp_rst_n),
        .connected(gt_connected),
        .communication_error(gt_error),
        .active_i2c_address(gt_addr),
        .product_id(gt_product_id),
        .touch_count(gt_count),
        .touch_x_all(gt_all_x),
        .touch_y_all(gt_all_y),
        .touch_size_all(gt_size_all),
        .touch_id_all(gt_id_all),
        .frame_valid(gt_frame_valid)
    );

    // GT911 cursor locations: 16x16 points; display overlay is UI-only.
    // Low-cost equality comparators avoid a slow 5-way X/Y subtractor.
    function [15:0] corrected_x;
        input [15:0] raw_x;
        begin corrected_x=(TOUCH_FLIP_X!=0 && raw_x<16'd800)?(16'd799-raw_x):raw_x;end
    endfunction
    wire [79:0] ui_touch_x,play_touch_y;
    wire [4:0] control_contacts;
    genvar ux;
    generate for(ux=0;ux<5;ux=ux+1)begin: TOUCH_AXIS
        assign ui_touch_x[ux*16 +:16]=corrected_x(gt_all_x[ux*16 +:16]);
        assign play_touch_y[ux*16 +:16]=control_contacts[ux]?16'hffff:gt_all_y[ux*16 +:16];
    end endgenerate
    wire [15:0] tx0 = ui_touch_x[15:0];
    wire [15:0] tx1 = ui_touch_x[31:16];
    wire [15:0] tx2 = ui_touch_x[47:32];
    wire [15:0] tx3 = ui_touch_x[63:48];
    wire [15:0] tx4 = ui_touch_x[79:64];
    wire [15:0] ty0 = gt_all_y[15:0];
    wire [15:0] ty1 = gt_all_y[31:16];
    wire [15:0] ty2 = gt_all_y[47:32];
    wire [15:0] ty3 = gt_all_y[63:48];
    wire [15:0] ty4 = gt_all_y[79:64];

    wire hit0 = (gt_count > 3'd0) && (tx0 < 16'd800) && (ty0 < 16'd480) &&
                (x[10:4] == tx0[10:4]) && (y[9:4] == ty0[9:4]);
    wire hit1 = (gt_count > 3'd1) && (tx1 < 16'd800) && (ty1 < 16'd480) &&
                (x[10:4] == tx1[10:4]) && (y[9:4] == ty1[9:4]);
    wire hit2 = (gt_count > 3'd2) && (tx2 < 16'd800) && (ty2 < 16'd480) &&
                (x[10:4] == tx2[10:4]) && (y[9:4] == ty2[9:4]);
    wire hit3 = (gt_count > 3'd3) && (tx3 < 16'd800) && (ty3 < 16'd480) &&
                (x[10:4] == tx3[10:4]) && (y[9:4] == ty3[9:4]);
    wire hit4 = (gt_count > 3'd4) && (tx4 < 16'd800) && (ty4 < 16'd480) &&
                (x[10:4] == tx4[10:4]) && (y[9:4] == ty4[9:4]);

    wire any_touch_hit = hit0 | hit1 | hit2 | hit3 | hit4;



    // ================================================================
    // TOUCH PIANO: waveform + release buttons, 8 playable keys.
    // All logic shares the ALREADY WORKING 35MHz clk, no CDC or extra OSC.
    // ================================================================

    // Voice slots are now allocated by GT911 TrackID (not packet order).
    // Each active slot owns its original note and its original Y position.
    wire [7:0]  keys_down;
    wire [3:0]  voice_on;
    wire [15:0] voice_notes;
    wire [15:0] mapped_live_notes, synth_note_bus;
    wire [23:0] keymap_packed;
    wire [7:0] keymap_changed;
    wire [2:0] guide_physical_key;
    wire map_valid,map_reset;
    wire [2:0] map_key,map_pitch;

    wire [31:0] voice_gains;
    wire [63:0] voice_sizes;
    wire [3:0]  voice_start;
    wire [3:0]  voice_update;
    wire [43:0] voice_deltas;
    wire [31:0] voice_track_ids;
    wire [15:0] debug_raw_size;
    wire [7:0]  debug_gain;

    touch_voice_manager #(
        .FLIP_X(0),
        .KEY_Y0(UI_KEY_Y0),
        .AREA_LOW(AREA_LOW),
        .AREA_SHIFT(AREA_SHIFT),
        .GAIN_CURVE(GAIN_CURVE)
    ) finger_voice_map (
        .clk(pix_clk),
        .rst_n(rst_n),
        .connected(gt_connected),
        .frame_valid(gt_frame_valid),
        .touch_count(gt_count),
        .touch_id_all(gt_id_all),
        .touch_x_all(ui_touch_x),
        .touch_y_all(play_touch_y),
        .touch_size_all(gt_size_all),
        .voice_on(voice_on),
        .voice_notes(voice_notes),
        .voice_gains(voice_gains),
        .voice_sizes(voice_sizes),
        .voice_start(voice_start),
        .voice_update(voice_update),
        .voice_deltas(voice_deltas),
        .voice_track_ids(voice_track_ids),
        .debug_size(debug_raw_size),
        .debug_gain(debug_gain),
        .keys_down(keys_down)
    );

    wire [2:0] menu,timbre_sel,visual_mode;
    wire [2:0] guide_ui_action,guide_remote_action;
    wire [1:0] layer_mode,release_mode;
    wire bt_song_valid,bt_bpm_valid,bt_timbre_valid;
    wire [1:0] bt_song,bt_bpm,bt_fx_toggle;
    wire upload_begin,upload_append,upload_finish;
    wire [2:0] upload_note;
    wire [1:0] upload_beats;
    wire upload_ready,upload_can_append,upload_can_commit;
    wire [7:0] upload_length;
    wire [2:0] upload_read_note;
    wire [1:0] upload_read_beats;
    wire record_toggle,play_toggle,record_stop;
    wire recording,replaying;
    wire [8:0] recorded_count;
    wire [7:0] recorded_read_addr;
    wire [31:0] recorded_read_word;
    wire [3:0] replay_on,replay_start;
    wire [15:0] replay_notes;
    wire [31:0] replay_gains;
    wire [2:0] bt_timbre;
    wire guide_running,guide_timed_mode;
    wire [1:0] guide_song_sel,guide_bpm_sel;
    wire [7:0] guide_step,guide_length;
    wire [2:0] guide_target_note;
    wire [7:0] guide_correct,guide_wrong;
    wire sustain_enabled,wide_bend,delay_enabled,diagnostic_mode;
    wire chorus_enabled,reverb_enabled;
    wire [7:0] master_gain,vibrato_depth,delay_mix,diagnostic_count;
    menu_controller controls(
        .clk(pix_clk),.rst_n(rst_n),.connected(gt_connected),.frame_valid(gt_frame_valid),
        .touch_count(gt_count),.touch_ids(gt_id_all),.touch_x(ui_touch_x),.touch_y(gt_all_y),
        .menu(menu),.timbre_sel(timbre_sel),.layer_mode(layer_mode),.release_mode(release_mode),
        .sustain_enabled(sustain_enabled),.wide_bend(wide_bend),.delay_enabled(delay_enabled),
        .chorus_enabled(chorus_enabled),.reverb_enabled(reverb_enabled),
        .diagnostic_mode(diagnostic_mode),.diagnostic_count(diagnostic_count),.master_gain(master_gain),
        .vibrato_depth(vibrato_depth),.delay_mix(delay_mix),.control_contacts(control_contacts),
        .visual_mode(visual_mode),.guide_action(guide_ui_action),
        .remote_timbre_valid(bt_timbre_valid),.remote_timbre(bt_timbre),
        .remote_fx_toggle(bt_fx_toggle));

    wire [7:0] guide_led_bus;
    genvar led_index;
    generate for (led_index=0;led_index<8;led_index=led_index+1)begin : LED_ORDER
        assign guide_led_n[led_index] = (GUIDE_LED_REVERSE!=0) ?
           guide_led_bus[7-led_index] : guide_led_bus[led_index];
    end endgenerate
    // V8.5: 8 physical keys remain at the exact old touch positions;
    // their pitches may be swapped remotely without changing GT911 tracking.
    keymap_v87 keyboard_map(
        .clk(pix_clk),.rst_n(rst_n),.set_valid(map_valid),
        .set_key(map_key),.set_pitch(map_pitch),.clear_map(map_reset),
        .physical_notes(voice_notes),.guide_pitch(guide_target_note),
        .mapped_notes(mapped_live_notes),.guide_key(guide_physical_key),
        .mapping(keymap_packed),.keymap_changed(keymap_changed));
    // V8.6: uploaded song stored in FPGA runtime RAM; 3 ROM songs kept.
    song_ram_v87 downloaded_song(
        .clk(pix_clk),.rst_n(rst_n),.clear_upload(upload_begin),
        .append_step(upload_append),.commit(upload_finish),
        .new_note(upload_note),.new_beats(upload_beats),
        .read_index(guide_step),.read_note(upload_read_note),
        .read_beats(upload_read_beats),.song_length(upload_length),
        .ready(upload_ready),.can_append(upload_can_append),
        .can_commit(upload_can_commit));
    guide_sequencer_v87 guide0(
        .clk(pix_clk),.rst_n(rst_n),.ui_action(guide_ui_action),
        .remote_action(guide_remote_action),.remote_song_valid(bt_song_valid),
        .remote_song(bt_song),.remote_bpm_valid(bt_bpm_valid),.remote_bpm(bt_bpm),
        .voice_start(voice_start),.voice_notes(mapped_live_notes),
        .song_uploaded(upload_ready),.uploaded_length(upload_length),
        .uploaded_note(upload_read_note),.uploaded_beats(upload_read_beats),
        .physical_key_for_note(guide_physical_key),
        .playing(guide_running),.timed_mode(guide_timed_mode),
        .song_sel(guide_song_sel),.bpm_sel(guide_bpm_sel),
        .song_step(guide_step),.song_length(guide_length),
        .next_note(guide_target_note),
        .correct_count(guide_correct),.wrong_count(guide_wrong),
        .led_n(guide_led_bus));
    // V8.7: record note events (NOT PCM), and replay four independent slots.
    record_v87 recorder0(
        .clk(pix_clk),.rst_n(rst_n),
        .record_toggle(record_toggle),.play_toggle(play_toggle),
        .stop_all(record_stop),
        .live_on(voice_on),.live_start(voice_start),
        .live_notes(mapped_live_notes),.live_gains(voice_gains),
        .dump_addr(recorded_read_addr),.dump_word(recorded_read_word),
        .event_count(recorded_count),.recording(recording),
        .replaying(replaying),.replay_on(replay_on),
        .replay_start(replay_start),.replay_notes(replay_notes),
        .replay_gains(replay_gains));
    // Legacy 9600-bps Classic SPP wiring is unchanged (Y21/Y22).
    link_v87 bluetooth0(
        .clk(pix_clk),.rst_n(rst_n),.uart_rx(hc05_rx),.uart_tx(hc05_tx),
        .status_song(guide_song_sel),.status_bpm(guide_bpm_sel),
        .status_mode(guide_timed_mode),.status_play(guide_running),
        .key_mapping(keymap_packed),
        .upload_ready(upload_ready),.upload_can_append(upload_can_append),
        .upload_can_commit(upload_can_commit),
        .recorder_active(recording),.replay_active(replaying),
        .record_count(recorded_count),.record_word(recorded_read_word),
        .record_read_addr(recorded_read_addr),
        .guide_action(guide_remote_action),.song_valid(bt_song_valid),
        .song(bt_song),.bpm_valid(bt_bpm_valid),.bpm(bt_bpm),
        .timbre_valid(bt_timbre_valid),.timbre(bt_timbre),
        .fx_toggle(bt_fx_toggle),.map_valid(map_valid),.map_key(map_key),
        .map_pitch(map_pitch),.map_reset(map_reset),
        .upload_begin(upload_begin),.upload_append(upload_append),
        .upload_finish(upload_finish),.upload_note(upload_note),
        .upload_beats(upload_beats),.record_toggle(record_toggle),
        .play_toggle(play_toggle),.record_stop(record_stop));
    wire [3:0] synth_voice_on;
    wire [3:0] actual_synth_on=(replaying?replay_on:synth_voice_on);
    wire [3:0] actual_synth_start=(replaying?replay_start:voice_start);
    wire [3:0] actual_synth_update=(replaying?4'd0:voice_update);
    assign synth_note_bus=replaying?replay_notes:mapped_live_notes;
    wire [31:0] synth_gain_bus=replaying?replay_gains:voice_gains;
    wire [63:0] synth_size_bus=replaying?{4{16'd64}}:voice_sizes;
    wire [43:0] synth_delta_bus=replaying?44'd0:voice_deltas;
    reg [7:0] voice_layers;
    reg [11:0] voice_presets;
    integer vc;
    always @(posedge pix_clk or negedge rst_n)begin
        if(!rst_n)begin voice_layers<=8'd0;voice_presets<=12'd0;end
        else for(vc=0;vc<4;vc=vc+1)begin
            // Live octave changes alter an already-held note; display must track it.
            if(voice_on[vc]) voice_layers[vc*2 +:2]<=layer_mode;
            if(voice_start[vc])voice_presets[vc*3 +:3]<=timbre_sel;
        end
    end
    sustain_manager sustain(.clk(pix_clk),.rst_n(rst_n),.connected(gt_connected),
        .enabled(sustain_enabled),.voice_on(voice_on),.voice_start(voice_start),.synth_on(synth_voice_on));

    // V6 compatibility selectors: FAST=quarter preset release, MED=preset,
    // SLOW=four times preset release. Values are latched at note start.
    wire [5:0] release_period =
        (release_mode==2'd0) ? 6'd1 :
        (release_mode==2'd1) ? 6'd12 : 6'd48;

    // Four playable voices, each containing thirty-two independent additive partials.
    wire audio_sample_tick;
    wire signed [15:0] audio_mix;
    wire signed [11:0] vibrato_q16,vibrato_raw;
    wire signed [20:0] vibrato_product=vibrato_raw*$signed({1'b0,vibrato_depth});
    assign vibrato_q16=vibrato_product[19:8];
    wire synth_pcm_valid,fx_pcm_valid;
    wire [7:0] active_oscillators;
    wire enable_velocity_wire = (ENABLE_VELOCITY != 0);

    vibrato_lfo vib0 (
        .clk(pix_clk),
        .rst_n(rst_n),
        .sample_tick(audio_sample_tick),
        .enable(vibrato_depth!=0),
        .vibrato_q16(vibrato_raw)
    );

    expressive_synth4 synth (
        .clk(pix_clk),
        .rst_n(rst_n),
        .sample_tick(audio_sample_tick),
        .voice_on(actual_synth_on),
        .voice_notes(synth_note_bus),
        .voice_gains(synth_gain_bus),
        .voice_sizes(synth_size_bus),
        .voice_start(actual_synth_start),
        .voice_update(actual_synth_update),
        .voice_deltas(synth_delta_bus),
        .timbre_sel(timbre_sel),
        .release_period(release_period),
        .wide_bend(wide_bend),
        .vibrato_q16(vibrato_q16),
        .layer_mode(layer_mode),
        .enable_velocity(enable_velocity_wire),
        .diagnostic_mode(diagnostic_mode),.diagnostic_count(diagnostic_count),.pcm_valid(synth_pcm_valid),
        .active_oscillators(active_oscillators),.audio_mix(audio_mix)
    );

    // Original PT8211 format/clock retained; sample request moved to frame start.
    // Unity mix is still bounded because oscillators use convex weights,
    // voice gains are <=1 and mixer4 averages the four channels.
    // To restore the previous -6dB, set MASTER_GAIN_BOOST=0.
    wire signed [15:0] pcm_safe = (MASTER_GAIN_BOOST != 0) ?
                                    audio_mix : (audio_mix >>> 1);

    // V8.1: preserve the V8 delay module and its independent 128-partial test.
    // Additional effects are after delay; both start OFF on reset. A zero master
    // volume or test transition invalidates ALL effects' history immediately.
    wire signed [15:0] delayed_pcm,audio_processed;
    wire delayed_pcm_valid;
    reg previous_test_mode;
    always @(posedge pix_clk or negedge rst_n)begin
        if(!rst_n)previous_test_mode<=0;
        else previous_test_mode<=diagnostic_mode;
    end
    wire clear_test_history=diagnostic_mode || (previous_test_mode!=diagnostic_mode);
    wire clear_fx_history=clear_test_history || (master_gain==8'd0);
    audio_delay_v7 effects(.clk(pix_clk),.rst_n(rst_n),.pcm_valid(synth_pcm_valid),
        .enabled(delay_enabled && !diagnostic_mode && master_gain!=8'd0),
        .pcm(pcm_safe),.wet_control(delay_mix),
        .master_gain(diagnostic_mode?(master_gain==0?8'd0:8'd255):master_gain),
        .pcm_out(delayed_pcm),.out_valid(delayed_pcm_valid),
        .clear_history(clear_fx_history));
    // Elaboration-time generate removes ALL three new effect RAMs in
    // low-congestion CORE_SAFE builds (not merely switching off their audio).
    generate if (ENABLE_V82_FX != 0) begin : FULL_FX
        audio_fx_v81 finishing_fx(
            .clk(pix_clk),.rst_n(rst_n),
            .pcm_valid(delayed_pcm_valid),.pcm(delayed_pcm),
            .chorus_enabled(chorus_enabled && !diagnostic_mode && master_gain!=8'd0),
            .reverb_enabled(reverb_enabled && !diagnostic_mode && master_gain!=8'd0),
            .clear_history(clear_fx_history),
            .pcm_out(audio_processed),.out_valid(fx_pcm_valid)
        );
    end else begin : CORE_ONLY
        assign audio_processed=delayed_pcm;
        assign fx_pcm_valid=delayed_pcm_valid;
    end endgenerate
    // Hard mute at the serialization boundary also suppresses any in-flight FX sample.
    wire signed [15:0] audio_dac_pcm=(master_gain==8'd0)?16'sd0:audio_processed;
    audio_serial_v7 #(.FORMAT(DAC_FORMAT)) dac_serial(.clk(pix_clk),.rst_n(rst_n),
        .pcm(audio_dac_pcm),.bck(HP_BCK),.ws(HP_WS),.din(HP_DIN),.sample_tick(audio_sample_tick));
    // Digital frame cadence is measured against pix_clk; the oscillator's
    // physical frequency must still be verified by probing HP_WS externally.
    wire [15:0] clock_frames;
    wire pipeline_fault;
    audio_score_monitor_v8 score_monitor(.clk(pix_clk),.rst_n(rst_n),
        .sample_tick(audio_sample_tick),.synth_valid(synth_pcm_valid),.fx_valid(fx_pcm_valid),
        .clock_frames(clock_frames),.deadline_fault(pipeline_fault));
    wire [15:0] last_latency_cycles,max_latency_cycles;
    wire latency_valid;
    audio_latency_v7 latency(.clk(pix_clk),.rst_n(rst_n),.note_start(|voice_start),
        .sample_tick(audio_sample_tick),.synth_valid(synth_pcm_valid),.fx_valid(fx_pcm_valid),
        .last_cycles(last_latency_cycles),.max_cycles(max_latency_cycles),.valid(latency_valid));
    wire [15:0] latency_us=max_latency_cycles/16'd35;
    // V8.3 visualization taps only READ post-FX PCM. Never stalls synth/DAC.
    // WAVE: dynamic picture-only gain + oscilloscope RAM, no audio AGC.
    wire [10:0] scope_dx=x+11'd1-11'd16;
    wire signed [15:0] scope_sample,scope_prev_sample;
    wire scope_ready;
    wire [3:0] wave_shift, wave_boost;
    audio_scope_v83 scope(.clk(pix_clk),.rst_n(rst_n),.pcm_valid(fx_pcm_valid),
        .pcm(audio_dac_pcm),.read_index(scope_dx[9:2]),
        .sample(scope_sample),.previous_sample(scope_prev_sample),.ready(scope_ready),
        .wave_shift(wave_shift),.wave_boost(wave_boost));

    // FFT: one independent shared butterfly; 512 fresh 48kHz PCM samples.
    // 48 visible bars, 2 bins per bar, bin width nominally 93.75Hz.
    wire [10:0] spectrum_dx=x+11'd1-11'd16;
    wire [5:0] spectrum_col=spectrum_dx[9:4];
    wire [6:0] spectrum_height,fft_peak_level,fft_bar_written,fft_bar_read;
    wire spectrum_ready,fft_input_seen;

    // 750Hz test tone, visible only in FFT. No connection to the DAC.
    // Because 750/(48000/512) = 8, the expected peak is column 4.
    reg [7:0] fft_test_phase;
    always @(posedge pix_clk or negedge rst_n) begin
        if(!rst_n) fft_test_phase<=8'd0;
        else if(fx_pcm_valid) fft_test_phase<=fft_test_phase+8'd4;
    end
    // 256-phase sine must cover the full quarter-wave LUT 0..128,
    // not only 0..64 (bug in the original 750Hz reference oscillator).
    wire [6:0] fft_quarter_base = fft_test_phase[6] ?
        (7'd64 - {1'b0,fft_test_phase[5:0]}) : {1'b0,fft_test_phase[5:0]};
    wire [7:0] fft_quarter_index = {fft_quarter_base,1'b0};
    wire signed [15:0] fft_quarter_sine;
    sine_q14_v83 fft_test_sine(.index(fft_quarter_index),
                              .value(fft_quarter_sine));
    wire signed [15:0] fft_test_pcm = fft_test_phase[7] ?
                                     -fft_quarter_sine : fft_quarter_sine;
    wire signed [15:0] fft_pcm = (FFT_SELF_TEST != 0) ?
                                 fft_test_pcm : audio_dac_pcm;
    wire [3:0] fft_wave_shift = (FFT_SELF_TEST != 0) ? 4'd9 : wave_shift;
    generate if(ENABLE_FFT_V83 != 0) begin : V83_FFT
        audio_fft512_v83 fft(
            .clk(pix_clk),.rst_n(rst_n),.pcm_valid(fx_pcm_valid),
            .pcm(fft_pcm),.wave_shift(fft_wave_shift),
            .display_column(spectrum_col),.bar_height(spectrum_height),
            .spectrum_ready(spectrum_ready),.peak_level(fft_peak_level),
            .bar_written_peak(fft_bar_written),.bar_read_peak(fft_bar_read),
            .frame_pcm_nonzero(fft_input_seen));
    end else begin : V83_FFT_BYPASS
        assign spectrum_height=7'd0;
        assign spectrum_ready=1'b0;
        assign fft_peak_level=7'd0;
        assign fft_bar_written=7'd0;
        assign fft_bar_read=7'd0;
        assign fft_input_seen=1'b0;
    end endgenerate

    // Special diagnostic deliberately bypasses FFT/bar RAM only
    // at the LCD input. Use to distinguish drawing from FFT-data faults.
    wire [6:0] draw_spectrum_height = (FFT_RENDER_TEST != 0) ?
          (7'd20 + {1'b0,spectrum_col}) : spectrum_height;
    wire draw_spectrum_ready = (FFT_RENDER_TEST != 0) ? 1'b1 : spectrum_ready;

    // XY: 2D phase portrait of PCM(t) and PCM(t-8), *not* stereo L/R.
    wire [10:0] xy_dx=x+11'd1-11'd144;
    wire [9:0] xy_dy=y-10'd116;
    // 128x64 phase portrait on a 512x128 screen area (4x2 pixels/cell).
    wire [12:0] xy_pixel_addr={xy_dy[6:1],xy_dx[8:2]};
    wire xy_pixel_on;
    generate if(ENABLE_XY_V83 != 0) begin : V83_XY
        audio_xy_v83 xy(
            .clk(pix_clk),.rst_n(rst_n),.pcm_valid(fx_pcm_valid),
            .pcm(audio_dac_pcm),.wave_shift(wave_shift),.wave_boost(wave_boost),
            .pixel_address(xy_pixel_addr),.pixel_on(xy_pixel_on));
    end else begin : V83_XY_BYPASS
        assign xy_pixel_on=1'b0;
    end endgenerate

    // AMP active-low after the same approximately 50ms delay.
    reg [20:0] amp_boot_timer;
    always @(posedge pix_clk or negedge rst_n) begin
        if (!rst_n)
            amp_boot_timer <= 21'd0;
        else if (amp_boot_timer < 21'd1750000)
            amp_boot_timer <= amp_boot_timer + 21'd1;
    end
    assign PA_EN=(DAC_FORMAT==1)?1'b1:((amp_boot_timer == 21'd1750000)?1'b0:1'b1);

    // New interface is a COMBINATIONAL pixel composer: existing registered
    // RGB666, HS, VS, DE, ~PCLK in TOP are deliberately unchanged.
    wire [23:0] rgb888_pixel;

    piano_ui_800x480 #(.UI_THEME(UI_THEME)) ui(
        .active(in_active_area),.x(x),.y(y),.connected(gt_connected),.error(gt_error),
        .menu(menu),.timbre_sel(timbre_sel),.layer_mode(layer_mode),.release_mode(release_mode),
        .sustain_enabled(sustain_enabled),.wide_bend(wide_bend),.delay_enabled(delay_enabled),
        .chorus_enabled(chorus_enabled),.reverb_enabled(reverb_enabled),
        .diagnostic_mode(diagnostic_mode),.diagnostic_count(diagnostic_count),.master_gain(master_gain),.vibrato_depth(vibrato_depth),
        .delay_mix(delay_mix),.keys_down(keys_down),.voice_on(synth_voice_on),.voice_notes(voice_notes),
        .voice_gains(voice_gains),.active_oscillators(master_gain==0?8'd0:active_oscillators),
        .clock_frames(clock_frames),.pipeline_fault(pipeline_fault),
        .voice_layers(voice_layers),.voice_presets(voice_presets),
        .latency_us(latency_us),.latency_valid(latency_valid),.raw_size(debug_raw_size),
        .scope_sample(scope_sample),.scope_prev_sample(scope_prev_sample),.scope_ready(scope_ready),
        .wave_shift(wave_shift),.wave_boost(wave_boost),
        .visual_mode(visual_mode),.spectrum_height(draw_spectrum_height),
        .spectrum_ready(draw_spectrum_ready),.fft_peak_level(fft_peak_level),
        .fft_bar_written(fft_bar_written),.fft_bar_read(fft_bar_read),
        .fft_input_seen(fft_input_seen),.xy_pixel_on(xy_pixel_on),
        .guide_running(guide_running),.guide_timed_mode(guide_timed_mode),
        .guide_song_sel(guide_song_sel),.guide_bpm_sel(guide_bpm_sel),
        .guide_step(guide_step),.guide_length(guide_length),
        .guide_target_note(guide_target_note),
        .guide_physical_key(guide_physical_key),
        .keymap_packed(keymap_packed),
        .recording_active(recording),.replaying_active(replaying),
        .guide_correct(guide_correct),.guide_wrong(guide_wrong),
        .rgb888_pixel(rgb888_pixel));

    // All output signals are registered together at pix_clk rising edge.
    // The LCD pixel clock rises half a period later (~14.3ns at 35MHz).
    // This avoids a large combinational path ending directly at RGB pins
    // and keeps DE/HS/VS/data aligned to the same sampled pixel.
    reg [5:0] r_reg, g_reg, b_reg;
    reg       hs_reg, vs_reg, de_reg;

    always @(posedge pix_clk or negedge rst_n) begin
        if (!rst_n) begin
            h_count <= 11'd0;
            v_count <= 10'd0;

            r_reg <= 6'd0;
            g_reg <= 6'd0;
            b_reg <= 6'd0;

            hs_reg <= 1'b1;
            vs_reg <= 1'b1;
            de_reg <= 1'b0;
        end else begin
            if (h_count == H_TOTAL - 11'd1) begin
                h_count <= 11'd0;
                if (v_count == V_TOTAL - 10'd1)
                    v_count <= 10'd0;
                else
                    v_count <= v_count + 10'd1;
            end else begin
                h_count <= h_count + 11'd1;
            end

            // Physical pins: R2..R7, G2..G7, B2..B7.
            // Keep the top six bits from each 8-bit color.
            r_reg <= rgb888_pixel[23:18];
            g_reg <= rgb888_pixel[15:10];
            b_reg <= rgb888_pixel[7:2];

            hs_reg <= (h_count >= H_SYNC);
            vs_reg <= (v_count >= V_SYNC);
            de_reg <= in_active_area;
        end
    end

    // Preserve original PCLK polarity. Never run a combinational pixel
    // pattern and an unrelated phase of PCLK in the same first test.
    assign sc_clk = ~pix_clk;
    assign sc_hs  = hs_reg;
    assign sc_vs  = vs_reg;
    assign sc_de  = de_reg;
    assign lcd_bl = 1'b1;

    assign r_out = r_reg;
    assign g_out = g_reg;
    assign b_out = b_reg;

endmodule
