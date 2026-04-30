# language: pt

Funcionalidade: Confirmar um pedido de compra
  Confirmar um PO significa que ele foi efetivamente enviado ao supplier.
  A partir desse momento o pedido vira read-only e o financeiro a pagar
  (Bills) é gerado automaticamente, uma linha por parcela do payment_term.

  Contexto:
    Dado a organization "Padaria do Cesar LTDA"
    E um pedido de compra em "draft" com total R$ 2.480,00
    E payment_term "30/60/90" com 3 parcelas iguais de 33,33%/33,33%/33,34%

  Cenário: Confirmar gera Bills conforme payment_term
    Quando Cesar confirma o pedido em 2026-04-23
    Então o status do pedido vai para "confirmed"
    E confirmed_at é registrado
    E 3 Bills são criados com origin "purchase_order":
      | installment | due_date   | amount         |
      | 1 de 3      | 2026-05-23 | R$ 826,82      |
      | 2 de 3      | 2026-06-22 | R$ 826,82      |
      | 3 de 3      | 2026-07-22 | R$ 826,36      |
    E a soma dos Bills fecha exatamente em R$ 2.480,00
    # última parcela absorve o arredondamento — regra em docs/00-globais/arredondamento-monetario.feature

  Cenário: Pedido confirmed fica read-only
    Dado um pedido em "confirmed"
    Quando Cesar tenta editar itens, quantidades ou despesas
    Então a operação é rejeitada

  Cenário: À vista gera 1 único Bill com vencimento imediato
    Dado um payment_term "À vista" (1 parcela, 0 dias, 100%)
    Quando Cesar confirma o pedido em 2026-04-23
    Então 1 Bill é criado com due_date 2026-04-23 e amount igual ao total do pedido

  Cenário: Bill gerado aparece em contas a pagar
    Dado um pedido recém-confirmado
    Quando um usuário consulta as contas a pagar
    Então os Bills gerados aparecem com status "pending" e origin "purchase_order"

  Cenário: Re-confirmar PO já confirmed é rejeitado
    Dado um pedido em "confirmed"
    Quando Cesar tenta confirmar novamente
    Então a operação é rejeitada com a mensagem "Pedido já está confirmed"
    E nenhum Bill duplicado é gerado
    # idempotência: ver docs/00-globais/README.md → seção "Idempotência"

  Cenário: Confirmar PO em status diferente de draft é rejeitado
    Dado um pedido em "partially_received"
    Quando Cesar tenta confirmar
    Então a operação é rejeitada com a mensagem "Apenas pedidos em draft podem ser confirmados"
