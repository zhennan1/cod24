`default_nettype none

module multicycle (
    input wire clk_i,
    input wire rst_i,

    // Wishbone interface signals
    output reg wb_cyc_o,
    output reg wb_stb_o,
    input wire wb_ack_i,
    output reg [31:0] wb_adr_o,
    output reg [31:0] wb_dat_o,
    input wire [31:0] wb_dat_i,
    output reg [3:0] wb_sel_o,
    output reg wb_we_o
);

    // State definitions
    typedef enum logic[3:0] {
        STATE_IF    = 4'd0,
        STATE_ID    = 4'd1,
        STATE_EXE   = 4'd2,
        STATE_MEM   = 4'd3,
        STATE_WB    = 4'd4
    } state_t;

    // ALU operation codes
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
    
    // Registers
    reg [31:0] pc_reg = 32'h8000_0000;
    reg [31:0] inst_reg = 32'b0;
    reg [31:0] pc_next = 32'h8000_0000;
    reg [31:0] operand1_reg = 32'b0;
    reg [31:0] operand2_reg = 32'b0;
    reg [31:0] alu_result = 32'b0;
    reg [31:0] rf_writeback_reg = 32'b0;
    reg [31:0] rf_writeback_data = 32'b0;

    reg rf_we = 1'b0;
    reg [4:0] rf_waddr = 5'b0;
    reg [31:0] rf_wdata = 32'b0;
    reg [4:0] rf_raddr1 = 5'b0;
    reg [4:0] rf_raddr2 = 5'b0;
    wire [31:0] rf_rdata1;
    wire [31:0] rf_rdata2;

    // ALU signals
    reg [31:0] alu_operand1 = 32'b0;
    reg [31:0] alu_operand2 = 32'b0;
    reg [3:0] alu_op = 4'd0;
    wire [31:0] alu_result_wire;

    // State register
    state_t state = STATE_IF;

    // Instantiate reg_file
    reg_file reg_file0 (
        .clk(clk_i),
        .waddr(rf_waddr),
        .wdata(rf_wdata),
        .we(rf_we),
        .raddr_a(rf_raddr1),
        .rdata_a(rf_rdata1),
        .raddr_b(rf_raddr2),
        .rdata_b(rf_rdata2)
    );

    // Instantiate alu
    alu alu0 (
        .a(alu_operand1),
        .b(alu_operand2),
        .op(alu_op),
        .y(alu_result_wire)
    );

    // Instruction fields
    wire [6:0] opcode = inst_reg[6:0];
    wire [4:0] rd = inst_reg[11:7];
    wire [2:0] funct3 = inst_reg[14:12];
    wire [4:0] rs1 = inst_reg[19:15];
    wire [4:0] rs2 = inst_reg[24:20];
    wire [6:0] funct7 = inst_reg[31:25];

    // Immediate generation logic
    function [31:0] imm_I;
        input [31:0] inst;
        imm_I = {{20{inst[31]}}, inst[31:20]};
    endfunction

    function [31:0] imm_S;
        input [31:0] inst;
        imm_S = {{20{inst[31]}}, inst[31:25], inst[11:7]};
    endfunction

    function [31:0] imm_B;
        input [31:0] inst;
        imm_B = {{19{inst[31]}}, inst[31], inst[7], inst[30:25], inst[11:8], 1'b0};
    endfunction

    function [31:0] imm_U;
        input [31:0] inst;
        imm_U = {inst[31:12], 12'b0};
    endfunction

    // Main state machine
    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i) begin
            // Initialize all key registers and state
            state <= STATE_IF;
            pc_reg <= 32'h8000_0000;
        end else begin
            case (state)
                STATE_IF: begin
                    if (wb_ack_i) begin
                        inst_reg <= wb_dat_i;
                        state <= STATE_ID;
                    end
                end
                STATE_ID: begin
                    state <= STATE_EXE;
                end
                STATE_EXE: begin
                    state <= STATE_MEM;
                    alu_result <= alu_result_wire;
                end
                STATE_MEM: begin
                    if (opcode == 7'b0000011) begin
                        if (wb_ack_i) begin
                            rf_writeback_data <= wb_dat_i;
                            state <= STATE_WB;
                        end
                    end else if (opcode == 7'b0100011) begin
                        if (wb_ack_i) begin
                            state <= STATE_WB;
                        end
                    end else begin
                        state <= STATE_WB;
                    end
                end
                STATE_WB: begin
                    pc_reg <= pc_next;
                    state <= STATE_IF;
                end
                default: state <= STATE_IF;
            endcase
        end
    end

    always_comb begin
        // Default values
        wb_cyc_o = 1'b0;
        wb_stb_o = 1'b0;
        wb_we_o = 1'b0;
        wb_adr_o = 32'b0;
        wb_dat_o = 32'b0;
        wb_sel_o = 4'b1111;
        alu_operand1 = 32'b0;
        alu_operand2 = 32'b0;
        alu_op = ADD;
        rf_we = 1'b0;
        rf_waddr = 5'b0;
        rf_wdata = 32'b0;
        pc_next = pc_reg + 4;

        case (state)
            STATE_IF: begin
                // Fetch instruction
                wb_cyc_o = 1'b1;
                wb_stb_o = 1'b1;
                wb_we_o = 1'b0;
                wb_adr_o = pc_reg;
            end
            STATE_ID: begin
                // Decode and read registers
                rf_raddr1 = rs1;
                rf_raddr2 = rs2;
                operand1_reg = rf_rdata1;
                operand2_reg = rf_rdata2;
            end
            STATE_EXE: begin
                alu_operand1 = operand1_reg;
                case (opcode)
                    7'b0010011: begin // I-type instructions
                        alu_operand2 = imm_I(inst_reg);
                        case (funct3)
                            3'b000: alu_op = ADD; // ADDI
                            3'b111: alu_op = AND; // ANDI
                            default: alu_op = ADD;
                        endcase
                    end
                    7'b0110011: begin // R-type instructions
                        alu_operand2 = operand2_reg;
                        case (funct3)
                            3'b000: alu_op = ADD; // ADD
                            default: alu_op = ADD;
                        endcase
                    end
                    7'b0110111: begin // LUI
                        alu_operand1 = 32'b0;
                        alu_operand2 = imm_U(inst_reg);
                        alu_op = ADD;
                    end
                    7'b1100011: begin // BEQ
                        alu_operand2 = operand2_reg;
                        alu_op = SUB;
                    end
                    7'b0000011: begin // Load
                        alu_operand2 = imm_I(inst_reg); // Address calculation
                        alu_op = ADD;
                    end
                    7'b0100011: begin // Store
                        alu_operand2 = imm_S(inst_reg); // Address calculation
                        alu_op = ADD;
                    end
                    default: alu_op = ADD;
                endcase
            end
            STATE_MEM: begin
                if (opcode == 7'b0000011) begin // Load
                    wb_cyc_o = 1'b1;
                    wb_stb_o = 1'b1;
                    wb_we_o = 1'b0;
                    wb_adr_o = alu_result;
                end else if (opcode == 7'b0100011) begin // Store
                    wb_cyc_o = 1'b1;
                    wb_stb_o = 1'b1;
                    wb_we_o = 1'b1;
                    wb_adr_o = alu_result;
                    wb_dat_o = operand2_reg; // Store value from rs2
                end
            end
            STATE_WB: begin
                case (opcode)
                    7'b0010011, 7'b0110011, 7'b0110111: begin
                        rf_we = 1'b1;
                        rf_waddr = rd;
                        rf_wdata = alu_result;
                    end
                    7'b0000011: begin // Load
                        rf_we = 1'b1;
                        rf_waddr = rd;
                        rf_wdata = rf_writeback_data;
                    end
                    7'b1100011: begin // BEQ
                        if (alu_result == 32'b0) begin
                            pc_next = pc_reg + imm_B(inst_reg);
                        end
                    end
                    default: ;
                endcase
            end
        endcase
    end

endmodule