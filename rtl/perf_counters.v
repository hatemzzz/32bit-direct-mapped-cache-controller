module perf_counters (
    input  wire        clk,
    input  wire        rst,
    input  wire        cache_access,
    input  wire        cache_hit,

    output reg  [31:0] total_accesses,
    output reg  [31:0] total_hits,
    output reg  [31:0] total_misses
);

    always @(posedge clk) begin
        if (rst) begin
            total_accesses <= 32'd0;
            total_hits     <= 32'd0;
            total_misses   <= 32'd0;
        end else if (cache_access) begin
            total_accesses <= total_accesses + 32'd1;

            if (cache_hit)
                total_hits <= total_hits + 32'd1;
            else
                total_misses <= total_misses + 32'd1;
        end
    end

endmodule