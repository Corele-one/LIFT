module elevator_modular_top #(
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
    output wire beep
);

localparam [2:0] ST_OFF      = 3'd0;
localparam [2:0] ST_POWER_ON = 3'd1;
localparam [2:0] ST_IDLE_1F  = 3'd2;
localparam [2:0] ST_IDLE_2F  = 3'd3;
localparam [2:0] ST_UP       = 3'd4;
localparam [2:0] ST_DOWN     = 3'd5;

localparam [3:0] DISP_BLANK = 4'he;
localparam [3:0] DISP_CHAR_O = 4'hb;
localparam [3:0] DISP_CHAR_N = 4'hc;
localparam [3:0] DISP_OFF_O = DISP_CHAR_O;
localparam [3:0] DISP_OFF_F = 4'hf;
localparam [3:0] DISP_UP    = 4'ha;
localparam [3:0] DISP_DOWN  = 4'hd;
localparam [3:0] DISP_IDLE  = 4'h0;

wire tick_01s;
wire reset_to_1f;
wire [3:0] key_code;
wire key_valid;
wire [2:0] state;
wire [5:0] state_time_01s;
wire [3:0] current_floor;
wire [3:0] target_floor;
wire [15:0] request_led;
wire arrive_pulse;
wire [4:0] led_motion;
wire [3:0] floor_display;
wire [3:0] run_seconds;
wire [3:0] run_tenths;
wire [3:0] state_symbol;

reg [3:0] disp0;
reg [3:0] disp1;
reg [3:0] disp2;
reg [3:0] disp3;
reg [3:0] disp4;
reg [3:0] disp5;
reg [5:0] disp_dp;

assign reset_to_1f = (sw11 == 1'b0);

clock_divider #(
    .CLK_FREQ_HZ(CLK_FREQ_HZ),
    .TICK_HZ(10)
) u_tick_01s (
    .clk(clk),
    .rst_n(rst_n),
    .tick(tick_01s)
);

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

elevator_controller u_elevator_controller (
    .clk(clk),
    .rst_n(rst_n),
    .power_sw(sw0),
    .reset_to_1f(reset_to_1f),
    .tick_01s(tick_01s),
    .key_valid(key_valid),
    .key_code(key_code),
    .state(state),
    .state_time_01s(state_time_01s),
    .current_floor(current_floor),
    .target_floor(target_floor),
    .request_led(request_led),
    .arrive_pulse(arrive_pulse)
);

buzzer_controller #(
    .CLK_FREQ_HZ(CLK_FREQ_HZ)
) u_buzzer_controller (
    .clk(clk),
    .rst_n(rst_n),
    .tick_01s(tick_01s),
    .arrive_pulse(arrive_pulse),
    .beep(beep)
);

elevator_motion_view u_elevator_motion_view (
    .state(state),
    .state_time_01s(state_time_01s),
    .current_floor(current_floor),
    .led_motion(led_motion),
    .floor_display(floor_display),
    .run_seconds(run_seconds),
    .run_tenths(run_tenths),
    .state_symbol(state_symbol)
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

always @(*) begin
    led = request_led;
    led[11:7] = led_motion;
end

always @(*) begin
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
