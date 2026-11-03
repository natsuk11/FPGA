`timescale 1ns/1ps
// Open-drain GT911 register master. One clock domain; I2C clocks are enables.
// Rounded-up divider, SDA/SCL synchronizers, stretching wait and bus timeout.
module i2c_reg_master #(
    parameter integer CLK_HZ = 35000000,
    parameter integer I2C_HZ = 100000
)(
    input wire clk, rst_n, start, read_mode,
    input wire [6:0] slave_addr,
    input wire [15:0] reg_addr,
    input wire [7:0] write_data,
    input wire [5:0] read_length,
    inout wire scl, sda,
    output wire busy,
    output reg done, error, io_data_valid,
    output reg [5:0] io_data_index,
    output reg [7:0] io_data
);
    // Symmetric SCL: Fast-mode tLOW >= 1.3 us; Standard-mode >= 4.7 us.
    localparam integer RATE = (I2C_HZ > 0) ? I2C_HZ : 100000;
    localparam integer RATE_DIV =
        (CLK_HZ + 4*RATE - 1) / (4*RATE);
    localparam integer LOW_DIV =
        (CLK_HZ * ((RATE <= 100000) ? 64'd47 : 64'd13)
         + 64'd19999999) / 64'd20000000;
    localparam integer Q0 = (RATE_DIV > LOW_DIV) ? RATE_DIV : LOW_DIV;
    localparam integer QDIV = (Q0 > 3) ? Q0 : 4;
    localparam integer TIMEOUT = (CLK_HZ/100 > 0) ? CLK_HZ/100 : 1;
    localparam [3:0] IDLE=0, START=1, TX=2, TXACK=3,
                     RESTART=4, RX=5, RXACK=6, STOP=7;
    reg [3:0] state;
    reg [1:0] phase;
    reg [31:0] divider, stretch_timer;
    reg scl_low, sda_low;
    reg [1:0] scl_sync, sda_sync;
    reg [6:0] address_r;
    reg [15:0] register_r;
    reg [7:0] data_r, tx_byte, rx_byte;
    reg [5:0] length_r, rx_index;
    reg read_r, ack_good;
    reg [2:0] tx_stage, bit_index;
    wire tick = (divider == QDIV-1);
    // Phase 1 releases SCL. Phase 2 must observe it physically high.
    wire wait_scl = (state != IDLE) && (phase == 2) && !scl_sync[1];
    assign scl = scl_low ? 1'b0 : 1'bz;
    assign sda = sda_low ? 1'b0 : 1'bz;
    assign busy = (state != IDLE);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            scl_sync <= 2'b11;
            sda_sync <= 2'b11;
        end else begin
            scl_sync <= {scl_sync[0],scl};
            sda_sync <= {sda_sync[0],sda};
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state<=IDLE; phase<=0; divider<=0; stretch_timer<=0;
            scl_low<=0; sda_low<=0; address_r<=0; register_r<=0;
            data_r<=0; tx_byte<=0; rx_byte<=0; length_r<=1;
            rx_index<=0; read_r<=0; ack_good<=0; tx_stage<=0;
            bit_index<=7; done<=0; error<=0; io_data_valid<=0;
            io_data_index<=0; io_data<=0;
        end else begin
            done<=0;
            io_data_valid<=0;
            if (state == IDLE) begin
                divider<=0; stretch_timer<=0; phase<=0;
                scl_low<=0; sda_low<=0;
                if (start) begin
                    address_r<=slave_addr; register_r<=reg_addr;
                    data_r<=write_data; read_r<=read_mode;
                    length_r<=(read_length==0) ? 6'd1 : read_length;
                    tx_byte<={slave_addr,1'b0}; tx_stage<=0;
                    bit_index<=7; rx_index<=0; error<=0; state<=START;
                end
            end else if (wait_scl) begin
                // Restart the high-period timer once SCL is released.
                divider<=0;
                if (stretch_timer >= TIMEOUT-1) begin
                    scl_low<=0; sda_low<=0; state<=IDLE;
                    error<=1; done<=1; stretch_timer<=0;
                end else stretch_timer<=stretch_timer+1'b1;
            end else begin
                stretch_timer<=0;
                if (!tick) divider<=divider+1'b1;
                else begin
                    divider<=0; phase<=phase+2'd1;
                    case (state)
                        START: case (phase)
                            0: begin scl_low<=0; sda_low<=0; end
                            1: sda_low<=1;
                            2: scl_low<=1;
                            3: state<=TX;
                        endcase
                        TX: case (phase)
                            0: begin scl_low<=1; sda_low<=~tx_byte[bit_index]; end
                            1: scl_low<=0;
                            2: begin end
                            3: begin
                                scl_low<=1;
                                if (bit_index==0) state<=TXACK;
                                else bit_index<=bit_index-1'b1;
                            end
                        endcase
                        TXACK: case (phase)
                            0: begin scl_low<=1; sda_low<=0; end
                            1: scl_low<=0;
                            2: ack_good<=~sda_sync[1];
                            3: begin
                                scl_low<=1; bit_index<=7;
                                if (!ack_good) begin error<=1; state<=STOP; end
                                else case (tx_stage)
                                    0: begin tx_stage<=1; tx_byte<=register_r[15:8]; state<=TX; end
                                    1: begin tx_stage<=2; tx_byte<=register_r[7:0]; state<=TX; end
                                    2: if (read_r) state<=RESTART;
                                       else begin tx_stage<=4; tx_byte<=data_r; state<=TX; end
                                    3: begin rx_index<=0; rx_byte<=0; state<=RX; end
                                    default: state<=STOP;
                                endcase
                            end
                        endcase
                        RESTART: case (phase)
                            0: begin scl_low<=1; sda_low<=0; end
                            1: scl_low<=0;
                            2: sda_low<=1;
                            3: begin
                                scl_low<=1; tx_stage<=3;
                                tx_byte<={address_r,1'b1}; bit_index<=7; state<=TX;
                            end
                        endcase
                        RX: case (phase)
                            0: begin scl_low<=1; sda_low<=0; end
                            1: scl_low<=0;
                            2: rx_byte[bit_index]<=sda_sync[1];
                            3: begin
                                scl_low<=1;
                                if (bit_index==0) begin
                                    io_data<=rx_byte; io_data_index<=rx_index;
                                    io_data_valid<=1; state<=RXACK;
                                end else bit_index<=bit_index-1'b1;
                            end
                        endcase
                        RXACK: case (phase)
                            0: begin scl_low<=1; sda_low<=(rx_index+6'd1 < length_r); end
                            1: scl_low<=0;
                            2: begin end
                            3: begin
                                scl_low<=1;
                                if (rx_index+6'd1 < length_r) begin
                                    rx_index<=rx_index+1'b1; bit_index<=7;
                                    rx_byte<=0; state<=RX;
                                end else state<=STOP;
                            end
                        endcase
                        STOP: case (phase)
                            0: begin scl_low<=1; sda_low<=1; end
                            1: scl_low<=0;
                            2: sda_low<=0;
                            3: begin scl_low<=0; sda_low<=0; state<=IDLE; done<=1; end
                        endcase
                        default: begin state<=IDLE; scl_low<=0; sda_low<=0; error<=1; done<=1; end
                    endcase
                end
            end
        end
    end
endmodule
