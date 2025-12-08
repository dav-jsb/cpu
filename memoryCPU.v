module memoryCPU (
    input [3:0] entrada1, 
    input [2:0] OPcoDE,   
    input [4:0] imediato, 
    input reset,          
    input clock,         
    
    // Portas de Saída
    output reg [15:0] valorSaidaA // Valor lido de register[entrada1]
);

    //A memoria sera sempre utilizada retornando apenas 1 valor de 1 registrador, 
	 //por isso esse modulo sempre será chamado mais de uma vez dependendo da entrada OpCOde
	 
    reg [15:0] register [0:15]; //Definição da matriz dos registradores (memória), de R0 até R15. É uma matriz de 16 linhas e que armazena 16 bits

    parameter [2:0] 
        LOAD    = 3'b000, 
        CLEAR   = 3'b110, 
        DISPLAY = 3'b111; 
		  
    parameter [3:0]
        R0  = 4'b0000, R1  = 4'b0001, R2  = 4'b0010, R3  = 4'b0011,
        R4  = 4'b0100, R5  = 4'b0101, R6  = 4'b0110, R7  = 4'b0111,
        R8  = 4'b1000, R9  = 4'b1001, R10 = 4'b1010, R11 = 4'b1011,
        R12 = 4'b1100, R13 = 4'b1101, R14 = 4'b1110, R15 = 4'b1111;
    
    integer i;

    always @ (posedge clock or posedge reset) 
    begin
        if (reset == 1'b1 || OPcoDE == CLEAR) begin
            for (i = 0; i < 16; i = i + 1) begin
                register[i] <= 16'd0;
            end
        end
        
        else begin
            case(OPcoDE)
                LOAD: begin
                    register[entrada1] <= {11'b0, imediato}; 
                end
               
                default: begin end
            endcase
        end
    end
	 
	 always @ (*) begin
	 
    valorSaidaA = register[entrada1];
	 
	 end

endmodule