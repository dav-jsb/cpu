module miniCPU (
    input clock_50mhz,              // Clock principal da placa (50 MHz)
    input botao_reset_ligar,        // Botão de Reset (Geralmente KEY0)
    input botao_enviar_instrucao,   // Botão de Enviar (Geralmente KEY1)
    input [17:0] switches_entrada,  // Todos os 18 switches da placa
    
    // Saída apenas para visualizar algo piscando (Debug)
    output [15:0] leds_vermelhos_debug 
);

    // ==============================================================================
    // 1. DECODIFICAÇÃO DOS SWITCHES (Fatiando o bolo de fios)
    // ==============================================================================
    
    // ORIGEM: Switches [17:15] -> DESTINO: Lógica de controle e MUXES
    wire [2:0] fio_opcode = switches_entrada[17:15];
    
    // ORIGEM: Switches [14:11] -> DESTINO: Porta 'write_reg_addr' da Memória
    wire [3:0] fio_endereco_registrador_destino = switches_entrada[14:11];
    
    // ORIGEM: Switches [10:7] -> DESTINO: Porta 'read_reg_addr_1' da Memória
    wire [3:0] fio_endereco_registrador_fonte_1 = switches_entrada[10:7];
    
    // ORIGEM: Switches [6:3] -> DESTINO: Porta 'read_reg_addr_2' da Memória (Só usado em ADD/SUB)
    wire [3:0] fio_endereco_registrador_fonte_2 = switches_entrada[6:3];
    
    // ORIGEM: Switch [6] -> DESTINO: Lógica de tratamento do imediato (Sinal)
    wire fio_bit_sinal_imediato = switches_entrada[6];
    
    // ORIGEM: Switches [5:0] -> DESTINO: Lógica de tratamento do imediato (Valor)
    wire [5:0] fio_valor_modulo_imediato = switches_entrada[5:0];


    // ==============================================================================
    // 2. FIOS INTERNOS (Os "Canos" que ligam os módulos)
    // ==============================================================================

    // ORIGEM: Saída 'read_data_1' da Memória -> DESTINO: Entrada 'data1' da ULA
    wire [15:0] fio_dado_saiu_memoria_porta_1;

    // ORIGEM: Saída 'read_data_2' da Memória -> DESTINO: Entrada do MUX da ULA
    wire [15:0] fio_dado_saiu_memoria_porta_2;

    // ORIGEM: Saída 'result' da ULA -> DESTINO: Entrada do MUX da Memória
    wire [15:0] fio_resultado_calculado_pela_ula;

    // ORIGEM: Saída do MUX da ULA -> DESTINO: Entrada 'data2' da ULA
    reg [15:0] fio_dado_escolhido_para_entrada_B_da_ula;

    // ORIGEM: Saída do MUX da Memória -> DESTINO: Entrada 'write_data' da Memória
    reg [15:0] fio_dado_escolhido_para_escrever_na_memoria;

    // ORIGEM: Lógica de extensão de sinal -> DESTINO: Entradas dos MUXES
    reg [15:0] fio_imediato_processado_16bits;

    // ORIGEM: Máquina de Estados (FSM) -> DESTINO: Porta 'regWrite' da Memória
    reg reg_controle_habilitar_escrita_memoria;


    // ==============================================================================
    // 3. TRATAMENTO DO NÚMERO IMEDIATO (Matemática Combinacional)
    // ==============================================================================
    // Objetivo: Transformar os switches picados em um número de 16 bits válido.
    
    always @(*) begin
        if (fio_bit_sinal_imediato == 1'b1) begin
            // SE NEGATIVO: Converte o módulo para negativo (Complemento de 2)
            // ORIGEM: Switches [5:0] -> DESTINO: Muxes
            fio_imediato_processado_16bits = -{10'b0, fio_valor_modulo_imediato}; 
        end else begin
            // SE POSITIVO: Apenas preenche com zeros à esquerda
            // ORIGEM: Switches [5:0] -> DESTINO: Muxes
            fio_imediato_processado_16bits = {10'b0, fio_valor_modulo_imediato};
        end
    end


    // ==============================================================================
    // 4. INSTANCIAÇÃO DOS MÓDULOS (Ligando os canos nas caixas)
    // ==============================================================================

    memoryCPU MEMORIA_PRINCIPAL (
        .clock(clock_50mhz),
        .reset(botao_reset_ligar),
        
        // Controle de Escrita (Vem da FSM)
        .regWrite(reg_controle_habilitar_escrita_memoria), 
        
        // ONDE escrever (Vem dos Switches)
        .write_reg_addr(fio_endereco_registrador_destino), 
        
        // O QUE escrever (Vem do MUX 2 - Pode ser da ULA ou Imediato)
        .write_data(fio_dado_escolhido_para_escrever_na_memoria), 
        
        // ENDEREÇOS de Leitura (Vêm dos Switches)
        .read_reg_addr_1(fio_endereco_registrador_fonte_1),
        .read_reg_addr_2(fio_endereco_registrador_fonte_2),
        
        // SAÍDAS de Dados (Vão para fios internos)
        .read_data_1(fio_dado_saiu_memoria_porta_1),
        .read_data_2(fio_dado_saiu_memoria_porta_2)
    );

    aluCPU UNIDADE_LOGICA_ARITMETICA (
        // Entrada A: Sempre vem direto da Memória
        .data1(fio_dado_saiu_memoria_porta_1),
        
        // Entrada B: Vem do MUX 1 (Pode ser Memória ou Imediato)
        .data2(fio_dado_escolhido_para_entrada_B_da_ula), 
        
        // Seletor: Os últimos 2 bits do Opcode definem a conta (+, -, *)
        .sel(fio_opcode[1:0]), 
        
        // Resultado: Vai para o fio interno
        .result(fio_resultado_calculado_pela_ula) 
    );


    // ==============================================================================
    // 5. LÓGICA DOS MULTIPLEXADORES (As Válvulas de Decisão)
    // ==============================================================================

    always @(*) begin
        // --- MUX 1: Quem entra na porta B da ULA? ---
        // Se Opcode for 001 (ADD) ou 011 (SUB - instrução reg-reg)
        if (fio_opcode == 3'b001 || fio_opcode == 3'b011) begin
            // ORIGEM: Memória Porta 2 -> DESTINO: ULA Porta B
            fio_dado_escolhido_para_entrada_B_da_ula = fio_dado_saiu_memoria_porta_2;
        end else begin
            // Caso contrário (ADDI, SUBI, MUL, LOAD...), usa o número fixo
            // ORIGEM: Imediato Processado -> DESTINO: ULA Porta B
            fio_dado_escolhido_para_entrada_B_da_ula = fio_imediato_processado_16bits;
        end

        // --- MUX 2: O que vamos gravar na memória? ---
        // Se Opcode for 000 (LOAD)
        if (fio_opcode == 3'b000) begin
            // ORIGEM: Imediato Processado -> DESTINO: Entrada de Dados da Memória
            // (Ignora a ULA completamente)
            fio_dado_escolhido_para_escrever_na_memoria = fio_imediato_processado_16bits;
        end else begin
            // Para todo o resto (Somas, Subtrações, Multiplicações)
            // ORIGEM: Resultado da ULA -> DESTINO: Entrada de Dados da Memória
            fio_dado_escolhido_para_escrever_na_memoria = fio_resultado_calculado_pela_ula;
        end
    end


    // ==============================================================================
    // 6. MÁQUINA DE ESTADOS (FSM) - O Maestro
    // ==============================================================================
    
    // Detector de Borda (Para detectar quando SOLTA o botão)
    reg reg_estado_anterior_botao;
    wire pulso_botao_enviar_solto;
    
    always @(posedge clock_50mhz) begin
        reg_estado_anterior_botao <= botao_enviar_instrucao;
    end
    // Gera 1 apenas quando o botão estava 0 (pressionado) e foi para 1 (solto) - assumindo active low logic
    // Se o seu botão for "Aperta = 0", use:
    assign pulso_botao_enviar_solto = (botao_enviar_instrucao == 1'b1 && reg_estado_anterior_botao == 1'b0);

    // Definição dos Estados
    reg [1:0] estado_atual;
    parameter ESTADO_OCIOSO    = 2'b00;
    parameter ESTADO_EXECUTAR  = 2'b01;
    parameter ESTADO_ESPERAR   = 2'b10;

    always @(posedge clock_50mhz or negedge botao_reset_ligar) begin
        if (~botao_reset_ligar) begin
            // RESETAR TUDO
            estado_atual <= ESTADO_OCIOSO;
            reg_controle_habilitar_escrita_memoria <= 0;
        end else begin
            case (estado_atual)
                ESTADO_OCIOSO: begin
                    reg_controle_habilitar_escrita_memoria <= 0; // Garante que não escreve nada
                    
                    // Se o usuário SOLTOU o botão enviar
                    if (pulso_botao_enviar_solto) begin
                        estado_atual <= ESTADO_EXECUTAR;
                    end
                end

                ESTADO_EXECUTAR: begin
                    // Momento da Ação!
                    // Só ativamos a escrita se NÃO for DISPLAY (111) nem CLEAR (110)
                    if (fio_opcode != 3'b111 && fio_opcode != 3'b110) begin
                        reg_controle_habilitar_escrita_memoria <= 1; // Pulso de escrita LIGADO
                    end
                    
                    // Vai imediatamente para espera no próximo clock
                    estado_atual <= ESTADO_ESPERAR;
                end

                ESTADO_ESPERAR: begin
                    // Desliga a escrita imediatamente para não escrever lixo
                    reg_controle_habilitar_escrita_memoria <= 0; 
                    
                    // Aqui entraria a lógica de espera do LCD no futuro...
                    // Por enquanto, volta pro início
                    estado_atual <= ESTADO_OCIOSO;
                end
            endcase
        end
    end

    // Visualização nos LEDs (Mostra o que está saindo da ULA)
    assign leds_vermelhos_debug = fio_resultado_calculado_pela_ula;

endmodule
