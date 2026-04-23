# language: pt

Funcionalidade: Movimentos de estoque
  Toda variação de saldo é registrada como um movimento imutável. O tipo do
  movimento determina a direção (soma ou subtrai) e o efeito sobre o custo
  médio. Movimentos nunca são editados nem apagados — correções acontecem
  criando novos movimentos.

  Contexto:
    Dado a organization "Padaria do Cesar LTDA"
    E o SKU "PAO-UN" com saldo 50 unidades e custo médio R$ 0,30

  Esquema do Cenário: Direção e efeito por tipo de movimento
    Quando um movimento do tipo "<tipo>" é registrado para "PAO-UN" com quantidade 10
    Então o saldo de "PAO-UN" passa a ser "<saldo_final>"
    E o custo médio "<efeito_custo>"

    Exemplos:
      | tipo           | saldo_final | efeito_custo         |
      | in             | 60          | é recalculado        |
      | out            | 40          | permanece R$ 0,30    |
      | adjustment_in  | 60          | permanece R$ 0,30    |
      | adjustment_out | 40          | permanece R$ 0,30    |

  Cenário: "in" é reservado para recebimentos de compra
    Quando um purchase_receipt confirmado processa a entrada de 10 unidades de "PAO-UN" a R$ 0,40 cada
    Então um movimento do tipo "in" é gerado
    E o "reference_type" do movimento é "purchase_receipt"
    E o custo médio é recalculado

  Cenário: "out" é reservado para emissão de invoice
    Quando uma invoice é emitida contendo 5 unidades de "PAO-UN"
    Então um movimento do tipo "out" é gerado por SKU
    E o "reference_type" do movimento é "sales_invoice"

  Cenário: "adjustment_in" no cancelamento de invoice
    Dado que uma invoice foi emitida e gerou um movimento "out" de 5 unidades com custo R$ 0,30
    Quando a invoice é cancelada
    Então um movimento "adjustment_in" é gerado com quantidade 5 e custo R$ 0,30
    E o "reference_type" do movimento é "invoice_cancellation"
    E o custo médio do SKU NÃO é recalculado

  Cenário: Ajustes manuais exigem nota
    Quando Cesar registra manualmente um "adjustment_out" de 3 unidades com nota "quebra identificada"
    Então o movimento é persistido com a nota
    E o saldo cai em 3 unidades

  Cenário: Quantidade do movimento é sempre positiva
    Quando o sistema cria qualquer movimento de estoque
    Então a quantidade é sempre um número positivo
    E a direção (entra/sai) é derivada exclusivamente do tipo do movimento

  Cenário: Movimentos são imutáveis
    Dado um movimento "in" de 10 unidades a R$ 0,40
    Quando Cesar tenta editar o movimento
    Então a operação é rejeitada
    E a única forma de corrigir é criar um movimento compensatório
