`default_nettype none

module reg_file (
    input wire clk,                      // 时钟信号
    input wire [4:0] waddr,              // 写操作的寄存器编号
    input wire [15:0] wdata,             // 写操作的数据
    input wire we,                       // 写操作的使能信号
    input wire [4:0] raddr_a,            // 读端口 A 的寄存器编号
    output reg [15:0] rdata_a,           // 读端口 A 的寄存器数据
    input wire [4:0] raddr_b,            // 读端口 B 的寄存器编号
    output reg [15:0] rdata_b            // 读端口 B 的寄存器数据
);

    // 寄存器数组，32 个 16 位寄存器
    reg [15:0] regs [31:0];

    // 初始化寄存器，0号寄存器恒为0
    initial begin
        integer i;
        for (i = 0; i < 32; i = i + 1) begin
            regs[i] = 16'b0;
        end
    end

    // 写操作：在上升沿时钟周期内执行写操作，0号寄存器忽略写入
    always_ff @(posedge clk) begin
        if (we && waddr != 5'd0) begin
            regs[waddr] <= wdata;
        end
    end

    // 读操作：组合逻辑读取寄存器数据
    always_comb begin
        // 读端口 A 的数据读取
        if (raddr_a == 5'd0) begin
            rdata_a = 16'b0;  // 0号寄存器恒为0
        end else begin
            rdata_a = regs[raddr_a];
        end

        // 读端口 B 的数据读取
        if (raddr_b == 5'd0) begin
            rdata_b = 16'b0;  // 0号寄存器恒为0
        end else begin
            rdata_b = regs[raddr_b];
        end
    end

endmodule
