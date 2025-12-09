module miniCPU (
    input clk,            // Clock de 50MHz da placa
	input ligar,          // ligar/ desligar -> ATIVO EM LOW(0) 
	input enviar,         // Botão Enviar -> ATIVO EM LOW(0)
	input [17:0] switches // Entrada dos switches

	//ainda nao temos a pinagem do LCD, então nao temos um Output para esse módulo
);
    reg btn_prev;
    wire enviar_solto; // Pulso de 1 clock quando solta o botão
    always @(posedge clk) begin
        btn_prev <= enviar; 
    end
	// ENABLE que detecta transição de subida do botão, armazena o estado anterior e o atual com base no clk. Habilita a transição
	//mudanças no código
	assign enviar_solto = (enviar == 1'b1 && btn_prev == 1'b0); 
    
	wire [2:0] opcode = switches[17:15]; //Opcode sempre definido nos bits 18 a 16
	wire [3:0] r_dest = switches[14:11]; //registrador de destino sempre definido nos bits de 15 a 12
	wire [3:0] r_src1 = switches[10:7]; //PRIMEIRO registrador ORIGEM, indice 0 a 15
	wire [3:0] r_src2 = switches[6:3]; // SEGUNDO registrador ORIGEM, indice 0 a 15
	wire sinal_imediato = switches[6]; //sinal do valor imediato
	wire [5:0] mod_imediato = switches[5:0]; // modulo do imediato

	//Precisa ter esses fios para sairem da MEMÓRIA e da ULA, saindo apenas VALORES
    wire [15:0] w_data_rd1, w_data_rd2;
    wire [15:0] w_alu_result;
    
    // Sinais de Controle (A FSM vai pilotar estes regs)
    reg reg_write_enable;     // Controle da Memória
	reg [15:0] mux_ula_b;     // Saída do MUX da ULA -> MULTIPLEXA a saída PARA a ULA, como valor imdeiato ou de busca na MEMORIA
	reg [15:0] mux_mem_data;  // Saída do MUX da Memória -> MULTIPLEXA a saída 
    reg [15:0] w_imediato_ext;// Imediato processado

    // Tratamento do Imediato (Combinacional)
    always @(*) begin
        if (sinal_imediato) 
            w_imediato_ext = -{10'b0, mod_imediato}; // Converte negativo
        else 
            w_imediato_ext = {10'b0, mod_imediato};  // Positivo
    end

    memoryCPU MEM (
        .clock(clk),
        .reset(ligar),          // Botão de reset
		.regWrite(reg_write_enable), //A FSM é que vai controlar se estará ou não escrevendo algo
        .write_reg_addr(r_dest),
        .write_data(mux_mem_data),
        .read_reg_addr_1(r_src1),
        .read_reg_addr_2(r_src2),
        .read_data_1(w_data_rd1),
        .read_data_2(w_data_rd2)
    );

    aluCPU ULA (
        .data1(w_data_rd1),
        .data2(mux_ula_b),       // Entra o valor decidido pelo MUX
        .sel(opcode[1:0]),       // Bits do opcode controlam a ULA
        .result(w_alu_result)
    );
	
    always @(*) begin
        if (opcode == 3'b001 || opcode == 3'b011)
            mux_ula_b = w_data_rd2;
        else
            mux_ula_b = w_imediato_ext;
        if (opcode == 3'b000) // LOAD
            mux_mem_data = w_imediato_ext;
        else
            mux_mem_data = w_alu_result;
    end
	
    // Definição dos Estados
    reg [1:0] estado_atual;
    parameter IDLE = 2'b00, EXECUTE = 2'b01, WAIT_RELEASE = 2'b10;

    always @(posedge clk or negedge ligar) begin
        if (~ligar) begin
            estado_atual <= IDLE;
            reg_write_enable <= 0;
        end else begin
            case (estado_atual)
                IDLE: begin
                    reg_write_enable <= 0;
                    if (enviar_solto) begin
                        estado_atual <= EXECUTE;
                    end
                end

                EXECUTE: begin
                    if (opcode != 3'b111 && opcode != 3'b110) begin 
                         reg_write_enable <= 1; // Pulso de escrita
                    end  
                    estado_atual <= WAIT_RELEASE;
                end
                WAIT_RELEASE: begin
                    reg_write_enable <= 0; // Desliga escrita imediatamente pois estamos acionando o LCD
                    // ACIONAR O LCD NESSE ESTADO -> ESPERAR 1ms 
                    estado_atual <= IDLE; 
                end
            endcase
        end
    end
endmodule
