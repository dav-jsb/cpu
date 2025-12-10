module lcd_controller (
    input clk,
    input reset_n,          // Botão Ligar/Desligar (Toggle)
    input start,            
    input [2:0] opcode,     
    input [3:0] reg_idx,    
    input signed [15:0] value, 
    
    output reg [7:0] lcd_data,
    output reg lcd_rs,      
    output wire lcd_rw,      
    output reg lcd_en,      
    output wire lcd_on,     
    output wire lcd_blon    
);

    assign lcd_rw = 1'b0; 
    // O LCD só liga se o estado não for IDLE
    assign lcd_on   = (state != STATE_IDLE);
    assign lcd_blon = (state != STATE_IDLE);

    localparam STATE_IDLE = 0, STATE_INIT = 1, STATE_READY = 2, 
               STATE_WRITE_LINE1 = 3, STATE_LINE2_ADDR = 4, STATE_WRITE_LINE2 = 5;
               
    reg [3:0] state = STATE_IDLE; 
    
    reg [5:0] char_index; 
    reg [19:0] counter;
    reg wait_flag;
    
    reg [2:0] op_store;
    reg [3:0] reg_store;
    reg signed [15:0] val_store;
    
    reg first_boot; 
    reg [15:0] unsigned_val;
    reg is_negative;
    reg [3:0] digit_10000, digit_1000, digit_100, digit_10, digit_1;

    // --- LÓGICA DO BOTÃO LIGAR/DESLIGAR ---
    reg prev_reset_n;       // Armazena estado anterior do botão
    reg system_active;      // 0 = Desligado, 1 = Ligado
    
    initial begin
        system_active = 0;  // Começa desligado ao energizar a FPGA
        prev_reset_n = 1;
    end
    // --------------------------------------

    reg [7:0] init_cmds [0:4];
    initial begin
        init_cmds[0] = 8'h38;
        init_cmds[1] = 8'h38;
        init_cmds[2] = 8'h0C;
        init_cmds[3] = 8'h01;
        init_cmds[4] = 8'h06;
    end

    function [39:0] get_op_string(input [2:0] op);
        case(op)
            3'b000: get_op_string = "LOAD ";
            3'b001: get_op_string = "ADD  ";
            3'b010: get_op_string = "ADDI ";
            3'b011: get_op_string = "SUB  ";
            3'b100: get_op_string = "SUBI ";
            3'b101: get_op_string = "MUL  ";
            3'b110: get_op_string = "CLEAR";
            3'b111: get_op_string = "DPL  ";
            default: get_op_string = "ERR  ";
        endcase
    endfunction

    // Note: Removi "negedge reset_n" da lista de sensibilidade.
    // Agora o reset é tratado sincronamente como um botão de comando.
    always @(posedge clk) begin
        
        // --- 1. Detector de Borda (Botão pressionado) ---
        prev_reset_n <= reset_n;
        // Se estava em 1 e foi para 0 (apertou), inverte o estado do sistema
        if (prev_reset_n == 1'b1 && reset_n == 1'b0) begin
            system_active <= ~system_active; 
        end

        // --- 2. Controle Geral do Sistema ---
        if (system_active == 1'b0) begin
            // SE ESTIVER DESLIGADO:
            state <= STATE_IDLE;
            
            // Reseta variáveis para que, ao ligar de novo, comece limpo
            lcd_en <= 0;
            wait_flag <= 0;
            counter <= 0;
            char_index <= 0;
            first_boot <= 1; // Prepara para mostrar a tela de boot na próxima ligada
        end 
        else begin
            // SE ESTIVER LIGADO (system_active == 1):
            
            // Se acabou de ligar (estava em IDLE), inicia o boot
            if (state == STATE_IDLE) begin
                state <= STATE_INIT;
                char_index <= 0;
                wait_flag <= 0;
                first_boot <= 1;
            end
            
            // --- Lógica Normal da Máquina de Estados ---
            else if (wait_flag) begin
                if (counter < 20'd100000) begin 
                    counter <= counter + 1;
                    if (counter == 20'd2000) lcd_en <= 0; 
                end else begin
                    wait_flag <= 0;
                    counter <= 0;
                end
            end else begin
                case (state)
                    
                    STATE_INIT: begin
                        lcd_rs <= 0;
                        lcd_data <= init_cmds[char_index];
                        lcd_en <= 1; 
                        wait_flag <= 1;
                        
                        if (char_index < 4) 
                            char_index <= char_index + 1;
                        else begin
                            char_index <= 0;
                            op_store <= 3'b000;
                            reg_store <= 4'b0000;
                            val_store <= 16'd0;
                            unsigned_val <= 16'd0;
                            is_negative <= 0;
                            state <= STATE_WRITE_LINE1; 
                        end
                    end

                    STATE_READY: begin
                        if (start) begin
                            op_store <= opcode;
                            reg_store <= reg_idx;
                            val_store <= value;
                            
                            if (value < 0) begin
                                is_negative <= 1;
                                unsigned_val <= -value;
                            end else begin
                                is_negative <= 0;
                                unsigned_val <= value;
                            end
                            
                            lcd_rs <= 0;
                            lcd_data <= 8'h01; 
                            lcd_en <= 1;
                            wait_flag <= 1;
                            
                            state <= STATE_WRITE_LINE1;
                            char_index <= 0;
                        end
                    end

                    STATE_WRITE_LINE1: begin
                        digit_10000 <= (unsigned_val / 10000) % 10;
                        digit_1000  <= (unsigned_val / 1000) % 10;
                        digit_100   <= (unsigned_val / 100) % 10;
                        digit_10    <= (unsigned_val / 10) % 10;
                        digit_1     <= (unsigned_val) % 10;

                        lcd_rs <= 1;
                        lcd_en <= 1;
                        wait_flag <= 1;
                        
                        if (char_index < 5) begin
                            if (first_boot)
                                lcd_data <= " "; 
                            else
                                lcd_data <= get_op_string(op_store) >> (8 * (4 - char_index));
                        end 
                        else begin
                            // Lógica do CLEAR (Limpa resto da linha)
                            if (op_store == 3'b110 && !first_boot) begin
                                lcd_data <= " ";
                            end else begin
                                if (char_index == 5) lcd_data <= " ";
                                else if (char_index == 6) lcd_data <= "[";
                                else if (char_index >= 7 && char_index <= 10) 
                                    lcd_data <= reg_store[10 - char_index] ? "1" : "0";
                                else if (char_index == 11) lcd_data <= "]";
                            end
                        end
                        
                        if (char_index < 11)
                            char_index <= char_index + 1;
                        else begin
                            char_index <= 0;
                            // Se for CLEAR, cancela linha 2
                            if (op_store == 3'b110 && !first_boot) begin
                                state <= STATE_READY;
                            end else begin
                                state <= STATE_LINE2_ADDR;
                            end
                        end
                    end

                    STATE_LINE2_ADDR: begin
                        lcd_rs <= 0;
                        lcd_data <= 8'hC0;
                        lcd_en <= 1;
                        wait_flag <= 1;
                        state <= STATE_WRITE_LINE2;
                    end

                    STATE_WRITE_LINE2: begin
                        lcd_rs <= 1;
                        lcd_en <= 1;
                        wait_flag <= 1;
                        
                        case(char_index)
                            0: lcd_data <= is_negative ? "-" : "+";
                            1: lcd_data <= 8'h30 + digit_10000;
                            2: lcd_data <= 8'h30 + digit_1000;
                            3: lcd_data <= 8'h30 + digit_100;
                            4: lcd_data <= 8'h30 + digit_10;
                            5: lcd_data <= 8'h30 + digit_1;
                        endcase
                        
                        if (char_index < 5)
                            char_index <= char_index + 1;
                        else begin
                            first_boot <= 0;
                            state <= STATE_READY;
                        end
                    end
                endcase
            end
        end
    end
endmodule