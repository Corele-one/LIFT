module elevator_motion_view (
    input wire [2:0] state,
    input wire [5:0] state_time_01s,
    input wire [3:0] current_floor,
    output reg [4:0] led_motion,
    output reg [3:0] floor_display,
    output reg [3:0] run_seconds,
    output reg [3:0] run_tenths,
    output reg [3:0] state_symbol
);

localparam [2:0] ST_OFF      = 3'd0;
localparam [2:0] ST_POWER_ON = 3'd1;
localparam [2:0] ST_IDLE_1F  = 3'd2;
localparam [2:0] ST_IDLE_2F  = 3'd3;
localparam [2:0] ST_UP       = 3'd4;
localparam [2:0] ST_DOWN     = 3'd5;

localparam [3:0] DISP_UP    = 4'ha;
localparam [3:0] DISP_DOWN  = 4'hd;
localparam [3:0] DISP_IDLE  = 4'h0;

always @(*) begin
    led_motion = 5'b00000;

    if (state == ST_DOWN) begin
        case (state_time_01s / 6'd6)
            6'd0: led_motion = 5'b00001;
            6'd1: led_motion = 5'b00010;
            6'd2: led_motion = 5'b00100;
            6'd3: led_motion = 5'b01000;
            default: led_motion = 5'b10000;
        endcase
    end else if (state == ST_UP) begin
        case (state_time_01s / 6'd6)
            6'd0: led_motion = 5'b10000;
            6'd1: led_motion = 5'b01000;
            6'd2: led_motion = 5'b00100;
            6'd3: led_motion = 5'b00010;
            default: led_motion = 5'b00001;
        endcase
    end

    if (state == ST_UP) begin
        floor_display = (state_time_01s < 6'd20) ? 4'd1 : 4'd2;
    end else if (state == ST_DOWN) begin
        floor_display = (state_time_01s < 6'd20) ? 4'd2 : 4'd1;
    end else begin
        floor_display = current_floor;
    end

    if (state == ST_UP || state == ST_DOWN) begin
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
end

endmodule
