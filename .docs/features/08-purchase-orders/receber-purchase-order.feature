# language: pt

Funcionalidade: Recebimento de pedido de compra
  Recebimentos são parciais por natureza — o supplier pode mandar em várias
  remessas. Cada recebimento registra o que chegou, gera movimentos de
  entrada no estoque e atualiza o custo médio. Quando todos os itens
  atingem a quantidade pedida, o pedido vira "received".

  Contexto:
    Dado a organization "Padaria do Cesar LTDA"
    E um pedido de compra "PO-000001" em status "confirmed" com:
      | SKU          | Qty pedida | Unit cost |
      | FARINHA-25KG | 20         | R$ 90,00  |
      | ACUCAR-5KG   | 40         | R$ 12,00  |
    E todos os SKUs com saldo atual zero e sem custo histórico

  Cenário: Recebimento parcial entra no estoque e move status
    Quando o supplier entrega 10 unidades de FARINHA-25KG
    E Cesar registra um receipt com qty 10 de FARINHA-25KG (sem despesas acessórias neste exemplo)
    Então um movimento "in" é gerado para FARINHA-25KG com qty 10 e unit_cost R$ 90,00
    E o saldo de FARINHA-25KG passa a ser 10
    E o custo médio de FARINHA-25KG passa a ser R$ 90,00
    E o pedido de compra passa para "partially_received"
    E received_quantity do item fica em 10 (de 20)

  Cenário: Recebimentos subsequentes fecham o pedido
    Dado um pedido em "partially_received" com FARINHA-25KG received_quantity 10 de 20 e ACUCAR-5KG 0 de 40
    Quando Cesar registra um segundo receipt com:
      | SKU          | Qty |
      | FARINHA-25KG | 10  |
      | ACUCAR-5KG   | 40  |
    Então received_quantity de FARINHA-25KG vira 20 (completo)
    E received_quantity de ACUCAR-5KG vira 40 (completo)
    E o pedido de compra passa para "received"

  Cenário: Não é possível receber mais do que foi pedido
    Dado received_quantity de FARINHA-25KG em 20 (completo)
    Quando Cesar tenta registrar um receipt adicional de 5 unidades de FARINHA-25KG
    Então a operação é rejeitada com a mensagem "Quantidade recebida excede a quantidade pedida"

  Cenário: Recebimento atualiza custo médio via fórmula ponderada
    Dado que FARINHA-25KG já tem saldo 10 e custo médio R$ 90,00
    Quando um novo receipt registra qty 10 a unit_cost efetivo R$ 100,00
    Então o custo médio passa a ser R$ 95,00
    # (10 × 90 + 10 × 100) / 20 = 95
