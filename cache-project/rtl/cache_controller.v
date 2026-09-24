module cache_controller (
    input  wire        clk,
    input  wire        rst,

    // CPU side interface
    input  wire [31:0] cpu_addr,
    input  wire        cpu_rd_en,
    input  wire        cpu_wr_en,
    input  wire [31:0] cpu_wr_data,
    output reg  [31:0] cpu_rd_data,
    output reg         cpu_ready,

    // cache_storage interface
    output reg  [5:0]   index,
    output reg  [21:0]  tag_in,
    output reg  [127:0] data_in,
    output reg          wr_en,
    output reg          dirty_in,
    input  wire         hit,
    input  wire         dirty_out,
    input  wire [127:0] data_out,
    input  wire [21:0]  tag_out,

    // main_memory interface
    output reg  [31:0]  mem_addr,
    output reg          mem_wr_en,
    output reg  [127:0] mem_wr_data,
    output reg          mem_rd_en,
    input  wire [127:0] mem_rd_data,
    input  wire         mem_ready
);

    // FSM state encoding
    localparam IDLE           = 3'b000;
    localparam COMPARE        = 3'b001;
    localparam HIT            = 3'b010;
    localparam MISS_WRITEBACK = 3'b011;
    localparam WB_DRAIN       = 3'b100; // 1-cycle turnaround: allows mem_ready to de-assert
    localparam MISS_WAIT      = 3'b101;
    localparam FILL           = 3'b110;

    reg [2:0] state, next_state;

    // Datapath registers
    reg [31:0]  addr_reg;
    reg [31:0]  wrdata_reg;
    reg         is_write_reg;
    reg [127:0] fetched_line;

    // 1) State register
    always @(posedge clk) begin
        if (rst)
            state <= IDLE;
        else
            state <= next_state;
    end

    // 2) Datapath latches
    always @(posedge clk) begin
        if (rst) begin
            addr_reg     <= 32'b0;
            wrdata_reg   <= 32'b0;
            is_write_reg <= 1'b0;
            fetched_line <= 128'b0;
        end else begin
            // Latch CPU request upon leaving IDLE
            if (state == IDLE && (cpu_rd_en || cpu_wr_en)) begin
                addr_reg     <= cpu_addr;
                wrdata_reg   <= cpu_wr_data;
                is_write_reg <= cpu_wr_en;
            end

            // Capture memory line exactly when ready is asserted
            if (state == MISS_WAIT && mem_ready) begin
                fetched_line <= mem_rd_data;
            end
        end
    end

    // 3) Combinational Next-State & Output Logic
    always @(*) begin
        next_state   = state;
        cpu_ready    = 1'b0;
        cpu_rd_data  = 32'b0;

        index        = addr_reg[9:4];
        tag_in       = addr_reg[31:10];
        data_in      = 128'b0;
        wr_en        = 1'b0;
        dirty_in     = 1'b0;

        mem_addr     = 32'b0;
        mem_wr_en    = 1'b0;
        mem_wr_data  = 128'b0;
        mem_rd_en    = 1'b0;

        case (state)

            IDLE: begin
                index  = cpu_addr[9:4];
                tag_in = cpu_addr[31:10];
                if (cpu_rd_en || cpu_wr_en)
                    next_state = COMPARE;
            end

            COMPARE: begin
                index  = addr_reg[9:4];
                tag_in = addr_reg[31:10];

                if (hit)
                    next_state = HIT;
                else if (dirty_out)
                    next_state = MISS_WRITEBACK;
                else
                    next_state = MISS_WAIT;
            end

            HIT: begin
                index     = addr_reg[9:4];
                tag_in    = addr_reg[31:10];
                cpu_ready = 1'b1;

                if (is_write_reg) begin
                    data_in = data_out;
                    case (addr_reg[3:2])
                        2'b00: data_in[31:0]   = wrdata_reg;
                        2'b01: data_in[63:32]  = wrdata_reg;
                        2'b10: data_in[95:64]  = wrdata_reg;
                        2'b11: data_in[127:96] = wrdata_reg;
                    endcase
                    wr_en    = 1'b1;
                    dirty_in = 1'b1;
                end else begin
                    case (addr_reg[3:2])
                        2'b00: cpu_rd_data = data_out[31:0];
                        2'b01: cpu_rd_data = data_out[63:32];
                        2'b10: cpu_rd_data = data_out[95:64];
                        2'b11: cpu_rd_data = data_out[127:96];
                    endcase
                end

                next_state = IDLE;
            end

            MISS_WRITEBACK: begin
                index       = addr_reg[9:4];
                tag_in      = addr_reg[31:10];
                mem_addr    = {tag_out, addr_reg[9:4], 4'b0000};
                mem_wr_data = data_out;
                mem_wr_en   = 1'b1;

                if (mem_ready)
                    next_state = WB_DRAIN;
                else
                    next_state = MISS_WRITEBACK;
            end

            // Turnaround cycle: mem_wr_en dropped, allows mem_ready to clear
            WB_DRAIN: begin
                next_state = MISS_WAIT;
            end

            MISS_WAIT: begin
                index     = addr_reg[9:4];
                tag_in    = addr_reg[31:10];
                mem_addr  = {addr_reg[31:4], 4'b0000};
                mem_rd_en = 1'b1;

                if (mem_ready)
                    next_state = FILL;
                else
                    next_state = MISS_WAIT;
            end

           FILL: begin
    index   = addr_reg[9:4];
    tag_in  = addr_reg[31:10];
    wr_en   = 1'b1;

    if (is_write_reg) begin
        data_in = mem_rd_data; // changed from fetched_line
        case (addr_reg[3:2])
            2'b00: data_in[31:0]   = wrdata_reg;
            2'b01: data_in[63:32]  = wrdata_reg;
            2'b10: data_in[95:64]  = wrdata_reg;
            2'b11: data_in[127:96] = wrdata_reg;
        endcase
        dirty_in   = 1'b1;
        cpu_ready  = 1'b1;
        next_state = IDLE;
    end else begin
        data_in    = mem_rd_data; // changed from fetched_line
        dirty_in   = 1'b0;
        case (addr_reg[3:2])
            2'b00: cpu_rd_data = mem_rd_data[31:0];   // changed from fetched_line
            2'b01: cpu_rd_data = mem_rd_data[63:32];  // changed from fetched_line
            2'b10: cpu_rd_data = mem_rd_data[95:64];  // changed from fetched_line
            2'b11: cpu_rd_data = mem_rd_data[127:96]; // changed from fetched_line
        endcase
        cpu_ready  = 1'b1;
        next_state = IDLE;
    end
end

            default: begin
                next_state = IDLE;
            end

        endcase
    end

endmodule