module miniCPU (
	input [17:0] switches,
	input ligar,
	input enviar,
	input clk,
);

	reg [2:0] Opcode = switches[17:15];
	reg [3:0] register1 = switches[14:11];
	reg [3:0] register2 = switches[10:7];
	reg [3:0] register3 = switches[6:3];
	reg signal = switches[6];
	reg [5:0] = imediato[5:0];
	
	wire [15:0] write_data1, write_data2, write_alu;
	
	parameter [2:0] LOAD = 3'b000, ADD = 3'b001, ADDI = 3'b010, SUB = 3'b011, 
		             SUBI = 3'b100, MUL = 3'b101, CLEAR = 3'b110, DISPLAY = 3'b111;
						 
	always @(negedge enviar) begin
		case (Opcode)
			LOAD: begin
				
			end
			
			ADD: begin
			
			end
			
			ADDI: begin
			
			end
			
			SUB: begin
			
			end
			
			SUBI: begin
			
			end
			
			MUL: begin
			
			end
			
			CLEAR: begin
			
			end
			
			DISPLAY: begin
			
			end
		endcase
	end
	
	always @(negedge clk or negedge ligar) begin
		case (Opcode)
			LOAD: begin
			
			end
			
			ADD: begin
			
			end
			
			ADDI: begin
			
			end
			
			SUB: begin
			
			end
			
			SUBI: begin
			
			end
			
			MUL: begin
			
			end
			
			CLEAR: begin
			
			end
			
			DISPLAY: begin
			
			end
			
		endcase
	end

endmodule 