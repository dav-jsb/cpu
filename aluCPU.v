module aluCPU(
    input [15:0] data1,
    input [15:0] data2,
    input [1:0] sel,
    output reg [15:0] result
); 
    
    parameter [1:0] 
        SUM = 2'b00,
        SUB = 2'b01,
        MUL = 2'b10;
    
    // Variável interna de 32 bits para evitar overflow silencioso
    reg [31:0] mul_full;

    always @(*) begin
        case(sel)
            SUM: begin
                result = data1 + data2;
            end
            
            SUB: begin
                result = data1 - data2;
            end
            
            MUL: begin
                // Ajuste para Suporte a Sinal (Especificado no PDF Input Type 2)
                mul_full = $signed(data1) * $signed(data2);
                result = mul_full[15:0]; 
            end
            
            default: result = 16'd0;
            
        endcase 
    end 
endmodule 