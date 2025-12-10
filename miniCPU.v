module miniCPU (
    input [17:0] switches,
    input ligar,     // KEY[0] - Reset Geral (Ativo em 0)
    input enviar,    // KEY[1] - Clock de Instrução (Ativo em 0)
    input clk,       // CLOCK_50 da placa 

    // --- SAÍDAS PARA O LCD (Novos Pinos) ---
    output [7:0] LCD_DATA,
    output LCD_RW,
    output LCD_EN,
    output LCD_RS,
    output LCD_ON,
    output LCD_BLON
);

    // ==============================================================================
    // 1. DECODIFICAÇÃO
    // ==============================================================================
    wire [2:0] opcode = switches [17:15];
    wire [3:0] reg_dest = switches [14:11]; // R1
    wire [3:0] reg_input1 = switches[10:7]; // R2 (Usado para ler o dado pro LCD)
    wire [3:0] reg_input2 = switches [6:3]; // R3
    wire signal = switches[6];
    
    // Tratamento de Sinal (Magnitude -> Complemento de 2)
    wire [15:0] imediato_module = {10'd0, switches[5:0]};
    wire [15:0] imediato = (signal) ? (-imediato_module) : imediato_module;
    
    // Fios de Dados Internos
    wire [15:0] mem_read_data1;
    wire [15:0] mem_read_data2;
    wire [15:0] alu_result;
    
    // ==============================================================================
    // 2. SINAIS DE CONTROLE E INTERFACE LCD
    // ==============================================================================
    
    // Controle da Memória/ULA
    reg write_enable;
    reg [15:0] mem_write;
    reg [1:0] alu_selector;
    reg [15:0] alu_input_2;
    
    // Controle do Reset (Hardware + Software CLEAR)
    reg soft_reset; 
    wire memory_reset_signal = ligar & ~soft_reset; 

    // Controle do LCD
    reg lcd_start;          // Gatilho para iniciar escrita
    wire lcd_busy;          // LCD avisa se está ocupado
    reg [15:0] lcd_data_in; // O valor que será enviado para a tela

    // Parâmetros de Opcode
    parameter [2:0] LOAD = 3'b000, ADD = 3'b001, ADDI = 3'b010, SUB = 3'b011,
                    SUBI = 3'b100, MUL = 3'b101, CLEAR = 3'b110, DISPLAY = 3'b111;

    // ==============================================================================
    // 3. INSTANCIAÇÃO DOS MÓDULOS
    // ==============================================================================

    memoryCPU Memo (
        .clock(clk),
        .reset(memory_reset_signal), // Reset físico OU comando CLEAR
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

    // Módulo Controlador do LCD (Driver)
    // ATENÇÃO: Certifique-se de ter os arquivos Module_LCD.v e lcd_init_hd44780.v no projeto
    Module_LCD LCD_System (
        .clk(clk),
        .reset(~ligar),         // Inverte o reset (Placa é 0, Módulo LCD espera 1)
        .start(lcd_start),      // Sinal vindo da FSM
        .data_in(lcd_data_in),  // Dado vindo da FSM
        .busy(lcd_busy),        // Sinal indo para a FSM
        
        // Conexões físicas
        .LCD_DATA(LCD_DATA),
        .LCD_RS(LCD_RS),
        .LCD_RW(LCD_RW),
        .LCD_EN(LCD_EN),
        .LCD_ON(LCD_ON),
        .LCD_BLON(LCD_BLON)
    );

    // ==============================================================================
    // 4. MÁQUINA DE ESTADOS (FSM)
    // ==============================================================================
    
    reg [2:0] state;
    // Estados aumentados para incluir espera do LCD
    parameter [2:0] IDLE = 3'd0, EXECUTE = 3'd1, WRITE = 3'd2, 
                    WAIT_RELEASE = 3'd3, WAIT_LCD = 3'd4;
                        
    always @(negedge clk or negedge ligar) begin
        if (!ligar) begin
            state <= IDLE;
            write_enable <= 0;
            soft_reset <= 0;
            lcd_start <= 0;
        end
        else begin
            case(state)
                // --- ESTADO 0: ESPERA O USUÁRIO ---
                IDLE: begin
                    write_enable <= 0;
                    soft_reset <= 0;
                    lcd_start <= 0;
                    if (!enviar) begin // Botão pressionado (nível baixo)
                        state <= EXECUTE;
                    end
                end
                
                // --- ESTADO 1: PROCESSAMENTO ---
                EXECUTE: begin
                    case(opcode)
                        // LOAD e CLEAR não usam ULA aritmética
                        LOAD: begin end
                        CLEAR: begin end
                        DISPLAY: begin end
                        
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
                
                // --- ESTADO 2: ESCRITA OU INÍCIO DO DISPLAY ---
                WRITE: begin
                    // Caso 1: CLEAR (Resetar Memória)
                    if (opcode == CLEAR) begin
                        soft_reset <= 1;
                        write_enable <= 0;
                        state <= WAIT_RELEASE;
                    end
                    
                    // Caso 2: DISPLAY (Mostrar no LCD)
                    else if (opcode == DISPLAY) begin
                        write_enable <= 0;
                        
                        // Configura o LCD para mostrar o Registrador 1 (selecionado nos switches [10:7])
                        lcd_data_in <= mem_read_data1; 
                        lcd_start <= 1; // Pulso de início
                        
                        state <= WAIT_LCD; // Vai para espera
                    end
                    
                    // Caso 3: Instrução Normal (Gravar na Memória)
                    else begin
                        write_enable <= 1;
                        if (opcode == LOAD)
                            mem_write <= imediato;
                        else
                            mem_write <= alu_result;
                            
                        state <= WAIT_RELEASE;
                    end
                end
                
                // --- ESTADO EXTRA: ESPERANDO O LCD ---
                WAIT_LCD: begin
                    lcd_start <= 0; // Baixa o pulso de start
                    
                    // Só sai daqui quando o LCD terminar (busy cair para 0)
                    if (lcd_busy == 0) begin
                        state <= WAIT_RELEASE;
                    end
                end
                
                // --- ESTADO 3: DEBOUNCE (SOLTAR BOTÃO) ---
                WAIT_RELEASE: begin
                    write_enable <= 0;
                    soft_reset <= 0; // Desliga reset lógico
                    
                    if (enviar) begin // Botão solto (nível alto)
                        state <= IDLE;
                    end
                end
            endcase
        end
    end
    
    
endmodule 