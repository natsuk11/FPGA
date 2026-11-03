module note_to_phase (
    input  wire [3:0]  note_id,
    output reg  [31:0] phase_inc
);

    // Fs = 48000 Hz
    //
    // 0 = C4
    // 1 = D4
    // 2 = E4
    // 3 = F4
    // 4 = G4
    // 5 = A4
    // 6 = B4
    // 7 = C5

    always @(*) begin

        case(note_id)

            4'd0: phase_inc = 32'd23409859; // C4 261.63 Hz
            4'd1: phase_inc = 32'd26276679; // D4 293.66 Hz
            4'd2: phase_inc = 32'd29494575; // E4 329.63 Hz
            4'd3: phase_inc = 32'd31248413; // F4 349.23 Hz
            4'd4: phase_inc = 32'd35075158; // G4 392.00 Hz
            4'd5: phase_inc = 32'd39370534; // A4 440.00 Hz
            4'd6: phase_inc = 32'd44191930; // B4 493.88 Hz
            4'd7: phase_inc = 32'd46819719; // C5 523.25 Hz

            default:
                phase_inc = 32'd0;

        endcase

    end

endmodule
