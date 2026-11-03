module adsr (
    input  wire               clk,
    input  wire               rst_n,
    input  wire               sample_tick,
    input  wire [5:0]         release_period, // samples per gain step

    // 1 = 按键按下
    // 0 = 按键松开
    input  wire               note_on,
    input  wire               note_start, // one clk pulse, latched until sample_tick

    input  wire signed [15:0] audio_in,

    output wire signed [15:0] audio_out,

    // 仿真时观察当前音量
    output reg [7:0]          gain
);

    localparam IDLE    = 3'd0;
    localparam ATTACK  = 3'd1;
    localparam DECAY   = 3'd2;
    localparam SUSTAIN = 3'd3;
    localparam RELEASE = 3'd4;

    reg [2:0] state;
    reg restart_pending;

    // 包络参数
    localparam [7:0] ATTACK_STEP  = 8'd4;
    localparam [7:0] DECAY_STEP   = 8'd1;
    reg [5:0] release_counter;
    wire [5:0] release_period_safe =
        (release_period == 6'd0) ? 6'd1 : release_period;

    // Sustain 音量约 62.5%
    localparam [7:0] SUSTAIN_LEVEL = 8'd160;


    always @(posedge clk or negedge rst_n) begin

        if(!rst_n) begin

            state <= IDLE;
            gain  <= 8'd0;
            release_counter <= 6'd0;
            restart_pending <= 1'b0;

        end

        else begin
            if (note_start) restart_pending <= 1'b1;
            if(sample_tick) begin
            restart_pending <= 1'b0;
            if (note_on && (note_start || restart_pending)) begin
                state <= ATTACK;
                gain <= 8'd0;
                release_counter <= 6'd0;
            end else begin
            if (state != RELEASE)
                release_counter <= 6'd0;

            case(state)

                // ==========================
                // 静音
                // ==========================
                IDLE: begin

                    gain <= 8'd0;

                    if(note_on)
                        state <= ATTACK;

                end


                // ==========================
                // Attack
                // 音量从0升到最大
                // ==========================
                ATTACK: begin

                    if(!note_on) begin

                        state <= RELEASE;

                    end

                    else if(gain >= 8'd255 - ATTACK_STEP) begin

                        gain  <= 8'd255;
                        state <= DECAY;

                    end

                    else begin

                        gain <= gain + ATTACK_STEP;

                    end

                end


                // ==========================
                // Decay
                // 最大音量下降到 Sustain
                // ==========================
                DECAY: begin

                    if(!note_on) begin

                        state <= RELEASE;

                    end

                    else if(gain <= SUSTAIN_LEVEL + DECAY_STEP) begin

                        gain  <= SUSTAIN_LEVEL;
                        state <= SUSTAIN;

                    end

                    else begin

                        gain <= gain - DECAY_STEP;

                    end

                end


                // ==========================
                // Sustain
                // 按键按住保持
                // ==========================
                SUSTAIN: begin

                    gain <= SUSTAIN_LEVEL;

                    if(!note_on)
                        state <= RELEASE;

                end


                // ==========================
                // Release
                // 松开后逐渐减小
                // ==========================
                RELEASE: begin
                    if (note_on) begin
                        state <= ATTACK;
                        release_counter <= 6'd0;
                    end else if (release_counter >= (release_period_safe - 6'd1)) begin
                        release_counter <= 6'd0;
                        if (gain <= 8'd1) begin
                            gain <= 8'd0;
                            state <= IDLE;
                        end else begin
                            gain <= gain - 8'd1;
                        end
                    end else begin
                        release_counter <= release_counter + 6'd1;
                    end
                end


                default: begin

                    gain  <= 8'd0;
                    state <= IDLE;

                end

            endcase
            end
            end

        end

    end


    // =====================================================
    // 音频 × 包络
    //
    // audio_in : signed 16bit
    // gain     : 0~255
    //
    // gain=255 → 接近原音量
    // gain=0   → 静音
    // =====================================================

    wire signed [24:0] mult_result;

    assign mult_result =
        audio_in * $signed({1'b0, gain});

    // gain 相当于 Q0.8 系数
    // 乘法后右移 8 bit，恢复为 16bit PCM
    assign audio_out = mult_result[23:8];

endmodule

