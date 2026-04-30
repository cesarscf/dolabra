# language: pt

Funcionalidade: Criar um pedido de venda
  Um pedido de venda registra a intenção de vender para um customer. Ele
  reúne itens, seller responsável, condição de pagamento e tabela de preço.
  Os totais são derivados dos itens.

  Contexto:
    Dado a organization "Padaria do Cesar LTDA"
    E o customer "Restaurante Sabor" com default_seller "Ana", default_price_list "Atacado" e default_payment_term "30/60"
    E o SKU "PAO-UN" com preço R$ 0,75 na tabela "Atacado"
    E o SKU "CAF-250G" com preço R$ 12,00 na tabela "Atacado"

  Cenário: Criar pedido com defaults herdados do customer
    Quando Cesar inicia um novo pedido para "Restaurante Sabor"
    Então o pedido vem pré-preenchido com:
      | Campo                | Valor    |
      | Seller               | Ana      |
      | Tabela de preço      | Atacado  |
      | Condição de pagamento| 30/60    |
    E Cesar pode trocar qualquer um desses valores antes de salvar

  Cenário: Adicionar itens ao pedido
    Dado um novo pedido para "Restaurante Sabor" na tabela "Atacado"
    Quando Cesar adiciona os itens:
      | SKU       | Quantidade | Desconto de item (%) |
      | PAO-UN    | 100        | 0                    |
      | CAF-250G  | 5          | 10                   |
    Então os totais são calculados:
      | Item       | Unit price | Qty | Discount | Total   |
      | PAO-UN     | 0,75       | 100 | 0        | 75,00   |
      | CAF-250G   | 12,00      | 5   | 6,00     | 54,00   |
    E o subtotal do pedido é R$ 129,00

  Cenário: Aplicar desconto no pedido todo
    Dado um pedido com subtotal R$ 129,00
    Quando Cesar aplica um desconto de pedido de R$ 9,00
    Então o total do pedido é R$ 120,00

  Cenário: Pedido recebe número sequencial
    Dado que 3 pedidos já foram criados na organization
    Quando Cesar cria mais um pedido e salva
    Então o número gerado é "SO-000004"

  Cenário: Pedido exige customer com type incluindo "customer"
    Dado o contact "Fornecedor X" do tipo "supplier"
    Quando Cesar tenta criar um pedido de venda para "Fornecedor X"
    Então a operação é rejeitada com a mensagem "Contact não é customer"

  Cenário: Pedido exige payment_term
    Quando Cesar tenta salvar um pedido sem informar payment_term
    Então a operação é rejeitada com a mensagem "Condição de pagamento é obrigatória"

  Cenário: SKU inativo não pode ser adicionado a um pedido
    Dado o produto "Pão Antigo" com status "inactive"
    Quando Cesar tenta adicionar o SKU de "Pão Antigo" a um novo pedido
    Então a operação é rejeitada com a mensagem "SKU não está disponível para venda"

  Cenário: SKU arquivado não pode ser adicionado a um pedido
    Dado o produto "Pão Descontinuado" com status "archived"
    Quando Cesar tenta adicionar o SKU de "Pão Descontinuado" a um novo pedido
    Então a operação é rejeitada com a mensagem "SKU não está disponível para venda"

  Cenário: Inativar SKU não cancela itens já adicionados
    Dado um pedido em "draft" contendo o SKU "PAO-UN" do produto "Pão Francês" (active)
    Quando o produto "Pão Francês" é mudado para "inactive"
    Então o item permanece no pedido sem alteração
    E o pedido segue o fluxo normal (pode ser confirmado, faturado etc.)
    Mas tentar adicionar mais um item do mesmo SKU é rejeitado
