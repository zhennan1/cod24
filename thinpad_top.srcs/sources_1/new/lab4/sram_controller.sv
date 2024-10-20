module sram_controller #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32,

    parameter SRAM_ADDR_WIDTH = 20,
    parameter SRAM_DATA_WIDTH = 32,

    localparam SRAM_BYTES = SRAM_DATA_WIDTH / 8,
    localparam SRAM_BYTE_WIDTH = $clog2(SRAM_BYTES)
) (
    // clk and reset
    input wire clk_i,
    input wire rst_i,

    // wishbone slave interface
    input wire wb_cyc_i,
    input wire wb_stb_i,
    output reg wb_ack_o,
    input wire [ADDR_WIDTH-1:0] wb_adr_i,
    input wire [DATA_WIDTH-1:0] wb_dat_i,
    output reg [DATA_WIDTH-1:0] wb_dat_o,
    input wire [DATA_WIDTH/8-1:0] wb_sel_i,
    input wire wb_we_i,

    // sram interface
    output reg [SRAM_ADDR_WIDTH-1:0] sram_addr,
    inout wire [SRAM_DATA_WIDTH-1:0] sram_data,
    output reg sram_ce_n,
    output reg sram_oe_n,
    output reg sram_we_n,
    output reg [SRAM_BYTES-1:0] sram_be_n
);


  // 状态定义
  typedef enum logic [2:0] {
    STATE_IDLE    = 3'd0,
    STATE_READ    = 3'd1,
    STATE_READ_2  = 3'd2,
    STATE_WRITE   = 3'd3,
    STATE_WRITE_2 = 3'd4,
    STATE_WRITE_3 = 3'd5,
    STATE_DONE    = 3'd6
  } state_t;

  state_t state;

  // SRAM 数据总线三态控制
  reg [SRAM_DATA_WIDTH-1:0] sram_data_o;
  wire [SRAM_DATA_WIDTH-1:0] sram_data_i;
  reg sram_data_t;

  assign sram_data = sram_data_t ? {SRAM_DATA_WIDTH{1'bz}} : sram_data_o;
  assign sram_data_i = sram_data;

  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      state         <= STATE_IDLE;
      wb_ack_o      <= 1'b0;
      wb_dat_o      <= {DATA_WIDTH{1'b0}};
      sram_ce_n     <= 1'b1;
      sram_oe_n     <= 1'b1;
      sram_we_n     <= 1'b1;
      sram_be_n     <= {SRAM_BYTES{1'b1}};
      sram_addr     <= {SRAM_ADDR_WIDTH{1'b0}};
      sram_data_t   <= 1'b1;
      sram_data_o   <= {SRAM_DATA_WIDTH{1'b0}};
    end else begin
      case (state)
        STATE_IDLE: begin
          wb_ack_o    <= 1'b0;
          sram_ce_n   <= 1'b1;
          sram_oe_n   <= 1'b1;
          sram_we_n   <= 1'b1;
          sram_be_n   <= {SRAM_BYTES{1'b1}};
          sram_data_t <= 1'b1; // 高阻态

          if (wb_stb_i && wb_cyc_i) begin
            sram_addr <= wb_adr_i[SRAM_ADDR_WIDTH + SRAM_BYTE_WIDTH -1 : SRAM_BYTE_WIDTH];
            sram_be_n <= ~wb_sel_i; // 低有效

            if (wb_we_i) begin
              // 写操作
              sram_ce_n   <= 1'b0; // 选中 SRAM
              sram_we_n   <= 1'b1;
              sram_oe_n   <= 1'b1;
              sram_data_o <= wb_dat_i;
              sram_data_t <= 1'b0; // 驱动数据总线
              state       <= STATE_WRITE;
            end else begin
              // 读操作
              sram_ce_n   <= 1'b0; // 选中 SRAM
              sram_we_n   <= 1'b1;
              sram_oe_n   <= 1'b0; // 输出使能
              sram_data_t <= 1'b1; // 高阻态，准备读取数据
              state       <= STATE_READ;
            end
          end
        end
        STATE_READ: begin
          // 保持控制信号
          sram_ce_n   <= 1'b0;
          sram_oe_n   <= 1'b0;
          sram_we_n   <= 1'b1;
          sram_be_n   <= ~wb_sel_i;
          sram_data_t <= 1'b1; // 高阻态
          // 等待一个周期
          state       <= STATE_READ_2;
        end
        STATE_READ_2: begin
          // 读取数据
          wb_dat_o    <= sram_data_i;
          wb_ack_o    <= 1'b1;
          // 重置控制信号
          sram_ce_n   <= 1'b1;
          sram_oe_n   <= 1'b1;
          sram_we_n   <= 1'b1;
          sram_be_n   <= {SRAM_BYTES{1'b1}};
          sram_data_t <= 1'b1;
          state       <= STATE_DONE;
        end
        STATE_WRITE: begin
          // 将 we_n 置为 0，开始写入
          sram_ce_n   <= 1'b0;
          sram_we_n   <= 1'b0;
          sram_oe_n   <= 1'b1;
          sram_be_n   <= ~wb_sel_i;
          sram_data_o <= wb_dat_i;
          sram_data_t <= 1'b0;
          state       <= STATE_WRITE_2;
        end
        STATE_WRITE_2: begin
          // 将 we_n 置回 1，结束写入
          sram_ce_n   <= 1'b0;
          sram_we_n   <= 1'b1;
          sram_oe_n   <= 1'b1;
          sram_be_n   <= ~wb_sel_i;
          sram_data_o <= wb_dat_i;
          sram_data_t <= 1'b0;
          state       <= STATE_WRITE_3;
        end
        STATE_WRITE_3: begin
          // 完成写操作
          wb_ack_o    <= 1'b1;
          sram_ce_n   <= 1'b1;
          sram_we_n   <= 1'b1;
          sram_oe_n   <= 1'b1;
          sram_be_n   <= {SRAM_BYTES{1'b1}};
          sram_data_t <= 1'b1; // 高阻态
          sram_data_o <= {SRAM_DATA_WIDTH{1'b0}};
          state       <= STATE_DONE;
        end
        STATE_DONE: begin
          wb_ack_o    <= 1'b0;
          if (~wb_stb_i || ~wb_cyc_i) begin
            state <= STATE_IDLE;
          end
        end
        default: state <= STATE_IDLE;
      endcase
    end
  end

endmodule
