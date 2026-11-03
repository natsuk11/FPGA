`timescale 1ns / 1ps
// Mix continuously reported contact-area expression and touch-down intensity.
// Product rather than linear addition increases the soft-vs-strong contrast.
//
// The minimum of 8/255 preserves quiet notes without flattening low dynamics.
// enable_velocity=0 is a useful A/B test against size-only expression.

module dynamic_gain (
    input  wire       enable_velocity,
    input  wire [7:0] area_gain,
    input  wire [7:0] velocity_gain,
    output wire [7:0] expression_gain
);
    wire [15:0] product = area_gain * velocity_gain;
    wire [7:0] weighted = product[15:8];
    wire [7:0] with_floor = (weighted < 8'd8) ? 8'd8 : weighted;
    assign expression_gain = enable_velocity ? with_floor : area_gain;
endmodule
