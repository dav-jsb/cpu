module lcd_init_hd44780 (
    input  wire       clk,
    input  wire       rst,    // Reset ativo alto
    input  wire       start,
    output reg        done,
    output reg  [7:0] lcd_data,
    output reg        lcd_rs,
    output reg        lcd_rw,
    output reg        lcd_e
);

    // Comandos de inicialização
    localparam [7:0] CMD_FUNCTION_SET  = 8'h38; // 8 bits, 2 linhas, 5x8
    localparam [7:0] CMD_DISPLAY_ON    = 8'h0C; // Display ON, Cursor OFF
    localparam [7:0] CMD_CLEAR_DISPLAY = 8'h01; // Limpa tudo
    localparam [7:0] CMD_ENTRY_MODE    = 8'h06; // Incrementa cursor

    reg [2:0] state;
    localparam S_IDLE       = 3'd0;
    localparam S_SETUP      = 3'd1;
    localparam S_PULSE      = 3'd2;
    localparam S_WAIT       = 3'd3;

    // ROM de Comandos
    reg [7:0] cmd_rom [0:3];
    initial begin
        cmd_rom[0] = CMD_FUNCTION_SET;
        cmd_rom[1] = CMD_DISPLAY_ON;
        cmd_rom[2] = CMD_CLEAR_DISPLAY;
        cmd_rom[3] = CMD_ENTRY_MODE;
    end

    reg [2:0] cmd_idx;
    reg [7:0] current_cmd;
    reg [20:0] counter; // Contador de delay

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= S_IDLE;
            done <= 0;
            cmd_idx <= 0;
            counter <= 0;
        end else begin
            case (state)
                S_IDLE: begin
                    done <= 0;
                    if (start) begin
                        cmd_idx <= 0;
                        state <= S_SETUP;
                    end
                end

                S_SETUP: begin
                    // Prepara o dado no barramento antes de subir o Enable
                    if (counter < 5) 
                        counter <= counter + 1;
                    else begin
                        counter <= 0;
                        state <= S_PULSE;
                    end
                end

                S_PULSE: begin
                    // Pulso de Enable deve durar um pouco
                    if (counter < 50) begin // ~1us @ 50MHz
                        counter <= counter + 1;
                    end else begin
                        counter <= 0;
                        state <= S_WAIT;
                    end
                end

                S_WAIT: begin
                    // Espera o LCD processar o comando
                    // Clear Display (idx 2) precisa de ~1.52ms => ~76000 clocks
                    // Outros precisam de ~37us => ~2000 clocks
                    reg [20:0] delay_limit;
                    delay_limit = (cmd_idx == 2) ? 100000 : 3000;

                    if (counter < delay_limit) begin
                        counter <= counter + 1;
                    end else begin
                        counter <= 0;
                        if (cmd_idx < 3) begin
                            cmd_idx <= cmd_idx + 1;
                            state <= S_SETUP;
                        end else begin
                            done <= 1; // Terminou tudo
                            state <= S_IDLE;
                        end
                    end
                end
            endcase
        end
    end

    // Saídas Combinacionais
    always @(*) begin
        lcd_rs = 0; // Sempre comando na inicialização
        lcd_rw = 0;
        lcd_data = cmd_rom[cmd_idx];
        
        if (state == S_PULSE) lcd_e = 1;
        else lcd_e = 0;
        
        if (state == S_IDLE && done == 1) lcd_e = 0; // Garante desligado no fim
    end

endmodule