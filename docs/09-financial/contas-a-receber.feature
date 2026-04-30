# language: pt

Funcionalidade: Contas a receber (CAR)
  CARs são gerados automaticamente quando uma invoice é emitida — nunca
  criados manualmente. Cada CAR é uma parcela da invoice, com vencimento
  calculado pelo payment_term. Pagamentos são registrados em eventos
  separados; o CAR caminha pending → partial → paid.

  Contexto:
    Dado a loja "Padaria do Cesar LTDA"
    E o customer "Restaurante Sabor"

  Cenário: Invoice emitida gera CARs por parcela
    Dado uma invoice emitida em 2026-04-23 no valor de R$ 1.000,00
    E o pedido usava payment_term "30/60" (50/50)
    Quando o sistema gera os CARs
    Então existem 2 CARs:
      | installment | due_date   | amount    | status  | paid_amount |
      | 1 de 2      | 2026-05-23 | R$ 500,00 | pending | R$ 0,00     |
      | 2 de 2      | 2026-06-22 | R$ 500,00 | pending | R$ 0,00     |

  Cenário: Registrar pagamento parcial
    Dado um CAR em "pending" com amount R$ 500,00
    Quando Cesar registra um car_payment de R$ 200,00 via PIX em 2026-05-10
    Então o paid_amount do CAR passa a ser R$ 200,00
    E o status do CAR passa para "partial"

  Cenário: Registrar pagamento que completa o valor
    Dado um CAR em "partial" com amount R$ 500,00 e paid_amount R$ 200,00
    Quando Cesar registra um car_payment de R$ 300,00 via boleto em 2026-05-20
    Então o paid_amount do CAR passa a ser R$ 500,00
    E o status do CAR passa para "paid"

  Cenário: Múltiplos pagamentos em métodos diferentes
    Dado um CAR de R$ 600,00
    Quando são registrados:
      | Amount     | Método        |
      | R$ 200,00  | cash          |
      | R$ 250,00  | credit_card   |
      | R$ 150,00  | bank_transfer |
    Então o CAR fica como "paid" com paid_amount R$ 600,00

  Cenário: "Overdue" é condição derivada, não status
    Dado um CAR "pending" com due_date 2026-04-15 e hoje é 2026-04-23
    Quando Cesar consulta os CARs
    Então o CAR aparece na categoria "vencido"
    Mas o status persistido continua sendo "pending"
    # overdue = status IN (pending, partial) AND due_date < hoje

  Cenário: CARs de invoice cancelada viram cancelled
    Dado uma invoice com 2 CARs "pending"
    Quando a invoice é cancelada
    Então os 2 CARs passam para "cancelled"
    E o fluxo de caixa projetado para o futuro perde esses valores

  Cenário: CAR paid dispara o cálculo de comissão
    Dado um CAR que acabou de atingir "paid"
    Quando o sistema processa o evento
    Então um Bill de comissão é gerado (ver feature de cálculo de comissão)

  Cenário: Não é possível criar CAR manualmente
    Quando um usuário tenta criar um CAR direto, sem uma invoice
    Então a operação é rejeitada
    # CARs sempre nascem de invoice emitida

  Cenário: Recebimento em excesso vira extra_amount
    Dado um CAR "pending" com amount R$ 500,00
    Quando Cesar registra um car_payment de R$ 520,00 via PIX (cliente pagou juros)
    Então o paid_amount do CAR fica em R$ 520,00
    E o extra_amount do CAR fica em R$ 20,00
    E o status do CAR vai para "paid"

  Cenário: Recebimento parcial seguido de excesso
    Dado um CAR "pending" com amount R$ 500,00
    Quando Cesar registra um car_payment de R$ 200,00 (parcial)
    Então o status passa para "partial" e paid_amount é R$ 200,00
    Quando Cesar registra um car_payment de R$ 350,00 (cobre o resto + R$ 50 de multa)
    Então o paid_amount fica em R$ 550,00
    E o extra_amount fica em R$ 50,00
    E o status passa para "paid"

  Cenário: Excedente entra no fluxo de caixa realizado
    Dado um CAR pago com paid_amount R$ 520,00 (amount R$ 500,00, extra R$ 20,00)
    Quando Cesar consulta o fluxo realizado do dia do pagamento
    Então a entrada do dia é R$ 520,00 (não R$ 500,00)

  Cenário: Cancelar um car_payment registrado por engano
    Dado um CAR de R$ 500,00 com paid_amount R$ 500,00 e status "paid"
    E o car_payment "P1" de R$ 500,00 foi registrado com método "PIX"
    Quando Cesar cancela o car_payment "P1" com motivo "Lançamento duplicado"
    Então o car_payment "P1" passa para status "cancelled"
    E o paid_amount do CAR recalcula para R$ 0,00
    E o status do CAR volta para "pending"
    E o motivo é registrado em notes do car_payment
    # estorno via cancelamento — car_payment não é editável nem deletável

  Cenário: Cancelar pagamento que estava parcial
    Dado um CAR com amount R$ 500,00, dois car_payments efetivos:
      | id | amount    | status    |
      | P1 | R$ 200,00 | effective |
      | P2 | R$ 300,00 | effective |
    E o status do CAR é "paid"
    Quando Cesar cancela o car_payment "P2"
    Então o paid_amount do CAR recalcula para R$ 200,00
    E o status do CAR volta para "partial"

  Cenário: car_payment cancelado não conta no fluxo de caixa realizado
    Dado um car_payment "effective" de R$ 500,00 em 2026-04-10
    Quando Cesar cancela o car_payment em 2026-04-15
    Então o fluxo realizado do dia 2026-04-10 não inclui mais esses R$ 500,00
    E nenhum lançamento aparece em 2026-04-15 (cancelamento não cria entrada)

  Cenário: Comissão já gerada por CAR pago não é revertida automaticamente ao cancelar pagamento
    Dado um CAR que ficou "paid" e gerou um Bill de comissão de R$ 25,00
    Quando Cesar cancela o car_payment que levou o CAR a "paid"
    Então o status do CAR volta para "partial" ou "pending"
    Mas o Bill de comissão permanece como está (imutável)
    E para reverter, admin precisa criar Bill manual de ajuste negativo
    # reversão automática de comissão fica fora do MVP — ver Financial → B22
