module elevator_controller (
    input wire clk,
    input wire rst_n,
    input wire power_sw,
    input wire reset_to_1f,
    input wire tick_01s,
    input wire key_valid,
    input wire [3:0] key_code,
    output reg [2:0] state,
    output reg [5:0] state_time_01s,
    output reg [3:0] current_floor,
    output reg [3:0] target_floor,
    output reg [15:0] request_led,
    output reg arrive_pulse
);

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

reg return_to_1f;

wire moving;
wire move_done;
wire [5:0] next_state_time_01s;

assign moving = (state == ST_UP) || (state == ST_DOWN);
assign move_done = moving && tick_01s && (state_time_01s == 6'd29);
assign next_state_time_01s = state_time_01s + 1'b1;

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

        if (!power_sw) begin
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

endmodule
