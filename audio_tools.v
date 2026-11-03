`timescale 1ns/1ps
// FORMAT=0: board PT8211 LSBJ. FORMAT=1: standard I2S, 32-bit channel slots.
// Same nominal 48kHz sample enable; fractional BCK clock remains a prototype.
module audio_serial_v7 #(parameter integer FORMAT=0)(
 input wire clk,rst_n,input wire signed [15:0] pcm,
 output reg bck,ws,din,sample_tick
);
 localparam [31:0] INC=(FORMAT==1)?32'd753950830:32'd376975415;
 localparam [5:0] LAST=(FORMAT==1)?6'd63:6'd31;
 reg [31:0] phase;wire [32:0] sum={1'b0,phase}+{1'b0,INC};
 reg [5:0] bit_index;reg [15:0] latched;
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin phase<=0;bit_index<=0;latched<=0;bck<=1;ws<=0;din<=0;sample_tick<=0;end
  else begin
   sample_tick<=0;phase<=sum[31:0];
   if(sum[32])begin
    bck<=~bck;
    if(bck)begin
     if(bit_index==0)begin latched<=pcm;sample_tick<=1;end
     if(FORMAT==1)begin
      ws<=bit_index[5];
      // LRCK changes at bit0; the next BCK carries the MSB.
      if(bit_index[4:0]>=5'd1 && bit_index[4:0]<=5'd16)
       din<=latched[5'd16-bit_index[4:0]];
      else din<=0;
     end else begin
      ws<=bit_index[4];
      if(bit_index==0)din<=pcm[15];
      else din<=latched[4'd15-bit_index[3:0]];
     end
    end else bit_index<=(bit_index==LAST)?6'd0:bit_index+6'd1;
   end
  end
 end
endmodule

// Synchronous RAM read, no reset loop over BRAM. Old contents are masked until filled.
// Feedback=1/2; wet<=127/256 keeps a direct dry path. Master0 mutes completely.
module audio_delay_v7 #(parameter integer ADDR_BITS=13)(
 input wire clk,rst_n,pcm_valid,enabled,
 input wire signed [15:0] pcm,input wire [7:0] wet_control,master_gain,
 output reg signed [15:0] pcm_out,output reg out_valid,
 input wire clear_history
);
 localparam integer DEPTH=1<<ADDR_BITS;
 reg signed [15:0] ram[0:DEPTH-1];
 reg [ADDR_BITS-1:0] pointer;
 reg [ADDR_BITS:0] filled;
 reg [1:0] state;
 reg signed [15:0] xin,delayed,mixed;
 reg [7:0] wet;reg [8:0] gain;
 wire [8:0] dry=9'd256-{1'b0,wet};
 wire signed [25:0] dry_product=xin*$signed({1'b0,dry});
 wire signed [25:0] wet_product=delayed*$signed({2'b00,wet});
 wire signed [26:0] mixture=$signed({dry_product[25],dry_product})+$signed({wet_product[25],wet_product});
 wire signed [16:0] feedback=($signed({xin[15],xin})>>>1)+($signed({delayed[15],delayed})>>>1);
 wire signed [25:0] master_product=mixed*$signed({1'b0,gain});
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin pointer<=0;filled<=0;state<=0;xin<=0;delayed<=0;mixed<=0;wet<=0;gain<=0;pcm_out<=0;out_valid<=0;end
  else begin
   out_valid<=0;
   case(state)
    2'd0:if(pcm_valid)begin
     xin<=pcm;delayed<=(filled==DEPTH)?ram[pointer]:16'sd0;
     wet<=enabled?{1'b0,wet_control[7:1]}:8'd0;
     gain<=(master_gain==0)?9'd0:{1'b0,master_gain}+9'd1;state<=1;
    end
    2'd1:begin
     ram[pointer]<=feedback[15:0];pointer<=pointer+1'b1;
     if(filled<DEPTH)filled<=filled+1'b1;
     mixed<=mixture[23:8];state<=2;
    end
    2'd2:begin pcm_out<=master_product[23:8];out_valid<=1;state<=0;end
    default:state<=0;
   endcase
   // Keep diagnostic tones out of the normal delay tail. Invalidate BRAM
   // without resetting its contents; the dry PCM/valid pipeline continues.
   if(clear_history)begin pointer<=0;filled<=0;delayed<=0;end
  end
 end
endmodule

// Single clock scope RAM; TOP requests the next pixel's index to align RGB.
module audio_scope_v7(
 input wire clk,rst_n,pcm_valid,input wire signed [15:0] pcm,
 input wire [7:0] read_index,output reg signed [15:0] sample,
 output wire ready
);
 reg signed [15:0] ram[0:255];reg [7:0] pointer;
 reg [8:0] filled;reg [1:0] divider;
 assign ready=(filled==9'd256);
 always @(posedge clk)sample<=ram[read_index];
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin pointer<=0;filled<=0;divider<=0;end
  else if(pcm_valid)begin
   divider<=divider+2'd1;
   if(divider==0)begin ram[pointer]<=pcm;pointer<=pointer+8'd1;
    if(filled<9'd256)filled<=filled+9'd1;end
  end
 end
endmodule

// Measures only voice_start -> completed audio frame; excludes physical touch scan.
module audio_latency_v7(
 input wire clk,rst_n,note_start,sample_tick,synth_valid,fx_valid,
 output reg [15:0] last_cycles,max_cycles,output reg valid
);
 reg [15:0] age;reg [2:0] stage;
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin age<=0;stage<=0;last_cycles<=0;max_cycles<=0;valid<=0;end
  else if(note_start)begin age<=0;stage<=1;end
  else if(stage!=0)begin
   if(age!=16'hffff)age<=age+16'd1;
   case(stage)
    3'd1:if(sample_tick)stage<=2;
    3'd2:if(synth_valid)stage<=3;
    3'd3:if(fx_valid)stage<=4;
    3'd4:if(sample_tick)begin
     last_cycles<=age;valid<=1;if(age>max_cycles)max_cycles<=age;stage<=0;
    end
    default:stage<=0;
   endcase
  end
 end
endmodule
