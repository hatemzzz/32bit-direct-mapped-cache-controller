module tb_cache_controller;

    reg clk;
    reg rst;

    always #5 clk = ~clk;

    reg         sel_manual;
    reg         trace_enable;

    reg  [31:0] manual_addr;
    reg         manual_rd_en;
    reg         manual_wr_en;
    reg  [31:0] manual_wr_data;

    wire [31:0] trace_addr;
    wire        trace_rd_en;
    wire        trace_wr_en;
    wire [31:0] trace_wr_data;
    wire        trace_valid;

    wire [31:0] cpu_addr;
    wire        cpu_rd_en;
    wire        cpu_wr_en;
    wire [31:0] cpu_wr_data;
    wire [31:0] cpu_rd_data;
    wire        cpu_ready;

    assign cpu_addr    = sel_manual ? manual_addr    : trace_addr;
    assign cpu_rd_en   = sel_manual ? manual_rd_en   : (trace_valid & trace_rd_en);
    assign cpu_wr_en   = sel_manual ? manual_wr_en   : (trace_valid & trace_wr_en);
    assign cpu_wr_data = sel_manual ? manual_wr_data : trace_wr_data;

    wire [5:0]   index;
    wire [21:0]  tag_in;
    wire [127:0] data_in;
    wire         wr_en;
    wire         dirty_in;
    wire         hit;
    wire         dirty_out;
    wire [127:0] data_out;
    wire [21:0]  tag_out;

    wire [31:0]  mem_addr;
    wire         mem_wr_en;
    wire [127:0] mem_wr_data;
    wire         mem_rd_en;
    wire [127:0] mem_rd_data;
    wire         mem_ready;

    reg was_hit;
    always @(posedge clk) begin
        if (rst)
            was_hit <= 1'b0;
        else if (u_cache_controller.state == 3'b001)
            was_hit <= hit;
    end

    wire cache_access = cpu_ready;
    wire cache_hit    = was_hit;

    wire [31:0] total_accesses;
    wire [31:0] total_hits;
    wire [31:0] total_misses;

    cache_storage #(
        .TAG_WIDTH(22),
        .DATA_WIDTH(128),
        .NUM_LINES(64)
    ) u_cache_storage (
        .clk       (clk),
        .rst       (rst),
        .index     (index),
        .tag_in    (tag_in),
        .data_in   (data_in),
        .wr_en     (wr_en),
        .dirty_in  (dirty_in),
        .hit       (hit),
        .dirty_out (dirty_out),
        .data_out  (data_out),
        .tag_out   (tag_out)
    );

    main_memory #(
        .DATA_WIDTH(128),
        .MEM_DEPTH(1024)
    ) u_main_memory (
        .clk     (clk),
        .rst     (rst),
        .addr    (mem_addr),
        .wr_en   (mem_wr_en),
        .wr_data (mem_wr_data),
        .rd_en   (mem_rd_en),
        .rd_data (mem_rd_data),
        .ready   (mem_ready)
    );

    cache_controller u_cache_controller (
        .clk         (clk),
        .rst         (rst),

        .cpu_addr    (cpu_addr),
        .cpu_rd_en   (cpu_rd_en),
        .cpu_wr_en   (cpu_wr_en),
        .cpu_wr_data (cpu_wr_data),
        .cpu_rd_data (cpu_rd_data),
        .cpu_ready   (cpu_ready),

        .index       (index),
        .tag_in      (tag_in),
        .data_in     (data_in),
        .wr_en       (wr_en),
        .dirty_in    (dirty_in),
        .hit         (hit),
        .dirty_out   (dirty_out),
        .data_out    (data_out),
        .tag_out     (tag_out),

        .mem_addr    (mem_addr),
        .mem_wr_en   (mem_wr_en),
        .mem_wr_data (mem_wr_data),
        .mem_rd_en   (mem_rd_en),
        .mem_rd_data (mem_rd_data),
        .mem_ready   (mem_ready)
    );

    perf_counters u_perf_counters (
        .clk            (clk),
        .rst            (rst),
        .cache_access   (cache_access),
        .cache_hit      (cache_hit),
        .total_accesses (total_accesses),
        .total_hits     (total_hits),
        .total_misses   (total_misses)
    );

    trace_generator u_trace_generator (
        .clk         (clk),
        .rst         (rst),
        .enable      (trace_enable),
        .cpu_addr    (trace_addr),
        .cpu_rd_en   (trace_rd_en),
        .cpu_wr_en   (trace_wr_en),
        .cpu_wr_data (trace_wr_data),
        .valid       (trace_valid)
    );

    reg mem_wr_en_d;
    always @(posedge clk) begin
        if (rst)
            mem_wr_en_d <= 1'b0;
        else
            mem_wr_en_d <= mem_wr_en;
    end

    always @(posedge clk) begin
        if (!rst && mem_wr_en && !mem_wr_en_d) begin
            $display("[%0t] *** DIRTY-LINE EVICTION: writing back index=%0d tag=%h data=%h to mem_addr=%h ***",
                      $time, index, tag_out, data_out, mem_addr);
        end
    end

    task cpu_read;
        input [31:0] addr;
        begin
            @(posedge clk);
            manual_addr  = addr;
            manual_rd_en = 1'b1;
            manual_wr_en = 1'b0;
            @(posedge clk);
            manual_rd_en = 1'b0;

            while (!cpu_ready) @(posedge clk);

            $display("[%0t] READ  addr=%h -> data=%h", $time, addr, cpu_rd_data);
        end
    endtask

    task cpu_write;
        input [31:0] addr;
        input [31:0] data;
        begin
            @(posedge clk);
            manual_addr    = addr;
            manual_wr_data = data;
            manual_wr_en   = 1'b1;
            manual_rd_en   = 1'b0;
            @(posedge clk);
            manual_wr_en   = 1'b0;

            while (!cpu_ready) @(posedge clk);

            $display("[%0t] WRITE addr=%h <- data=%h", $time, addr, data);
        end
    endtask

    initial begin
        clk            = 1'b0;
        rst            = 1'b1;
        sel_manual     = 1'b1;
        trace_enable   = 1'b0;
        manual_addr    = 32'b0;
        manual_rd_en   = 1'b0;
        manual_wr_en   = 1'b0;
        manual_wr_data = 32'b0;

        repeat (4) @(posedge clk);
        rst = 1'b0;
        @(posedge clk);

        $display("=========================================================");
        $display(" Scenario 1: Cold miss (read address not yet in cache)");
        $display("=========================================================");
        cpu_read(32'h00000000);

        $display("=========================================================");
        $display(" Scenario 2: Hit (read the exact same address again)");
        $display("=========================================================");
        cpu_read(32'h00000000);

        $display("=========================================================");
        $display(" Scenario 3: Dirty-line eviction");
        $display("=========================================================");
        cpu_write(32'h00000100, 32'hDEADBEEF);
        cpu_read(32'h00000500);

        $display("=========================================================");
        $display(" Directed scenarios complete. Handing control to trace_generator.");
        $display("=========================================================");

        sel_manual   = 1'b0;
        trace_enable = 1'b1;

        repeat (500) @(posedge clk);

        $display("=========================================================");
        $display(" FINAL PERFORMANCE COUNTERS");
        $display("   Total Accesses = %0d", total_accesses);
        $display("   Total Hits     = %0d", total_hits);
        $display("   Total Misses   = %0d", total_misses);
        $display("=========================================================");

        $finish;
    end

endmodule