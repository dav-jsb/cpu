module memoryCPU (
    input clock,
    input reset, // LIGAR/DESLIGAR
    
    // Controle de Escrita
    input regWrite,              // Sinal de controle: 1 para escrever, 0 para ler
    input [3:0] write_reg_addr,  // Onde escrever (Destino D1) [cite: 297]
    input [15:0] write_data,     // O dado a ser escrito (Vem do Mux: Imediato ou ULA)
    
    // Controle de Leitura (Para a ULA acessar 2 regs simultaneamente)
    input [3:0] read_reg_addr_1, 
    input [3:0] read_reg_addr_2, 
    
    // Saídas
    output [15:0] read_data_1,   // Valor do Registrador 1
    output [15:0] read_data_2    // Valor do Registrador 2
);

    reg [15:0] register [0:15]; // Matriz 16x16 bits -> MEMORIA
    integer i;

    // Escrita Síncrona (Na borda do clock)
    always @ (posedge clock or negedge reset) begin // transição do clock sempre de subida e do reset sempre que for de descida
        if (reset) begin
            for (i = 0; i < 16; i = i + 1) begin
                register[i] <= 16'd0;
            end
        end
        else if (regWrite) begin
            register[write_reg_addr] <= write_data;
        end
    end

    assign read_data_1 = register[read_reg_addr_1];
    assign read_data_2 = register[read_reg_addr_2];


endmodule
