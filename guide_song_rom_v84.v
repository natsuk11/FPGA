`timescale 1ns / 1ps
// ROM contains NOTEs, not recorded PCM. Note indices C4 D4 E4 F4 G4 A4 B4 C5.
// Song 0: Twinkle Twinkle (14 steps); Song 1: ascending scale (8);
// Song 2: Ode to Joy excerpt (16). Single- or two-beat notes.
module guide_song_rom_v84(
    input wire [1:0] song,
    input wire [4:0] index,
    output reg [2:0] note,
    output reg [1:0] beats,
    output reg [4:0] length
);
  always @(*) begin
    note=3'd0;beats=2'd1;length=5'd14;
    case(song)
      2'd0: begin
        length=5'd14;
        case(index)
          5'd0,5'd1:note=3'd0; // C C
          5'd2,5'd3,5'd6:note=3'd4; // G G G
          5'd4,5'd5:note=3'd5; // A A
          5'd7,5'd8:note=3'd3; // F F
          5'd9,5'd10:note=3'd2; // E E
          5'd11,5'd12:note=3'd1; // D D
          default:note=3'd0;
        endcase
        if(index==5'd6 || index==5'd13)beats=2'd2;
      end
      2'd1: begin
        length=5'd8;
        note=index[2:0];
        if(index==5'd7)beats=2'd2;
      end
      default: begin
        length=5'd16;
        case(index)
          5'd0,5'd1,5'd6,5'd11,5'd12:note=3'd2; // E
          5'd2,5'd5:note=3'd3; // F
          5'd3,5'd4:note=3'd4; // G
          5'd7,5'd10,5'd13,5'd14,5'd15:note=3'd1; // D
          default:note=3'd0; // C
        endcase
        if(index==5'd15)beats=2'd2;
      end
    endcase
  end
endmodule
