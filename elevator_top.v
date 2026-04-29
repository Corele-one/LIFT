module elevator_top #(
    parameter integer CLK_FREQ_HZ = 50_000_000
)(
    input wire clk,
    input wire rst_n,
    input wire sw0,
    input wire sw11,
    input wire [3:0] col,
    output wire [3:0] row,
    output wire [7:0] seg,
    output wire [5:0] dig,
    output reg [15:0] led,
    output reg beep
);

localparam integer TICK_01S_MAX = CLK_FREQ_HZ / 10;
localparam integer BEEP_DIV_MAX = CLK_FREQ_HZ / 2000;

localparam [2:0] ST_OFF      = 3'd0;
localparam [2:0] ST_POWER_ON = 3'd1;
localparam [2:0] ST_IDLE_1F  = 3'd2;
localparam [2:0] ST_IDLE_2F  = 3'd3;
localparam [2:0] ST_UP       = 3'd4;
localparam [2:0] ST_DOWN     = 3'd5;

localparam [3:0] KEY_1F_UP     = 4'd0;
localparam [3:0] KEY_INNER_1F  = 4'd3;
localparam [3:0] KEY_2F_DOWN   = 4'd12;
localparam [3:0] KEY_INNER_2F  = 4'd15;

localparam [3:0] DISP_BLANK = 4'he;
localparam [3:0] DISP_CHAR_O = 4'hb;
localparam [3:0] DISP_CHAR_N = 4'hc;
localparam [3:0] DISP_OFF_O = DISP_CHAR_O;
localparam [3:0] DISP_OFF_F = 4'hf;
localparam [3:0] DISP_UP    = 4'ha;
localparam [3:0] DISP_DOWN  = 4'hd;
localparam [3:0] DISP_IDLE  = 4'h0;

reg [2:0] state;
reg [2:0] next_state;
reg [31:0] tick_cnt;
reg tick_01s;
reg [5:0] state_time_01s;
reg [3:0] current_floor;
reg [3:0] target_floor;
reg [15:0] request_led;
reg return_to_1f;
reg [3:0] disp0;
reg [3:0] disp1;
reg [3:0] disp2;
reg [3:0] disp3;
reg [3:0] disp4;
reg [3:0] disp5;
reg [5:0] disp_dp;
reg [3:0] floor_display;
reg [3:0] run_seconds;
reg [3:0] run_tenths;
reg [3:0] state_symbol;
wire [3:0] key_code;
wire key_valid;
reg arrive_pulse;
reg [3:0] beep_time_01s;
reg [31:0] beep_div_cnt;
reg beep_1khz;
reg beep_en;

wire reset_to_1f;
wire moving;
wire move_done;
wire [5:0] next_state_time_01s;

assign reset_to_1f = (sw11 == 1'b0);
assign moving = (state == ST_UP) || (state == ST_DOWN);
assign move_done = moving && tick_01s && (state_time_01s == 6'd29);
assign next_state_time_01s = state_time_01s + 1'b1;

matrix_keypad_controller #(
    .CLK_FREQ_HZ(CLK_FREQ_HZ)
) u_keypad (
    .clk(clk),
    .rst_n(rst_n),
    .col(col),
    .row(row),
    .key_code(key_code),
    .key_valid(key_valid)
);

dynamic_led6 u_dynamic_led6 (
    .disp_data_right0(disp0),
    .disp_data_right1(disp1),
    .disp_data_right2(disp2),
    .disp_data_right3(disp3),
    .disp_data_right4(disp4),
    .disp_data_right5(disp5),
    .dp_en(disp_dp),
    .clk(clk),
    .seg(seg),
    .dig(dig)
);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        tick_cnt <= 32'd0;
        tick_01s <= 1'b0;
    end else begin
        if (tick_cnt == TICK_01S_MAX - 1) begin
            tick_cnt <= 32'd0;
            tick_01s <= 1'b1;
        end else begin
            tick_cnt <= tick_cnt + 1'b1;
            tick_01s <= 1'b0;
        end
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= ST_OFF;
        state_time_01s <= 6'd0;
        current_floor <= 4'd1;
        target_floor <= 4'd1;
        request_led <= 16'd0;
        return_to_1f <= 1'b0;
        arrive_pulse <= 1'b0;
    end else begin
        arrive_pulse <= 1'b0;

        if (!sw0) begin
            state <= ST_OFF;
            state_time_01s <= 6'd0;
            request_led <= 16'd0;
            return_to_1f <= 1'b0;
        end else if (reset_to_1f && state != ST_IDLE_1F && state != ST_DOWN) begin
            state <= ST_DOWN;
            state_time_01s <= 6'd0;
            target_floor <= 4'd1;
            request_led <= 16'd0;
            return_to_1f <= 1'b1;
        end else begin
            case (state)
                ST_OFF: begin
                    state <= ST_POWER_ON;
                    state_time_01s <= 6'd0;
                end

                ST_POWER_ON: begin
                    if (tick_01s) begin
                        if (state_time_01s == 6'd9) begin
                            state <= (current_floor == 4'd2) ? ST_IDLE_2F : ST_IDLE_1F;
                            state_time_01s <= 6'd0;
                        end else begin
                            state_time_01s <= next_state_time_01s;
                        end
                    end
                end

                ST_IDLE_1F: begin
                    state_time_01s <= 6'd0;
                    request_led <= 16'd0;
                    return_to_1f <= 1'b0;
                    current_floor <= 4'd1;
                    target_floor <= 4'd1;

                    if (key_valid && key_code == KEY_INNER_2F) begin
                        state <= ST_UP;
                        target_floor <= 4'd2;
                        request_led <= 16'h0008;
                    end else if (key_valid && key_code == KEY_2F_DOWN) begin
                        state <= ST_UP;
                        target_floor <= 4'd2;
                        request_led <= 16'h0002;
                    end
                end

                ST_IDLE_2F: begin
                    state_time_01s <= 6'd0;
                    request_led <= 16'd0;
                    return_to_1f <= 1'b0;
                    current_floor <= 4'd2;
                    target_floor <= 4'd2;

                    if (key_valid && key_code == KEY_INNER_1F) begin
                        state <= ST_DOWN;
                        target_floor <= 4'd1;
                        request_led <= 16'h0004;
                    end else if (key_valid && key_code == KEY_1F_UP) begin
                        state <= ST_DOWN;
                        target_floor <= 4'd1;
                        request_led <= 16'h0001;
                    end
                end

                ST_UP: begin
                    if (key_valid && key_code == KEY_INNER_1F) begin
                        request_led <= 16'h0004;
                        return_to_1f <= 1'b1;
                    end else if (key_valid && key_code == KEY_1F_UP) begin
                        request_led <= 16'h0001;
                        return_to_1f <= 1'b1;
                    end

                    if (move_done) begin
                        current_floor <= 4'd2;
                        arrive_pulse <= 1'b1;
                        state_time_01s <= 6'd0;

                        if (return_to_1f) begin
                            state <= ST_DOWN;
                            target_floor <= 4'd1;
                        end else begin
                            state <= ST_IDLE_2F;
                            target_floor <= 4'd2;
                            request_led <= 16'd0;
                        end
                    end else if (tick_01s) begin
                        state_time_01s <= next_state_time_01s;
                    end
                end

                ST_DOWN: begin
                    if (key_valid && key_code == KEY_INNER_2F) begin
                        request_led <= 16'h0008;
                        return_to_1f <= 1'b0;
                    end else if (key_valid && key_code == KEY_2F_DOWN) begin
                        request_led <= 16'h0002;
                        return_to_1f <= 1'b0;
                    end

                    if (move_done) begin
                        current_floor <= 4'd1;
                        arrive_pulse <= 1'b1;
                        state_time_01s <= 6'd0;
                        state <= ST_IDLE_1F;
                        target_floor <= 4'd1;
                        request_led <= 16'd0;
                        return_to_1f <= 1'b0;
                    end else if (tick_01s) begin
                        state_time_01s <= next_state_time_01s;
                    end
                end

                default: begin
                    state <= ST_OFF;
                    state_time_01s <= 6'd0;
                end
            endcase
        end
    end
end

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

always @(*) begin
    beep = beep_en ? beep_1khz : 1'b0;
end

always @(*) begin
    led = request_led;

    if (state == ST_DOWN) begin
        case (state_time_01s / 6'd6)
            6'd0: led[11:7] = 5'b00001;
            6'd1: led[11:7] = 5'b00010;
            6'd2: led[11:7] = 5'b00100;
            6'd3: led[11:7] = 5'b01000;
            default: led[11:7] = 5'b10000;
        endcase
    end else if (state == ST_UP) begin
        case (state_time_01s / 6'd6)
            6'd0: led[11:7] = 5'b10000;
            6'd1: led[11:7] = 5'b01000;
            6'd2: led[11:7] = 5'b00100;
            6'd3: led[11:7] = 5'b00010;
            default: led[11:7] = 5'b00001;
        endcase
    end else begin
        led[11:7] = 5'b00000;
    end
end

always @(*) begin
    if (state == ST_UP) begin
        floor_display = (state_time_01s < 6'd20) ? 4'd1 : 4'd2;
    end else if (state == ST_DOWN) begin
        floor_display = (state_time_01s < 6'd20) ? 4'd2 : 4'd1;
    end else begin
        floor_display = current_floor;
    end

    if (moving) begin
        run_seconds = state_time_01s / 6'd10;
        run_tenths = state_time_01s % 6'd10;
    end else begin
        run_seconds = 4'd0;
        run_tenths = 4'd0;
    end

    case (state)
        ST_UP: state_symbol = DISP_UP;
        ST_DOWN: state_symbol = DISP_DOWN;
        default: state_symbol = DISP_IDLE;
    endcase

    disp0 = floor_display;
    disp1 = state_symbol;
    disp2 = DISP_BLANK;
    disp3 = run_tenths;
    disp4 = run_seconds;
    disp5 = DISP_BLANK;
    disp_dp = 6'b010000;

    if (state == ST_OFF) begin
        disp0 = DISP_OFF_F;
        disp1 = DISP_OFF_F;
        disp2 = DISP_OFF_O;
        disp3 = DISP_BLANK;
        disp4 = DISP_BLANK;
        disp5 = DISP_BLANK;
        disp_dp = 6'b000000;
    end else if (state == ST_POWER_ON) begin
        disp0 = DISP_CHAR_N;
        disp1 = DISP_CHAR_O;
        disp2 = DISP_BLANK;
        disp3 = DISP_BLANK;
        disp4 = DISP_BLANK;
        disp5 = DISP_BLANK;
        disp_dp = 6'b000000;
    end
end

endmodule
