module mixer4 (
    input  wire signed [15:0] ch0,
    input  wire signed [15:0] ch1,
    input  wire signed [15:0] ch2,
    input  wire signed [15:0] ch3,

    output wire signed [15:0] audio_out
);

    // 符号扩展到18位
    wire signed [17:0] s0;
    wire signed [17:0] s1;
    wire signed [17:0] s2;
    wire signed [17:0] s3;

    wire signed [17:0] mix_sum;

    assign s0 = {{2{ch0[15]}}, ch0};
    assign s1 = {{2{ch1[15]}}, ch1};
    assign s2 = {{2{ch2[15]}}, ch2};
    assign s3 = {{2{ch3[15]}}, ch3};

    // 四路相加
    assign mix_sum = s0 + s1 + s2 + s3;

    // 除以4，避免削波
    assign audio_out = mix_sum[17:2]; // explicit signed divide-by-four slice

endmodule
