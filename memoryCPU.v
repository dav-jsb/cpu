module memoryCPU (
    input clock,
    input reset, // LIGAR/DESLIGAR
    
    // Escrita
    input regWrite,              // Sinal de controle: 1 para escrever, 0 para ler
    input [3:0] write_reg_addr,  // Índice de registrador em que será escrito um valor 
    input [15:0] write_data,     //o valor que está sendo escrito, pode vir do imediato ou da saída da ULA
    
    // Leitura -> A ULA acessa dois índices de registradores paralelamente para poder manipular as operações
    input [3:0] read_reg_addr_1, 
    input [3:0] read_reg_addr_2, 
    
    // Saídas
    output [15:0] read_data_1,   // Valor do Registrador 1
    output [15:0] read_data_2    // Valor do Registrador 2
);

    reg [15:0] register [0:15]; // -> MEMORIA
    integer i;
	 
    always @ (posedge clock or negedge reset) begin // transição do clock sempre de subida e do reset sempre que for de descida
        if (~reset) begin
            for (i = 0; i < 16; i = i + 1) begin
                register[i] <= 16'd0;
            end
        end
        else if (regWrite) begin  // Se for uma operação de escrita, ele irá escrever no registrador de indice recebido
            register[write_reg_addr] <= write_data;
        end
    end
	 
	 //Sempre sai um valor de leitura para algum local, mas só será usado essa valor da forma esperada conforme o OPcode que tenha a necessidade de ler algum valor de reg na memoria para usá-lo
    assign read_data_1 = register[read_reg_addr_1]; 
    assign read_data_2 = register[read_reg_addr_2];


endmodule

