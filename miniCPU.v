module miniCPU (
    input [17:0] switches,
    input ligar,      // Botão físico de Reset (KEY[0])
    input enviar,     // Botão de Enviar (KEY[1])
    input clk,
    
    // Outputs para LCD
    output [7:0] LCD_DATA,
    output LCD_RS,
    output LCD_RW,
    output LCD_EN,
    output LCD_ON,
    output LCD_BLON,

    // Outputs Debug
    output [15:0] leds_debug
);

    // --- 1. Decodificação ---
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
    reg soft_reset; 
    
    wire memory_reset_signal = ligar & ~soft_reset;

    parameter [2:0] LOAD = 3'b000, ADD = 3'b001, ADDI = 3'b010, SUB = 3'b011,
                    SUBI = 3'b100, MUL = 3'b101, CLEAR = 3'b110, DISPLAY = 3'b111;
                        
    // --- Instanciação dos Módulos ---
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
    
    // --- Integração LCD ---
    reg lcd_start_signal;
    reg [15:0] lcd_value_reg;
    reg [3:0] lcd_reg_idx;
    
    // O registrador a ser mostrado no LCD depende da instrução:
    // DISPLAY: Mostra o registrador fonte (Src1)
    // OUTROS: Mostra o registrador destino (Dest)
    wire [3:0] current_lcd_reg_idx = (opcode == DISPLAY) ? reg_input1 : reg_dest;
    
    // O valor a ser mostrado depende da instrução:
    // LOAD: Valor Imediato
    // DISPLAY: Valor lido da memória (Src1)
    // OUTROS: Resultado da ULA
    reg [15:0] current_lcd_value;

    // Lógica combinacional para definir o valor enviado ao LCD antes do clock
    always @(*) begin
        if (opcode == LOAD)
            current_lcd_value = imediato;
        else if (opcode == DISPLAY)
            current_lcd_value = mem_read_data1;
        else
            current_lcd_value = alu_result;
    end

    lcd_controller LCD (
        .clk(clk),
        .reset_n(ligar),
        .start(lcd_start_signal),
        .opcode(opcode),
        .reg_idx(lcd_reg_idx),  // Usamos registradores internos para manter o valor estável
        .value(lcd_value_reg),  // Usamos registradores internos
        
        .lcd_data(LCD_DATA),
        .lcd_rs(LCD_RS),
        .lcd_rw(LCD_RW),
        .lcd_en(LCD_EN),
        .lcd_on(LCD_ON),
        .lcd_blon(LCD_BLON)
    );

    // --- Máquina de Estados Principal ---
    reg [2:0] state;
    parameter [2:0] IDLE = 3'd0, EXECUTE = 3'd1, WRITE = 3'd2, WAIT_RELEASE = 3'd3;
                        
    always @(posedge clk or negedge ligar) begin // Usei posedge clk para alinhar com o resto
        if (!ligar) begin
            state <= IDLE;
            write_enable <= 0;
            soft_reset <= 0;
            lcd_start_signal <= 0;
        end
        else begin
            case(state)
                IDLE: begin
                    write_enable <= 0;
                    soft_reset <= 0;
                    lcd_start_signal <= 0; // Garante que o sinal de start baixe
                    
                    if (!enviar) begin
                        state <= EXECUTE;
                    end
                end
                
                EXECUTE: begin
                    // Configuração da ULA
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
                
                WRITE: begin
                    // --- ATUALIZAÇÃO DO LCD ---
                    // Capturamos os valores neste momento exato em que o resultado está pronto
                    lcd_reg_idx <= current_lcd_reg_idx;
                    lcd_value_reg <= current_lcd_value;
                    lcd_start_signal <= 1; // Dispara o pulso para o módulo LCD iniciar
                    
                    // Lógica de Memória Original
                    if (opcode == CLEAR) begin
                        soft_reset <= 1;
                        write_enable <= 0;
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
                    lcd_start_signal <= 0; // Desliga o sinal de start do LCD (ele já capturou os dados)
                    
                    if (enviar) begin // Botão solto (lógica pull-up, enviar=1 é solto)
                        state <= IDLE;
                    end
                end
            endcase
        end
    end
    
    // Debug
    assign leds_debug = alu_result; 
endmodule
