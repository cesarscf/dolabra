# language: pt

Funcionalidade: Cancelar um pedido de compra
  Um PO só pode ser cancelado enquanto não existir nenhum recebimento.
  Depois que qualquer quantidade entra no estoque, o caminho é devolução
  (pós-MVP), não cancelamento. Ao cancelar, os Bills gerados são cancelados.

  Contexto:
    Dado a organization "Padaria do Cesar LTDA"
    E um pedido de compra "PO-000001"

  Cenário: Cancelar PO em draft
    Dado o pedido em "draft"
    Quando Cesar cancela o pedido
    Então o pedido passa para "cancelled"
    E nenhum Bill foi gerado (draft nunca gera)

  Cenário: Cancelar PO confirmed sem nenhum recebimento
    Dado o pedido em "confirmed" com 3 Bills "pending" gerados
    Quando Cesar cancela o pedido
    Então o pedido passa para "cancelled"
    E os 3 Bills passam para "cancelled"

  Cenário: Cancelar PO com recebimento é bloqueado
    Dado o pedido em "partially_received" com um receipt já registrado
    Quando Cesar tenta cancelar
    Então a operação é rejeitada com a mensagem "Pedido já teve recebimento — use devolução"

  Cenário: Cancelar PO received é bloqueado
    Dado o pedido em "received"
    Quando Cesar tenta cancelar
    Então a operação é rejeitada

  Cenário: PO cancelled é imutável
    Dado o pedido em "cancelled"
    Quando Cesar tenta editar qualquer campo ou registrar receipt
    Então a operação é rejeitada
