`timescale 1ns / 1ps

module tb_reg_file;

    // 信号声明
    reg clk;
    reg [4:0] waddr;
    reg [15:0] wdata;
    reg we;
    reg [4:0] raddr_a;
    wire [15:0] rdata_a;
    reg [4:0] raddr_b;
    wire [15:0] rdata_b;

    // 实例化 reg_file 模块
    reg_file uut (
        .clk(clk),
        .waddr(waddr),
        .wdata(wdata),
        .we(we),
        .raddr_a(raddr_a),
        .rdata_a(rdata_a),
        .raddr_b(raddr_b),
        .rdata_b(rdata_b)
    );

    // 时钟生成器，每 5 ns 翻转一次，周期为 10 ns
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // 测试过程
    initial begin
        integer i;
        reg [15:0] expected_data;  // 修改为 reg，确保正确的位宽和初始化

        // 初始化
        we = 0;
        waddr = 5'd0;
        wdata = 16'd0;
        raddr_a = 5'd0;
        raddr_b = 5'd0;

        // 等待一些时钟周期，让寄存器文件初始化完成
        #20;

        // 写入并测试所有寄存器
        for (i = 1; i < 32; i = i + 1) begin
            // 写入寄存器 i，数据为 16'hAAAA + i
            we = 1;
            waddr = i[4:0];
            wdata = 16'hAAAA + i[15:0]; // 确保位宽一致
            #10;  // 等待一个时钟周期写入

            // 停止写入
            we = 0;

            // 等待额外的时钟周期，确保写入已生效
            #20;

            // 计算预期值
            expected_data = 16'hAAAA + i[15:0]; // 确保位宽一致

            // 读寄存器 i，通过端口 A 读取，期望读出数据 expected_data
            raddr_a = i[4:0];
            #5;  // 增加组合逻辑延迟
            $display("Read raddr_a = %d, rdata_a = %h, expected = %h", raddr_a, rdata_a, expected_data);
            assert(rdata_a == expected_data) else begin
                $fatal("Error: Read data from raddr_a = %d, expected %h, but got %h", raddr_a, expected_data, rdata_a);
            end
        end

        // 确保 0 号寄存器始终为 0
        // 尝试写入寄存器 0，数据为 16'hFFFF（不应写入）
        we = 1;
        waddr = 5'd0;
        wdata = 16'hFFFF;
        #10;  // 等待一个时钟周期

        // 停止写入
        we = 0;

        // 等待一个额外的时钟周期，确保写入已生效
        #20;

        // 读寄存器 0，期望读出数据 0（应保持不变）
        raddr_a = 5'd0;
        #5;  // 增加组合逻辑延迟
        $display("Read raddr_a = %d, rdata_a = %h", raddr_a, rdata_a);
        assert(rdata_a == 16'h0000) else $fatal("Error: Register 0 should always read 16'h0000");

        // 读寄存器 0，通过端口 B，期望读出数据 0（再次验证）
        raddr_b = 5'd0;
        #5;  // 增加组合逻辑延迟
        $display("Read raddr_b = %d, rdata_b = %h", raddr_b, rdata_b);
        assert(rdata_b == 16'h0000) else $fatal("Error: Register 0 should always read 16'h0000 through raddr_b");

        // 再次读所有寄存器，确保所有写入的数据正确保留
        for (i = 1; i < 32; i = i + 1) begin
            // 等待一个时钟周期确保前面的操作稳定
            #20;

            // 读寄存器 i，通过端口 A 和 B 交替读取，期望读出数据 16'hAAAA + i
            expected_data = 16'hAAAA + i[15:0];  // 确保位宽一致
            
            raddr_a = i[4:0];
            #5;  // 增加组合逻辑延迟
            $display("Read raddr_a = %d, rdata_a = %h, expected = %h", raddr_a, rdata_a, expected_data);
            assert(rdata_a == expected_data) else begin
                $fatal("Error: Read data from raddr_a should be %h, but got %h", expected_data, rdata_a);
            end

            raddr_b = i[4:0];
            #5;  // 增加组合逻辑延迟
            $display("Read raddr_b = %d, rdata_b = %h, expected = %h", raddr_b, rdata_b, expected_data);
            assert(rdata_b == expected_data) else begin
                $fatal("Error: Read data from raddr_b should be %h, but got %h", expected_data, rdata_b);
            end
        end

        // 测试完成
        $display("All tests passed.");
        $finish;
    end

endmodule
