`timescale 1ns/1ps
// Compact menu interface, 800x480. Popup choices never cover the keyboard.
module piano_ui_800x480 #(parameter integer UI_THEME=0)(
 input wire active,input wire [10:0] x,input wire [9:0] y,
 input wire connected,error,input wire [2:0] menu,timbre_sel,
 input wire [1:0] layer_mode,release_mode,
 input wire sustain_enabled,wide_bend,delay_enabled,diagnostic_mode,
 input wire chorus_enabled,reverb_enabled,
 input wire [7:0] master_gain,vibrato_depth,delay_mix,keys_down,
 input wire [3:0] voice_on,input wire [15:0] voice_notes,
 input wire [31:0] voice_gains,input wire [7:0] active_oscillators,voice_layers,
 input wire [11:0] voice_presets,
 input wire [7:0] diagnostic_count,input wire [15:0] clock_frames,
 input wire pipeline_fault,
 input wire [15:0] latency_us,raw_size,input wire latency_valid,
 input wire signed [15:0] scope_sample,scope_prev_sample,input wire scope_ready,
 input wire [3:0] wave_shift,wave_boost,input wire [2:0] visual_mode,
 input wire [6:0] spectrum_height,input wire spectrum_ready,
 input wire [6:0] fft_peak_level,fft_bar_written,fft_bar_read,
 input wire fft_input_seen,input wire xy_pixel_on,
 input wire guide_running,guide_timed_mode,
 input wire [1:0] guide_song_sel,guide_bpm_sel,
 input wire [7:0] guide_step,guide_length,
 input wire [2:0] guide_target_note,guide_physical_key,
 input wire [23:0] keymap_packed,
 input wire recording_active,replaying_active,
 input wire [7:0] guide_correct,guide_wrong,
 output reg [23:0] rgb888_pixel
);
 localparam [23:0] BG=(UI_THEME==1)?24'hF5F1E8:24'h101C2B;
 localparam [23:0] PANEL=(UI_THEME==1)?24'hE5E8DF:24'h223348;
 localparam [23:0] TEXT=(UI_THEME==1)?24'h244044:24'hECF4F4;
 localparam [23:0] MUTED=(UI_THEME==1)?24'h637575:24'h94AABD;
 localparam [23:0] ACCENT=(UI_THEME==1)?24'hE97861:24'h42D5C0;
 localparam [23:0] INK=24'h12343D;
 function in_rect;
  input [10:0] l,r;input [9:0] t,b;
  begin in_rect=(x>=l && x<r && y>=t && y<b);end
 endfunction
 function [7:0] decimal_char;
  input [15:0] number;input [1:0] digit_index;reg [15:0] digit;
  begin case(digit_index)
   0:digit=(number/16'd1000)%16'd10;
   1:digit=(number/16'd100)%16'd10;
   2:digit=(number/16'd10)%16'd10;
   default:digit=number%16'd10;
  endcase decimal_char=8'd48+{4'd0,digit[3:0]};end
 endfunction
 function [7:0] ten_thousands_char;
  input [15:0] number;reg [15:0] digit;
  begin digit=number/16'd10000;ten_thousands_char=8'd48+{4'd0,digit[3:0]};end
 endfunction
 function [7:0] hexchar;
  input [3:0] n;begin hexchar=(n<10)?8'd48+{4'd0,n}:8'd55+{4'd0,n};end
 endfunction
 function [23:0] voice_color;
  input [1:0] n;begin case(n)
   0:voice_color=24'h42D5C0;1:voice_color=24'hB898EF;
   2:voice_color=24'hF4BE68;default:voice_color=24'h79B9EF;
  endcase end
 endfunction
 function [7:0] word_char;
  input [7:0] id;input [3:0] pos;reg [127:0] bits;
  begin case(id)
   8'd0:bits=128'h544f5543482053594e54482020202020; // TOUCH SYNTH
   8'd1:bits=128'h80812020202020202020202020202020; // 音色
   8'd2:bits=128'h82832020202020202020202020202020; // 八度
   8'd3:bits=128'h84802020202020202020202020202020; // 释音
   8'd4:bits=128'h85862020202020202020202020202020; // 效果
   8'd5:bits=128'h464c5554452020202020202020202020; // FLUTE
   8'd6:bits=128'h4f5247414e2020202020202020202020; // ORGAN
   8'd7:bits=128'h504c55434b2020202020202020202020; // PLUCK
   8'd8:bits=128'h56494f4c494e20202020202020202020; // VIOLIN
   8'd9:bits=128'h47554954415220202020202020202020; // GUITAR
   8'd10:bits=128'h5049414e4f2020202020202020202020; // PIANO
   8'd11:bits=128'h4d414e444f4c494e2020202020202020; // MANDOLIN
   8'd12:bits=128'h87882020202020202020202020202020; // 长笛
   8'd13:bits=128'h898a8b20202020202020202020202020; // 管风琴
   8'd14:bits=128'h8c8d2020202020202020202020202020; // 拨弦
   8'd15:bits=128'h8e8f8b20202020202020202020202020; // 小提琴
   8'd16:bits=128'h90912020202020202020202020202020; // 吉他
   8'd17:bits=128'h928b2020202020202020202020202020; // 钢琴
   8'd18:bits=128'h93949520202020202020202020202020; // 曼陀铃
   8'd19:bits=128'h4c4f5720202020202020202020202020; // LOW
   8'd20:bits=128'h4e4f524d202020202020202020202020; // NORM
   8'd21:bits=128'h4f435420202020202020202020202020; // OCT
   8'd22:bits=128'h46415354202020202020202020202020; // FAST
   8'd23:bits=128'h4d454420202020202020202020202020; // MED
   8'd24:bits=128'h534c4f57202020202020202020202020; // SLOW
   8'd25:bits=128'h5355535441494e204f4e202020202020; // SUSTAIN ON
   8'd26:bits=128'h5355535441494e204f46462020202020; // SUSTAIN OFF
   8'd27:bits=128'h96809798202020202020202020202020; // 延音保持
   8'd28:bits=128'h42454e44205749444520202020202020; // BEND WIDE
   8'd29:bits=128'h42454e44204e4152524f572020202020; // BEND NARROW
   8'd30:bits=128'h44454c4159204f4e2020202020202020; // DELAY ON
   8'd31:bits=128'h44454c4159204f464620202020202020; // DELAY OFF
   8'd32:bits=128'h54455354204f4e202020202020202020; // TEST ON
   8'd33:bits=128'h54455354204f46462020202020202020; // TEST OFF
   8'd34:bits=128'h99809a9b202020202020202020202020; // 弯音范围
   8'd35:bits=128'h9c9d8586202020202020202020202020; // 回声效果
   8'd36:bits=128'h9e9fa0a1202020202020202020202020; // 分量测试
   8'd37:bits=128'h434c4f53452020202020202020202020; // CLOSE
   8'd38:bits=128'ha29c2020202020202020202020202020; // 返回
   8'd39:bits=128'ha3a4a5a6202020202020202020202020; // 实时波形
   8'd40:bits=128'h809f2020202020202020202020202020; // 音量
   8'd41:bits=128'ha7802020202020202020202020202020; // 颤音
   8'd42:bits=128'h9c9d2020202020202020202020202020; // 回声
   8'd43:bits=128'h544f554348204f4b2020202020202020; // TOUCH OK
   8'd44:bits=128'h544f5543482045525220202020202020; // TOUCH ERR
   8'd45:bits=128'h434f4e4e454354494e47202020202020; // CONNECTING
   8'd46:bits=128'h43342020202020202020202020202020; // C4
   8'd47:bits=128'h44342020202020202020202020202020; // D4
   8'd48:bits=128'h45342020202020202020202020202020; // E4
   8'd49:bits=128'h46342020202020202020202020202020; // F4
   8'd50:bits=128'h47342020202020202020202020202020; // G4
   8'd51:bits=128'h41342020202020202020202020202020; // A4
   8'd52:bits=128'h42342020202020202020202020202020; // B4
   8'd53:bits=128'h43352020202020202020202020202020; // C5
   8'd54:bits=128'h56312020202020202020202020202020; // V1
   8'd55:bits=128'h56322020202020202020202020202020; // V2
   8'd56:bits=128'h56332020202020202020202020202020; // V3
   8'd57:bits=128'h56342020202020202020202020202020; // V4
   8'd58:bits=128'h2d2d2020202020202020202020202020; // --
   8'd59:bits=128'h54455354202020202020202020202020; // TEST
   8'd60:bits=128'h504544414c2020202020202020202020; // PEDAL
   8'd61:bits=128'h4f464620202020202020202020202020; // OFF
   8'd62:bits=128'h4f4e2020202020202020202020202020; // ON
   8'd63:bits=128'h43484f525553204f4e20202020202020; // CHORUS ON
   8'd64:bits=128'h43484f525553204f4646202020202020; // CHORUS OFF
   8'd65:bits=128'h524556455242204f4e20202020202020; // REVERB ON
   8'd66:bits=128'h524556455242204f4646202020202020; // REVERB OFF
   8'd67:bits=128'h46582041435449564520202020202020; // FX ACTIVE
   8'd68:bits=128'h48494748202020202020202020202020; // HIGH
   8'd69:bits=128'h57415645202020202020202020202020; // V8.3 WAVE
   8'd70:bits=128'h46465420202020202020202020202020; // V8.3 FFT
   8'd71:bits=128'h58592020202020202020202020202020; // V8.3 XY
   8'd72:bits=128'h47554944452020202020202020202020; // V8.3 GUIDE
   8'd73:bits=128'h4354524c202020202020202020202020; // V8.3 CTRL
   8'd74:bits=128'h4c49564520574156452050434d202020; // V8.3 LIVE WAVE PCM
   8'd75:bits=128'h4c495645204646542035313220202020; // V8.3 LIVE FFT 512
   8'd76:bits=128'h50484153452058592020202020202020; // V8.3 PHASE XY
   8'd77:bits=128'h4c454420534f4e472047554944452020; // LED SONG GUIDE
   8'd78:bits=128'h4b455953204c49564520202020202020; // KEYS LIVE
   8'd79:bits=128'h564f4c20202020202020202020202020; // V8.3 VOL
   8'd80:bits=128'h56494220202020202020202020202020; // V8.3 VIB
   8'd81:bits=128'h4543484f202020202020202020202020; // V8.3 ECHO
   8'd82:bits=128'h464654204f4b20202020202020202020; // FFT OK
   8'd83:bits=128'h464654205a45524f2020202020202020; // FFT ZERO
   8'd84:bits=128'h46465420574149542020202020202020; // FFT WAIT
   8'd85:bits=128'h4e4f2050434d20202020202020202020; // NO PCM
   8'd86:bits=128'h5457494e4b4c45202020202020202020; // TWINKLE
   8'd87:bits=128'h5343414c452020202020202020202020; // SCALE
   8'd88:bits=128'h4f444520544f204a4f59202020202020; // ODE TO JOY
   8'd89:bits=128'h534f4e47202020202020202020202020; // SONG
   8'd97:bits=128'h55504c4f414420202020202020202020; // UPLOAD
   8'd98:bits=128'h5245434f5244494e4720202020202020; // RECORDING
   8'd99:bits=128'h5245504c4159494e47202020202020; // REPLAYING
   8'd90:bits=128'h53544152542020202020202020202020; // START
   8'd91:bits=128'h50415553452020202020202020202020; // PAUSE
   8'd92:bits=128'h57414954202020202020202020202020; // WAIT
   8'd93:bits=128'h42454154202020202020202020202020; // BEAT
   8'd94:bits=128'h42504d20202020202020202020202020; // BPM
   8'd95:bits=128'h4e455854202020202020202020202020; // NEXT
   8'd96:bits=128'h444f4e45202020202020202020202020; // DONE
   default:bits=128'h20202020202020202020202020202020;
  endcase
  case(pos)
   4'd0:word_char=bits[127:120];
   4'd1:word_char=bits[119:112];
   4'd2:word_char=bits[111:104];
   4'd3:word_char=bits[103:96];
   4'd4:word_char=bits[95:88];
   4'd5:word_char=bits[87:80];
   4'd6:word_char=bits[79:72];
   4'd7:word_char=bits[71:64];
   4'd8:word_char=bits[63:56];
   4'd9:word_char=bits[55:48];
   4'd10:word_char=bits[47:40];
   4'd11:word_char=bits[39:32];
   4'd12:word_char=bits[31:24];
   4'd13:word_char=bits[23:16];
   4'd14:word_char=bits[15:8];
   4'd15:word_char=bits[7:0];
  endcase end
 endfunction
 reg [2:0] key_index;reg [10:0] key_base;
 reg [2:0] current_key_pitch;
 function [7:0] pitch_letter;
 input [2:0] p;
 begin case(p)
  0,7:pitch_letter="C";1:pitch_letter="D";
  2:pitch_letter="E";3:pitch_letter="F";
  4:pitch_letter="G";5:pitch_letter="A";
  default:pitch_letter="B";
 endcase end
 endfunction
 integer k;
 always @(*)begin
  key_index=0;key_base=0;
  for(k=1;k<8;k=k+1)if(x>=k*100)begin key_index=k[2:0];key_base=k[10:0]*11'd100;end
  current_key_pitch=keymap_packed[key_index*3 +:3];
 end
 reg text_valid,cjk,big;reg [7:0] word_id;reg [1:0] label_octave;
 reg [10:0] text_left,dx,scaled_dx,offset;
 reg [9:0] text_top,dy,scaled_dy;
 reg [23:0] text_color;
 reg [3:0] glyph_pos,glyph_col,glyph_row;
 reg [7:0] glyph_code;
 wire [15:0] glyph_pixels;
 ui_glyph_rom glyph(.code(glyph_code),.row(glyph_row),.pixels(glyph_pixels));
 integer i;
 always @(*)begin
  text_valid=0;cjk=0;big=0;word_id=0;text_left=0;text_top=0;text_color=TEXT;label_octave=layer_mode;
  if(in_rect(11'd16,11'd280,10'd0,10'd32))begin text_valid=1;cjk=1'b0;big=1'b1;word_id=8'd0;text_left=11'd16;text_top=10'd0;text_color=TEXT;end
  if((connected && !error) && in_rect(11'd640,11'd736,10'd8,10'd24))begin text_valid=1;cjk=1'b0;big=1'b0;word_id=8'd43;text_left=11'd640;text_top=10'd8;text_color=ACCENT;end
  if((error) && in_rect(11'd640,11'd748,10'd8,10'd24))begin text_valid=1;cjk=1'b0;big=1'b0;word_id=8'd44;text_left=11'd640;text_top=10'd8;text_color=24'hED7979;end
  if((!connected && !error) && in_rect(11'd640,11'd760,10'd8,10'd24))begin text_valid=1;cjk=1'b0;big=1'b0;word_id=8'd45;text_left=11'd640;text_top=10'd8;text_color=MUTED;end
  if(in_rect(11'd26,11'd58,10'd52,10'd68))begin text_valid=1;cjk=1'b1;big=1'b0;word_id=8'd1;text_left=11'd26;text_top=10'd52;text_color=TEXT;end
  if(in_rect(11'd88,11'd220,10'd52,10'd68))begin text_valid=1;cjk=1'b0;big=1'b0;word_id=8'd5+{5'd0,timbre_sel};text_left=11'd88;text_top=10'd52;text_color=TEXT;end
  // Momentary octave modifier labels, always visible (no popup menu).
  if(in_rect(11'd270,11'd318,10'd52,10'd68))begin text_valid=1;cjk=0;big=0;word_id=8'd19;text_left=11'd270;text_top=10'd52;text_color=(layer_mode==2)?INK:TEXT;end
  if(in_rect(11'd382,11'd442,10'd52,10'd68))begin text_valid=1;cjk=0;big=0;word_id=8'd68;text_left=11'd382;text_top=10'd52;text_color=(layer_mode==1)?INK:TEXT;end
  if(in_rect(11'd478,11'd510,10'd52,10'd68))begin text_valid=1;cjk=1;big=0;word_id=8'd3;text_left=11'd478;text_top=10'd52;text_color=TEXT;end
  if(in_rect(11'd526,11'd586,10'd52,10'd68))begin text_valid=1;cjk=0;big=0;word_id=8'd22+{6'd0,release_mode};text_left=11'd526;text_top=10'd52;text_color=TEXT;end
  if(in_rect(11'd622,11'd654,10'd52,10'd68))begin text_valid=1;cjk=1;big=0;word_id=8'd4;text_left=11'd622;text_top=10'd52;text_color=TEXT;end
  if(in_rect(11'd666,11'd780,10'd52,10'd68))begin text_valid=1;cjk=0;big=0;word_id=(chorus_enabled || reverb_enabled)?8'd67:(delay_enabled?8'd30:8'd31);text_left=11'd666;text_top=10'd52;text_color=TEXT;end
  if(in_rect(11'd288,11'd345,10'd8,10'd24))begin text_valid=1;cjk=0;big=0;word_id=(layer_mode==2)?8'd19:(layer_mode==1)?8'd68:8'd20;text_left=11'd288;text_top=10'd8;text_color=(layer_mode!=0)?ACCENT:MUTED;end
  if((sustain_enabled) && in_rect(11'd352,11'd412,10'd8,10'd24))begin text_valid=1;cjk=1'b0;big=1'b0;word_id=8'd60;text_left=11'd352;text_top=10'd8;text_color=ACCENT;end
  if(in_rect(11'd456,11'd540,10'd8,10'd24))begin text_valid=1;cjk=1'b0;big=1'b0;word_id=8'd252;text_left=11'd456;text_top=10'd8;text_color=MUTED;end
  if(menu==0 && in_rect(11'd60,11'd146,10'd90,10'd106))begin text_valid=1;cjk=0;big=0;word_id=8'd69;text_left=11'd60;text_top=10'd90;text_color=(visual_mode==3'd0)?INK:TEXT;end
  if(menu==0 && in_rect(11'd203,11'd289,10'd90,10'd106))begin text_valid=1;cjk=0;big=0;word_id=8'd70;text_left=11'd203;text_top=10'd90;text_color=(visual_mode==3'd1)?INK:TEXT;end
  if(menu==0 && in_rect(11'd370,11'd456,10'd90,10'd106))begin text_valid=1;cjk=0;big=0;word_id=8'd71;text_left=11'd370;text_top=10'd90;text_color=(visual_mode==3'd2)?INK:TEXT;end
  if(menu==0 && in_rect(11'd507,11'd593,10'd90,10'd106))begin text_valid=1;cjk=0;big=0;word_id=8'd72;text_left=11'd507;text_top=10'd90;text_color=(visual_mode==3'd3)?INK:TEXT;end
  if(menu==0 && in_rect(11'd659,11'd745,10'd90,10'd106))begin text_valid=1;cjk=0;big=0;word_id=8'd73;text_left=11'd659;text_top=10'd90;text_color=(visual_mode==3'd4)?INK:TEXT;end
  if(menu==0 && visual_mode==0 && in_rect(11'd32,11'd192,10'd118,10'd134))begin text_valid=1;cjk=0;big=0;word_id=8'd74;text_left=11'd32;text_top=10'd118;text_color=MUTED;end
  if(menu==0 && visual_mode==1 && in_rect(11'd32,11'd192,10'd118,10'd134))begin text_valid=1;cjk=0;big=0;word_id=8'd75;text_left=11'd32;text_top=10'd118;text_color=MUTED;end
  if(menu==0 && visual_mode==1 && in_rect(11'd656,11'd784,10'd118,10'd134))begin
      text_valid=1;cjk=0;big=0;
      word_id = !spectrum_ready ? 8'd84 :
                 !fft_input_seen ? 8'd85 :
                 (fft_peak_level==0 ? 8'd83 : 8'd82);
      text_left=11'd656;text_top=10'd118;
      text_color=(spectrum_ready && fft_input_seen && fft_peak_level!=0)?ACCENT:MUTED;
  end
  // P: FFT math peak, W: peak of written bar RAM,
  // R: peak successfully read out of the LCD bar RAM read port.
  if(menu==0 && visual_mode==1 && in_rect(11'd644,11'd784,10'd136,10'd152))begin
      text_valid=1;cjk=0;big=0;word_id=8'd253;
      text_left=11'd644;text_top=10'd136;text_color=MUTED;
  end
  if(menu==0 && visual_mode==2 && in_rect(11'd32,11'd192,10'd118,10'd134))begin text_valid=1;cjk=0;big=0;word_id=8'd76;text_left=11'd32;text_top=10'd118;text_color=MUTED;end
  if(menu==0 && visual_mode==3)begin
    if(in_rect(11'd32,11'd220,10'd126,10'd142))begin
      text_valid=1;cjk=0;big=0;word_id=8'd77;
      text_left=11'd32;text_top=10'd126;text_color=ACCENT;end
    if(in_rect(11'd280,11'd472,10'd126,10'd142))begin
      text_valid=1;cjk=0;big=0;word_id=(guide_song_sel==2'd3)?8'd97:(8'd86+{6'd0,guide_song_sel});
      text_left=11'd280;text_top=10'd126;text_color=TEXT;end
    if(in_rect(11'd552,11'd744,10'd126,10'd142))begin
      text_valid=1;cjk=0;big=0;word_id=8'd246;
      text_left=11'd552;text_top=10'd126;text_color=ACCENT;end
    if(in_rect(11'd32,11'd200,10'd148,10'd164))begin
      text_valid=1;cjk=0;big=0;word_id=8'd242;
      text_left=11'd32;text_top=10'd148;text_color=MUTED;end
    if(in_rect(11'd260,11'd510,10'd148,10'd164))begin
      text_valid=1;cjk=0;big=0;word_id=8'd243;
      text_left=11'd260;text_top=10'd148;text_color=MUTED;end
    if(in_rect(11'd606,11'd780,10'd148,10'd164))begin
      text_valid=1;cjk=0;big=0;word_id=8'd244;
      text_left=11'd606;text_top=10'd148;text_color=MUTED;end
    if(in_rect(11'd44,11'd116,10'd191,10'd207))begin
      text_valid=1;cjk=0;big=0;word_id=8'd89;
      text_left=11'd44;text_top=10'd191;text_color=INK;end
    if(in_rect(11'd236,11'd356,10'd191,10'd207))begin
      text_valid=1;cjk=0;big=0;word_id=guide_running?8'd91:8'd90;
      text_left=11'd236;text_top=10'd191;text_color=INK;end
    if(in_rect(11'd424,11'd540,10'd191,10'd207))begin
      text_valid=1;cjk=0;big=0;word_id=guide_timed_mode?8'd93:8'd92;
      text_left=11'd424;text_top=10'd191;text_color=INK;end
    if(in_rect(11'd616,11'd752,10'd191,10'd207))begin
      text_valid=1;cjk=0;big=0;word_id=8'd245;
      text_left=11'd616;text_top=10'd191;text_color=INK;end
  end
  if(menu==0 && (recording_active || replaying_active) &&
     in_rect(11'd560,11'd740,10'd232,10'd248))begin
       text_valid=1;cjk=0;big=0;
       word_id=recording_active?8'd98:8'd99;
       text_left=11'd560;text_top=10'd232;text_color=ACCENT;
  end
  if(menu==0 && visual_mode==4 && in_rect(11'd48,11'd128,10'd136,10'd152))begin text_valid=1;cjk=0;big=0;word_id=8'd79;text_left=11'd48;text_top=10'd136;text_color=TEXT;end
  if(menu==0 && visual_mode==4 && in_rect(11'd48,11'd128,10'd172,10'd188))begin text_valid=1;cjk=0;big=0;word_id=8'd80;text_left=11'd48;text_top=10'd172;text_color=TEXT;end
  if(menu==0 && visual_mode==4 && in_rect(11'd48,11'd128,10'd208,10'd224))begin text_valid=1;cjk=0;big=0;word_id=8'd81;text_left=11'd48;text_top=10'd208;text_color=TEXT;end
  if(menu==0 && visual_mode!=3 && in_rect(11'd20,11'd132,10'd233,10'd249))begin text_valid=1;cjk=0;big=0;word_id=8'd250;text_left=11'd20;text_top=10'd233;text_color=MUTED;end
  if(menu==0 && visual_mode!=3 && in_rect(11'd260,11'd400,10'd233,10'd249))begin text_valid=1;cjk=0;big=0;word_id=8'd247;text_left=11'd260;text_top=10'd233;text_color=pipeline_fault?24'hED7979:ACCENT;end
  if(menu==0 && visual_mode!=3 && in_rect(11'd514,11'd720,10'd233,10'd249))begin text_valid=1;cjk=0;big=0;word_id=8'd252;text_left=11'd514;text_top=10'd233;text_color=MUTED;end
  if(in_rect(key_base+11'd26,key_base+11'd74,10'd418,10'd450))begin text_valid=1;big=1;word_id=8'd46+{5'd0,key_index};text_left=key_base+11'd26;text_top=10'd418;text_color=INK;end
  if((menu==1) && in_rect(11'd30,11'd90,10'd99,10'd115))begin text_valid=1;cjk=1'b0;big=1'b0;word_id=8'd5;text_left=11'd30;text_top=10'd99;text_color=(timbre_sel==3'd0)?INK:TEXT;end
  if((menu==1) && in_rect(11'd160,11'd192,10'd117,10'd133))begin text_valid=1;cjk=1'b1;big=1'b0;word_id=8'd12;text_left=11'd160;text_top=10'd117;text_color=(timbre_sel==3'd0)?INK:MUTED;end
  if((menu==1) && in_rect(11'd286,11'd346,10'd99,10'd115))begin text_valid=1;cjk=1'b0;big=1'b0;word_id=8'd6;text_left=11'd286;text_top=10'd99;text_color=(timbre_sel==3'd1)?INK:TEXT;end
  if((menu==1) && in_rect(11'd416,11'd464,10'd117,10'd133))begin text_valid=1;cjk=1'b1;big=1'b0;word_id=8'd13;text_left=11'd416;text_top=10'd117;text_color=(timbre_sel==3'd1)?INK:MUTED;end
  if((menu==1) && in_rect(11'd542,11'd602,10'd99,10'd115))begin text_valid=1;cjk=1'b0;big=1'b0;word_id=8'd7;text_left=11'd542;text_top=10'd99;text_color=(timbre_sel==3'd2)?INK:TEXT;end
  if((menu==1) && in_rect(11'd672,11'd704,10'd117,10'd133))begin text_valid=1;cjk=1'b1;big=1'b0;word_id=8'd14;text_left=11'd672;text_top=10'd117;text_color=(timbre_sel==3'd2)?INK:MUTED;end
  if((menu==1) && in_rect(11'd30,11'd102,10'd151,10'd167))begin text_valid=1;cjk=1'b0;big=1'b0;word_id=8'd8;text_left=11'd30;text_top=10'd151;text_color=(timbre_sel==3'd3)?INK:TEXT;end
  if((menu==1) && in_rect(11'd160,11'd208,10'd169,10'd185))begin text_valid=1;cjk=1'b1;big=1'b0;word_id=8'd15;text_left=11'd160;text_top=10'd169;text_color=(timbre_sel==3'd3)?INK:MUTED;end
  if((menu==1) && in_rect(11'd286,11'd358,10'd151,10'd167))begin text_valid=1;cjk=1'b0;big=1'b0;word_id=8'd9;text_left=11'd286;text_top=10'd151;text_color=(timbre_sel==3'd4)?INK:TEXT;end
  if((menu==1) && in_rect(11'd416,11'd448,10'd169,10'd185))begin text_valid=1;cjk=1'b1;big=1'b0;word_id=8'd16;text_left=11'd416;text_top=10'd169;text_color=(timbre_sel==3'd4)?INK:MUTED;end
  if((menu==1) && in_rect(11'd542,11'd602,10'd151,10'd167))begin text_valid=1;cjk=1'b0;big=1'b0;word_id=8'd10;text_left=11'd542;text_top=10'd151;text_color=(timbre_sel==3'd5)?INK:TEXT;end
  if((menu==1) && in_rect(11'd672,11'd704,10'd169,10'd185))begin text_valid=1;cjk=1'b1;big=1'b0;word_id=8'd17;text_left=11'd672;text_top=10'd169;text_color=(timbre_sel==3'd5)?INK:MUTED;end
  if((menu==1) && in_rect(11'd30,11'd126,10'd203,10'd219))begin text_valid=1;cjk=1'b0;big=1'b0;word_id=8'd11;text_left=11'd30;text_top=10'd203;text_color=(timbre_sel==3'd6)?INK:TEXT;end
  if((menu==1) && in_rect(11'd160,11'd208,10'd221,10'd237))begin text_valid=1;cjk=1'b1;big=1'b0;word_id=8'd18;text_left=11'd160;text_top=10'd221;text_color=(timbre_sel==3'd6)?INK:MUTED;end
  if((menu==2) && in_rect(11'd32,11'd68,10'd109,10'd125))begin text_valid=1;cjk=1'b0;big=1'b0;word_id=8'd19;text_left=11'd32;text_top=10'd109;text_color=(layer_mode==2'd2)?INK:TEXT;end
  if((menu==2) && in_rect(11'd288,11'd336,10'd109,10'd125))begin text_valid=1;cjk=1'b0;big=1'b0;word_id=8'd20;text_left=11'd288;text_top=10'd109;text_color=(layer_mode==2'd0)?INK:TEXT;end
  if((menu==2) && in_rect(11'd544,11'd580,10'd109,10'd125))begin text_valid=1;cjk=1'b0;big=1'b0;word_id=8'd21;text_left=11'd544;text_top=10'd109;text_color=(layer_mode==2'd1)?INK:TEXT;end
  if((menu==3) && in_rect(11'd32,11'd80,10'd109,10'd125))begin text_valid=1;cjk=1'b0;big=1'b0;word_id=8'd22;text_left=11'd32;text_top=10'd109;text_color=(release_mode==2'd0)?INK:TEXT;end
  if((menu==3) && in_rect(11'd288,11'd324,10'd109,10'd125))begin text_valid=1;cjk=1'b0;big=1'b0;word_id=8'd23;text_left=11'd288;text_top=10'd109;text_color=(release_mode==2'd1)?INK:TEXT;end
  if((menu==3) && in_rect(11'd544,11'd592,10'd109,10'd125))begin text_valid=1;cjk=1'b0;big=1'b0;word_id=8'd24;text_left=11'd544;text_top=10'd109;text_color=(release_mode==2'd2)?INK:TEXT;end
  if((menu==3) && in_rect(11'd32,11'd164,10'd159,10'd175))begin text_valid=1;cjk=1'b0;big=1'b0;word_id=sustain_enabled?8'd25:8'd26;text_left=11'd32;text_top=10'd159;text_color=sustain_enabled?INK:TEXT;end
  if((menu==3) && in_rect(11'd176,11'd240,10'd181,10'd197))begin text_valid=1;cjk=1'b1;big=1'b0;word_id=8'd27;text_left=11'd176;text_top=10'd181;text_color=sustain_enabled?INK:MUTED;end
  if((menu==4) && in_rect(11'd32,11'd164,10'd98,10'd114))begin text_valid=1;cjk=1'b0;big=1'b0;word_id=wide_bend?8'd28:8'd29;text_left=11'd32;text_top=10'd98;text_color=wide_bend?INK:TEXT;end
  if((menu==4) && in_rect(11'd168,11'd232,10'd124,10'd140))begin text_valid=1;cjk=1'b1;big=1'b0;word_id=8'd34;text_left=11'd168;text_top=10'd124;text_color=wide_bend?INK:TEXT;end
  if((menu==4) && in_rect(11'd288,11'd396,10'd98,10'd114))begin text_valid=1;cjk=1'b0;big=1'b0;word_id=delay_enabled?8'd30:8'd31;text_left=11'd288;text_top=10'd98;text_color=delay_enabled?INK:TEXT;end
  if((menu==4) && in_rect(11'd424,11'd488,10'd124,10'd140))begin text_valid=1;cjk=1'b1;big=1'b0;word_id=8'd35;text_left=11'd424;text_top=10'd124;text_color=delay_enabled?INK:TEXT;end
  if((menu==4) && in_rect(11'd544,11'd640,10'd98,10'd114))begin text_valid=1;cjk=1'b0;big=1'b0;word_id=8'd249;text_left=11'd544;text_top=10'd98;text_color=diagnostic_mode?INK:TEXT;end
  if((menu==4) && in_rect(11'd680,11'd744,10'd124,10'd140))begin text_valid=1;cjk=1'b1;big=1'b0;word_id=8'd36;text_left=11'd680;text_top=10'd124;text_color=diagnostic_mode?INK:TEXT;end
  if((menu!=0) && in_rect(11'd550,11'd610,10'd205,10'd221))begin text_valid=1;cjk=1'b0;big=1'b0;word_id=8'd37;text_left=11'd550;text_top=10'd205;text_color=TEXT;end
  if((menu!=0) && in_rect(11'd700,11'd732,10'd226,10'd242))begin text_valid=1;cjk=1'b1;big=1'b0;word_id=8'd38;text_left=11'd700;text_top=10'd226;text_color=MUTED;end
  if(menu==4 && in_rect(11'd32,11'd200,10'd160,10'd176))begin
   text_valid=1;cjk=0;big=0;word_id=chorus_enabled?8'd63:8'd64;
   text_left=32;text_top=160;text_color=chorus_enabled?INK:TEXT;end
  if(menu==4 && in_rect(11'd288,11'd464,10'd160,10'd176))begin
   text_valid=1;cjk=0;big=0;word_id=reverb_enabled?8'd65:8'd66;
   text_left=288;text_top=160;text_color=reverb_enabled?INK:TEXT;end
  if(menu==4 && in_rect(11'd32,11'd176,10'd212,10'd228))begin
   text_valid=1;cjk=0;big=0;word_id=8'd248;text_left=32;text_top=212;text_color=MUTED;end
  if(menu==4 && in_rect(11'd288,11'd432,10'd212,10'd228))begin
   text_valid=1;cjk=0;big=0;word_id=8'd247;text_left=288;text_top=212;
   text_color=pipeline_fault?24'hED7979:ACCENT;end
  dx=x-text_left;dy=y-text_top;scaled_dx=big?(dx>>1):dx;scaled_dy=big?(dy>>1):dy;
  glyph_pos=0;glyph_col=15;glyph_row=scaled_dy[3:0];offset=0;
  if(cjk)begin glyph_pos=scaled_dx[7:4];glyph_col=scaled_dx[3:0];end
  else for(i=0;i<16;i=i+1)if(scaled_dx>=i*12 && scaled_dx<(i+1)*12)begin
   glyph_pos=i[3:0];offset=scaled_dx-i[10:0]*11'd12;glyph_col=offset[3:0];end
  glyph_code=word_char(word_id,glyph_pos);
  if(word_id>=8'd46 && word_id<=8'd53)begin
   if(glyph_pos==0)glyph_code=pitch_letter(current_key_pitch);
   else if(glyph_pos==1)begin
     glyph_code=(current_key_pitch==3'd7)?"5":"4";
     if(label_octave==1)glyph_code=glyph_code+8'd1;
     else if(label_octave==2)glyph_code=glyph_code-8'd1;
   end
  end
  case(word_id)
   8'd242:case(glyph_pos)
     0:glyph_code="S";1:glyph_code="T";2:glyph_code="E";3:glyph_code="P";
     4:glyph_code=" ";5:glyph_code=decimal_char({8'd0,guide_step},1);
     6:glyph_code=decimal_char({8'd0,guide_step},2);
     7:glyph_code=decimal_char({8'd0,guide_step},3);
     8:glyph_code="/";
     9:glyph_code=decimal_char({8'd0,guide_length},1);
     10:glyph_code=decimal_char({8'd0,guide_length},2);
     11:glyph_code=decimal_char({8'd0,guide_length},3);
     default:glyph_code=" ";endcase
   8'd243:case(glyph_pos)
     0:glyph_code="O";1:glyph_code="K";2:glyph_code=" ";
     3:glyph_code=decimal_char({8'd0,guide_correct},1);
     4:glyph_code=decimal_char({8'd0,guide_correct},2);
     5:glyph_code=decimal_char({8'd0,guide_correct},3);
     6:glyph_code=" ";7:glyph_code="B";8:glyph_code="A";9:glyph_code="D";
     10:glyph_code=" ";11:glyph_code=decimal_char({8'd0,guide_wrong},2);
     12:glyph_code=decimal_char({8'd0,guide_wrong},3);
     default:glyph_code=" ";endcase
   8'd244:case(glyph_pos)
     0:glyph_code="B";1:glyph_code="T";2:glyph_code=" ";
     3:glyph_code=guide_running?"1":"0";
     default:glyph_code=" ";endcase
   8'd245:case(glyph_pos)
     0:glyph_code="B";1:glyph_code="P";2:glyph_code="M";3:glyph_code=" ";
     4:glyph_code=guide_bpm_sel==0?"0":(guide_bpm_sel==1?"1":(guide_bpm_sel==2?"1":"1"));
     5:glyph_code=guide_bpm_sel==0?"8":(guide_bpm_sel==1?"0":(guide_bpm_sel==2?"2":"6"));
     6:glyph_code=guide_bpm_sel==0?"0":(guide_bpm_sel==1?"0":(guide_bpm_sel==2?"0":"0"));
     default:glyph_code=" ";endcase
   8'd246:case(glyph_pos)
     0:glyph_code=guide_running?"N":"D";
     1:glyph_code=guide_running?"E":"O";
     2:glyph_code=guide_running?"X":"N";
     3:glyph_code=guide_running?"T":"E";
     4:glyph_code=" ";
     5:glyph_code=guide_running?(guide_target_note==0 || guide_target_note==7 ? "C" :
                     (guide_target_note==1?"D":(guide_target_note==2?"E":
                     (guide_target_note==3?"F":(guide_target_note==4?"G":
                     (guide_target_note==5?"A":"B")))))):" ";
     6:glyph_code=guide_running?(guide_target_note==7?"5":"4"):" ";
     default:glyph_code=" ";endcase
   8'd247:case(glyph_pos)
    0:glyph_code="P";1:glyph_code="I";2:glyph_code="P";3:glyph_code="E";
    4:glyph_code=" ";5:glyph_code=pipeline_fault?"F":"O";
    6:glyph_code=pipeline_fault?"A":"K";7:glyph_code=pipeline_fault?"I":" ";
    8:glyph_code=pipeline_fault?"L":" ";default:glyph_code=" ";endcase
   8'd248:case(glyph_pos)
    0:glyph_code="C";1:glyph_code="L";2:glyph_code="K";3:glyph_code="F";
    4:glyph_code="S";5:glyph_code=" ";
    6:glyph_code=ten_thousands_char(clock_frames);
    7:glyph_code=decimal_char(clock_frames,0);8:glyph_code=decimal_char(clock_frames,1);
    9:glyph_code=decimal_char(clock_frames,2);10:glyph_code=decimal_char(clock_frames,3);
    default:glyph_code=" ";endcase
   8'd249:case(glyph_pos)
    0:glyph_code="T";1:glyph_code="E";2:glyph_code="S";3:glyph_code="T";4:glyph_code=" ";
    5:glyph_code=diagnostic_mode?decimal_char({8'd0,diagnostic_count},1):"O";
    6:glyph_code=diagnostic_mode?decimal_char({8'd0,diagnostic_count},2):"F";
    7:glyph_code=diagnostic_mode?decimal_char({8'd0,diagnostic_count},3):"F";
    default:glyph_code=" ";endcase
   8'd250:case(glyph_pos)
    0:glyph_code="O";1:glyph_code="S";2:glyph_code="C";3:glyph_code=" ";
    4:glyph_code=decimal_char({8'd0,active_oscillators},1);
    5:glyph_code=decimal_char({8'd0,active_oscillators},2);
    6:glyph_code=decimal_char({8'd0,active_oscillators},3);
    default:glyph_code=" ";endcase
   8'd251:case(glyph_pos)
    0:glyph_code="P";1:glyph_code="R";2:glyph_code="O";3:glyph_code="C";4:glyph_code=" ";
    5:glyph_code=latency_valid?decimal_char(latency_us,0):"-";
    6:glyph_code=latency_valid?decimal_char(latency_us,1):"-";
    7:glyph_code=latency_valid?decimal_char(latency_us,2):"-";
    8:glyph_code=latency_valid?decimal_char(latency_us,3):"-";
    9:glyph_code="U";10:glyph_code="S";default:glyph_code=" ";endcase
   8'd253:case(glyph_pos)
     0:glyph_code="P";
     1:glyph_code=hexchar({1'b0,fft_peak_level[6:4]});
     2:glyph_code=hexchar(fft_peak_level[3:0]);
     3:glyph_code=" ";
     4:glyph_code="W";
     5:glyph_code=hexchar({1'b0,fft_bar_written[6:4]});
     6:glyph_code=hexchar(fft_bar_written[3:0]);
     7:glyph_code=" ";
     8:glyph_code="R";
     9:glyph_code=hexchar({1'b0,fft_bar_read[6:4]});
     10:glyph_code=hexchar(fft_bar_read[3:0]);
     default:glyph_code=" ";endcase
   8'd252:case(glyph_pos)
    0:glyph_code="S";1:glyph_code="Z";2:glyph_code=" ";
    3:glyph_code=hexchar(raw_size[15:12]);4:glyph_code=hexchar(raw_size[11:8]);
    5:glyph_code=hexchar(raw_size[7:4]);6:glyph_code=hexchar(raw_size[3:0]);default:glyph_code=" ";endcase
   default:begin end
  endcase
 end
 integer b,v,r;
 reg [10:0] bx;reg [9:0] by;
 reg selected;reg [7:0] slider;
 reg signed [15:0] wave_height;reg signed [16:0] wave_y;reg signed [15:0] wave_prev_height;reg signed [16:0] wave_prev_y;
 wire signed [25:0] wave_boosted =
     $signed({{10{scope_sample[15]}},scope_sample}) <<< wave_boost;
 wire signed [25:0] wave_scaled = wave_boosted >>> wave_shift;
 wire signed [25:0] prev_wave_boosted =
     $signed({{10{scope_prev_sample[15]}},scope_prev_sample}) <<< wave_boost;
 wire signed [25:0] prev_wave_scaled = prev_wave_boosted >>> wave_shift;
  wire [6:0] draw_bar_height = (spectrum_height!=7'd0 && spectrum_height<7'd14) ?
      7'd14 : spectrum_height;
 reg [23:0] key_fill;
 always @(*)begin
  rgb888_pixel=BG;bx=0;by=0;selected=0;slider=0;key_fill=24'hF0F1EB;
  if(wave_scaled>26'sd54)wave_height=16'sd54;
  else if(wave_scaled< -26'sd54)wave_height=-16'sd54;
  else wave_height=wave_scaled[15:0];
  wave_y=17'sd174-$signed({wave_height[15],wave_height});
  if(prev_wave_scaled>26'sd54)wave_prev_height=16'sd54;
  else if(prev_wave_scaled< -26'sd54)wave_prev_height=-16'sd54;
  else wave_prev_height=prev_wave_scaled[15:0];
  wave_prev_y=17'sd174-$signed({wave_prev_height[15],wave_prev_height});
  if(in_rect(11'd16,11'd224,10'd40,10'd80))rgb888_pixel=PANEL;
  if(in_rect(11'd238,11'd342,10'd40,10'd80))rgb888_pixel=(layer_mode==2)?ACCENT:PANEL;
  if(in_rect(11'd354,11'd458,10'd40,10'd80))rgb888_pixel=(layer_mode==1)?ACCENT:PANEL;
  if(in_rect(11'd470,11'd602,10'd40,10'd80))rgb888_pixel=PANEL;
  if(in_rect(11'd614,11'd784,10'd40,10'd80))rgb888_pixel=PANEL;
  if(menu==0)begin
   // Full-width navigation and live view. Original key and top-menu regions remain untouched.
   if(in_rect(11'd16,11'd784,10'd88,10'd252))rgb888_pixel=PANEL;
   for(b=0;b<5;b=b+1)begin
    bx=11'd16+b[10:0]*11'd152;
    if(in_rect(bx,bx+11'd144,10'd88,10'd116))
     rgb888_pixel=(visual_mode==b[2:0])?ACCENT:BG;
   end
   if(in_rect(11'd16,11'd784,10'd116,10'd232))begin
    rgb888_pixel=BG;
    if(y==10'd174 || y==10'd202)rgb888_pixel=PANEL;
    if((x[6:0]==0) && (visual_mode==0 || visual_mode==1))rgb888_pixel=PANEL;
    if(visual_mode==0 && scope_ready && x>=11'd16 && x<11'd784)begin
      if(y==wave_y[9:0] || y==wave_y[9:0]+10'd1 ||
         (x[1:0]==2'd0 &&
          $signed({7'd0,y})>=((wave_y<wave_prev_y)?wave_y:wave_prev_y) &&
          $signed({7'd0,y})<=((wave_y>wave_prev_y)?wave_y:wave_prev_y)))
          rgb888_pixel=ACCENT;
    end else if(visual_mode==1 && x>=11'd16 && x<11'd784)begin
      if(spectrum_ready && spectrum_height!=7'd0 && x[3:0]<4'd12 && y>=10'd118 &&
         {1'b0,y} >= (11'd230-{4'd0,draw_bar_height}))rgb888_pixel=ACCENT;
    end else if(visual_mode==2)begin
      // 2D phase portrait: PCM(t) versus PCM(t-8), not stereo L/R.
      if(in_rect(11'd144,11'd656,10'd116,10'd244) && xy_pixel_on)
       rgb888_pixel=ACCENT;
      if(x==11'd400 || y==10'd180)rgb888_pixel=PANEL;
    end
   end
   if(visual_mode==3)begin
      if(in_rect(11'd16,11'd192,10'd176,10'd224))rgb888_pixel=ACCENT;
      if(in_rect(11'd208,11'd384,10'd176,10'd224))rgb888_pixel=guide_running?ACCENT:PANEL;
      if(in_rect(11'd400,11'd576,10'd176,10'd224))rgb888_pixel=guide_timed_mode?ACCENT:PANEL;
      if(in_rect(11'd592,11'd784,10'd176,10'd224))rgb888_pixel=ACCENT;
   end
   if(visual_mode==4)begin
    for(b=0;b<3;b=b+1)begin
     by=10'd136+b[9:0]*10'd36;
     case(b)0:slider=master_gain;1:slider=vibrato_depth;default:slider=delay_mix;endcase
     if(in_rect(11'd220,11'd732,by,by+10'd12))
      rgb888_pixel=(x-11'd220<{1'b0,slider,1'b0})?ACCENT:BG;
    end
   end
   if(in_rect(11'd16,11'd784,10'd232,10'd252))rgb888_pixel=PANEL;
  end
  if(y>=10'd256)begin
   key_fill=24'hF0F1EB;
   if(visual_mode==3'd3 && guide_running &&
      key_index==guide_physical_key)key_fill=24'hF8DEA0;
   for(v=0;v<4;v=v+1)if(voice_on[v] && voice_notes[v*4 +:4]=={1'b0,key_index})key_fill=voice_color(v[1:0]);
   if(in_rect(key_base+11'd5,key_base+11'd95,10'd256,10'd476))begin
    rgb888_pixel=key_fill;
    if(y<10'd266)rgb888_pixel=voice_color(key_index[1:0]);
    if(y>=10'd469)rgb888_pixel=pressed_color(key_fill,keys_down[key_index]);
   end
  end
  if(menu!=0 && y>=10'd88 && y<10'd256)begin
   rgb888_pixel=BG;
   if(menu==1)for(b=0;b<7;b=b+1)begin
    bx=11'd16;by=10'd96;
    case(b)1,4:bx=11'd272;2,5:bx=11'd528;default:bx=11'd16;endcase
    if(b>=3)by=10'd148;if(b>=6)by=10'd200;
    if(in_rect(bx,bx+11'd240,by,by+10'd44))rgb888_pixel=(timbre_sel==b[2:0])?ACCENT:PANEL;
   end
   else for(b=0;b<3;b=b+1)begin
    bx=11'd16+b[10:0]*11'd256;selected=0;
    if(menu==2)selected=((b==0 && layer_mode==2)||(b==1 && layer_mode==0)||(b==2 && layer_mode==1));
    if(menu==3)selected=(release_mode==b[1:0]);
    if(menu==4)case(b)0:selected=wide_bend;1:selected=delay_enabled;default:selected=diagnostic_mode;endcase
    if(in_rect(bx,bx+11'd240,10'd96,10'd144))rgb888_pixel=selected?ACCENT:PANEL;
   end
   if(menu==3 && in_rect(11'd16,11'd256,10'd156,10'd200))rgb888_pixel=sustain_enabled?ACCENT:PANEL;
   if(menu==4)begin
    if(in_rect(11'd16,11'd256,10'd148,10'd192))
     rgb888_pixel=chorus_enabled?ACCENT:PANEL;
    if(in_rect(11'd272,11'd512,10'd148,10'd192))
     rgb888_pixel=reverb_enabled?ACCENT:PANEL;
   end
   if(in_rect(11'd528,11'd768,10'd200,10'd244))rgb888_pixel=PANEL;
  end
  if(text_valid && glyph_pixels[4'd15-glyph_col])rgb888_pixel=text_color;
  if(!active || x>=11'd800 || y>=10'd480)rgb888_pixel=24'h000000;
 end
 function [23:0] pressed_color;
  input [23:0] color;input pressed;
  begin pressed_color=pressed?ACCENT:color;end
 endfunction
endmodule
