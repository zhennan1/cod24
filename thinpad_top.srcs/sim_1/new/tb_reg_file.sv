`timescale 1ns / 1ps

module tb_reg_file;

    // �ź�����
    reg clk;
    reg [4:0] waddr;
    reg [15:0] wdata;
    reg we;
    reg [4:0] raddr_a;
    wire [15:0] rdata_a;
    reg [4:0] raddr_b;
    wire [15:0] rdata_b;

    // ʵ���� reg_file ģ��
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

    // ʱ����������ÿ 5 ns ��תһ�Σ�����Ϊ 10 ns
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // ���Թ���
    initial begin
        integer i;
        reg [15:0] expected_data;  // �޸�Ϊ reg��ȷ����ȷ��λ��ͳ�ʼ��

        // ��ʼ��
        we = 0;
        waddr = 5'd0;
        wdata = 16'd0;
        raddr_a = 5'd0;
        raddr_b = 5'd0;

        // �ȴ�һЩʱ�����ڣ��üĴ����ļ���ʼ�����
        #20;

        // д�벢�������мĴ���
        for (i = 1; i < 32; i = i + 1) begin
            // д��Ĵ��� i������Ϊ 16'hAAAA + i
            we = 1;
            waddr = i[4:0];
            wdata = 16'hAAAA + i[15:0]; // ȷ��λ��һ��
            #10;  // �ȴ�һ��ʱ������д��

            // ֹͣд��
            we = 0;

            // �ȴ������ʱ�����ڣ�ȷ��д������Ч
            #20;

            // ����Ԥ��ֵ
            expected_data = 16'hAAAA + i[15:0]; // ȷ��λ��һ��

            // ���Ĵ��� i��ͨ���˿� A ��ȡ�������������� expected_data
            raddr_a = i[4:0];
            #5;  // ��������߼��ӳ�
            $display("Read raddr_a = %d, rdata_a = %h, expected = %h", raddr_a, rdata_a, expected_data);
            assert(rdata_a == expected_data) else begin
                $fatal("Error: Read data from raddr_a = %d, expected %h, but got %h", raddr_a, expected_data, rdata_a);
            end
        end

        // ȷ�� 0 �żĴ���ʼ��Ϊ 0
        // ����д��Ĵ��� 0������Ϊ 16'hFFFF����Ӧд�룩
        we = 1;
        waddr = 5'd0;
        wdata = 16'hFFFF;
        #10;  // �ȴ�һ��ʱ������

        // ֹͣд��
        we = 0;

        // �ȴ�һ�������ʱ�����ڣ�ȷ��д������Ч
        #20;

        // ���Ĵ��� 0�������������� 0��Ӧ���ֲ��䣩
        raddr_a = 5'd0;
        #5;  // ��������߼��ӳ�
        $display("Read raddr_a = %d, rdata_a = %h", raddr_a, rdata_a);
        assert(rdata_a == 16'h0000) else $fatal("Error: Register 0 should always read 16'h0000");

        // ���Ĵ��� 0��ͨ���˿� B�������������� 0���ٴ���֤��
        raddr_b = 5'd0;
        #5;  // ��������߼��ӳ�
        $display("Read raddr_b = %d, rdata_b = %h", raddr_b, rdata_b);
        assert(rdata_b == 16'h0000) else $fatal("Error: Register 0 should always read 16'h0000 through raddr_b");

        // �ٴζ����мĴ�����ȷ������д���������ȷ����
        for (i = 1; i < 32; i = i + 1) begin
            // �ȴ�һ��ʱ������ȷ��ǰ��Ĳ����ȶ�
            #20;

            // ���Ĵ��� i��ͨ���˿� A �� B �����ȡ�������������� 16'hAAAA + i
            expected_data = 16'hAAAA + i[15:0];  // ȷ��λ��һ��
            
            raddr_a = i[4:0];
            #5;  // ��������߼��ӳ�
            $display("Read raddr_a = %d, rdata_a = %h, expected = %h", raddr_a, rdata_a, expected_data);
            assert(rdata_a == expected_data) else begin
                $fatal("Error: Read data from raddr_a should be %h, but got %h", expected_data, rdata_a);
            end

            raddr_b = i[4:0];
            #5;  // ��������߼��ӳ�
            $display("Read raddr_b = %d, rdata_b = %h, expected = %h", raddr_b, rdata_b, expected_data);
            assert(rdata_b == expected_data) else begin
                $fatal("Error: Read data from raddr_b should be %h, but got %h", expected_data, rdata_b);
            end
        end

        // �������
        $display("All tests passed.");
        $finish;
    end

endmodule
