module miniCPU (
    input [17:0] switches, //entrada de Switches
    input ligar,      // Botão Ligar / Desligar
    input enviar,     // Botão de Enviar 
    input clk,        // clk do sistema
    
    // Outputs para LCD
    output [7:0] LCD_DATA,
    output LCD_RS,
    output LCD_RW,
    output LCD_EN,
    output LCD_ON,
    output LCD_BLON
);

    // fios de decodificação no sistema
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
    
    // Sinais de controle do sistema
    reg write_enable;
    reg [15:0] mem_write;
    reg [1:0] alu_selector;
    reg [15:0] alu_input_2;
    reg soft_reset; 
    wire memory_reset_signal = ligar & ~soft_reset; //porta logica ativa em 0 para resetar a memoria -> ativa em CLEAR ou Desligando o sist.

    parameter [2:0] LOAD = 3'b000, ADD = 3'b001, ADDI = 3'b010, SUB = 3'b011,
                    SUBI = 3'b100, MUL = 3'b101, CLEAR = 3'b110, DISPLAY = 3'b111;                   
    //modulo de memoria
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
    //modulo de ULA
    aluCPU ALU (
        .data1(mem_read_data1),
        .data2(alu_input_2),
        .sel(alu_selector),
        .result(alu_result)
    );
    // O LCD deve ser integrado com um ENABLE de start e puxando o de indice do registrador e o valor contido nele
    reg lcd_start_signal;
    reg [15:0] lcd_value_reg;
    reg [3:0] lcd_reg_idx;
    
    //se for Display, deve mostrar o registrador de fonte; todos os outros casos mostra o registrador de destino
    wire [3:0] current_lcd_reg_idx = (opcode == DISPLAY) ? reg_input1 : reg_dest;
    
    // O valor a ser mostrado depende da instrução: se for LOAD, mostra o valor imediato. Display -> valor lido do Reg na memoria.
    //todos os outros casos são de valores resultantes de operações na ULA
    reg [15:0] current_lcd_value;

    //modulo de LCD
    lcd_controller LCD (
        .clk(clk),
        .reset_n(ligar),
        .start(lcd_start_signal),
        .opcode(opcode),
        .reg_idx(lcd_reg_idx),  // Usamos registradores internos para manter o valor estável
        .value(lcd_value_reg),  
        
        //Pinagem direta dos outputs do LCD e do modulo da CPU
        .lcd_data(LCD_DATA),
        .lcd_rs(LCD_RS),
        .lcd_rw(LCD_RW),
        .lcd_en(LCD_EN),
        .lcd_on(LCD_ON),
        .lcd_blon(LCD_BLON)
    );
    
    //este é o Bloco Combinacional; nele estamos tratando o valor que vai sair para o LCD a partir do sinal no OPCODE
    always @(*) begin
        if (opcode == LOAD)
            current_lcd_value = imediato;
        else if (opcode == DISPLAY)
            current_lcd_value = mem_read_data1;
        else
            current_lcd_value = alu_result;
    end

    // Este é o bloco Sequencial, no qual definimos os estados e as transições
    reg [2:0] state;
    parameter [2:0] IDLE = 3'd0, EXECUTE = 3'd1, WRITE = 3'd2, WAIT_RELEASE = 3'd3;                 
    always @(posedge clk or negedge ligar) begin 
        if (~ligar) begin
            state <= IDLE;
            write_enable <= 0;
            soft_reset <= 0;
            lcd_start_signal <= 0;
        end
        else begin
            case(state)
                IDLE: begin //estado de espera
                    write_enable <= 0;
                    soft_reset <= 0;
                    lcd_start_signal <= 0; // Garante que o sinal de start fique em LOW
                    
                    //sempre que aperta o botão, passa o estado da máquina para o estado de execução
                    if (!enviar) begin
                        state <= EXECUTE;
                    end
                end
                EXECUTE: begin //Execução na ULA
                    
                    // O estado de Execute opera em cima das operações próprias da ULA; as operações de interação DIRETA
                    //na memória são tratadas em WRITE
                    case(opcode)
                        ADD: begin alu_selector <= 2'b00; alu_input_2 <= mem_read_data2; end
                        ADDI: begin alu_selector <= 2'b00; alu_input_2 <= imediato; end
                        SUB: begin alu_selector <= 2'b01; alu_input_2 <= mem_read_data2; end
                        SUBI: begin alu_selector <= 2'b01; alu_input_2 <= imediato; end
                        MUL: begin alu_selector <= 2'b10; alu_input_2 <= imediato; end
                        default: begin alu_selector <= 2'b00; alu_input_2 <= 16'd0; end
                    endcase
                    state <= WRITE;
                end
                WRITE: begin //Escrita na memoria ou lançamento direto ao LCD
                    
                    // Capturamos os valores neste momento exato em que o resultado está pronto
                    lcd_reg_idx <= current_lcd_reg_idx; //indice do registrador a ser mostrado no LCD
                    lcd_value_reg <= current_lcd_value; //valor contido no registrador que está sendo mostrado no LCD
                    lcd_start_signal <= 1; // ENABLE para o LCD inicializar
                    
                    // Ativa o reset da memoria para reiniciar todos os registradores
                    if (opcode == CLEAR) begin
                        soft_reset <= 1;
                        write_enable <= 0;
                    end
                    //se não for opcode de clear, as unicas possiblidades de tratamente nesse estado é o de LOAD um novo valor
                    //OU de uma saída ligada ao valor da ULA
                    else if (opcode != DISPLAY) begin
                        write_enable <= 1;
                        if (opcode == LOAD)
                            mem_write <= imediato;
                        else
                            mem_write <= alu_result;
                    end
                    state <= WAIT_RELEASE;
                end
                WAIT_RELEASE: begin //estado de debboucing do botão de enviar
                    
                    write_enable <= 0; // desliga o sinal de escrita no sistema
                    soft_reset <= 0; // desliga o sinal de reinicio do sistema
                    lcd_start_signal <= 0; // Desliga o sinal de start do LCD 
                    
                    if (enviar) begin // Somente quando o botão é SOLTO ele será então enviado ao LCD com as informações
                        state <= IDLE; //retorna ao estado de espera
                    end
                end
            endcase
        end
    end
endmodule 
