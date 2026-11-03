`timescale 1ns/1ps
// Presets: FLUTE ORGAN PLUCK VIOLIN GUITAR PIANO MANDOLIN.
// Spectra and envelopes are real-time additive approximations.
module instrument_params32 (
 input wire [4:0] partial_id, input wire [2:0] preset,input wire [5:0] release_period,
 output reg [8:0] weight,
 output reg [23:0] attack_step,decay_step,sustain_level,
 output wire [23:0] release_step
);
 reg [23:0] release_base;
 assign release_step=(release_period==6'd1)?(release_base<<2):
  (release_period==6'd48)?(release_base>>2):release_base;
 always @(*)begin
  weight=9'd0;attack_step=24'd23302;decay_step=24'd700;
  sustain_level=24'd13421772;release_base=24'd2913;
  case(preset)
   3'd0:begin
    attack_step=24'd23302;sustain_level=24'd13421772;release_base=24'd2913;
    decay_step=24'd700;
    case(partial_id)
     0:weight=9'd212;
     1:weight=9'd25;
     2:weight=9'd12;
     3:weight=9'd7;
     4:weight=9'd0;
     5:weight=9'd0;
     6:weight=9'd0;
     7:weight=9'd0;
     8:weight=9'd0;
     9:weight=9'd0;
     10:weight=9'd0;
     11:weight=9'd0;
     12:weight=9'd0;
     13:weight=9'd0;
     14:weight=9'd0;
     15:weight=9'd0;
     16:weight=9'd0;
     17:weight=9'd0;
     18:weight=9'd0;
     19:weight=9'd0;
     20:weight=9'd0;
     21:weight=9'd0;
     22:weight=9'd0;
     23:weight=9'd0;
     24:weight=9'd0;
     25:weight=9'd0;
     26:weight=9'd0;
     27:weight=9'd0;
     28:weight=9'd0;
     29:weight=9'd0;
     30:weight=9'd0;
     31:weight=9'd0;
     default:weight=9'd0;
    endcase
   end
   3'd1:begin
    attack_step=24'd116509;sustain_level=24'd16777215;release_base=24'd4370;
    decay_step=24'd0;
    case(partial_id)
     0:weight=9'd116;
     1:weight=9'd46;
     2:weight=9'd15;
     3:weight=9'd18;
     4:weight=9'd8;
     5:weight=9'd6;
     6:weight=9'd5;
     7:weight=9'd7;
     8:weight=9'd3;
     9:weight=9'd3;
     10:weight=9'd3;
     11:weight=9'd2;
     12:weight=9'd2;
     13:weight=9'd2;
     14:weight=9'd2;
     15:weight=9'd2;
     16:weight=9'd1;
     17:weight=9'd1;
     18:weight=9'd1;
     19:weight=9'd1;
     20:weight=9'd1;
     21:weight=9'd1;
     22:weight=9'd1;
     23:weight=9'd1;
     24:weight=9'd1;
     25:weight=9'd1;
     26:weight=9'd1;
     27:weight=9'd1;
     28:weight=9'd1;
     29:weight=9'd1;
     30:weight=9'd1;
     31:weight=9'd1;
     default:weight=9'd0;
    endcase
   end
   3'd2:begin
    attack_step=24'd174763;sustain_level=24'd0;release_base=24'd3496;
    case(partial_id)
     0:decay_step=24'd1166;
     1:decay_step=24'd1305;
     2:decay_step=24'd1445;
     3:decay_step=24'd1585;
     4:decay_step=24'd1725;
     5:decay_step=24'd1865;
     6:decay_step=24'd2004;
     7:decay_step=24'd2144;
     8:decay_step=24'd2284;
     9:decay_step=24'd2424;
     10:decay_step=24'd2564;
     11:decay_step=24'd2703;
     12:decay_step=24'd2843;
     13:decay_step=24'd2983;
     14:decay_step=24'd3123;
     15:decay_step=24'd3263;
     16:decay_step=24'd3403;
     17:decay_step=24'd3542;
     18:decay_step=24'd3682;
     19:decay_step=24'd3822;
     20:decay_step=24'd3962;
     21:decay_step=24'd4102;
     22:decay_step=24'd4241;
     23:decay_step=24'd4381;
     24:decay_step=24'd4521;
     25:decay_step=24'd4661;
     26:decay_step=24'd4801;
     27:decay_step=24'd4940;
     28:decay_step=24'd5080;
     29:decay_step=24'd5220;
     30:decay_step=24'd5360;
     31:decay_step=24'd5500;
     default:decay_step=24'd1000;
    endcase
    case(partial_id)
     0:weight=9'd159;
     1:weight=9'd40;
     2:weight=9'd18;
     3:weight=9'd10;
     4:weight=9'd6;
     5:weight=9'd4;
     6:weight=9'd3;
     7:weight=9'd3;
     8:weight=9'd2;
     9:weight=9'd2;
     10:weight=9'd1;
     11:weight=9'd1;
     12:weight=9'd1;
     13:weight=9'd1;
     14:weight=9'd1;
     15:weight=9'd1;
     16:weight=9'd1;
     17:weight=9'd1;
     18:weight=9'd1;
     19:weight=9'd0;
     20:weight=9'd0;
     21:weight=9'd0;
     22:weight=9'd0;
     23:weight=9'd0;
     24:weight=9'd0;
     25:weight=9'd0;
     26:weight=9'd0;
     27:weight=9'd0;
     28:weight=9'd0;
     29:weight=9'd0;
     30:weight=9'd0;
     31:weight=9'd0;
     default:weight=9'd0;
    endcase
   end
   3'd3:begin
    attack_step=24'd8739;sustain_level=24'd12582911;release_base=24'd1942;
    decay_step=24'd583;
    case(partial_id)
     0:weight=9'd40;
     1:weight=9'd26;
     2:weight=9'd23;
     3:weight=9'd22;
     4:weight=9'd20;
     5:weight=9'd16;
     6:weight=9'd11;
     7:weight=9'd8;
     8:weight=9'd7;
     9:weight=9'd6;
     10:weight=9'd6;
     11:weight=9'd5;
     12:weight=9'd5;
     13:weight=9'd5;
     14:weight=9'd4;
     15:weight=9'd4;
     16:weight=9'd4;
     17:weight=9'd4;
     18:weight=9'd4;
     19:weight=9'd3;
     20:weight=9'd3;
     21:weight=9'd3;
     22:weight=9'd3;
     23:weight=9'd3;
     24:weight=9'd3;
     25:weight=9'd3;
     26:weight=9'd3;
     27:weight=9'd3;
     28:weight=9'd3;
     29:weight=9'd2;
     30:weight=9'd2;
     31:weight=9'd2;
     default:weight=9'd0;
    endcase
   end
   3'd4:begin
    attack_step=24'd174763;sustain_level=24'd0;release_base=24'd2185;
    case(partial_id)
     0:decay_step=24'd500;
     1:decay_step=24'd560;
     2:decay_step=24'd620;
     3:decay_step=24'd680;
     4:decay_step=24'd739;
     5:decay_step=24'd799;
     6:decay_step=24'd859;
     7:decay_step=24'd919;
     8:decay_step=24'd979;
     9:decay_step=24'd1039;
     10:decay_step=24'd1099;
     11:decay_step=24'd1159;
     12:decay_step=24'd1219;
     13:decay_step=24'd1279;
     14:decay_step=24'd1339;
     15:decay_step=24'd1399;
     16:decay_step=24'd1459;
     17:decay_step=24'd1518;
     18:decay_step=24'd1578;
     19:decay_step=24'd1638;
     20:decay_step=24'd1698;
     21:decay_step=24'd1758;
     22:decay_step=24'd1818;
     23:decay_step=24'd1878;
     24:decay_step=24'd1938;
     25:decay_step=24'd1998;
     26:decay_step=24'd2058;
     27:decay_step=24'd2118;
     28:decay_step=24'd2178;
     29:decay_step=24'd2237;
     30:decay_step=24'd2297;
     31:decay_step=24'd2357;
     default:decay_step=24'd1000;
    endcase
    case(partial_id)
     0:weight=9'd157;
     1:weight=9'd29;
     2:weight=9'd22;
     3:weight=9'd8;
     4:weight=9'd9;
     5:weight=9'd4;
     6:weight=9'd5;
     7:weight=9'd2;
     8:weight=9'd3;
     9:weight=9'd2;
     10:weight=9'd2;
     11:weight=9'd1;
     12:weight=9'd2;
     13:weight=9'd1;
     14:weight=9'd1;
     15:weight=9'd1;
     16:weight=9'd1;
     17:weight=9'd1;
     18:weight=9'd1;
     19:weight=9'd1;
     20:weight=9'd1;
     21:weight=9'd0;
     22:weight=9'd1;
     23:weight=9'd0;
     24:weight=9'd1;
     25:weight=9'd0;
     26:weight=9'd0;
     27:weight=9'd0;
     28:weight=9'd0;
     29:weight=9'd0;
     30:weight=9'd0;
     31:weight=9'd0;
     default:weight=9'd0;
    endcase
   end
   3'd5:begin
    attack_step=24'd174763;sustain_level=24'd0;release_base=24'd1399;
    case(partial_id)
     0:decay_step=24'd250;
     1:decay_step=24'd280;
     2:decay_step=24'd310;
     3:decay_step=24'd340;
     4:decay_step=24'd370;
     5:decay_step=24'd400;
     6:decay_step=24'd430;
     7:decay_step=24'd460;
     8:decay_step=24'd490;
     9:decay_step=24'd520;
     10:decay_step=24'd550;
     11:decay_step=24'd580;
     12:decay_step=24'd610;
     13:decay_step=24'd640;
     14:decay_step=24'd670;
     15:decay_step=24'd700;
     16:decay_step=24'd730;
     17:decay_step=24'd759;
     18:decay_step=24'd789;
     19:decay_step=24'd819;
     20:decay_step=24'd849;
     21:decay_step=24'd879;
     22:decay_step=24'd909;
     23:decay_step=24'd939;
     24:decay_step=24'd969;
     25:decay_step=24'd999;
     26:decay_step=24'd1029;
     27:decay_step=24'd1059;
     28:decay_step=24'd1089;
     29:decay_step=24'd1119;
     30:decay_step=24'd1149;
     31:decay_step=24'd1179;
     default:decay_step=24'd1000;
    endcase
    case(partial_id)
     0:weight=9'd121;
     1:weight=9'd43;
     2:weight=9'd23;
     3:weight=9'd15;
     4:weight=9'd11;
     5:weight=9'd6;
     6:weight=9'd5;
     7:weight=9'd4;
     8:weight=9'd3;
     9:weight=9'd3;
     10:weight=9'd2;
     11:weight=9'd2;
     12:weight=9'd2;
     13:weight=9'd2;
     14:weight=9'd1;
     15:weight=9'd1;
     16:weight=9'd1;
     17:weight=9'd1;
     18:weight=9'd1;
     19:weight=9'd1;
     20:weight=9'd1;
     21:weight=9'd1;
     22:weight=9'd1;
     23:weight=9'd1;
     24:weight=9'd1;
     25:weight=9'd1;
     26:weight=9'd1;
     27:weight=9'd1;
     28:weight=9'd0;
     29:weight=9'd0;
     30:weight=9'd0;
     31:weight=9'd0;
     default:weight=9'd0;
    endcase
   end
   3'd6:begin
    attack_step=24'd349526;sustain_level=24'd0;release_base=24'd3496;
    case(partial_id)
     0:decay_step=24'd1589;
     1:decay_step=24'd1780;
     2:decay_step=24'd1971;
     3:decay_step=24'd2161;
     4:decay_step=24'd2352;
     5:decay_step=24'd2543;
     6:decay_step=24'd2733;
     7:decay_step=24'd2924;
     8:decay_step=24'd3114;
     9:decay_step=24'd3305;
     10:decay_step=24'd3496;
     11:decay_step=24'd3686;
     12:decay_step=24'd3877;
     13:decay_step=24'd4068;
     14:decay_step=24'd4258;
     15:decay_step=24'd4449;
     16:decay_step=24'd4640;
     17:decay_step=24'd4830;
     18:decay_step=24'd5021;
     19:decay_step=24'd5212;
     20:decay_step=24'd5402;
     21:decay_step=24'd5593;
     22:decay_step=24'd5784;
     23:decay_step=24'd5974;
     24:decay_step=24'd6165;
     25:decay_step=24'd6356;
     26:decay_step=24'd6546;
     27:decay_step=24'd6737;
     28:decay_step=24'd6927;
     29:decay_step=24'd7118;
     30:decay_step=24'd7309;
     31:decay_step=24'd7499;
     default:decay_step=24'd1000;
    endcase
    case(partial_id)
     0:weight=9'd51;
     1:weight=9'd51;
     2:weight=9'd21;
     3:weight=9'd21;
     4:weight=9'd12;
     5:weight=9'd12;
     6:weight=9'd9;
     7:weight=9'd9;
     8:weight=9'd6;
     9:weight=9'd6;
     10:weight=9'd5;
     11:weight=9'd5;
     12:weight=9'd4;
     13:weight=9'd4;
     14:weight=9'd3;
     15:weight=9'd3;
     16:weight=9'd3;
     17:weight=9'd3;
     18:weight=9'd3;
     19:weight=9'd3;
     20:weight=9'd2;
     21:weight=9'd2;
     22:weight=9'd2;
     23:weight=9'd2;
     24:weight=9'd2;
     25:weight=9'd2;
     26:weight=9'd2;
     27:weight=9'd2;
     28:weight=9'd2;
     29:weight=9'd2;
     30:weight=9'd1;
     31:weight=9'd1;
     default:weight=9'd0;
    endcase
   end
   default:begin weight=9'd0;end
  endcase
 end
endmodule

// V8.2: 32 genuinely independent phase/envelope STATES per voice,
// with one SHARED arithmetic datapath (time-multiplexed at 35MHz).
// This avoids 32 copies of constant-frequency multipliers and 32 wide
// ADSR arithmetic networks *per voice*. All 32 components are visited
// during EVERY audio frame, not one component per 48kHz frame.
// A complete 32-component pass takes 32*7+3 = 227 clocks per voice,
// while the nominal 48kHz frame has 729.17 clocks at 35MHz.
// No recorded audio, external CPU, DSP IP, or derived clock is required.
module instrument_voice32 #(parameter integer VOICE_INDEX=0)(
    input wire clk, rst_n, sample_tick, note_on, note_start,
    input wire [31:0] phase_inc,
    input wire [2:0] timbre_sel, input wire [1:0] layer_mode,
    input wire diagnostic_mode,
    input wire [5:0] release_period,
    input wire [7:0] expression_gain,
    output reg signed [15:0] audio_data,
    output reg pcm_valid, output reg [5:0] active_partials,
    input wire [7:0] diagnostic_count
);
    // Control events arrive asynchronously to the PCM-frame enable but are
    // synchronous to clk. Retain the brief note_start pulse until the frame.
    reg start_pending;
    reg [2:0] pending_preset, active_preset;
    reg [1:0] active_layer;
    reg [5:0] pending_release, active_release;
    reg diagnostic_previous;
    wire mode_changed = (diagnostic_mode != diagnostic_previous);
    wire restart = note_on && (note_start || start_pending);
    wire [2:0] next_preset = restart ? (note_start ? timbre_sel : pending_preset) : active_preset;
    // The momentary LOW/HIGH modifier can change a held note at every PCM
    // frame, without resetting phase or retriggering ADSR. Release tails
    // retain their final octave when note_on goes low.
    wire [1:0] next_layer = note_on ? layer_mode : active_layer;
    wire [5:0] next_release = restart ? (note_start ? release_period : pending_release) : active_release;
    // These are stable throughout an audio frame.
    reg [2:0] preset_frame;
    reg diagnostic_frame, frame_restart, frame_clear, note_frame;
    reg [7:0] diag_count_frame, gain_snapshot;
    reg [35:0] fundamental_frame, harmonic_run, paired_run;
    reg [4:0] index;

    wire [35:0] new_fundamental =
        (next_layer == 2'd1) ? ({4'b0,phase_inc} << 1) :
        (next_layer == 2'd2) ? ({4'b0,phase_inc} >> 1) : {4'b0,phase_inc};

    // Asynchronous reset is limited to control/valid bits; NOT to data RAM.
    // This keeps memory inference possible (no 32-address reset loop).
    reg [31:0] phase_state [0:31];
    reg [23:0] envelope_level [0:31];
    reg [2:0] envelope_state [0:31];
    reg [31:0] valid_mask;
    reg [31:0] phase_read;
    reg [23:0] env_level_read;
    reg [2:0] env_state_read;
    reg prior_valid;

    // One dynamic preset decoder is shared by all 32 partials in a voice.
    wire [8:0] params_weight;
    wire [23:0] params_attack, params_decay, params_sustain, params_release;
    instrument_params32 params(
        .partial_id(index), .preset(preset_frame), .release_period(active_release),
        .weight(params_weight), .attack_step(params_attack),
        .decay_step(params_decay), .sustain_level(params_sustain),
        .release_step(params_release)
    );
    reg [8:0] weight_frame;
    reg [23:0] attack_frame, decay_frame, sustain_frame, release_frame;

    // One 21x10 piano inharmonicity multiplier, *not* 32 copies.
    // 5x5 => max h*h is 961. Sequential accumulation supplies h*f0 and
    // ceil(h/2)*f0 with wide adders, not duplicated constant multipliers.
    wire [9:0] stiffness = {5'd0,index} * {5'd0,index};
    reg [35:0] piano_correction;
    wire [35:0] paired_tuned = index[0] ?
        (paired_run + (paired_run >> 10)) :
        (paired_run - (paired_run >> 10));
    wire [35:0] played_inc =
        (preset_frame == 3'd6) ? paired_tuned :
        (preset_frame == 3'd5) ? (harmonic_run + piano_correction) : harmonic_run;
    localparam [31:0] TEST_BASE=(64 + VOICE_INDEX*32*8)*524288;
    wire [31:0] test_inc = TEST_BASE + ({27'd0,index} << 22);
    wire [35:0] inc_wide = diagnostic_frame ? {4'd0,test_inc} : played_inc;
    wire [31:0] selected_inc = inc_wide[31:0];
    wire inc_in_band = (inc_wide != 36'd0) && (inc_wide < 36'd2147483648);
    wire [7:0] global_index = (VOICE_INDEX*32) + {3'd0,index};
    wire test_gate = (global_index < diag_count_frame);
    wire effective_note = diagnostic_frame ? test_gate : note_frame;

    // Per-partial independent ADSR STATE and LEVEL; the adder/subtractor and
    // state-decode hardware are shared, one partial at a time.
    localparam [2:0] E_IDLE=3'd0, E_ATTACK=3'd1, E_DECAY=3'd2,
                     E_SUSTAIN=3'd3, E_RELEASE=3'd4;
    wire [23:0] attack_step_safe = (attack_frame == 0) ? 24'd1 : attack_frame;
    wire [23:0] release_step_safe = (release_frame == 0) ? 24'd1 : release_frame;
    wire [23:0] old_level = prior_valid ? env_level_read : 24'd0;
    wire [2:0] old_state = prior_valid ? env_state_read : E_IDLE;
    wire [24:0] attack_sum = {1'b0,old_level} + {1'b0,attack_step_safe};
    wire [23:0] decay_distance = old_level - sustain_frame;
    reg [2:0] env_next_state;
    reg [23:0] env_next_level;
    always @(*) begin
        env_next_state = old_state;
        env_next_level = old_level;
        if (frame_clear) begin
            env_next_state = E_IDLE;
            env_next_level = 24'd0;
        end else if (frame_restart && effective_note) begin
            env_next_state = E_ATTACK;
            env_next_level = 24'd0;
        end else case (old_state)
            E_IDLE: begin
                env_next_level = 24'd0;
                if (effective_note) env_next_state = E_ATTACK;
            end
            E_ATTACK: begin
                if (!effective_note) env_next_state = E_RELEASE;
                else if (attack_sum >= 25'd16777215) begin
                    env_next_level = 24'd16777215;
                    env_next_state = E_DECAY;
                end else env_next_level = attack_sum[23:0];
            end
            E_DECAY: begin
                if (!effective_note) env_next_state = E_RELEASE;
                else if (old_level <= sustain_frame || decay_distance <= decay_frame) begin
                    env_next_level = sustain_frame;
                    env_next_state = E_SUSTAIN;
                end else if (decay_frame != 0) env_next_level = old_level - decay_frame;
            end
            E_SUSTAIN: begin
                env_next_level = sustain_frame;
                if (!effective_note) env_next_state = E_RELEASE;
            end
            E_RELEASE: begin
                if (effective_note) begin
                    env_next_level = 24'd0;
                    env_next_state = E_ATTACK;
                end else if (old_level <= release_step_safe) begin
                    env_next_level = 24'd0;
                    env_next_state = E_IDLE;
                end else env_next_level = old_level - release_step_safe;
            end
            default: begin
                env_next_state = E_IDLE;
                env_next_level = 24'd0;
            end
        endcase
    end

    // 65-point quarter sine table gives 256 phase positions per full cycle.
    function signed [15:0] sine256;
        input [7:0] p;
        reg [6:0] address;
        reg signed [15:0] magnitude;
        begin
            address=p[6] ? (7'd64-{1'b0,p[5:0]}) : {1'b0,p[5:0]};
            case(address)
                7'd0: magnitude=16'sd0;
                7'd1: magnitude=16'sd294;
                7'd2: magnitude=16'sd589;
                7'd3: magnitude=16'sd883;
                7'd4: magnitude=16'sd1176;
                7'd5: magnitude=16'sd1469;
                7'd6: magnitude=16'sd1761;
                7'd7: magnitude=16'sd2052;
                7'd8: magnitude=16'sd2341;
                7'd9: magnitude=16'sd2629;
                7'd10: magnitude=16'sd2916;
                7'd11: magnitude=16'sd3201;
                7'd12: magnitude=16'sd3483;
                7'd13: magnitude=16'sd3764;
                7'd14: magnitude=16'sd4043;
                7'd15: magnitude=16'sd4319;
                7'd16: magnitude=16'sd4592;
                7'd17: magnitude=16'sd4863;
                7'd18: magnitude=16'sd5131;
                7'd19: magnitude=16'sd5395;
                7'd20: magnitude=16'sd5657;
                7'd21: magnitude=16'sd5915;
                7'd22: magnitude=16'sd6169;
                7'd23: magnitude=16'sd6420;
                7'd24: magnitude=16'sd6667;
                7'd25: magnitude=16'sd6910;
                7'd26: magnitude=16'sd7148;
                7'd27: magnitude=16'sd7383;
                7'd28: magnitude=16'sd7613;
                7'd29: magnitude=16'sd7838;
                7'd30: magnitude=16'sd8059;
                7'd31: magnitude=16'sd8274;
                7'd32: magnitude=16'sd8485;
                7'd33: magnitude=16'sd8691;
                7'd34: magnitude=16'sd8891;
                7'd35: magnitude=16'sd9087;
                7'd36: magnitude=16'sd9276;
                7'd37: magnitude=16'sd9460;
                7'd38: magnitude=16'sd9638;
                7'd39: magnitude=16'sd9811;
                7'd40: magnitude=16'sd9978;
                7'd41: magnitude=16'sd10138;
                7'd42: magnitude=16'sd10293;
                7'd43: magnitude=16'sd10441;
                7'd44: magnitude=16'sd10583;
                7'd45: magnitude=16'sd10719;
                7'd46: magnitude=16'sd10848;
                7'd47: magnitude=16'sd10971;
                7'd48: magnitude=16'sd11087;
                7'd49: magnitude=16'sd11196;
                7'd50: magnitude=16'sd11299;
                7'd51: magnitude=16'sd11394;
                7'd52: magnitude=16'sd11483;
                7'd53: magnitude=16'sd11565;
                7'd54: magnitude=16'sd11640;
                7'd55: magnitude=16'sd11708;
                7'd56: magnitude=16'sd11769;
                7'd57: magnitude=16'sd11823;
                7'd58: magnitude=16'sd11870;
                7'd59: magnitude=16'sd11910;
                7'd60: magnitude=16'sd11942;
                7'd61: magnitude=16'sd11967;
                7'd62: magnitude=16'sd11986;
                7'd63: magnitude=16'sd11996;
                7'd64: magnitude=16'sd12000;
                default: magnitude=16'sd0;
            endcase
            sine256=p[7] ? -magnitude : magnitude;
        end
    endfunction


    localparam [3:0] IDLE=4'd0, PREP=4'd1, PHASE=4'd2, ENV=4'd3,
                     ENV_MUL=4'd4, WEIGHT_MUL=4'd5, ACT=4'd6,
                     SUM=4'd7, GAIN_MUL=4'd8, OUTPUT_PCM=4'd9;
    reg [3:0] state;
    reg [15:0] env_sample;
    reg [8:0] weight_sample;
    reg [5:0] active_count;
    reg signed [15:0] wave;
    reg signed [32:0] env_product;
    reg signed [25:0] weight_product;
    reg [24:0] activity_env_weight;
    reg [32:0] activity_peak;
    reg signed [31:0] accumulator;
    reg signed [40:0] expression_product;
    wire signed [31:0] term = {{14{weight_product[25]}}, weight_product[25:8]};
    reg missed_deadline; // inspection in simulation/SignalTap; not external pin

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            start_pending<=0;
            pending_preset<=0; pending_release<=6'd12;
            active_preset<=0; active_layer<=0; active_release<=6'd12;
            diagnostic_previous<=0;
            preset_frame<=0; diagnostic_frame<=0; frame_restart<=0; frame_clear<=0;
            note_frame<=0; diag_count_frame<=0; gain_snapshot<=0;
            fundamental_frame<=0; harmonic_run<=0; paired_run<=0;
            index<=0;valid_mask<=0;prior_valid<=0;
            phase_read<=0;env_level_read<=0;env_state_read<=0;
            weight_frame<=0;attack_frame<=0;decay_frame<=0;
            sustain_frame<=0;release_frame<=0;piano_correction<=0;
            state<=IDLE;env_sample<=0;weight_sample<=0;active_count<=0;
            wave<=0;env_product<=0;weight_product<=0;
            activity_env_weight<=0;activity_peak<=0;accumulator<=0;
            expression_product<=0;audio_data<=0;pcm_valid<=0;active_partials<=0;
            missed_deadline<=0;
        end else begin
            pcm_valid<=0;
            if (note_start) begin
                start_pending<=1;
                pending_preset<=timbre_sel;
                pending_release<=release_period;
            end
            if (sample_tick && state!=IDLE) missed_deadline<=1;
            case(state)
                IDLE: if (sample_tick) begin
                    start_pending<=0;
                    diagnostic_previous<=diagnostic_mode;
                    if(restart) begin
                        active_preset<=next_preset;
                        active_release<=next_release;
                    end
                    if(note_on) active_layer<=layer_mode;
                    preset_frame<=next_preset;
                    diagnostic_frame<=diagnostic_mode;
                    frame_restart<=mode_changed || (!diagnostic_mode && restart);
                    frame_clear<=mode_changed && !diagnostic_mode && !note_on;
                    note_frame<=note_on;
                    diag_count_frame<=diagnostic_count;
                    gain_snapshot<=diagnostic_mode ? 8'd255 : expression_gain;
                    fundamental_frame<=new_fundamental;
                    harmonic_run<=new_fundamental;
                    paired_run<=new_fundamental;
                    index<=0;accumulator<=0;active_count<=0;
                    state<=PREP;
                end
                PREP: begin
                    phase_read<=phase_state[index];
                    env_level_read<=envelope_level[index];
                    env_state_read<=envelope_state[index];
                    prior_valid<=valid_mask[index];
                    attack_frame<=diagnostic_frame ? 24'd65536 : params_attack;
                    decay_frame<=diagnostic_frame ? 24'd0 : params_decay;
                    sustain_frame<=diagnostic_frame ? 24'hffffff : params_sustain;
                    release_frame<=diagnostic_frame ? 24'd262144 : params_release;
                    weight_frame<=params_weight;
                    piano_correction<=(harmonic_run >> 15) * stiffness;
                    state<=PHASE;
                end
                PHASE: begin
                    // phase_state and envelope_state belong to the same index.
                    // Snapshot the previous phase (or zero on retrigger) before
                    // advancing it with this component's own frequency.
                    wave<=sine256((frame_restart || !prior_valid) ?
                                8'd0 : phase_read[31:24]);
                    phase_state[index] <= (frame_restart ? 32'd0 :
                        (prior_valid ? phase_read : 32'd0) + selected_inc);
                    weight_sample <= diagnostic_frame ? (test_gate ? 9'd8 : 9'd0) :
                                      (inc_in_band ? weight_frame : 9'd0);
                    state<=ENV;
                end
                ENV: begin
                    envelope_state[index]<=env_next_state;
                    envelope_level[index]<=env_next_level;
                    valid_mask[index]<=1'b1;
                    env_sample<=env_next_level[23:8];
                    state<=ENV_MUL;
                end
                ENV_MUL: begin
                    env_product<=wave * $signed({1'b0,env_sample});
                    activity_env_weight<=env_sample * weight_sample;
                    state<=WEIGHT_MUL;
                end
                WEIGHT_MUL: begin
                    weight_product<=$signed(env_product[31:16]) *
                        $signed({1'b0,weight_sample});
                    state<=ACT;
                end
                ACT: begin
                    activity_peak<=activity_env_weight * gain_snapshot;
                    state<=SUM;
                end
                SUM: begin
                    accumulator<=accumulator + term;
                    if(activity_peak>=33'd22906493)active_count<=active_count+1'b1;
                    if(index==5'd31) state<=GAIN_MUL;
                    else begin
                        index<=index+1'b1;
                        harmonic_run<=harmonic_run+fundamental_frame;
                        if(index[0])paired_run<=paired_run+fundamental_frame;
                        state<=PREP;
                    end
                end
                GAIN_MUL: begin
                    expression_product<=accumulator * $signed({1'b0,gain_snapshot});
                    state<=OUTPUT_PCM;
                end
                OUTPUT_PCM: begin
                    audio_data<=expression_product[23:8];
                    active_partials<=active_count;
                    pcm_valid<=1;
                    state<=IDLE;
                end
                default: state<=IDLE;
            endcase
        end
    end
endmodule
