# language: pt

Funcionalidade: Cálculo do custo médio ponderado móvel
  Toda entrada de estoque (movimento "in") recalcula o custo médio do SKU
  usando a fórmula clássica de média ponderada móvel. Saídas e ajustes
  NÃO alteram o custo médio — apenas consomem o valor vigente.

  Contexto:
    Dado a loja "Padaria do Cesar LTDA"
    E o SKU "PAO-UN" do produto "Pão Francês"

  Cenário: Primeira entrada estabelece o custo
    Dado que "PAO-UN" nunca teve movimento
    Quando um movimento "in" de 100 unidades a R$ 0,30 é processado
    Então o saldo fica em 100 unidades
    E o custo médio fica em R$ 0,30

  Cenário: Entradas subsequentes aplicam a média ponderada
    Dado que "PAO-UN" tem saldo 100 e custo médio R$ 0,30
    Quando um movimento "in" de 50 unidades a R$ 0,42 é processado
    Então o saldo fica em 150 unidades
    E o custo médio fica em R$ 0,34
    # (100 × 0,30 + 50 × 0,42) / 150 = 0,34

  Cenário: Saída não altera o custo médio
    Dado que "PAO-UN" tem saldo 150 e custo médio R$ 0,34
    Quando um movimento "out" de 30 unidades é processado
    Então o saldo cai para 120 unidades
    E o custo médio permanece em R$ 0,34

  Cenário: Ajuste não altera o custo médio
    Dado que "PAO-UN" tem saldo 120 e custo médio R$ 0,34
    Quando um movimento "adjustment_in" de 5 unidades é processado (correção de contagem)
    Então o saldo sobe para 125 unidades
    E o custo médio permanece em R$ 0,34

  Cenário: Entrada com custo incluindo rateio de despesas acessórias
    Dado que "PAO-UN" tem saldo 0
    E um purchase_receipt traz 100 unidades a R$ 0,40 de custo unitário
    E R$ 10,00 de frete são rateados para essas 100 unidades
    Quando o movimento "in" é processado
    Então o custo unitário efetivo usado no cálculo é R$ 0,50
    # 0,40 + (10,00 / 100)
    E o custo médio passa a ser R$ 0,50

  Cenário: Cancelamento de invoice preserva custo histórico
    Dado que "PAO-UN" tem saldo 50 e custo médio R$ 0,34
    E uma invoice foi emitida baixando 10 unidades com movimento "out" a custo R$ 0,34
    Quando a invoice é cancelada
    Então o movimento "adjustment_in" usa o mesmo custo R$ 0,34 do "out" original
    E o custo médio continua em R$ 0,34 (não é recalculado)
