# language: pt

Funcionalidade: Alterar o kit_price_mode de um kit existente
  Trocar o modo de preço de um kit tem efeitos colaterais em price_list_item.
  O sistema força as regras na camada de serviço para evitar dados órfãos ou
  kits bloqueados em vendas.

  Contexto:
    Dado a organization "Padaria do Cesar LTDA"
    E a tabela de preço default "Varejo"
    E o kit "Café da Manhã Completo" com componentes já cadastrados

  Cenário: Mudar para "fixed" exige preço do SKU do kit na tabela default
    Dado que o kit está no modo "sum"
    Quando Cesar tenta mudar o modo para "fixed" sem informar o preço do SKU do kit na "Varejo"
    Então a alteração é rejeitada com a mensagem "Informe o preço do kit na tabela de preço default"

    Quando Cesar muda o modo para "fixed" informando preço R$ 19,90 na "Varejo"
    Então a alteração é aceita
    E o SKU do kit passa a ter preço R$ 19,90 na tabela "Varejo"

  Cenário: Mudar de "fixed" para "sum" limpa os preços do SKU do kit
    Dado que o kit está no modo "fixed" com preços cadastrados:
      | Tabela  | Preço (R$) |
      | Varejo  | 19,90      |
      | Atacado | 15,00      |
    Quando Cesar muda o modo para "sum"
    Então os preços do SKU do kit nas tabelas "Varejo" e "Atacado" são removidos
    E novos pedidos passam a calcular o kit pela soma dos componentes

  Cenário: Mudar de "fixed" para "discount" limpa os preços do SKU do kit
    Dado que o kit está no modo "fixed" com preço R$ 19,90 na "Varejo"
    Quando Cesar muda o modo para "discount" com 10% de desconto
    Então o preço do SKU do kit na "Varejo" é removido
    E novos pedidos passam a calcular o kit com desconto sobre a soma dos componentes

  Cenário: Mudar entre "sum" e "discount" ajusta apenas o desconto
    Dado que o kit está no modo "sum"
    Quando Cesar muda o modo para "discount" com 5% de desconto
    Então a alteração é aceita sem precisar mexer em nenhuma tabela de preço
    E o kit passa a aplicar 5% de desconto sobre a soma dos componentes
