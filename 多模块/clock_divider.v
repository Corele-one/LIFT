module clock_divider #(
    parameter integer CLK_FREQ_HZ = 50_000_000,
    parameter integer TICK_HZ = 10
)(
    input wire clk,
    input wire rst_n,
    output reg tick
);

localparam integer DIV_MAX = CLK_FREQ_HZ / TICK_HZ;

reg [31:0] div_cnt;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        div_cnt <= 32'd0;
        tick <= 1'b0;
    end else begin
        if (div_cnt == DIV_MAX - 1) begin
            div_cnt <= 32'd0;
            tick <= 1'b1;
        end else begin
            div_cnt <= div_cnt + 1'b1;
            tick <= 1'b0;
        end
    end
end

endmodule
