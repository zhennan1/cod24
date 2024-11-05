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
        STATE_IF    = 4'd0, // Instruction Fetch
        STATE_ID    = 4'd1, // Instruction Decode
        STATE_EXE   = 4'd2, // Execute
        STATE_MEM   = 4'd3, // Memory Access
        STATE_WB    = 4'd4  // Write Back
    } state_t;

    // ALU operation codes
    typedef enum logic [3:0] {
        ALU_ADD = 4'b0001,
        ALU_SUB = 4'b0010,
        ALU_AND = 4'b0011,
        ALU_OR  = 4'b0100,
        ALU_XOR = 4'b0101,
        ALU_NOT = 4'b0110,
        ALU_SLL = 4'b0111,
        ALU_SRL = 4'b1000,
        ALU_SRA = 4'b1001,
        ALU_ROL = 4'b1010
    } alu_opcode_t;

    // Opcode definitions
    parameter OPCODE_LUI      = 7'b0110111;
    parameter OPCODE_AUIPC    = 7'b0010111;
    parameter OPCODE_JAL      = 7'b1101111;
    parameter OPCODE_JALR     = 7'b1100111;
    parameter OPCODE_BRANCH   = 7'b1100011;
    parameter OPCODE_LOAD     = 7'b0000011;
    parameter OPCODE_STORE    = 7'b0100011;
    parameter OPCODE_IMM      = 7'b0010011;
    parameter OPCODE_REG      = 7'b0110011;

    // Funct3 definitions for BRANCH
    parameter FUNCT3_BEQ      = 3'b000;
    parameter FUNCT3_BNE      = 3'b001;

    // Funct3 definitions for immediate operations
    parameter FUNCT3_ADDI     = 3'b000;
    parameter FUNCT3_ANDI     = 3'b111;

    // Funct3 definitions for load/store
    parameter FUNCT3_LB       = 3'b000;
    parameter FUNCT3_SB       = 3'b000;
    parameter FUNCT3_SW       = 3'b010;

    // Funct3 definitions for R-type operations
    parameter FUNCT3_ADD      = 3'b000;

    // Registers
    reg [31:0] pc_reg = 32'h8000_0000;
    reg [31:0] inst_reg = 32'b0;
    reg [31:0] pc_next = 32'h8000_0000;

    reg [31:0] operand1_reg = 32'b0;
    reg [31:0] operand2_reg = 32'b0;
    reg [31:0] result = 32'b0;
    reg [31:0] rf_writeback_data = 32'b0;

    // Register file signals
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
    reg [3:0] alu_op = ALU_ADD;
    wire [31:0] alu_result;

    // State register
    state_t state = STATE_IF;

    // Instantiate register file (./lab3/reg_file.sv)
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

    // Instantiate ALU (./lab3/alu.sv)
    alu alu0 (
        .a(alu_operand1),
        .b(alu_operand2),
        .op(alu_op),
        .y(alu_result)
    );

    // Instruction fields
    wire [6:0] opcode = inst_reg[6:0];
    wire [4:0] rd = inst_reg[11:7];
    wire [2:0] funct3 = inst_reg[14:12];
    wire [4:0] rs1 = inst_reg[19:15];
    wire [4:0] rs2 = inst_reg[24:20];
    wire [6:0] funct7 = inst_reg[31:25];

    // Immediate generation logic
    // I-type immediate
    function [31:0] imm_I;
        input [31:0] inst;
        imm_I = {{20{inst[31]}}, inst[31:20]};
    endfunction

    // S-type immediate
    function [31:0] imm_S;
        input [31:0] inst;
        imm_S = {{20{inst[31]}}, inst[31:25], inst[11:7]};
    endfunction

    // B-type immediate
    function [31:0] imm_B;
        input [31:0] inst;
        imm_B = {{19{inst[31]}}, inst[31], inst[7], inst[30:25], inst[11:8], 1'b0};
    endfunction

    // U-type immediate
    function [31:0] imm_U;
        input [31:0] inst;
        imm_U = {inst[31:12], 12'b0};
    endfunction

    // Main state machine
    always_ff @(posedge clk_i or posedge rst_i) begin
        if (rst_i) begin
            // Reset: Initialize state and PC
            state <= STATE_IF;
            pc_reg <= 32'h8000_0000;
        end else begin
            case (state)
                STATE_IF: begin
                    // Instruction Fetch Stage
                    if (wb_ack_i) begin
                        inst_reg <= wb_dat_i;
                        state <= STATE_ID;
                    end
                end

                STATE_ID: begin
                    // Instruction Decode Stage
                    state <= STATE_EXE;
                end

                STATE_EXE: begin
                    // Execute Stage: Perform ALU operations or calculate addresses
                    result <= alu_result;

                    if (opcode == OPCODE_LOAD || opcode == OPCODE_STORE) begin
                        state <= STATE_MEM;
                    end else begin
                        state <= STATE_WB;
                    end
                end

                STATE_MEM: begin
                    // Memory Access Stage
                    if (opcode == OPCODE_LOAD) begin
                        if (wb_ack_i) begin
                            rf_writeback_data <= wb_dat_i;
                            state <= STATE_WB;
                        end
                    end else if (opcode == OPCODE_STORE) begin
                        if (wb_ack_i) begin
                            state <= STATE_WB;
                        end
                    end else begin
                        state <= STATE_WB;
                    end
                end

                STATE_WB: begin
                    // Write Back Stage
                    pc_reg <= pc_next;
                    state <= STATE_IF;
                end

                default: begin
                    state <= STATE_IF;
                end
            endcase
        end
    end

    // Combinational logic for control signals and ALU operations
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
        alu_op = ALU_ADD;

        rf_we = 1'b0;
        rf_waddr = 5'b0;
        rf_wdata = 32'b0;

        pc_next = pc_reg + 4;

        case (state)
            STATE_IF: begin
                // Instruction Fetch: Set Wishbone signals to fetch instruction
                wb_cyc_o = 1'b1;
                wb_stb_o = 1'b1;
                wb_we_o = 1'b0;
                wb_adr_o = pc_reg;
            end

            STATE_ID: begin
                // Instruction Decode: Read registers
                rf_raddr1 = rs1;
                rf_raddr2 = rs2;
                operand1_reg = rf_rdata1;
                operand2_reg = rf_rdata2;
            end

            STATE_EXE: begin
                // Execute: Set ALU operands and operation based on instruction
                alu_operand1 = operand1_reg;

                case (opcode)
                    OPCODE_IMM: begin // I-type instructions
                        alu_operand2 = imm_I(inst_reg);
                        case (funct3)
                            FUNCT3_ADDI: alu_op = ALU_ADD; // ADDI
                            FUNCT3_ANDI: alu_op = ALU_AND; // ANDI
                            default:     alu_op = ALU_ADD;
                        endcase
                    end

                    OPCODE_REG: begin // R-type instructions
                        alu_operand2 = operand2_reg;
                        case (funct3)
                            FUNCT3_ADD: alu_op = ALU_ADD; // ADD
                            default:    alu_op = ALU_ADD;
                        endcase
                    end

                    OPCODE_LUI: begin // LUI
                        alu_operand1 = 32'b0;
                        alu_operand2 = imm_U(inst_reg);
                        alu_op = ALU_ADD;
                    end

                    OPCODE_BRANCH: begin // Branch instructions
                        alu_operand2 = operand2_reg;
                        alu_op = ALU_SUB;
                    end

                    OPCODE_LOAD: begin // Load instructions
                        alu_operand2 = imm_I(inst_reg); // Address calculation
                        alu_op = ALU_ADD;
                    end

                    OPCODE_STORE: begin // Store instructions
                        alu_operand2 = imm_S(inst_reg); // Address calculation
                        alu_op = ALU_ADD;
                    end

                    default: alu_op = ALU_ADD;
                endcase
            end

            STATE_MEM: begin
                // Memory Access: Perform load or store operations
                if (opcode == OPCODE_LOAD) begin // Load
                    wb_cyc_o = 1'b1;
                    wb_stb_o = 1'b1;
                    wb_we_o = 1'b0;
                    wb_adr_o = result;
                end else if (opcode == OPCODE_STORE) begin // Store
                    wb_cyc_o = 1'b1;
                    wb_stb_o = 1'b1;
                    wb_we_o = 1'b1;
                    wb_adr_o = result;
                    wb_dat_o = operand2_reg; // Store value from rs2
                end
            end

            STATE_WB: begin
                // Write Back: Write results to register file and update PC
                case (opcode)
                    OPCODE_IMM, OPCODE_REG, OPCODE_LUI: begin
                        // Write ALU result to rd
                        rf_we = 1'b1;
                        rf_waddr = rd;
                        rf_wdata = result;
                    end

                    OPCODE_LOAD: begin // Load
                        rf_we = 1'b1;
                        rf_waddr = rd;
                        rf_wdata = rf_writeback_data;
                    end

                    OPCODE_BRANCH: begin // Branch instructions
                        if (funct3 == FUNCT3_BEQ) begin // BEQ
                            if (result == 32'b0) begin
                                // Branch taken: update PC
                                pc_next = pc_reg + imm_B(inst_reg);
                            end
                        end
                    end

                    default: ;
                endcase
            end
        endcase
    end

endmodule