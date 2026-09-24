module main_memory #(
    parameter DATA_WIDTH = 128,
    parameter MEM_DEPTH  = 1024
) (
    input  wire                  clk,
    input  wire                  rst,
    input  wire [31:0]           addr,
    input  wire                  wr_en,
    input  wire [DATA_WIDTH-1:0] wr_data,
    input  wire                  rd_en,
    output reg  [DATA_WIDTH-1:0] rd_data,
    output reg                   ready
);

    reg [DATA_WIDTH-1:0] mem_array [0:MEM_DEPTH-1];
    integer i;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i < MEM_DEPTH; i = i + 1) begin
                mem_array[i] <= {DATA_WIDTH{1'b0}};
            end
            mem_array[0] <= 128'hDEADBEEF_CAFEF00D_11223344_AABBCCDD;
            rd_data <= {DATA_WIDTH{1'b0}};
            ready   <= 1'b0;
        end else begin
            ready <= 1'b0;
            
            if (wr_en) begin
                mem_array[addr[13:4]] <= wr_data;
                ready                 <= 1'b1;
            end else if (rd_en) begin
                rd_data <= mem_array[addr[13:4]];
                ready   <= 1'b1;
            end
        end
    end
endmodule