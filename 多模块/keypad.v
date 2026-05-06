module matrix_keypad_controller #(
    parameter integer CLK_FREQ_HZ = 50_000_000,
    parameter integer SCAN_HZ = 1000,
    parameter integer DEBOUNCE_FRAMES = 5
)(
    input wire clk,
    input wire rst_n,
    input wire [3:0] col,
    output wire [3:0] row,
    output reg [3:0] key_code,
    output reg key_valid
);

localparam integer SCAN_DIVIDER = CLK_FREQ_HZ / SCAN_HZ;

reg [31:0] scan_counter;
reg scan_tick;
reg [1:0] row_index;
reg [15:0] matrix_sample;
reg [15:0] raw_keys;
reg [15:0] raw_keys_prev;
reg [15:0] debounced_keys;
reg [15:0] debounce_count;

wire [3:0] col_pressed;
wire [15:0] frame_keys;

assign col_pressed = ~col;
assign row = ~(4'b0001 << row_index);

assign frame_keys[3:0]   = (row_index == 2'd0) ? col_pressed : matrix_sample[3:0];
assign frame_keys[7:4]   = (row_index == 2'd1) ? col_pressed : matrix_sample[7:4];
assign frame_keys[11:8]  = (row_index == 2'd2) ? col_pressed : matrix_sample[11:8];
assign frame_keys[15:12] = (row_index == 2'd3) ? col_pressed : matrix_sample[15:12];

function [3:0] encode_key;
    input [15:0] keys;
    begin
        casez (keys)
            16'b???????????????1: encode_key = 4'd0;
            16'b??????????????10: encode_key = 4'd1;
            16'b?????????????100: encode_key = 4'd2;
            16'b????????????1000: encode_key = 4'd3;
            16'b???????????10000: encode_key = 4'd4;
            16'b??????????100000: encode_key = 4'd5;
            16'b?????????1000000: encode_key = 4'd6;
            16'b????????10000000: encode_key = 4'd7;
            16'b???????100000000: encode_key = 4'd8;
            16'b??????1000000000: encode_key = 4'd9;
            16'b?????10000000000: encode_key = 4'd10;
            16'b????100000000000: encode_key = 4'd11;
            16'b???1000000000000: encode_key = 4'd12;
            16'b??10000000000000: encode_key = 4'd13;
            16'b?100000000000000: encode_key = 4'd14;
            16'b1000000000000000: encode_key = 4'd15;
            default:              encode_key = 4'd0;
        endcase
    end
endfunction

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        scan_counter <= 32'd0;
        scan_tick <= 1'b0;
    end else begin
        if (scan_counter == SCAN_DIVIDER - 1) begin
            scan_counter <= 32'd0;
            scan_tick <= 1'b1;
        end else begin
            scan_counter <= scan_counter + 1'b1;
            scan_tick <= 1'b0;
        end
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        row_index <= 2'd0;
        matrix_sample <= 16'd0;
        raw_keys <= 16'd0;
        raw_keys_prev <= 16'd0;
        debounced_keys <= 16'd0;
        debounce_count <= 16'd0;
        key_code <= 4'd0;
        key_valid <= 1'b0;
    end else begin
        key_valid <= 1'b0;

        if (scan_tick) begin
            case (row_index)
                2'd0: matrix_sample[3:0]   <= col_pressed;
                2'd1: matrix_sample[7:4]   <= col_pressed;
                2'd2: matrix_sample[11:8]  <= col_pressed;
                2'd3: matrix_sample[15:12] <= col_pressed;
                default: matrix_sample <= 16'd0;
            endcase

            if (row_index == 2'd3) begin
                raw_keys_prev <= raw_keys;
                raw_keys <= frame_keys;

                if (frame_keys == raw_keys_prev) begin
                    if (debounce_count < DEBOUNCE_FRAMES) begin
                        debounce_count <= debounce_count + 1'b1;
                    end

                    if (debounce_count == DEBOUNCE_FRAMES - 1) begin
                        debounced_keys <= frame_keys;
                        key_valid <= |(frame_keys & ~debounced_keys);
                        key_code <= encode_key(frame_keys & ~debounced_keys);
                    end
                end else begin
                    debounce_count <= 16'd0;
                end
            end

            row_index <= row_index + 1'b1;
        end
    end
end

endmodule
