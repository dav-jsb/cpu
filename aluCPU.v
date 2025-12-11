module aluCPU(
    input [15:0] data1, //primeiro valor lido
    input [15:0] data2, //segundo valor lido
    input [1:0] sel, //seleçao diferente de OPCODE -> apenas tratamos SUB, ADD e MUL, sem verificar se é ou nao com imediato AQUI
    output reg [15:0] result
); 
    parameter [1:0] 
        SUM = 2'b00,
        SUB = 2'b01,
        MUL = 2'b10;
    
    reg [31:0] mul_full; //fez-se necessario add esse reg para tratar overflow na multiplicação e não quebrar o sistema

    always @(*) begin
        case(sel)
            SUM: begin
                result = data1 + data2;
            end
            SUB: begin
                result = data1 - data2;
            end
            MUL: begin
                mul_full = $signed(data1) * $signed(data2); //executa a multiplicação, mas com o $ para tratar valores com sinal
                result = mul_full[15:0]; //iguala no reg de 16 bits o valor da multiplicação
            end
            default: result = 16'd0; //boa prática definir o valor 0 como default
        endcase 
    end 
endmodule 

