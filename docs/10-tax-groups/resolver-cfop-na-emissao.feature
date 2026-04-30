# language: pt

Funcionalidade: Resolução de CFOP no momento da emissão
  Cada tax_group tem dois CFOPs: um para operações dentro do estado do
  vendedor e outro para operações interestaduais. Na emissão da invoice,
  o sistema compara o estado da loja com o estado do customer e
  copia o CFOP correto para o snapshot do item.

  Contexto:
    Dado a loja "Padaria do Cesar LTDA" no estado "SP"
    E o tax_group "Alimento — padaria" com:
      | CFOP mesmo estado | 5102 |
      | CFOP outro estado | 6102 |
    E produtos associados ao tax_group

  Cenário: Customer no mesmo estado usa CFOP 5102
    Dado o customer "Restaurante Sabor" com endereço de billing em "SP"
    Quando uma invoice é emitida para o customer
    Então o CFOP copiado para cada item é "5102"

  Cenário: Customer em outro estado usa CFOP 6102
    Dado o customer "Pousada da Serra" com endereço de billing em "MG"
    Quando uma invoice é emitida para o customer
    Então o CFOP copiado para cada item é "6102"

  Cenário: Só o CFOP resolvido entra no snapshot
    Dado um customer em "SP"
    Quando a invoice é emitida
    Então o item copia "5102" como CFOP
    E o CFOP "6102" NÃO vai para o snapshot
    # a invoice guarda o CFOP aplicado, não os dois do template

  Cenário: Customer sem endereço de billing impede emissão
    Dado o customer "Cliente Incompleto" sem endereço de billing cadastrado
    Quando Cesar tenta emitir invoice para o customer
    Então a emissão é rejeitada com a mensagem "Customer precisa de endereço de billing para emissão fiscal"
