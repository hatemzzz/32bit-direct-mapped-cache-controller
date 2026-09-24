module cache_storage #(
    parameter TAG_WIDTH  = 22,
    parameter DATA_WIDTH = 128,
    parameter NUM_LINES  = 64
) (
    input  wire                  clk,
    input  wire                  rst,
    input  wire [5:0]            index,
    input  wire [TAG_WIDTH-1:0]  tag_in,
    input  wire [DATA_WIDTH-1:0] data_in,
    input  wire                  wr_en,
    input  wire                  dirty_in,
    output wire                  hit,
    output wire                  dirty_out,
    output wire [DATA_WIDTH-1:0] data_out,
    output wire [TAG_WIDTH-1:0]  tag_out
);

    reg [TAG_WIDTH-1:0]  tag_array   [0:NUM_LINES-1];
    reg                  valid_array [0:NUM_LINES-1];
    reg                  dirty_array [0:NUM_LINES-1];
    reg [DATA_WIDTH-1:0] data_array  [0:NUM_LINES-1];

    integer k;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (k = 0; k < NUM_LINES; k = k + 1) begin
                tag_array[k]   <= {TAG_WIDTH{1'b0}};
                valid_array[k] <= 1'b0;
                dirty_array[k] <= 1'b0;
                data_array[k]  <= {DATA_WIDTH{1'b0}};
            end
        end else if (wr_en) begin
            tag_array[index]   <= tag_in;
            data_array[index]  <= data_in;
            valid_array[index] <= 1'b1;
            dirty_array[index] <= dirty_in;
        end
    end

    assign tag_out   = tag_array[index];
    assign dirty_out = valid_array[index] && dirty_array[index];
    assign data_out  = data_array[index];
    assign hit       = valid_array[index] && (tag_array[index] == tag_in);
endmodule