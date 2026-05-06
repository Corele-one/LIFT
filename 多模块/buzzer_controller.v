module buzzer_controller #(
    parameter integer CLK_FREQ_HZ = 50_000_000
)(
    input wire clk,
    input wire rst_n,
    input wire tick_01s,
    input wire arrive_pulse,
    output wire beep
);

localparam integer BEEP_DIV_MAX = CLK_FREQ_HZ / 2000;

reg [31:0] beep_div_cnt;
reg beep_1khz;
reg [3:0] beep_time_01s;
reg beep_en;

assign beep = beep_en ? beep_1khz : 1'b0;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        beep_div_cnt <= 32'd0;
        beep_1khz <= 1'b0;
    end else begin
        if (beep_div_cnt == BEEP_DIV_MAX - 1) begin
            beep_div_cnt <= 32'd0;
            beep_1khz <= ~beep_1khz;
        end else begin
            beep_div_cnt <= beep_div_cnt + 1'b1;
        end
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        beep_time_01s <= 4'd0;
        beep_en <= 1'b0;
    end else begin
        if (arrive_pulse) begin
            beep_time_01s <= 4'd15;
        end else if (tick_01s && beep_time_01s != 4'd0) begin
            beep_time_01s <= beep_time_01s - 1'b1;
        end

        beep_en <= (beep_time_01s == 4'd15) ||
                   (beep_time_01s == 4'd14) ||
                   (beep_time_01s == 4'd10) ||
                   (beep_time_01s == 4'd9)  ||
                   (beep_time_01s == 4'd5)  ||
                   (beep_time_01s == 4'd4);
    end
end

endmodule
