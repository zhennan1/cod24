`default_nettype none

module trigger (
    input wire clk,
    input wire reset,
    input wire btn,        // 输入按键信号
    output reg trigger_pulse  // 上升沿触发脉冲
);

  // 用于存储按键的前一个状态
  reg btn_last;

  always_ff @(posedge clk or posedge reset) begin
    if (reset) begin
      btn_last <= 1'b0;
      trigger_pulse <= 1'b0;
    end else begin
      // 检测上升沿，当 btn 从0变为1时，触发脉冲
      if (btn && ~btn_last) begin
        trigger_pulse <= 1'b1;
      end else begin
        trigger_pulse <= 1'b0;
      end
      // 更新按键状态
      btn_last <= btn;
    end
  end

endmodule
