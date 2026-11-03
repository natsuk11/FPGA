`timescale 1ns/1ps
// Compatible GT911 reader: INT hint + periodic status fallback.
// Read status first, then exactly N*8 point bytes; publish frames atomically.
// Does not modify panel configuration, refresh rate or firmware flash.
module gt911_reader #(
    parameter integer CLK_HZ = 35000000,
    parameter integer READ_COORDS = 1,
    parameter integer I2C_HZ = 400000,
    parameter integer POLL_US = 1000
)(
    input wire clk, rst_n,
    inout wire ctp_scl, ctp_sda, ctp_int,
    output wire ctp_rst_n,
    output reg connected, communication_error,
    output reg [6:0] active_i2c_address,
    output reg [31:0] product_id,
    output reg [2:0] touch_count,
    output wire [79:0] touch_x_all, touch_y_all, touch_size_all,
    output wire [39:0] touch_id_all,
    output reg frame_valid
);
    localparam integer RESET_TICKS = CLK_HZ/50;
    localparam integer HIGH_TICKS = CLK_HZ/16;
    localparam integer BOOT_TICKS = CLK_HZ/4;
    localparam integer POLL_TICKS = (CLK_HZ/1000000)*POLL_US;
    localparam integer RETRY_TICKS = CLK_HZ/3;
    localparam [3:0] RESET_LOW=0, RESET_HIGH=1, BOOT=2,
        PROBE_START=3, PROBE_WAIT=4, WAIT_FRAME=5, STATUS_START=6,
        STATUS_WAIT=7, POINT_START=8, POINT_WAIT=9, COMMIT=10,
        CLEAR_START=11, CLEAR_WAIT=12, RETRY=13, PROBE_ONLY=14;
    reg [3:0] state;
    reg [31:0] timer;
    reg second_address, reset_high, int_low;
    reg [1:0] int_sync;
    reg int_previous, int_pending;
    wire int_edge = (int_sync[1] != int_previous);
    assign ctp_int = int_low ? 1'b0 : 1'bz;
    assign ctp_rst_n = reset_high;

    reg bus_start, bus_read;
    reg [6:0] bus_address;
    reg [15:0] bus_register;
    reg [5:0] bus_length;
    wire bus_done, bus_error, byte_valid;
    wire [5:0] byte_index;
    wire [7:0] byte_data;
    i2c_reg_master #(.CLK_HZ(CLK_HZ),.I2C_HZ(I2C_HZ)) i2c0 (
        .clk(clk),.rst_n(rst_n),.start(bus_start),.read_mode(bus_read),
        .slave_addr(bus_address),.reg_addr(bus_register),.write_data(8'd0),
        .read_length(bus_length),.scl(ctp_scl),.sda(ctp_sda),.busy(),
        .done(bus_done),.error(bus_error),.io_data_valid(byte_valid),
        .io_data_index(byte_index),.io_data(byte_data)
    );
    reg [7:0] status_byte;
    reg [2:0] pending_count;
    reg invalid_status;
    reg [7:0] packet[0:39];
    reg [15:0] px[0:4], py[0:4], psz[0:4];
    reg [7:0] pid[0:4];
    assign touch_x_all={px[4],px[3],px[2],px[1],px[0]};
    assign touch_y_all={py[4],py[3],py[2],py[1],py[0]};
    assign touch_size_all={psz[4],psz[3],psz[2],psz[1],psz[0]};
    assign touch_id_all={pid[4],pid[3],pid[2],pid[1],pid[0]};
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin int_sync<=0; int_previous<=0; end
        else begin
            int_sync<={int_sync[0],ctp_int};
            int_previous<=int_sync[1];
        end
    end
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state<=RESET_LOW; timer<=0; second_address<=0;
            reset_high<=0; int_low<=1; int_pending<=0;
            connected<=0; communication_error<=0;
            active_i2c_address<=0; product_id<=0; touch_count<=0;
            frame_valid<=0; bus_start<=0; bus_read<=1;
            bus_address<=7'h5d; bus_register<=16'h8140; bus_length<=4;
            status_byte<=0; pending_count<=0; invalid_status<=0;
            for (i=0;i<5;i=i+1) begin px[i]<=0; py[i]<=0; psz[i]<=0; pid[i]<=0; end
            for (i=0;i<40;i=i+1) packet[i]<=0;
        end else begin
            bus_start<=0;
            frame_valid<=0;
            if (connected && int_edge) int_pending<=1;
            if (byte_valid) begin
                if (state==PROBE_WAIT) begin
                    case (byte_index)
                        0: product_id[7:0]<=byte_data;
                        1: product_id[15:8]<=byte_data;
                        2: product_id[23:16]<=byte_data;
                        3: product_id[31:24]<=byte_data;
                        default: begin end
                    endcase
                end else if (state==STATUS_WAIT && byte_index==0)
                    status_byte<=byte_data;
                else if (state==POINT_WAIT && byte_index<40)
                    packet[byte_index]<=byte_data;
            end
            // On a bus failure release notes, then reset and probe the panel.
            if (bus_done && bus_error &&
                (state==STATUS_WAIT || state==POINT_WAIT || state==CLEAR_WAIT)) begin
                connected<=0; communication_error<=1; touch_count<=0;
                frame_valid<=1; int_pending<=0; timer<=0; state<=RETRY;
            end else case (state)
                RESET_LOW: begin
                    reset_high<=0; int_low<=1;
                    if (timer>=RESET_TICKS-1) begin timer<=0; state<=RESET_HIGH; end
                    else timer<=timer+1'b1;
                end
                RESET_HIGH: begin
                    reset_high<=1; int_low<=1;
                    if (timer>=HIGH_TICKS-1) begin timer<=0; int_low<=0; state<=BOOT; end
                    else timer<=timer+1'b1;
                end
                BOOT: begin
                    if (timer>=BOOT_TICKS-1) begin timer<=0; state<=PROBE_START; end
                    else timer<=timer+1'b1;
                end
                PROBE_START: begin
                    bus_address<=second_address ? 7'h14 : 7'h5d;
                    bus_register<=16'h8140; bus_length<=4;
                    bus_read<=1; bus_start<=1; state<=PROBE_WAIT;
                end
                PROBE_WAIT: if (bus_done) begin
                    if (!bus_error) begin
                        connected<=1; communication_error<=0;
                        active_i2c_address<=bus_address; timer<=0; int_pending<=0;
                        state<=(READ_COORDS!=0) ? STATUS_START : PROBE_ONLY;
                    end else if (!second_address) begin second_address<=1; state<=PROBE_START; end
                    else begin
                        connected<=0; communication_error<=1; touch_count<=0;
                        timer<=0; state<=RETRY;
                    end
                end
                WAIT_FRAME: begin
                    if (int_pending || int_edge || timer>=POLL_TICKS-1) begin
                        timer<=0; int_pending<=0; state<=STATUS_START;
                    end else timer<=timer+1'b1;
                end
                STATUS_START: begin
                    bus_address<=active_i2c_address; bus_register<=16'h814e;
                    bus_length<=1; bus_read<=1; bus_start<=1; state<=STATUS_WAIT;
                end
                STATUS_WAIT: if (bus_done) begin
                    if (!status_byte[7]) begin
                        // Not-ready is not note-off: a stationary touch may be silent.
                        timer<=0; state<=WAIT_FRAME;
                    end else begin
                        invalid_status<=(status_byte[3:0]>5);
                        pending_count<=(status_byte[3:0]<=5) ? status_byte[2:0] : 3'd0;
                        state<=(status_byte[3:0]>=1 && status_byte[3:0]<=5) ? POINT_START : COMMIT;
                    end
                end
                POINT_START: begin
                    bus_register<=16'h814f;
                    bus_length<={pending_count,3'b000};
                    bus_read<=1; bus_start<=1; state<=POINT_WAIT;
                end
                POINT_WAIT: if (bus_done) state<=COMMIT;
                COMMIT: begin
                    touch_count<=pending_count; frame_valid<=1;
                    communication_error<=invalid_status;
                    for (i=0;i<5;i=i+1) begin
                        if (i<pending_count) begin
                            pid[i]<=packet[i*8];
                            px[i]<={packet[i*8+2],packet[i*8+1]};
                            py[i]<={packet[i*8+4],packet[i*8+3]};
                            psz[i]<={packet[i*8+6],packet[i*8+5]};
                        end else begin px[i]<=0; py[i]<=0; psz[i]<=0; pid[i]<=0; end
                    end
                    state<=CLEAR_START;
                end
                CLEAR_START: begin
                    bus_register<=16'h814e; bus_length<=1;
                    bus_read<=0; bus_start<=1; state<=CLEAR_WAIT;
                end
                CLEAR_WAIT: if (bus_done) begin timer<=0; state<=WAIT_FRAME; end
                RETRY: begin
                    if (timer>=RETRY_TICKS-1) begin
                        timer<=0; second_address<=0; int_pending<=0; state<=RESET_LOW;
                    end else timer<=timer+1'b1;
                end
                PROBE_ONLY: touch_count<=0;
                default: begin
                    connected<=0; touch_count<=0; timer<=0; int_pending<=0; state<=RESET_LOW;
                end
            endcase
        end
    end
endmodule
