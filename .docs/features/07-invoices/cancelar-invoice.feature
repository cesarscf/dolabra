# language: pt

Funcionalidade: Cancelar uma invoice
  Uma invoice emitida pode ser cancelada. O cancelamento reverte o estoque
  com um movimento "adjustment_in" (para não poluir o histórico de compras)
  e cancela os CARs ainda em aberto. CARs já pagos permanecem — e Bills de
  comissão deles também (dinheiro entrou, comissão é devida).

  Contexto:
    Dado a organization "Padaria do Cesar LTDA"
    E uma invoice "INV-000010" em status "issued" com:
      | SKU     | Qty faturada | Custo no movimento "out" |
      | PAO-UN  | 100          | R$ 0,30                  |
    E 2 CARs gerados pela invoice:
      | installment | status  | paid_amount |
      | 1 de 2      | paid    | R$ 64,50    |
      | 2 de 2      | pending | R$ 0,00     |

  Cenário: Reversão de estoque usa adjustment_in com custo original
    Quando Cesar cancela a invoice
    Então um movimento "adjustment_in" é gerado para PAO-UN com quantidade 100
    E o unit_cost do movimento é R$ 0,30 (igual ao do "out" original)
    E o reference_type é "invoice_cancellation"
    E o reference_id aponta para a invoice cancelada
    E o custo médio do SKU NÃO é recalculado

  Cenário: CARs pendentes viram cancelled
    Quando Cesar cancela a invoice
    Então o CAR "2 de 2" (pending) passa para "cancelled"
    Mas o CAR "1 de 2" (paid) permanece como "paid"

  Cenário: Bills de comissão de CARs já pagos permanecem
    Dado que o CAR "1 de 2" paid já disparou um Bill de comissão para o seller
    Quando Cesar cancela a invoice
    Então o Bill de comissão continua válido e devido ao seller
    E nenhum Bill de comissão é gerado para o CAR cancelled

  Cenário: Invoice cancelada é imutável
    Dado uma invoice em "cancelled"
    Quando Cesar tenta editar qualquer campo
    Então a operação é rejeitada

  Cenário: Pedido volta a poder ser faturado no saldo não faturado?
    Dado um pedido com faturamento parcial
    E uma das invoices parciais foi cancelada
    Quando Cesar prepara uma nova invoice para o pedido
    Então o saldo de "quantidade faturada" por item volta a refletir apenas invoices não canceladas
    # ou seja, o cancelamento "libera" as quantidades daquela invoice para serem faturadas de novo
