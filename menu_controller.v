`timescale 1ns/1ps
// Menus stay above y256; piano remains playable while a menu is open.
// Trigger buttons on NEW TrackIDs, so held fingers do not repeat actions.
module menu_controller(
 input wire clk,rst_n,connected,frame_valid,
 input wire [2:0] touch_count,input wire [39:0] touch_ids,
 input wire [79:0] touch_x,touch_y,
 output reg [2:0] menu,timbre_sel,
 output wire [1:0] layer_mode,
 output reg [1:0] release_mode,
 output reg sustain_enabled,wide_bend,delay_enabled,diagnostic_mode,
 output reg [7:0] master_gain,vibrato_depth,delay_mix,
 output reg [4:0] control_contacts,
 output reg [7:0] diagnostic_count,
 output reg chorus_enabled,reverb_enabled,
 output reg [2:0] visual_mode,
 output reg [2:0] guide_action,
 input wire remote_timbre_valid,input wire [2:0] remote_timbre,
 input wire [1:0] remote_fx_toggle
);
 reg [39:0] previous_ids;reg [2:0] previous_count;
 reg [9:0] prev_octave_codes,octave_codes;
 reg [4:0] low_held,high_held;
 // 2 = LOW (-12 semitones), 1 = HIGH (+12), 0 = NORM.
 assign layer_mode = ((|low_held) && !(|high_held)) ? 2'd2 :
                     ((|high_held) && !(|low_held)) ? 2'd1 : 2'd0;

 reg [4:0] previous_controls;
 reg [14:0] previous_sliders,slider_contacts;
 integer ci,cj;
 // Classify a contact at its first frame; remember it across packet reorder.
 // A menu finger sliding into the keys must not accidentally start a voice.
 always @(*)begin
  control_contacts=5'd0;slider_contacts=15'd0;
  octave_codes=10'd0;low_held=5'd0;high_held=5'd0;
  for(ci=0;ci<5;ci=ci+1)if(connected && ci<touch_count)begin
   control_contacts[ci]=(touch_y[ci*16 +:16]<16'd256);
   // Two momentary octave keys live in the top bar; latch key identity
   // to a GT911 TrackID, not to the frame index or moving X/Y position.
   if(touch_y[ci*16 +:16]>=16'd40 && touch_y[ci*16 +:16]<16'd80) begin
    if(touch_x[ci*16 +:16]>=16'd238 && touch_x[ci*16 +:16]<16'd342)
     octave_codes[ci*2 +:2]=2'd2;
    else if(touch_x[ci*16 +:16]>=16'd354 && touch_x[ci*16 +:16]<16'd458)
     octave_codes[ci*2 +:2]=2'd1;
   end
   // V8.3: sliders only exist inside CTRL view; visual tabs are not sliders.
   if(menu==0 && visual_mode==3'd4 &&
      touch_x[ci*16 +:16]>=16'd220 && touch_x[ci*16 +:16]<16'd732)begin
    if(touch_y[ci*16 +:16]>=16'd132 && touch_y[ci*16 +:16]<16'd156)slider_contacts[ci*3 +:3]=3'd1;
    if(touch_y[ci*16 +:16]>=16'd168 && touch_y[ci*16 +:16]<16'd192)slider_contacts[ci*3 +:3]=3'd2;
    if(touch_y[ci*16 +:16]>=16'd204 && touch_y[ci*16 +:16]<16'd228)slider_contacts[ci*3 +:3]=3'd3;
   end
   for(cj=0;cj<5;cj=cj+1)
    if(cj<previous_count && touch_ids[ci*8 +:8]==previous_ids[cj*8 +:8])begin
     control_contacts[ci]=previous_controls[cj];
     slider_contacts[ci*3 +:3]=previous_sliders[cj*3 +:3];
     octave_codes[ci*2 +:2]=prev_octave_codes[cj*2 +:2];
    end
  end
  for(ci=0;ci<5;ci=ci+1)begin
   low_held[ci]=(octave_codes[ci*2 +:2]==2'd2);
   high_held[ci]=(octave_codes[ci*2 +:2]==2'd1);
  end
 end
 reg seen,handled;reg [15:0] tx,ty,dx;
 reg [7:0] slider_value;
 integer t,p,col,row,choice;
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin
   previous_ids<=40'd0;previous_count<=3'd0;previous_controls<=5'd0;previous_sliders<=15'd0;prev_octave_codes<=10'd0;
   menu<=3'd0;timbre_sel<=3'd0;release_mode<=2'd1;visual_mode<=3'd0;
   sustain_enabled<=0;wide_bend<=0;delay_enabled<=0;diagnostic_mode<=0;diagnostic_count<=0;
   chorus_enabled<=0;reverb_enabled<=0;
   master_gain<=8'd255;vibrato_depth<=8'd0;delay_mix<=8'd96;
   seen=0;handled=0;tx=0;ty=0;dx=0;slider_value=0;
   col=0;row=0;choice=0;
  end else begin
   // All state updates belong to the same non-reset branch.
   // This is the single valid async reset + clock enable template.
   if(!connected)begin
   previous_count<=0;previous_controls<=0;previous_sliders<=0;prev_octave_codes<=0;menu<=0;sustain_enabled<=0;diagnostic_mode<=0;diagnostic_count<=0;
  end else if(frame_valid)begin
   handled=0;
   for(t=0;t<5;t=t+1)if(t<touch_count)begin
    tx=touch_x[t*16 +:16];ty=touch_y[t*16 +:16];seen=0;
    for(p=0;p<5;p=p+1)
     if(p<previous_count && touch_ids[t*8 +:8]==previous_ids[p*8 +:8])seen=1;
    if(menu==0 && visual_mode==3'd4 && slider_contacts[t*3 +:3]!=0 &&
       tx>=16'd220 && tx<16'd732)begin
     dx=tx-16'd220;slider_value=dx[8:1];
     if(dx==16'd511)slider_value=8'd255;
     if(slider_contacts[t*3 +:3]==1 && ty>=16'd132 && ty<16'd156)master_gain<=slider_value;
     if(slider_contacts[t*3 +:3]==2 && ty>=16'd168 && ty<16'd192)vibrato_depth<=slider_value;
     if(slider_contacts[t*3 +:3]==3 && ty>=16'd204 && ty<16'd228)delay_mix<=slider_value;
    end
    if(!seen && !handled && tx<16'd800 && ty<16'd256)begin
     if(ty>=16'd40 && ty<16'd80)begin
      if(tx>=16'd16 && tx<16'd224)begin menu<=(menu==1)?3'd0:3'd1;handled=1;end
      // LOW / HIGH keys deliberately do not open a persistent menu.
      else if(tx>=16'd470 && tx<16'd602)begin menu<=(menu==3)?3'd0:3'd3;handled=1;end
      else if(tx>=16'd614 && tx<16'd784)begin menu<=(menu==4)?3'd0:3'd4;handled=1;end
     end else if(menu==0 && ty>=16'd88 && ty<16'd116)begin
      // WAVE / FFT / XY / GUIDE / CTRL, new TrackID only.
      if(tx>=16'd16 && tx<16'd160) begin visual_mode<=3'd0;handled=1;end
      else if(tx>=16'd168 && tx<16'd312) begin visual_mode<=3'd1;handled=1;end
      else if(tx>=16'd320 && tx<16'd464) begin visual_mode<=3'd2;handled=1;end
      else if(tx>=16'd472 && tx<16'd616) begin visual_mode<=3'd3;handled=1;end
      else if(tx>=16'd624 && tx<16'd784) begin visual_mode<=3'd4;handled=1;end
     end else if(menu!=0 && ty>=16'd88)begin
      col=-1;row=-1;
      if(tx>=16'd16 && tx<16'd256)col=0;
      else if(tx>=16'd272 && tx<16'd512)col=1;
      else if(tx>=16'd528 && tx<16'd768)col=2;
      if(ty>=16'd96 && ty<16'd140)row=0;
      else if(ty>=16'd148 && ty<16'd192)row=1;
      else if(ty>=16'd200 && ty<16'd244)row=2;
      choice=row*3+col;
      case(menu)
       3'd1:if(col>=0 && row>=0 && choice<7)begin
        timbre_sel<=choice[2:0];menu<=0;end
       3'd3:begin
        if(col>=0 && ty>=16'd96 && ty<16'd144)begin release_mode<=col[1:0];menu<=0;end
        if(tx>=16'd16 && tx<16'd256 && ty>=16'd156 && ty<16'd200)
         sustain_enabled<=~sustain_enabled;
       end
       3'd4:begin
        if(col>=0 && ty>=16'd148 && ty<16'd192)begin
         if(col==0)chorus_enabled<=~chorus_enabled;
         else if(col==1)reverb_enabled<=~reverb_enabled;
        end
        if(col>=0 && ty>=16'd96 && ty<16'd144)begin
         if(col==0)wide_bend<=~wide_bend;
         else if(col==1)delay_enabled<=~delay_enabled;
         else begin
         // New contact advances one tier; held contacts never auto-repeat.
         case(diagnostic_count)
          8'd0:begin diagnostic_count<=8'd1;diagnostic_mode<=1;end
          8'd1:diagnostic_count<=8'd8;
          8'd8:diagnostic_count<=8'd16;
          8'd16:diagnostic_count<=8'd32;
          8'd32:diagnostic_count<=8'd64;
          8'd64:diagnostic_count<=8'd128;
          default:begin diagnostic_count<=0;diagnostic_mode<=0;end
         endcase
         end
        end
       end
       default:menu<=0;
      endcase
      // Explicit close cell; other blank areas do not change settings.
      if(tx>=16'd528 && tx<16'd768 && ty>=16'd200 && ty<16'd244)menu<=0;
      handled=1;
     end
    end
   end
   previous_ids<=touch_ids;previous_controls<=control_contacts;previous_sliders<=slider_contacts;prev_octave_codes<=octave_codes;
   previous_count<=(touch_count>3'd5)?3'd5:touch_count;
  end
  // Remote controls are applied after local UI events. They also work
  // while GT911 is disconnected. Reset always has priority.
  // They are intentionally INSIDE the outer `else` of if(!rst_n).
    if(remote_timbre_valid && remote_timbre<3'd7)timbre_sel<=remote_timbre;
    case(remote_fx_toggle)
      2'd1:delay_enabled<=~delay_enabled;
      2'd2:chorus_enabled<=~chorus_enabled;
      2'd3:reverb_enabled<=~reverb_enabled;
      default:begin end
    endcase
  end
 end
 // GUIDE actions use combinational TrackID edge recognition, followed
 // by exactly one output register. No un-reset scratch FF is inferred.
 function guide_id_is_new;
   input [7:0] current_id;
   input [2:0] old_count;
   input [39:0] old_ids;
   integer k;
   begin
     guide_id_is_new=1'b1;
     for(k=0;k<5;k=k+1)
       if(k<old_count && current_id==old_ids[k*8 +:8])
         guide_id_is_new=1'b0;
   end
 endfunction
 reg [2:0] guide_next_action;
 integer g;
 always @(*) begin
   guide_next_action=3'd0;
   if(connected && frame_valid && menu==0 && visual_mode==3'd3)begin
     for(g=0;g<5;g=g+1)begin
       if(g<touch_count &&
          touch_y[g*16 +:16]>=16'd176 &&
          touch_y[g*16 +:16]<16'd224 &&
          guide_id_is_new(touch_ids[g*8 +:8],previous_count,previous_ids))begin
         if(touch_x[g*16 +:16]>=16'd16 && touch_x[g*16 +:16]<16'd192)
             guide_next_action=3'd1;
         else if(touch_x[g*16 +:16]>=16'd208 && touch_x[g*16 +:16]<16'd384)
             guide_next_action=3'd2;
         else if(touch_x[g*16 +:16]>=16'd400 && touch_x[g*16 +:16]<16'd576)
             guide_next_action=3'd3;
         else if(touch_x[g*16 +:16]>=16'd592 && touch_x[g*16 +:16]<16'd784)
             guide_next_action=3'd4;
       end
     end
   end
 end
 always @(posedge clk or negedge rst_n)begin
   if(!rst_n)guide_action<=3'd0;
   else guide_action<=guide_next_action;
 end
endmodule

// Pedal-like sustain: released slots remain sounding until pedal-off or reuse.
module sustain_manager(
 input wire clk,rst_n,connected,enabled,
 input wire [3:0] voice_on,voice_start,output wire [3:0] synth_on
);
 reg [3:0] previous_on,held;
 assign synth_on=voice_on|held;
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin previous_on<=0;held<=0;end
  else begin
   previous_on<=voice_on;
   if(!connected || !enabled)held<=0;
   else held<=(held|(previous_on&~voice_on))&~voice_start;
  end
 end
endmodule
