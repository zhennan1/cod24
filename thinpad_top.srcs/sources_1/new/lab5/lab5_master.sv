module lab5_master #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
) (
    input wire clk_i,
    input wire rst_i,
    input wire [31:0] switch_i,  // 从DIP开关读取起始地址

    // wishbone master
    output reg wb_cyc_o,
    output reg wb_stb_o,
    input wire wb_ack_i,
    output reg [ADDR_WIDTH-1:0] wb_adr_o,
    output reg [DATA_WIDTH-1:0] wb_dat_o,
    input wire [DATA_WIDTH-1:0] wb_dat_i,
    output reg [DATA_WIDTH/8-1:0] wb_sel_o,
    output reg wb_we_o
);

  // 内部信号
  reg [31:0] signal;
  reg [31:0] data;
  reg [31:0] addr;
  reg [3:0] data_count;

  // 状态定义
  typedef enum logic [3:0] {
    IDLE = 0,
    READ_WAIT_ACTION = 1,
    READ_WAIT_CHECK = 2,
    READ_DATA_ACTION = 3,
    READ_DATA_DONE = 4,
    WRITE_SRAM_ACTION = 5,
    WRITE_SRAM_DONE = 6,
    WRITE_WAIT_ACTION = 7,
    WRITE_WAIT_CHECK = 8,
    WRITE_DATA_ACTION = 9,
    WRITE_DATA_DONE = 10
  } state_t;

  state_t state, next_state;

  always_ff @(posedge clk_i or posedge rst_i) begin
    // 同步复位
    if (rst_i) begin
      state <= IDLE;
      addr <= switch_i;
      data <= 0;
      signal <= 0;
      data_count <= 0;
      wb_cyc_o <= 0;
      wb_we_o <= 0;
    end else begin
      // 状态机转移
      state <= next_state;
      case (state)
        IDLE: begin
          wb_adr_o <= 32'h10000005;
          wb_cyc_o <= 1;
          wb_we_o <= 0;
        end
        READ_WAIT_ACTION: begin
          if (wb_ack_i) begin
            signal <= wb_dat_i;
            wb_cyc_o <= 0;
          end else begin
            wb_cyc_o <= 1;
          end
          wb_we_o <= 0;
        end
        READ_WAIT_CHECK: begin
          if (signal[0]) begin
            wb_adr_o <= 32'h10000000;
            wb_cyc_o <= 1;
          end else begin
            wb_cyc_o <= 0;
          end
          wb_we_o <= 0;
        end
        READ_DATA_ACTION: begin
          if (wb_ack_i) begin
            data <= wb_dat_i;
            wb_cyc_o <= 0;
          end else begin
            wb_cyc_o <= 1;
          end
          wb_we_o <= 0;
        end
        READ_DATA_DONE: begin
          wb_adr_o <= addr;
          wb_dat_o <= data;
          wb_cyc_o <= 1;
          wb_we_o <= 1;
        end
        WRITE_SRAM_ACTION: begin
          wb_cyc_o <= 1;
          wb_we_o <= 1;
        end
        WRITE_SRAM_DONE: begin
          wb_adr_o <= 32'h10000005;
          wb_cyc_o <= 1;
          wb_we_o <= 0;
        end
        WRITE_WAIT_ACTION: begin
          if (wb_ack_i) begin
            signal <= wb_dat_i;
            wb_cyc_o <= 0;
          end else begin
            wb_cyc_o <= 1;
          end
          wb_we_o <= 0;
        end
        WRITE_WAIT_CHECK: begin
          if (signal[5]) begin
            wb_adr_o <= 32'h10000000;
            wb_dat_o <= data;
            wb_cyc_o <= 1;
            wb_we_o <= 1;
          end else begin
            wb_cyc_o <= 0;
            wb_we_o <= 0;
          end
        end
        WRITE_DATA_ACTION: begin
          wb_cyc_o <= 1;
          wb_we_o <= 1;
        end
        WRITE_DATA_DONE: begin
          addr <= addr + 4;
          data_count <= data_count + 1;
          wb_cyc_o <= 0;
          wb_we_o <= 0;
        end
        default: begin
          wb_adr_o <= 32'h10000005;
          wb_cyc_o <= 0;
          wb_we_o <= 0;
        end
      endcase
    end
  end

  always_comb begin
    case (state)
      IDLE: begin
        next_state = READ_WAIT_ACTION;
      end
      READ_WAIT_ACTION: begin
        if (wb_ack_i) begin
          next_state = READ_WAIT_CHECK;
        end else begin
          next_state = READ_WAIT_ACTION;
        end
      end
      READ_WAIT_CHECK: begin
        if (signal[0]) begin
          next_state = READ_DATA_ACTION;
        end else begin
          next_state = READ_WAIT_ACTION;
        end
      end
      READ_DATA_ACTION: begin
        if (wb_ack_i) begin
          next_state = READ_DATA_DONE;
        end else begin
          next_state = READ_DATA_ACTION;
        end
      end
      READ_DATA_DONE: begin
        next_state = WRITE_SRAM_ACTION;
      end
      WRITE_SRAM_ACTION: begin
        if (wb_ack_i) begin
          next_state = WRITE_SRAM_DONE;
        end else begin
          next_state = WRITE_SRAM_ACTION;
        end
      end
      WRITE_SRAM_DONE: begin
        next_state = WRITE_WAIT_ACTION;
      end
      WRITE_WAIT_ACTION: begin
        if (wb_ack_i) begin
          next_state = WRITE_WAIT_CHECK;
        end else begin
          next_state = WRITE_WAIT_ACTION;
        end
      end
      WRITE_WAIT_CHECK: begin
        if (signal[5]) begin
          next_state = WRITE_DATA_ACTION;
        end else begin
          next_state = IDLE;
        end
      end
      WRITE_DATA_ACTION: begin
        if (wb_ack_i) begin
          next_state = WRITE_DATA_DONE;
        end else begin
          next_state = WRITE_DATA_ACTION;
        end
      end
      WRITE_DATA_DONE: begin
        if (data_count == 4'ha) begin
          next_state = WRITE_DATA_DONE;
        end else begin
          next_state = IDLE;
        end
      end
      default: begin
        next_state = IDLE;
      end
    endcase

    wb_stb_o = wb_cyc_o;
    wb_sel_o = 4'b0001;
  end

endmodule
