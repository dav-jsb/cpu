module memoryCPU (
    input clock,
    input reset,
    
    // Controle de Escrita
    input regWrite,              // Sinal de controle: 1 para escrever, 0 para ler
    input [3:0] write_reg_addr,  // Onde escrever (Destino D1) [cite: 297]
    input [15:0] write_data,     // O dado a ser escrito (Vem do Mux: Imediato ou ULA)
    
    // Controle de Leitura (Para a ULA acessar 2 regs simultaneamente)
    input [3:0] read_reg_addr_1, // Fonte 1 (O1) [cite: 297]
    input [3:0] read_reg_addr_2, // Fonte 2 (O2) [cite: 297]
    
    // Saídas
    output [15:0] read_data_1,   // Valor do Registrador 1
    output [15:0] read_data_2    // Valor do Registrador 2
);

    reg [15:0] register [0:15]; // Matriz 16x16 bits [cite: 377]
    integer i;

    // Escrita Síncrona (Na borda do clock)
    always @ (posedge clock or posedge reset) begin
        if (reset) begin
            // Zera tudo no reset ou instrução CLEAR (tratada externamente como reset ou write de 0s)
            // [cite: 204, 326]
            for (i = 0; i < 16; i = i + 1) begin
                register[i] <= 16'd0;
            end
        end
        else if (regWrite) begin
            // Escreve o dado (seja load ou resultado de ALU) no registrador de destino
            // IMPORTANTE: O registrador R0 geralmente é constante 0 em algumas arquiteturas,
            // mas o PDF do projeto não proíbe escrita em R0, então mantemos genérico.
            register[write_reg_addr] <= write_data;
        end
    end

    // Leitura Assíncrona (Combinacional)
    // Permite que a ULA receba os dados assim que os endereços mudam
    assign read_data_1 = register[read_reg_addr_1];
    assign read_data_2 = register[read_reg_addr_2];

endmodule