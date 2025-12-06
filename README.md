# Arquitetura do sistema
Sempre que *criarem* ou *alterarem* um módulo, mudem aqui:

-> Explicação dos módulos

*AQUI*

Sempre que forem fazer alguma alteração, como estamos trabalhando em Quartus, precisamos sempre dar download em zip; após isso,
crie uma branch com o nome da alteração que está fazendo (Ex. branch mudando_modulo_somador). Após verificar a funcionalidade,
é preciso adicionar diretamente na branch nova e em seguida dar merge

# Funcionamento do Switch

Tava bem confuso, então eu pensei em fazermos dessa forma: o OP Code, que são os 3 bits de instrução, devem estar sempre na entrada
nos bits [17:15], para estruturar bem. A gente pode fazer uma leitura incial nele e para então direcionar à leitura dos demais bits.
Dentre as operações que estão sendo pedidas, tem ADD, ADDI (adição do valor de um registrador com o valor que recebeu naquele momento),
SUB, SUBI(mesma coisa de ADDI,mas subtraindo), e MUL(mulitplicação do valor de um registrador com o valor que recebeu no momento). Essas
operações estão listadas no OP CODE de 001 até 101; LOAD (000) pega o um valor e joga em um registrador de destino, CLEAR (110) limpa o 
valor de todos os registradores e DISPLAY (111) armazena o valor que está no registrador que entra no switch


# Divisão de tarefas:
Arthur: Como a Unidade de Controle opera ( parece que é uma FSM, mas a gente tem que ver claramente o que é)

Davi José: Como o LCD opera (olhar datasheet e as explicações de Abel na descrição do projeto)

Davi Lima: Funcionamento da Memória (como integrar a memória ao sistema pra poder armazenar os dados que estão sendo contabilizados)

Gabriel: Pensar como fazer a ULA em verilog baseado nas especificações que Abel colocou(ver quais módulos criar)

Matheus: Pensar arquitetura do sistema (como ele vai se comunicar internamente) 
