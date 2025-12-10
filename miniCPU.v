module miniCPU (
    input [17:0] switches,
    input ligar,     // Botão físico de Reset (KEY[0])
    input enviar,    // Botão de Enviar (KEY[1])
    input clk,
    // Outputs para LCD ou Debug
    output [15:0] leds_debug
);

    // 1. Decodificação
    wire [2:0] opcode = switches [17:15];
    wire [3:0] reg_dest = switches [14:11];
    wire [3:0] reg_input1 = switches[10:7];
    wire [3:0] reg_input2 = switches [6:3];
    wire signal = switches[6];
    
    wire [15:0] imediato_module = {10'd0, switches[5:0]};
    wire [15:0] imediato = (signal) ? (-imediato_module) : imediato_module;
    
    wire [15:0] mem_read_data1;
    wire [15:0] mem_read_data2;
    wire [15:0] alu_result;
    
    // Sinais de Controle
    reg write_enable;
    reg [15:0] mem_write;
    reg [1:0] alu_selector;
    reg [15:0] alu_input_2;
    
    // O soft reset sera um novo sinal enviado para a reinicialização do sistema
    reg soft_reset; 
    
    wire memory_reset_signal = ligar & ~soft_reset; // só sendo ativo quando o botao de ligar/desligar for apertado ou quando a negação clear dor ativa -> ativo em 0

    parameter [2:0] LOAD = 3'b000, ADD = 3'b001, ADDI = 3'b010, SUB = 3'b011,
                    SUBI = 3'b100, MUL = 3'b101, CLEAR = 3'b110, DISPLAY = 3'b111;
                        
    memoryCPU Memo (
        .clock(clk),
        .reset(memory_reset_signal),
        .regWrite(write_enable),
        .write_reg_addr(reg_dest),
        .write_data(mem_write),
        .read_reg_addr_1(reg_input1),
        .read_reg_addr_2(reg_input2),
        .read_data_1(mem_read_data1),
        .read_data_2(mem_read_data2)
    );
    
    aluCPU ALU (
        .data1(mem_read_data1),
        .data2(alu_input_2),
        .sel(alu_selector),
        .result(alu_result)
    );
    
    reg [2:0] state;
    parameter [2:0] IDLE = 3'd0, EXECUTE = 3'd1, WRITE = 3'd2, WAIT_RELEASE = 3'd3;
                        
    always @(negedge clk or negedge ligar) begin
        if (!ligar) begin
            state <= IDLE;
            write_enable <= 0;
            soft_reset <= 0; // Garante que começa desligado
        end
        else begin
            case(state)
                IDLE: begin
                    write_enable <= 0;
                    soft_reset <= 0; // Garante que o reset de software está desligado
                    if (!enviar) begin
                        state <= EXECUTE;
                    end
                end
                
                EXECUTE: begin   // Configuração da ULA nesse estado -> contempla todas as funções dela
                    
                    case(opcode)
                        ADD: begin
                            alu_selector <= 2'b00;
                            alu_input_2 <= mem_read_data2;
                        end
                        ADDI: begin
                            alu_selector <= 2'b00;
                            alu_input_2 <= imediato;
                        end
                        SUB: begin
                            alu_selector <= 2'b01;
                            alu_input_2 <= mem_read_data2;
                        end
                        SUBI: begin
                            alu_selector <= 2'b01;
                            alu_input_2 <= imediato;
                        end
                        MUL: begin
                            alu_selector <= 2'b10;
                            alu_input_2 <= mem_read_data2;
                        end
                    endcase
                    state <= WRITE;
                end
                
                WRITE: begin
                    // VERIFICAÇÃO DO CLEAR
                    if (opcode == CLEAR) begin
                        soft_reset <= 1; // Ativa o reset da memoria
                        write_enable <= 0; // Não escreve nada na memoria neste momento
                    end
                    else if (opcode != DISPLAY) begin
                        write_enable <= 1;
                        if (opcode == LOAD)
                            mem_write <= imediato;
                        else
                            mem_write <= alu_result;
                    end
                    
                    state <= WAIT_RELEASE;
                end
                
                WAIT_RELEASE: begin
                    write_enable <= 0;
                    soft_reset <= 0; 
                    
                    if (enviar) begin
                        state <= IDLE;
                    end
                end
            endcase
        end
    end
    
    // Debug
    assign leds_debug = alu_result; 
    
endmodule