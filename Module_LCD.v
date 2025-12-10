module Module_LCD (
    input  wire        clk,
    input  wire        reset,      // Reset ativo alto (conforme seu código original)
    input  wire        start,      // Pulso da CPU para iniciar escrita
    input  wire [15:0] data_in,    // O valor numérico a ser mostrado
    output reg         busy,       // Diz para a CPU esperar
    
    // Saídas Físicas
    output reg  [7:0]  LCD_DATA,
    output reg         LCD_RS,
    output reg         LCD_RW,
    output reg         LCD_EN,
    output wire        LCD_ON,
    output wire        LCD_BLON
);

    // Configuração fixa
    assign LCD_ON   = 1'b1;
    assign LCD_BLON = 1'b1;

    // Sinais da Inicialização
    wire [7:0] init_data;
    wire       init_rs, init_rw, init_en, init_done;
    reg        start_init;

    // Instância do Inicializador
    lcd_init_hd44780 INIT_MODULE (
        .clk(clk),
        .rst(reset),
        .start(start_init),
        .done(init_done),
        .lcd_data(init_data),
        .lcd_rs(init_rs),
        .lcd_rw(init_rw),
        .lcd_e(init_en)
    );

    // Estados da Máquina de Escrita
    reg [3:0] state;
    localparam S_IDLE       = 0;
    localparam S_Init_Wait  = 1; // Espera inicialização terminar
    localparam S_Ready      = 2; // Esperando comando da CPU
    localparam S_Clear      = 3; // Limpar tela antes de escrever novo
    localparam S_Convert    = 4; // Converte binário para ASCII
    localparam S_Setup_Char = 5; // Coloca dado na porta
    localparam S_Pulse_Char = 6; // Pulso de Enable
    localparam S_Wait_Char  = 7; // Espera LCD processar

    // Variáveis internas
    reg [15:0] stored_data;
    reg [2:0]  char_index; // Qual caractere estamos escrevendo (0 a 3)
    reg [7:0]  ascii_char; // O caractere atual convertido
    reg [3:0]  nibble;     // Pedaço de 4 bits do número
    reg [15:0] wait_cnt;   // Contador de espera

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= S_IDLE;
            start_init <= 0;
            busy <= 1; // Ocupado durante reset
            char_index <= 0;
        end else begin
            case(state)
                // 1. Manda inicializar o LCD assim que liga
                S_IDLE: begin
                    start_init <= 1;
                    state <= S_Init_Wait;
                    busy <= 1;
                end

                // 2. Espera o módulo 'lcd_init' terminar
                S_Init_Wait: begin
                    start_init <= 0;
                    if (init_done) begin
                        state <= S_Ready;
                        busy <= 0;
                    end
                end

                // 3. Estado de Repouso: Espera a CPU mandar 'start'
                S_Ready: begin
                    busy <= 0;
                    char_index <= 0;
                    if (start) begin
                        stored_data <= data_in; // Captura o dado
                        busy <= 1;              // Avisa que está ocupado
                        state <= S_Setup_Char;  // Começa a escrever
                    end
                end

                // 4. Prepara o caractere atual
                S_Setup_Char: begin
                    // Seleciona qual pedaço de 4 bits vamos mostrar (Hexadecimal)
                    // Ordem: Bits [15:12] -> [11:8] -> [7:4] -> [3:0]
                    case (char_index)
                        0: nibble = stored_data[15:12];
                        1: nibble = stored_data[11:8];
                        2: nibble = stored_data[7:4]; // Correção: "nibble =" faltou aqui na lógica mental
                        3: nibble = stored_data[3:0];
                        default: nibble = 4'h0;
                    endcase
                    
                    // --- CORREÇÃO DA SINTAXE DO CASE ACIMA ---
                    if (char_index == 0) nibble = stored_data[15:12];
                    else if (char_index == 1) nibble = stored_data[11:8];
                    else if (char_index == 2) nibble = stored_data[7:4];
                    else nibble = stored_data[3:0];

                    // Conversão Hex -> ASCII
                    if (nibble < 10) ascii_char <= nibble + 8'h30;      // 0-9
                    else ascii_char <= nibble - 4'd10 + 8'h41;          // A-F

                    wait_cnt <= 0;
                    state <= S_Pulse_Char;
                end

                // 5. Gera o pulso de Enable
                S_Pulse_Char: begin
                    if (wait_cnt < 50) begin // Pequeno delay pra estabilizar
                        wait_cnt <= wait_cnt + 1;
                    end else begin
                        wait_cnt <= 0;
                        state <= S_Wait_Char;
                    end
                end

                // 6. Espera o LCD escrever e verifica se acabou
                S_Wait_Char: begin
                    if (wait_cnt < 2500) begin // ~50us de espera
                        wait_cnt <= wait_cnt + 1;
                    end else begin
                        // Se já escreveu os 4 caracteres
                        if (char_index == 3) begin
                            state <= S_Ready; // Volta pra espera
                            busy <= 0;        // Libera a CPU
                        end else begin
                            char_index <= char_index + 1; // Próximo caractere
                            state <= S_Setup_Char;
                        end
                    end
                end
            endcase
        end
    end

    // MUX de Saída: Controla quem manda nos pinos (Init ou Escrita)
    always @(*) begin
        if (state == S_IDLE || state == S_Init_Wait) begin
            // Durante inicialização, o módulo INIT controla
            LCD_DATA = init_data;
            LCD_RS   = init_rs;
            LCD_RW   = init_rw;
            LCD_EN   = init_en;
        end else begin
            // Durante operação normal
            LCD_DATA = ascii_char;
            LCD_RS   = 1'b1; // 1 = Dado (Caracteres)
            LCD_RW   = 1'b0; // 0 = Escrita
            
            // O Enable só liga no estado S_Pulse_Char
            if (state == S_Pulse_Char) LCD_EN = 1'b1;
            else LCD_EN = 1'b0;
        end
    end

endmodule