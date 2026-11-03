`timescale 1ns/1ps
// V8.7: 256 event slots, 32 bit per event, up to ~65 seconds.
// Event format: [31:16]=milliseconds, [15]=NOTE_ON,
// [14:13]=voice slot, [12:10]=pitch 0..7, [9:2]=gain, [1:0]=0.
// One write per clock; up to 4 same-frame GT911 events are serialized using
// per-slot pending latches. Recording does NOT alter live audio.
module record_v87 #(parameter integer CLK_HZ=35000000)(
 input wire clk,rst_n,record_toggle,play_toggle,stop_all,
 input wire [3:0] live_on,live_start,
 input wire [15:0] live_notes,
 input wire [31:0] live_gains,
 input wire [7:0] dump_addr,
 output wire [31:0] dump_word,
 output reg [8:0] event_count,
 output reg recording,replaying,
 output reg [3:0] replay_on,replay_start,
 output reg [15:0] replay_notes,
 output reg [31:0] replay_gains
);
 reg [31:0] events [0:255];
 assign dump_word=events[dump_addr];
 reg [15:0] elapsed_ms,playback_ms;
 reg [31:0] cycle_count;
 reg [3:0] previous_live;
 reg [3:0] pending_on,pending_off;
 reg [15:0] pending_notes;
 reg [31:0] pending_gains;
 reg [8:0] play_index;
 integer q,z;
 reg pending_found,pending_is_on;
 reg [1:0] pending_slot;
 integer i;
 // Combinational priority encoder. First process releases (one per cycle)
 // then note-ons; repeated note changes do not require release events.
 always @(*) begin
    pending_found=1'b0;
    pending_is_on=1'b0;
    pending_slot=2'd0;
    for(q=3;q>=0;q=q-1)begin
       if(pending_off[q])begin
          pending_found=1'b1;pending_is_on=1'b0;pending_slot=q[1:0];
       end
    end
    for(z=3;z>=0;z=z-1)begin
       if(pending_on[z])begin
          pending_found=1'b1;pending_is_on=1'b1;pending_slot=z[1:0];
       end
    end
 end
 reg [3:0] next_on,next_off;
 always @(*)begin
   next_on=pending_on;
   next_off=pending_off;
   if(pending_found)begin
      if(pending_is_on)next_on[pending_slot]=1'b0;
      else next_off[pending_slot]=1'b0;
   end
   if(recording && !replaying)begin
      next_on=next_on | live_start;
      next_off=next_off | (previous_live & ~live_on & ~live_start);
   end
 end
 // Playback RAM has its own independent read index. Reading concurrently
 // with UART dump is safe; recording and playback are mutually exclusive.
 wire [31:0] next_play_event=events[play_index[7:0]];
 always @(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
      elapsed_ms<=0;playback_ms<=0;cycle_count<=0;
      event_count<=0;recording<=0;replaying<=0;
      previous_live<=0;pending_on<=0;pending_off<=0;
      pending_notes<=0;pending_gains<=0;
      replay_on<=0;replay_start<=0;replay_notes<=0;
      replay_gains<=0;play_index<=0;
    end else begin
      replay_start<=4'b0000;
      previous_live<=live_on;
      if(cycle_count==CLK_HZ/1000-1)begin
         cycle_count<=0;
         if(recording && elapsed_ms!=16'hffff)elapsed_ms<=elapsed_ms+16'd1;
         if(replaying && playback_ms!=16'hffff)playback_ms<=playback_ms+16'd1;
      end else cycle_count<=cycle_count+32'd1;

      if(recording)begin
        pending_on<=next_on;
        pending_off<=next_off;
        for(i=0;i<4;i=i+1)
           if(live_start[i])begin
              pending_notes[i*4 +:4]<=live_notes[i*4 +:4];
              pending_gains[i*8 +:8]<=live_gains[i*8 +:8];
           end
        if(pending_found && event_count<9'd256)begin
           events[event_count[7:0]]<=
              {elapsed_ms,pending_is_on,pending_slot,
               pending_notes[pending_slot*4 +:3],
               pending_gains[pending_slot*8 +:8],2'b00};
           event_count<=event_count+9'd1;
        end else if(event_count==9'd256)
           recording<=1'b0;
      end else begin pending_on<=0;pending_off<=0;end

      if(replaying)begin
         if(play_index>=event_count)begin
           replaying<=0;replay_on<=0;
         end else if(playback_ms>=next_play_event[31:16])begin
           if(next_play_event[15])begin
              replay_on[next_play_event[14:13]]<=1'b1;
              replay_start[next_play_event[14:13]]<=1'b1;
              replay_notes[next_play_event[14:13]*4 +:4]
                     <={1'b0,next_play_event[12:10]};
              replay_gains[next_play_event[14:13]*8 +:8]
                     <=next_play_event[9:2];
           end else replay_on[next_play_event[14:13]]<=1'b0;
           play_index<=play_index+9'd1;
         end
      end
      // Explicit commands always override any event processed in this cycle.
      if(stop_all)begin
         recording<=0;replaying<=0;replay_on<=0;
         replay_start<=0;pending_on<=0;pending_off<=0;
      end else if(record_toggle)begin
         if(recording)begin recording<=0;pending_on<=0;pending_off<=0;end
         else begin
            recording<=1'b1;replaying<=0;replay_on<=0;
            pending_on<=0;pending_off<=0;elapsed_ms<=0;
            event_count<=0;
         end
      end else if(play_toggle)begin
         if(replaying)begin replaying<=0;replay_on<=0;end
         else if(event_count!=0)begin
            recording<=0;replaying<=1'b1;playback_ms<=0;play_index<=0;
            replay_on<=0;replay_start<=0;
         end
      end
    end
 end
endmodule
