# Arquitetura do sistema

-> Explicação dos módulos

Module: Memory 

A Memória atua de forma "Burra", ou seja, apenas lê ou escreve informações nela, sem necessariamente saber o que está acontecendo
Para isso, há um botão Enable de input que ativa a escrita conforme a entrada de dados no switch, mas toda essa interpretação não
é feita neste módulo.

Module: ALU

Também é um módulo simples e burro. Ele é composto apenas por operações e retorna um valor para a Unidade de Controle. Esse valor
pode vir de uma soma, multiplicação ou subtração. Tratando de imediatos ou de busca em registradores, novamente, são tarefas delegadas
à Unidade de Controle, sem atuação direta neste módulo.

# Funcionamento do Switch

Tava bem confuso, então eu pensei em fazermos dessa forma: o OP Code, que são os 3 bits de instrução, devem estar sempre na entrada
nos bits [17:15], para estruturar bem. A gente pode fazer uma leitura incial nele e para então direcionar à leitura dos demais bits.
Dentre as operações que estão sendo pedidas, tem ADD, ADDI (adição do valor de um registrador com o valor que recebeu naquele momento),
SUB, SUBI(mesma coisa de ADDI,mas subtraindo), e MUL(mulitplicação do valor de um registrador com o valor que recebeu no momento). Essas
operações estão listadas no OP CODE de 001 até 101; LOAD (000) pega o um valor e joga em um registrador de destino, CLEAR (110) limpa o 
valor de todos os registradores e DISPLAY (111) armazena o valor que está no registrador que entra no switch
