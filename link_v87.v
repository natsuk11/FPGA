`timescale 1ns/1ps
// V8.7 HC-05 Bluetooth Classic SPP, 9600 8N1, ASCII + CR/LF protocol.
// Kept legacy S0..S3 B0..B3 T0..T6 P X M D C R ? queries;
// Legacy R still toggles Reverb; J toggles event recording.
// New Kxy (swap key x to pitch y), K? (read mapping), Z (reset map),
// U / Nxy / E (begin / append pitch x duration y / commit song),
// V (export events), G (replay), J (record), L (count), H/R (Reverb).
// Every command is ACKed before a host must send another. Max 3 ASCII chars.
module link_v87 #(parameter integer UART_DIV=3646)(
 input wire clk,rst_n,uart_rx,output wire uart_tx,
 input wire [1:0] status_song,status_bpm,
 input wire status_mode,status_play,
 input wire [23:0] key_mapping,
 input wire upload_ready,upload_can_append,upload_can_commit,
 input wire recorder_active,replay_active,
 input wire [8:0] record_count,
 input wire [31:0] record_word,
 output reg [7:0] record_read_addr,
 output reg [2:0] guide_action,
 output reg song_valid,output reg [1:0] song,
 output reg bpm_valid,output reg [1:0] bpm,
 output reg timbre_valid,output reg [2:0] timbre,
 output reg [1:0] fx_toggle,
 output reg map_valid,output reg [2:0] map_key,map_pitch,
 output reg map_reset,
 output reg upload_begin,upload_append,upload_finish,
 output reg [2:0] upload_note,output reg [1:0] upload_beats,
 output reg record_toggle,play_toggle,record_stop
);
 wire [7:0] rx_byte;
 wire rx_valid;
 guide_uart_rx_v84 #(.DIV(UART_DIV)) u_rx(
 .clk(clk),.rst_n(rst_n),.rx(uart_rx),.data(rx_byte),.valid(rx_valid));
 reg tx_start;
 reg [7:0] tx_data;
 wire tx_busy;
 guide_uart_tx_v84 #(.DIV(UART_DIV)) u_tx(
 .clk(clk),.rst_n(rst_n),.start(tx_start),.data(tx_data),
 .tx(uart_tx),.busy(tx_busy));
 reg [7:0] c0,c1,c2;
 reg [1:0] command_len;
 reg too_long;
 reg accepted;
 reg [2:0] pending_reply;
 // 0 idle,1 OK,2 ERR,3 STATUS,4 KEYMAP,5 COUNT,6 EVENT,7 END
 reg [4:0] reply_index;
 reg [1:0] tx_state;
 reg dump_after_count;
 reg [8:0] dump_next;
 reg [8:0] snap_count;
 reg [23:0] snap_mapping;
 reg [1:0] snap_song,snap_bpm;
 reg snap_mode,snap_play;
 reg [3:0] reply_last;
 reg [7:0] reply_byte;
 reg [3:0] hex_value;
 reg [31:0] event_snapshot;
 function [7:0] to_hex;
 input [3:0] nib;
 begin to_hex=(nib<10)?(8'h30+{4'd0,nib}):(8'h41+{4'd0,nib}-8'd10);end
 endfunction
 always @(*)begin
   reply_last=0;
   case(pending_reply)
     1:reply_last=3;   // OK CR LF
     2:reply_last=4;   // ERR CR LF
     3:reply_last=12;  // S# B# M# P# CR LF
     4:reply_last=10;  // Kdddddddd CR LF
     5:reply_last=5;   // Nxxx CR LF
     6:reply_last=10;  // @hhhhhhhh CR LF
     7:reply_last=4;   // END CR LF
     default:reply_last=0;
   endcase
   reply_byte=8'h0a;
   hex_value=0;
   case(pending_reply)
     1:case(reply_index)
       0:reply_byte="O";1:reply_byte="K";
       2:reply_byte=8'h0d;default:reply_byte=8'h0a;
     endcase
     2:case(reply_index)
       0:reply_byte="E";1:reply_byte="R";2:reply_byte="R";
       3:reply_byte=8'h0d;default:reply_byte=8'h0a;
     endcase
     3:case(reply_index)
       0:reply_byte="S";1:reply_byte=8'h30+{6'd0,snap_song};
       2:reply_byte=" ";3:reply_byte="B";
       4:reply_byte=8'h30+{6'd0,snap_bpm};5:reply_byte=" ";
       6:reply_byte="M";7:reply_byte=snap_mode?"1":"0";
       8:reply_byte=" ";9:reply_byte="P";
       10:reply_byte=snap_play?"1":"0";
       11:reply_byte=8'h0d;default:reply_byte=8'h0a;
     endcase
     4:begin
       if(reply_index==0)reply_byte="K";
       else if(reply_index<9)
          reply_byte=8'h30+{5'd0,snap_mapping[(reply_index-1)*3+:3]};
       else if(reply_index==9)reply_byte=8'h0d;
       else reply_byte=8'h0a;
     end
     5:begin
       case(reply_index)
         0:reply_byte="N";
         1:reply_byte=to_hex({3'd0,snap_count[8]});
         2:reply_byte=to_hex(snap_count[7:4]);
         3:reply_byte=to_hex(snap_count[3:0]);
         4:reply_byte=8'h0d;default:reply_byte=8'h0a;
       endcase
     end
     6:begin
       if(reply_index==0)reply_byte="@";
       else if(reply_index>=1 && reply_index<=8)begin
         hex_value=(event_snapshot >> ((8-reply_index)*4));
         reply_byte=to_hex(hex_value);
       end else if(reply_index==9)reply_byte=8'h0d;
       else reply_byte=8'h0a;
     end
     7:case(reply_index)
       0:reply_byte="E";1:reply_byte="N";2:reply_byte="D";
       3:reply_byte=8'h0d;default:reply_byte=8'h0a;
     endcase
     default:reply_byte=8'h0a;
   endcase
 end
 always @(posedge clk or negedge rst_n)begin
   if(!rst_n)begin
      c0<=0;c1<=0;c2<=0;command_len<=0;too_long<=0;
      accepted<=0;pending_reply<=0;reply_index<=0;tx_state<=0;
      dump_after_count<=0;dump_next<=0;snap_count<=0;
      snap_song<=0;snap_bpm<=0;snap_mode<=0;snap_play<=0;
      snap_mapping<=0;event_snapshot<=0;record_read_addr<=0;
      tx_start<=0;tx_data<=0;
      guide_action<=0;song_valid<=0;song<=0;
      bpm_valid<=0;bpm<=0;timbre_valid<=0;timbre<=0;fx_toggle<=0;
      map_valid<=0;map_key<=0;map_pitch<=0;map_reset<=0;
      upload_begin<=0;upload_append<=0;upload_finish<=0;
      upload_note<=0;upload_beats<=0;
      record_toggle<=0;play_toggle<=0;record_stop<=0;
   end else begin
      guide_action<=0;song_valid<=0;bpm_valid<=0;timbre_valid<=0;
      fx_toggle<=0;map_valid<=0;map_reset<=0;
      upload_begin<=0;upload_append<=0;upload_finish<=0;
      record_toggle<=0;play_toggle<=0;record_stop<=0;
      tx_start<=0;
      // Accept new command only while the reply engine is idle.
      if(rx_valid)begin
       if(rx_byte==8'h0a || rx_byte==8'h0d)begin
         if(command_len!=0 || too_long)begin
           accepted=0;
           if(!too_long && pending_reply==0)begin
             if(command_len==1)case(c0)
                "P":begin guide_action<=3'd2;accepted=1;end
                "X":begin guide_action<=3'd5;record_stop<=1;accepted=1;end
                "M":begin guide_action<=3'd3;accepted=1;end
                "D":begin fx_toggle<=2'd1;accepted=1;end
                "C":begin fx_toggle<=2'd2;accepted=1;end
                "H","R":begin fx_toggle<=2'd3;accepted=1;end
                "?":accepted=1;
                "Z":begin map_reset<=1;accepted=1;end
                "U":begin upload_begin<=1;guide_action<=3'd5;accepted=1;end
                "E":begin if(upload_can_commit)begin upload_finish<=1;accepted=1;end end
                "J":begin record_toggle<=1;accepted=1;end
                "G":begin if(record_count!=0)begin play_toggle<=1;accepted=1;end end
                "V":begin
                      if(!recorder_active && !replay_active)begin
                        accepted=1;dump_after_count<=1;end
                      end
                "L":accepted=1;
                default:accepted=0;
             endcase
             else if(command_len==2)begin
                if(c0=="S" && c1>="0" && c1<="3" &&
                   (c1!="3" || upload_ready))begin
                   song_valid<=1;song<=c1[1:0];accepted=1;
                end else if(c0=="B" && c1>="0" && c1<="3")begin
                   bpm_valid<=1;bpm<=c1[1:0];accepted=1;
                end else if(c0=="T" && c1>="0" && c1<="6")begin
                   timbre_valid<=1;timbre<=c1[2:0];accepted=1;
                end else if(c0=="K" && c1=="?")accepted=1;
             end else if(command_len==3)begin
                if(c0=="K" && c1>="0" && c1<="7" &&
                   c2>="0" && c2<="7")begin
                    map_valid<=1;map_key<=c1[2:0];map_pitch<=c2[2:0];
                    accepted=1;
                end else if(c0=="N" && c1>="0" && c1<="7" &&
                          c2>="1" && c2<="3" && upload_can_append)begin
                    upload_note<=c1[2:0];upload_beats<=c2[1:0];
                    upload_append<=1;accepted=1;
                end
             end
             if(c0=="?" && command_len==1 && accepted)
                  pending_reply<=3'd3;
             else if(c0=="K" && command_len==2 && c1=="?" && accepted)
                  pending_reply<=3'd4;
             else if((c0=="V" || c0=="L") && command_len==1 && accepted)
                  pending_reply<=3'd5;
             else pending_reply<=accepted?3'd1:3'd2;
             reply_index<=0;tx_state<=0;
             snap_song<=status_song;snap_bpm<=status_bpm;
             snap_mode<=status_mode;snap_play<=status_play;
             snap_mapping<=key_mapping;snap_count<=record_count;
           end
         end
         command_len<=0;too_long<=0;
       end else if(command_len==0)begin c0<=rx_byte;command_len<=1;end
       else if(command_len==1)begin c1<=rx_byte;command_len<=2;end
       else if(command_len==2)begin c2<=rx_byte;command_len<=3;end
       else too_long<=1;
      end
      if(pending_reply!=0)begin
        case(tx_state)
          0:if(!tx_busy)begin
               tx_data<=reply_byte;
               tx_start<=1;
               tx_state<=1;
            end
          1:if(tx_busy)tx_state<=2;
          2:if(!tx_busy)begin
              if(reply_index==reply_last)begin
                reply_index<=0;tx_state<=0;
                if(pending_reply==5 && dump_after_count)begin
                    dump_after_count<=0;
                    dump_next<=0;
                    record_read_addr<=0;
                    if(snap_count==0)pending_reply<=7;
                    else begin
                       event_snapshot<=record_word;
                       pending_reply<=6;
                    end
                end else if(pending_reply==6)begin
                    if(dump_next+9'd1>=snap_count)
                         pending_reply<=7;
                    else begin
                         dump_next<=dump_next+9'd1;
                         record_read_addr<=dump_next[7:0]+8'd1;
                         // pipeline stage added below before next line starts
                         pending_reply<=6;
                    end
                end else pending_reply<=0;
              end else begin
                 reply_index<=reply_index+5'd1;
                 tx_state<=0;
              end
            end
          default:tx_state<=0;
        endcase
      end
      // Address changed above; capture next RAM word on the next clock.
      // UART byte spacing > 35k clocks, so this is stable for each event.
      if(pending_reply==6 && reply_index==0 && tx_state==0)
         event_snapshot<=record_word;
    end
 end
endmodule
