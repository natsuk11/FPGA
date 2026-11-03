`timescale 1ns/1ps
// 35MHz / 3646 ~= 9600 bit/s, 8N1, compatible with typical HC-05 SPP.
module guide_uart_rx_v84 #(parameter integer DIV=3646)(
 input wire clk,rst_n,rx,
 output reg [7:0] data,output reg valid
);
 reg [1:0] state;
 reg [12:0] ticks;
 reg [2:0] bit_no;
 reg [7:0] shift_byte;
 always @(posedge clk or negedge rst_n)begin
   if(!rst_n)begin state<=0;ticks<=0;bit_no<=0;shift_byte<=0;data<=0;valid<=0;end
   else begin
     valid<=0;
     case(state)
       0:if(!rx)begin state<=1;ticks<=DIV/2;end
       1:if(ticks!=0)ticks<=ticks-1'b1;
         else if(!rx)begin state<=2;ticks<=DIV-1;bit_no<=0;end
         else state<=0;
       2:if(ticks!=0)ticks<=ticks-1'b1;
         else begin
           shift_byte[bit_no]<=rx;ticks<=DIV-1;
           if(bit_no==3'd7)state<=3;
           else bit_no<=bit_no+3'd1;
         end
       3:if(ticks!=0)ticks<=ticks-1'b1;
         else begin
           if(rx)begin data<=shift_byte;valid<=1;end
           state<=0;
         end
       default:state<=0;
     endcase
   end
 end
endmodule

module guide_uart_tx_v84 #(parameter integer DIV=3646)(
 input wire clk,rst_n,input wire start,input wire [7:0] data,
 output reg tx,output wire busy
);
 reg [1:0] state;
 reg [12:0] ticks;
 reg [2:0] bit_no;
 reg [7:0] shift_byte;
 assign busy=(state!=0);
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin state<=0;tx<=1;ticks<=0;bit_no<=0;shift_byte<=0;end
  else case(state)
    0:if(start)begin state<=1;tx<=0;shift_byte<=data;ticks<=DIV-1;end
    1:if(ticks!=0)ticks<=ticks-1'b1;
      else begin state<=2;bit_no<=0;tx<=shift_byte[0];ticks<=DIV-1;end
    2:if(ticks!=0)ticks<=ticks-1'b1;
      else if(bit_no==3'd7)begin state<=3;tx<=1;ticks<=DIV-1;end
      else begin bit_no<=bit_no+3'd1;tx<=shift_byte[bit_no+3'd1];ticks<=DIV-1;end
    3:if(ticks!=0)ticks<=ticks-1'b1;else state<=0;
    default:state<=0;
  endcase
 end
endmodule

// ASCII commands terminated by LF or CR, no phone app needed beyond an SPP terminal:
// P toggle PLAY; X STOP; M toggle WAIT/BEAT; S0..S2 song; B0..B3 BPM;
// T0..T6 timbre; D/C/R toggle Delay/Chorus/Reverb; ? status.
// Replies OK, ERR or S# B# M# P#. Input is intentionally NOT used for note triggers.
module guide_hc05_v84 #(parameter integer UART_DIV=3646)(input wire clk,rst_n,uart_rx,
 input wire [1:0] status_song,status_bpm,
 input wire status_mode,status_play,
 output wire uart_tx,
 output reg [2:0] guide_action,
 output reg song_valid,output reg [1:0] song,
 output reg bpm_valid,output reg [1:0] bpm,
 output reg timbre_valid,output reg [2:0] timbre,
 output reg [1:0] fx_toggle
);
 wire [7:0] rx_byte;
 wire rx_valid;
 guide_uart_rx_v84 #(.DIV(UART_DIV)) rx0(.clk(clk),.rst_n(rst_n),.rx(uart_rx),
                          .data(rx_byte),.valid(rx_valid));
 reg tx_start;
 reg [7:0] tx_data;
 wire tx_busy;
 guide_uart_tx_v84 #(.DIV(UART_DIV)) tx0(.clk(clk),.rst_n(rst_n),.start(tx_start),
                              .data(tx_data),.tx(uart_tx),.busy(tx_busy));
 reg [7:0] c0,c1;
 reg [1:0] cmd_len;
 reg too_long;
 reg [1:0] reply_kind; // 1=OK, 2=ERR, 3=status
 reg [3:0] reply_index;
 reg [1:0] reply_state; // 0=idle, 1=send, 2=wait busy, 3=wait done
 reg [1:0] snap_song,snap_bpm;
 reg snap_mode,snap_play;
 reg is_ok;
 function [7:0] reply_char;
  input [1:0] kind;input [3:0] idx;
  input [1:0] song_no,bpm_no;input mode_bit,play_bit;
  begin
   reply_char=8'h0a;
   if(kind==1)case(idx)
      0:reply_char="O";1:reply_char="K";2:reply_char=8'h0d;default:reply_char=8'h0a;
   endcase
   else if(kind==2)case(idx)
      0:reply_char="E";1:reply_char="R";2:reply_char="R";
      3:reply_char=8'h0d;default:reply_char=8'h0a;
   endcase
   else case(idx)
      0:reply_char="S";1:reply_char=8'd48+{6'd0,song_no};2:reply_char=" ";
      3:reply_char="B";4:reply_char=8'd48+{6'd0,bpm_no};5:reply_char=" ";
      6:reply_char="M";7:reply_char=mode_bit?"1":"0";8:reply_char=" ";
      9:reply_char="P";10:reply_char=play_bit?"1":"0";
      11:reply_char=8'h0d;default:reply_char=8'h0a;
   endcase
  end
 endfunction
 wire [3:0] reply_last=(reply_kind==2)?4'd4:((reply_kind==3)?4'd12:4'd3);
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin
   c0<=0;c1<=0;cmd_len<=0;too_long<=0;
   guide_action<=0;song_valid<=0;song<=0;bpm_valid<=0;bpm<=0;
   timbre_valid<=0;timbre<=0;fx_toggle<=0;
   reply_kind<=0;reply_index<=0;reply_state<=0;
   tx_start<=0;tx_data<=0;snap_song<=0;snap_bpm<=0;
   snap_mode<=0;snap_play<=0;is_ok<=0;
  end else begin
   guide_action<=0;song_valid<=0;bpm_valid<=0;timbre_valid<=0;
   fx_toggle<=0;tx_start<=0;
   if(rx_valid)begin
    if(rx_byte==8'h0a || rx_byte==8'h0d)begin
      if(cmd_len!=0 || too_long)begin
       is_ok=0;
       if(!too_long)begin
        if(cmd_len==1)begin
         case(c0)
           "P":begin guide_action<=3'd2;is_ok=1;end
           "X":begin guide_action<=3'd5;is_ok=1;end
           "M":begin guide_action<=3'd3;is_ok=1;end
           "D":begin fx_toggle<=2'd1;is_ok=1;end
           "C":begin fx_toggle<=2'd2;is_ok=1;end
           "R":begin fx_toggle<=2'd3;is_ok=1;end
           "?":is_ok=1;
           default:is_ok=0;
         endcase
        end else if(cmd_len==2)begin
         if(c0=="S" && c1>="0" && c1<="2")begin
           song_valid<=1;song<=c1[1:0];is_ok=1;
         end else if(c0=="B" && c1>="0" && c1<="3")begin
           bpm_valid<=1;bpm<=c1[1:0];is_ok=1;
         end else if(c0=="T" && c1>="0" && c1<="6")begin
           timbre_valid<=1;timbre<=c1[2:0];is_ok=1;
         end
        end
       end
       if(reply_state==0)begin
        reply_kind<=!is_ok?2'd2:((c0=="?" && cmd_len==1)?2'd3:2'd1);
        reply_index<=0;reply_state<=1;
        snap_song<=status_song;snap_bpm<=status_bpm;
        snap_mode<=status_mode;snap_play<=status_play;
       end
      end
      cmd_len<=0;too_long<=0;
    end else if(cmd_len==0)begin c0<=rx_byte;cmd_len<=1;end
    else if(cmd_len==1)begin c1<=rx_byte;cmd_len<=2;end
    else too_long<=1;
   end
   case(reply_state)
    0:begin end
    1:if(!tx_busy)begin
       tx_data<=reply_char(reply_kind,reply_index,snap_song,snap_bpm,snap_mode,snap_play);
       tx_start<=1;reply_state<=2;
      end
    2:if(tx_busy)reply_state<=3;
    3:if(!tx_busy)begin
       if(reply_index>=reply_last)reply_state<=0;
       else begin reply_index<=reply_index+4'd1;reply_state<=1;end
      end
    default:reply_state<=0;
   endcase
  end
 end
endmodule
