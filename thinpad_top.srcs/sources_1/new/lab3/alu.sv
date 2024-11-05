module alu (
    input wire [31:0] a,       // 操作数 A
    input wire [31:0] b,       // 操作数 B
    input wire [3:0] op,       // 操作码，控制具体的运算类型
    output reg [31:0] y        // 运算结果
);

  // 定义操作码类型
  typedef enum logic [3:0] {
    ADD = 4'b0001,
    SUB = 4'b0010,
    AND = 4'b0011,
    OR  = 4'b0100,
    XOR = 4'b0101,
    NOT = 4'b0110,
    SLL = 4'b0111,
    SRL = 4'b1000,
    SRA = 4'b1001,
    ROL = 4'b1010
  } opcode_t;

  // ALU 运算逻辑
  always_comb begin
    case (op)
      ADD: y = a + b;                         // 加法
      SUB: y = a - b;                         // 减法
      AND: y = a & b;                         // 按位与
      OR:  y = a | b;                         // 按位或
      XOR: y = a ^ b;                         // 按位异或
      NOT: y = ~a;                            // 按位取非（仅对 A 进行）
      SLL: y = a << b[3:0];                   // 逻辑左移 B 位，取 B 的低 4 位以控制移位量
      SRL: y = a >> b[3:0];                   // 逻辑右移 B 位，取 B 的低 4 位以控制移位量
      SRA: y = $signed(a) >>> b[3:0];         // 算术右移 B 位，取 B 的低 4 位以控制移位量
      ROL: y = (a << b[3:0]) | (a >> (32 - b[3:0])); // 循环左移 B 位
      default: y = 32'b0;                     // 默认输出为 0
    endcase
  end

endmodule
