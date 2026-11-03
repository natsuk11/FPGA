module timbre_voice (
    input  wire               clk,
    input  wire               rst_n,
    input  wire               sample_tick,

    // DDS phase increment
    input  wire [31:0]        phase_inc,

    // 0 = sine
    // 1 = square
    // 2 = saw
    input  wire [1:0]         timbre_sel,

    output reg signed [15:0]  audio_data
);


// ============================================================
// Phase accumulator
// ============================================================

reg [31:0] phase_acc;


// ============================================================
// Sine lookup table
//
// 32-point sine table
// amplitude about +/-12000
// ============================================================

function signed [15:0] sine_lut;

    input [4:0] addr;

    begin

        case(addr)

            5'd0:  sine_lut =  16'sd0;
            5'd1:  sine_lut =  16'sd2341;
            5'd2:  sine_lut =  16'sd4592;
            5'd3:  sine_lut =  16'sd6667;
            5'd4:  sine_lut =  16'sd8485;
            5'd5:  sine_lut =  16'sd9978;
            5'd6:  sine_lut =  16'sd11087;
            5'd7:  sine_lut =  16'sd11769;

            5'd8:  sine_lut =  16'sd12000;

            5'd9:  sine_lut =  16'sd11769;
            5'd10: sine_lut =  16'sd11087;
            5'd11: sine_lut =  16'sd9978;
            5'd12: sine_lut =  16'sd8485;
            5'd13: sine_lut =  16'sd6667;
            5'd14: sine_lut =  16'sd4592;
            5'd15: sine_lut =  16'sd2341;

            5'd16: sine_lut =  16'sd0;

            5'd17: sine_lut = -16'sd2341;
            5'd18: sine_lut = -16'sd4592;
            5'd19: sine_lut = -16'sd6667;
            5'd20: sine_lut = -16'sd8485;
            5'd21: sine_lut = -16'sd9978;
            5'd22: sine_lut = -16'sd11087;
            5'd23: sine_lut = -16'sd11769;

            5'd24: sine_lut = -16'sd12000;

            5'd25: sine_lut = -16'sd11769;
            5'd26: sine_lut = -16'sd11087;
            5'd27: sine_lut = -16'sd9978;
            5'd28: sine_lut = -16'sd8485;
            5'd29: sine_lut = -16'sd6667;
            5'd30: sine_lut = -16'sd4592;
            5'd31: sine_lut = -16'sd2341;

            default:
                sine_lut = 16'sd0;

        endcase

    end

endfunction


// ============================================================
// Square wave
// ============================================================

wire signed [15:0] square_wave;

assign square_wave =
    phase_acc[31] ?
    -16'sd12000 :
     16'sd12000;


// ============================================================
// Saw wave
//
// phase_acc[31:24] = 0 ~ 255
// convert it to approximately -12000 ~ +12000
// ============================================================

wire signed [8:0]  saw_centered;
wire signed [24:0] saw_scaled;

assign saw_centered =
    $signed({1'b0, phase_acc[31:24]}) - 9'sd128;

assign saw_scaled =
    saw_centered * 16'sd94;


// ============================================================
// DDS + Timbre selection
// ============================================================

always @(posedge clk or negedge rst_n) begin

    if(!rst_n) begin

        phase_acc  <= 32'd0;
        audio_data <= 16'sd0;

    end

    else if(sample_tick) begin

        // Keep phase running continuously
        phase_acc <= phase_acc + phase_inc;

        case(timbre_sel)

            // ------------------------
            // Sine
            // ------------------------

            2'd0: begin

                audio_data <= sine_lut(
                    phase_acc[31:27]
                );

            end


            // ------------------------
            // Square
            // ------------------------

            2'd1: begin

                audio_data <= square_wave;

            end


            // ------------------------
            // Saw
            // ------------------------

            2'd2: begin

                audio_data <= saw_scaled[15:0];

            end


            // ------------------------
            // Reserved
            // ------------------------

            default: begin

                audio_data <= sine_lut(
                    phase_acc[31:27]
                );

            end

        endcase

    end

end


endmodule
