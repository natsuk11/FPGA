`timescale 1ns/1ps
// Eight-key permutation. User command Kxy swaps the pitch assigned to
// physical key x with the key formerly playing pitch y. No duplicates.
module keymap_v87(
 input wire clk,rst_n,
 input wire set_valid,input wire [2:0] set_key,set_pitch,
 input wire clear_map,
 input wire [15:0] physical_notes,
 input wire [2:0] guide_pitch,
 output wire [15:0] mapped_notes,
 output reg [2:0] guide_key,
 output wire [23:0] mapping,
 output wire [7:0] keymap_changed
);
 reg [2:0] map_r [0:7];
 integer i;
 wire [2:0] displaced = map_r[set_key];
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin
   for(i=0;i<8;i=i+1)map_r[i]<=i[2:0];
  end else if(clear_map)begin
   for(i=0;i<8;i=i+1)map_r[i]<=i[2:0];
  end else if(set_valid)begin
   for(i=0;i<8;i=i+1)begin
     if(i==set_key)map_r[i]<=set_pitch;
     else if(map_r[i]==set_pitch)map_r[i]<=displaced;
   end
  end
 end
 genvar k;
 generate for(k=0;k<8;k=k+1)begin: MAPPING
   assign mapping[k*3 +:3]=map_r[k];
   assign keymap_changed[k]=(map_r[k]!=k);
 end endgenerate
 genvar v;
 generate for(v=0;v<4;v=v+1)begin: VOICE_MAP
   assign mapped_notes[v*4 +:4] =
       (physical_notes[v*4 +:4] < 4'd8) ?
       {1'b0,map_r[physical_notes[v*4 +:4]]} : 4'd0;
 end endgenerate
 integer h;
 always @(*)begin
   guide_key=3'd0;
   for(h=0;h<8;h=h+1)
      if(map_r[h]==guide_pitch)guide_key=h[2:0];
 end
endmodule
