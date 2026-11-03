`timescale 1ns/1ps
// Four songs: three immutable ROM songs and slot 3 downloaded via HC-05 RAM.
// All song indices represent *pitch*, not physical key position.
module guide_sequencer_v87(
 input wire clk,rst_n,
 input wire [2:0] ui_action,remote_action,
 input wire remote_song_valid,input wire [1:0] remote_song,
 input wire remote_bpm_valid,input wire [1:0] remote_bpm,
 input wire [3:0] voice_start,input wire [15:0] voice_notes,
 input wire song_uploaded,input wire [7:0] uploaded_length,
 input wire [2:0] uploaded_note,input wire [1:0] uploaded_beats,
 input wire [2:0] physical_key_for_note,
 output reg playing,timed_mode,
 output reg [1:0] song_sel,bpm_sel,
 output reg [7:0] song_step,
 output wire [7:0] song_length,
 output wire [2:0] next_note,
 output reg [7:0] correct_count,wrong_count,
 output wire [7:0] led_n
);
 wire [2:0] builtin_note;
 wire [1:0] builtin_beats;
 wire [4:0] builtin_length;
 guide_song_rom_v84 builtin(
 .song(song_sel),.index(song_step[4:0]),
 .note(builtin_note),.beats(builtin_beats),.length(builtin_length));
 assign song_length=(song_sel==2'd3) ?
                    (song_uploaded?uploaded_length:8'd0) : {3'd0,builtin_length};
 assign next_note=(song_sel==2'd3)?uploaded_note:builtin_note;
 wire [1:0] duration=(song_sel==2'd3)?uploaded_beats:builtin_beats;
 reg [24:0] beat_counter,beat_limit;
 reg [1:0] beats_elapsed;
 reg step_hit;
 reg [22:0] wrong_flash;
 reg matched,any_new;
 integer v;
 always @(*)begin
   matched=0;any_new=0;
   for(v=0;v<4;v=v+1)
    if(voice_start[v])begin
      any_new=1;
      if(voice_notes[v*4+:4]=={1'b0,next_note})matched=1;
    end
 end
 always @(*)begin
    case(bpm_sel)
      0:beat_limit=25'd26250000;
      1:beat_limit=25'd21000000;
      2:beat_limit=25'd17500000;
      default:beat_limit=25'd13125000;
    endcase
 end
 wire [2:0] action=remote_action!=0?remote_action:ui_action;
 wire beat_edge=beat_counter>=beat_limit-25'd1;
 wire [7:0] led_mask=(8'b00000001<<physical_key_for_note);
 wire blank_beat=beat_counter<(beat_limit>>3);
 assign led_n=(!playing || song_length==0 || blank_beat)?8'hff :
              wrong_flash!=0?8'h00:~led_mask;
 always @(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
      playing<=0;timed_mode<=0;song_sel<=0;bpm_sel<=2'd2;
      song_step<=0;correct_count<=0;wrong_count<=0;
      beat_counter<=0;beats_elapsed<=0;step_hit<=0;wrong_flash<=0;
    end else begin
      if(wrong_flash!=0)wrong_flash<=wrong_flash-23'd1;
      if(!playing)beat_counter<=0;
      else if(beat_edge)beat_counter<=0;
      else beat_counter<=beat_counter+25'd1;
      if(playing && beat_edge && timed_mode)begin
       if(beats_elapsed+2'd1 >= duration)begin
         beats_elapsed<=0;step_hit<=0;
         if(!step_hit && wrong_count!=8'hff)wrong_count<=wrong_count+8'd1;
         if(song_step+8'd1>=song_length)begin
            playing<=0;song_step<=song_length;
         end else song_step<=song_step+8'd1;
       end else beats_elapsed<=beats_elapsed+2'd1;
      end
      if(playing && any_new)begin
       if(matched)begin
          if(!step_hit && correct_count!=8'hff)correct_count<=correct_count+8'd1;
          step_hit<=1;
          if(!timed_mode)begin
            beat_counter<=0;beats_elapsed<=0;step_hit<=0;
            if(song_step+8'd1>=song_length)begin
               playing<=0;song_step<=song_length;
            end else song_step<=song_step+8'd1;
          end
       end else begin
         if(wrong_count!=8'hff)wrong_count<=wrong_count+8'd1;
         wrong_flash<=23'd3500000;
       end
      end
      if(action==3'd1 || remote_song_valid)begin
         if(remote_song_valid) song_sel<=
             (remote_song==2'd3 && !song_uploaded)?2'd0:remote_song;
         else if(song_sel==2'd2 && !song_uploaded) song_sel<=2'd0;
         else song_sel<=song_sel+2'd1;
         song_step<=0;playing<=0;beats_elapsed<=0;step_hit<=0;
         correct_count<=0;wrong_count<=0;beat_counter<=0;
      end else if(action==3'd2)begin
         if(song_length!=0)begin
           playing<=~playing;
           if(song_step>=song_length)song_step<=0;
         end
         beat_counter<=0;beats_elapsed<=0;step_hit<=0;
      end else if(action==3'd3)begin
         timed_mode<=~timed_mode;
         song_step<=0;beat_counter<=0;beats_elapsed<=0;step_hit<=0;
         correct_count<=0;wrong_count<=0;
      end else if(action==3'd4 || remote_bpm_valid)begin
         bpm_sel<=remote_bpm_valid?remote_bpm:bpm_sel+2'd1;
         beat_counter<=0;beats_elapsed<=0;
      end else if(action==3'd5)begin
         playing<=0;song_step<=0;beat_counter<=0;beats_elapsed<=0;step_hit<=0;
      end
    end
 end
endmodule
