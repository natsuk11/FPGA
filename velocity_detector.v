`timescale 1ns / 1ps
// GT911 pseudo-velocity / attack intensity estimator.
// NOT a true pressure sensor or mechanical strike-velocity measurement.
// Works from the first reported size and positive size growth in up to
// three subsequent sensor frames, then freezes the attack factor per note.
//
// voice_start / voice_update are one-35MHz-cycle pulses from the manager.
// The elapsed time between valid GT911 reports is ~10ms + I2C transfer.
// No new clocks, timer domains, or sampling assumptions are introduced.

module velocity_detector (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        voice_on,
    input  wire        voice_start,
    input  wire        voice_update,
    input  wire [15:0] contact_size,
    input  wire [7:0]  area_gain,
    output reg  [7:0]  velocity_gain
);
    reg [15:0] last_size;
    reg [1:0]  frames_left;

    wire [15:0] positive_rise =
        (contact_size > last_size) ? (contact_size - last_size) : 16'd0;

    // A +32-size-unit increase during one contact-frame interval
    // reaches the maximum attack factor. Small increases are graded.
    wire [7:0] rise_candidate =
        (positive_rise >= 16'd32) ? 8'd255 :
        (8'd96 + (positive_rise[4:0] * 8'd5));

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            velocity_gain <= 8'd192;
            last_size <= 16'd0;
            frames_left <= 2'd0;
        end else if (voice_start && voice_on) begin
            last_size <= contact_size;
            frames_left <= 2'd3;
            // Size=0: firmware may not provide a meaningful value.
            velocity_gain <= (contact_size == 16'd0) ?
                             8'd255 : (8'd80 + (area_gain >> 1));
        end else if (voice_update && voice_on && (frames_left != 2'd0)) begin
            if (contact_size != 16'd0 && last_size != 16'd0 &&
                positive_rise != 16'd0 &&
                rise_candidate > velocity_gain)
                velocity_gain <= rise_candidate;
            last_size <= contact_size;
            frames_left <= frames_left - 2'd1;
        end
        // Otherwise retain the factor, including throughout ADSR RELEASE.
    end
endmodule
