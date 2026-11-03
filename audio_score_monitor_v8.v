`timescale 1ns/1ps
// Counts real serializer frame requests in a CLOCK_HZ-cycle reference window.
// This is NOT an independent measurement of the physical FPGA clock or DAC.
// Sticky fault: missing, unsolicited or duplicate synth/FX completion.
module audio_score_monitor_v8 #(parameter integer CLOCK_HZ=35000000)(
 input wire clk,rst_n,sample_tick,synth_valid,fx_valid,
 output reg [15:0] clock_frames,output reg deadline_fault
);
 reg [31:0] window_cycles;
 reg [15:0] frames;
 reg synth_pending,fx_pending,window_overflow;
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin
   window_cycles<=32'd0;frames<=16'd0;clock_frames<=16'd0;
   synth_pending<=0;fx_pending<=0;deadline_fault<=0;window_overflow<=0;
  end else begin
   if(window_cycles==CLOCK_HZ-1)begin
    window_cycles<=0;
    clock_frames<=(sample_tick && frames!=16'hffff)?frames+16'd1:frames;
    frames<=0;window_overflow<=0;
   end else begin
    window_cycles<=window_cycles+32'd1;
    if(sample_tick)begin
     if(frames==16'hffff)window_overflow<=1;
     else frames<=frames+16'd1;
    end
   end
   if(window_overflow)deadline_fault<=1;
   if(synth_valid)begin
    if(!synth_pending)deadline_fault<=1;
    synth_pending<=0;
   end
   if(fx_valid)begin
    if(!fx_pending || (synth_pending && !synth_valid))deadline_fault<=1;
    fx_pending<=0;
   end
   if(sample_tick)begin
    if((synth_pending && !synth_valid) || (fx_pending && !fx_valid))deadline_fault<=1;
    synth_pending<=1;fx_pending<=1;
   end
  end
 end
endmodule
