module lcd_controller (
    input clk,
    input reset_n,          // Reset ativo em baixo (ligar)
    input start,            // Sinal para iniciar a escrita (vindo da CPU)
    input [2:0] opcode,     // Opcode da instrução
    input [3:0] reg_idx,    // Índice do registrador (ex: 0010)
    input signed [15:0] value, // Valor a ser mostrado (Resultado ou Imediato)
    
    // Pinos físicos da FPGA para o LCD
    output reg [7:0] lcd_data,
    output reg lcd_rs,      // 0: Comando, 1: Dados
    output wire lcd_rw,      // 0: Escrita, 1: Leitura (Geralmente 0)
    output reg lcd_en,      // Enable pulse
    output lcd_on,          // Liga o Display
    output lcd_blon         // Liga o Backlight
);

    // Configurações fixas
    assign lcd_rw = 1'b0;   // Sempre escrita
    assign lcd_on = 1'b1;   // Display sempre Ativo
    assign lcd_blon = 1'b1; // Backlight sempre Aceso

    // Parâmetros de Estado
    localparam STATE_IDLE = 0, STATE_INIT = 1, STATE_READY = 2, 
               STATE_WRITE_LINE1 = 3, STATE_LINE2_ADDR = 4, STATE_WRITE_LINE2 = 5, STATE_DONE = 6;
    
    reg [3:0] state = STATE_IDLE;
    reg [5:0] char_index; // Índice do caractere atual sendo escrito
    
    // Delay timer (Assumindo clock de 50MHz)
    // 1ms = 50,000 ciclos. Usaremos 16 bits.
    reg [19:0] counter;
    reg wait_flag;
    
    // Armazenamento interno dos dados para exibição estável
    reg [2:0] op_store;
    reg [3:0] reg_store;
    reg signed [15:0] val_store;
    
    // Dados processados para BCD (Binary Coded Decimal)
    reg [15:0] unsigned_val;
    reg is_negative;
    reg [3:0] digit_10000, digit_1000, digit_100, digit_10, digit_1;

    // Sequência de Inicialização do LCD (Datasheet)
    // 0x38: Function Set (8-bit, 2 lines)
    // 0x0C: Display ON, Cursor OFF
    // 0x01: Clear Display
    // 0x06: Entry Mode
    reg [7:0] init_cmds [0:4];
    initial begin
        init_cmds[0] = 8'h38;
        init_cmds[1] = 8'h38; // Repetir para garantir
        init_cmds[2] = 8'h0C;
        init_cmds[3] = 8'h01;
        init_cmds[4] = 8'h06;
    end

    // Mapeamento de Opcodes para Texto
    // LOAD(0), ADD(1), ADDI(2), SUB(3), SUBI(4), MUL(5), CLEAR(6), DISP(7)
    function [39:0] get_op_string(input [2:0] op);
        case(op)
            3'b000: get_op_string = "LOAD ";
            3'b001: get_op_string = "ADD  ";
            3'b010: get_op_string = "ADDI ";
            3'b011: get_op_string = "SUB  ";
            3'b100: get_op_string = "SUBI ";
            3'b101: get_op_string = "MUL  ";
            3'b110: get_op_string = "CLEAR";
            3'b111: get_op_string = "DPL  "; // DPL para Display
            default: get_op_string = "ERR  ";
        endcase
    endfunction

    // Lógica de Delay e Máquina de Estados
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            state <= STATE_INIT;
            counter <= 0;
            char_index <= 0;
            lcd_en <= 0;
            wait_flag <= 0;
        end else begin
            
            // Gerenciador de Espera (Delay)
            if (wait_flag) begin
                if (counter < 20'd100000) begin // ~2ms para segurança (Datasheet pede ~1.52ms para Clear)
                    counter <= counter + 1;
                    if (counter == 20'd2000) lcd_en <= 0; // Desce o Enable após um tempo curto
                end else begin
                    wait_flag <= 0;
                    counter <= 0;
                end
            end else begin
                // FSM Principal
                case (state)
                    // --- Inicialização do LCD ---
                    STATE_INIT: begin
                        lcd_rs <= 0; // Modo Comando
                        lcd_data <= init_cmds[char_index];
                        lcd_en <= 1; // Pulso de Enable
                        wait_flag <= 1; // Inicia espera
                        
                        if (char_index < 4) 
                            char_index <= char_index + 1;
                        else begin
                            state <= STATE_READY;
                            char_index <= 0;
                        end
                    end

                    // --- Aguardando Instrução da CPU ---
                    STATE_READY: begin
                        if (start) begin
                            // Captura os dados para evitar mudanças durante a escrita
                            op_store <= opcode;
                            reg_store <= reg_idx;
                            val_store <= value;
                            
                            // Conversão Binário -> Módulo e Sinal
                            if (value < 0) begin
                                is_negative <= 1;
                                unsigned_val <= -value;
                            end else begin
                                is_negative <= 0;
                                unsigned_val <= value;
                            end
                            
                            // Limpa o display antes de escrever novo dado
                            lcd_rs <= 0;
                            lcd_data <= 8'h01; // Clear
                            lcd_en <= 1;
                            wait_flag <= 1;
                            
                            state <= STATE_WRITE_LINE1;
                            char_index <= 0;
                        end
                    end

                    // --- Escrevendo Linha 1: "OP   [RRRR]" ---
                    STATE_WRITE_LINE1: begin
                        // Lógica de decomposição Decimal antes de escrever a linha 2 (aproveitando o tempo)
                        // Simples extração de dígitos (não eficiente em área, mas funciona para FPGA didática)
                        digit_10000 <= (unsigned_val / 10000) % 10;
                        digit_1000  <= (unsigned_val / 1000) % 10;
                        digit_100   <= (unsigned_val / 100) % 10;
                        digit_10    <= (unsigned_val / 10) % 10;
                        digit_1     <= (unsigned_val) % 10;

                        lcd_rs <= 1; // Modo Dados
                        lcd_en <= 1;
                        wait_flag <= 1;
                        
                        // Seleciona o caractere baseado no índice
                        // Formato: "OPCOD [BBBB]" (Total 11 chars)
                        if (char_index < 5) begin
                            // Extrai caractere da string do Opcode (Byte a byte)
                            // "LOAD " -> char 0 é 'L', char 1 é 'O'...
                            lcd_data <= get_op_string(op_store) >> (8 * (4 - char_index)); 
                        end else if (char_index == 5) begin
                            lcd_data <= " "; // Espaço
                        end else if (char_index == 6) begin
                            lcd_data <= "[";
                        end else if (char_index >= 7 && char_index <= 10) begin
                            // Converte bit do registrador para ASCII '0' ou '1'
                            // reg_store[3] é o primeiro a ser mostrado
                            lcd_data <= reg_store[10 - char_index] ? "1" : "0";
                        end else if (char_index == 11) begin
                            lcd_data <= "]";
                        end 
                        
                        if (char_index < 11)
                            char_index <= char_index + 1;
                        else begin
                            char_index <= 0;
                            state <= STATE_LINE2_ADDR;
                        end
                    end

                    // --- Mover cursor para Linha 2 ---
                    STATE_LINE2_ADDR: begin
                        lcd_rs <= 0; // Comando
                        lcd_data <= 8'hC0; // Endereço 0x40 (Início da linha 2)
                        lcd_en <= 1;
                        wait_flag <= 1;
                        state <= STATE_WRITE_LINE2;
                    end

                    // --- Escrevendo Linha 2: "+12345" ---
                    STATE_WRITE_LINE2: begin
                        lcd_rs <= 1; // Dados
                        lcd_en <= 1;
                        wait_flag <= 1;
                        
                        if (op_store == 3'b110) begin 
                            // Se for CLEAR, não escreve nada na linha 2 ou escreve "Done"
                            state <= STATE_READY; 
                        end else begin
                            case(char_index)
                                0: lcd_data <= is_negative ? "-" : "+";
                                1: lcd_data <= 8'h30 + digit_10000; // ASCII '0' + valor
                                2: lcd_data <= 8'h30 + digit_1000;
                                3: lcd_data <= 8'h30 + digit_100;
                                4: lcd_data <= 8'h30 + digit_10;
                                5: lcd_data <= 8'h30 + digit_1;
                            endcase
                            
                            if (char_index < 5)
                                char_index <= char_index + 1;
                            else begin
                                state <= STATE_READY; // Volta para esperar nova instrução
                            end
                        end
                    end
                endcase
            end
        end
    end
endmodule