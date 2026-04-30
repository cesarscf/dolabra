# language: pt

Funcionalidade: Contas a pagar (Bills)
  Bills nascem de três origens:
  - purchase_order: automaticamente na confirmação do PO.
  - commission: automaticamente quando um CAR é paid.
  - manual: criados pelo usuário para despesas recorrentes (aluguel, contas
    de consumo) que não exigem PO.

  Contexto:
    Dado a loja "Padaria do Cesar LTDA"

  Cenário: Bill originário de purchase order aponta para supplier
    Dado um PO confirmado para o supplier "Moinho Central" de R$ 2.480,00 (3 parcelas)
    Quando os Bills são gerados
    Então cada Bill tem:
      | Campo        | Valor            |
      | origin       | purchase_order   |
      | supplier_id  | Moinho Central   |
      | seller_id    | (vazio)          |

  Cenário: Bill de comissão aponta para seller e não para supplier
    Dado um CAR que virou "paid" vinculado ao seller "Ana"
    Quando o Bill de comissão é gerado
    Então o Bill tem:
      | Campo        | Valor          |
      | origin       | commission     |
      | supplier_id  | (vazio)        |
      | seller_id    | Ana            |

  Cenário: Bill manual para aluguel
    Quando Cesar registra manualmente:
      | Campo        | Valor                              |
      | origin       | manual                             |
      | description  | Aluguel abril/2026                  |
      | supplier_id  | Imobiliária Central LTDA (contact) |
      | due_date     | 2026-04-30                         |
      | amount       | R$ 3.500,00                        |
      | category     | Aluguel (expense)                  |
    Então o Bill é criado em "pending"
    E aparece em contas a pagar

  Cenário: Bill manual exige description
    Quando Cesar tenta criar um Bill manual sem description
    Então a operação é rejeitada com a mensagem "Descrição é obrigatória para Bill manual"

  Cenário: Pagar um Bill
    Dado um Bill "pending" de R$ 3.500,00
    Quando Cesar registra um bill_payment de R$ 3.500,00 via "bank_transfer"
    Então o Bill passa para "paid"

  Cenário: Pagamento parcial de Bill
    Dado um Bill "pending" de R$ 1.000,00
    Quando Cesar registra um bill_payment de R$ 400,00
    Então o Bill passa para "partial"
    E paid_amount fica em R$ 400,00

  Cenário: "Overdue" é condição derivada em Bills também
    Dado um Bill "pending" com due_date no passado
    Quando Cesar consulta os Bills
    Então o Bill aparece como "vencido"
    Mas o status persistido continua "pending"

  Cenário: Cancelar PO cancela os Bills originários
    Dado 3 Bills originários de um PO, todos em "pending"
    Quando o PO é cancelado (sem recebimentos)
    Então os 3 Bills passam para "cancelled"

  Cenário: Bills de comissão são imutáveis (mesmo com invoice cancelada)
    Dado um Bill de comissão "pending" gerado a partir de um CAR paid
    Quando a invoice original é cancelada
    Então o Bill de comissão permanece como está (imutável)
    E reverter exige Bill de ajuste manual

  Cenário: Bill manual de ajuste com amount negativo (estorno de comissão)
    Dado um Bill de comissão de R$ 31,00 já paid para o seller "Ana"
    E a invoice originadora foi cancelada após o pagamento
    Quando Cesar (admin) cria um Bill manual de ajuste:
      | Campo       | Valor                                       |
      | origin      | manual                                      |
      | description | Estorno de comissão — INV-000010 cancelada  |
      | seller_id   | Ana                                         |
      | supplier_id | (vazio)                                     |
      | amount      | -31,00                                      |
      | category    | Comissões (expense)                         |
    Então o Bill é criado em "pending"
    E aparece em contas a pagar com saída negativa
    E quando o Bill for "paid", o fluxo realizado registra entrada de R$ 31,00 (saída negativa = entrada)
    # bills manuais aceitam amount negativo (ajustes); origin = purchase_order ou commission não aceita
    # ver Financial → B22

  Cenário: Bill com origin diferente de manual rejeita amount negativo
    Quando Cesar tenta criar um Bill com origin "purchase_order" e amount -100,00
    Então a operação é rejeitada com a mensagem "Amount negativo só é permitido em Bill manual"

  Cenário: Cancelar um bill_payment registrado por engano
    Dado um Bill de R$ 1.000,00 com paid_amount R$ 1.000,00 e status "paid"
    E o bill_payment "BP1" de R$ 1.000,00 foi registrado
    Quando Cesar cancela o bill_payment "BP1" com motivo "Pago em conta errada"
    Então o bill_payment "BP1" passa para status "cancelled"
    E o paid_amount do Bill recalcula para R$ 0,00
    E o status do Bill volta para "pending"
    # estorno via cancelamento — bill_payment não é editável nem deletável

  Cenário: Deletar Bill manual sem pagamentos é permitido
    Dado um Bill manual em "pending" sem nenhum bill_payment registrado
    Quando Cesar deleta o Bill
    Então o Bill é removido
    # convenção de delete em docs/00-globais/README.md

  Cenário: Deletar Bill com pagamentos é bloqueado
    Dado um Bill com bill_payment(s) registrado(s) — mesmo que cancelados
    Quando Cesar tenta deletar o Bill
    Então a operação é rejeitada com a mensagem "Bill com pagamentos não pode ser deletado — cancele os pagamentos e o Bill"

  Cenário: Cancelar Bill em pending
    Dado um Bill manual em "pending" sem pagamentos
    Quando Cesar cancela o Bill com motivo "Despesa duplicada"
    Então o Bill passa para "cancelled"
    E o motivo é registrado em notes
