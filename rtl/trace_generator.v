module trace_generator (
    input  wire        clk,
    input  wire        rst,
    input  wire        enable,

    output reg  [31:0] cpu_addr,
    output reg         cpu_rd_en,
    output reg         cpu_wr_en,
    output reg  [31:0] cpu_wr_data,
    output reg         valid
);

    localparam WAIT_CYCLES = 4'd12;

    reg [3:0]  pattern_step;
    reg [3:0]  wait_count;
    reg        issuing;
    reg [31:0] base_addr;

    reg [31:0] step_addr;
    reg        step_is_write;

    always @(*) begin
        case (pattern_step)
            4'd0: begin step_addr = base_addr;                step_is_write = 1'b1; end
            4'd1: begin step_addr = base_addr;                step_is_write = 1'b0; end
            4'd2: begin step_addr = base_addr + 32'h00000010; step_is_write = 1'b1; end
            4'd3: begin step_addr = base_addr + 32'h00000010; step_is_write = 1'b0; end
            4'd4: begin step_addr = base_addr + 32'h00000400; step_is_write = 1'b1; end
            4'd5: begin step_addr = base_addr + 32'h00000400; step_is_write = 1'b0; end
            4'd6: begin step_addr = base_addr;                step_is_write = 1'b0; end
            4'd7: begin step_addr = base_addr + 32'h00000020; step_is_write = 1'b1; end
            4'd8: begin step_addr = base_addr + 32'h00000020; step_is_write = 1'b0; end
            4'd9: begin step_addr = base_addr;                step_is_write = 1'b1; end
            default: begin step_addr = base_addr;             step_is_write = 1'b0; end
        endcase
    end

    always @(posedge clk) begin
        if (rst) begin
            pattern_step <= 4'd0;
            wait_count   <= 4'd0;
            issuing      <= 1'b0;
            base_addr    <= 32'h00000000;
            cpu_addr     <= 32'b0;
            cpu_rd_en    <= 1'b0;
            cpu_wr_en    <= 1'b0;
            cpu_wr_data  <= 32'b0;
            valid        <= 1'b0;
        end else if (!enable) begin
            cpu_rd_en  <= 1'b0;
            cpu_wr_en  <= 1'b0;
            valid      <= 1'b0;
            issuing    <= 1'b0;
            wait_count <= 4'd0;
        end else begin
            if (!issuing) begin
                cpu_addr    <= step_addr;
                cpu_wr_data <= step_addr;
                cpu_rd_en   <= ~step_is_write;
                cpu_wr_en   <= step_is_write;
                valid       <= 1'b1;
                issuing     <= 1'b1;
                wait_count  <= 4'd0;
            end else begin
                cpu_rd_en <= 1'b0;
                cpu_wr_en <= 1'b0;
                valid     <= 1'b0;

                if (wait_count == WAIT_CYCLES) begin
                    issuing <= 1'b0;
                    if (pattern_step == 4'd9) begin
                        pattern_step <= 4'd0;
                        base_addr    <= base_addr + 32'h00000040;
                    end else begin
                        pattern_step <= pattern_step + 4'd1;
                    end
                end else begin
                    wait_count <= wait_count + 4'd1;
                end
            end
        end
    end

endmodule