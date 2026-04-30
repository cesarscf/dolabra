# language: pt

Funcionalidade: Fluxo de status do pedido de venda
  Um pedido passa por: draft → [awaiting_approval] → approved → picking →
  invoiced. A etapa "awaiting_approval" é controlada pelo setting
  "requires_sales_order_approval" da loja — mas a verificação de
  credit_limit pode forçá-la mesmo quando o setting está desligado. O fluxo
  termina em "invoiced" no MVP — registro de entrega ("delivered") fica
  fora do escopo.

  Contexto:
    Dado a loja "Padaria do Cesar LTDA"
    E o customer "Restaurante Sabor" sem credit_limit definido

  Cenário: Pedido em draft é totalmente editável
    Dado um pedido "SO-000001" em status "draft"
    Quando Cesar edita qualquer campo (itens, descontos, seller, payment_term)
    Então todas as edições são aceitas
    E nenhum movimento de estoque ou financeiro é gerado

  Cenário: Loja com requires_sales_order_approval=false: draft → approved
    Dado a loja com requires_sales_order_approval "false"
    E um pedido em "draft"
    Quando Cesar confirma o pedido
    Então o pedido vai direto para "approved"

  Cenário: Loja com requires_sales_order_approval=true: draft → awaiting_approval
    Dado a loja com requires_sales_order_approval "true"
    E um pedido em "draft"
    Quando Cesar confirma o pedido
    Então o pedido vai para "awaiting_approval"
    E fica read-only para o criador
    E um admin precisa aprovar manualmente

  Cenário: Admin aprova pedido em awaiting_approval
    Dado um pedido em "awaiting_approval"
    Quando um admin aprova
    Então o pedido passa para "approved"

  Cenário: Admin rejeita pedido em awaiting_approval volta para draft
    Dado um pedido em "awaiting_approval"
    Quando um admin rejeita o pedido com motivo "Crédito não autorizado pelo financeiro"
    Então o pedido volta para "draft"
    E o motivo da rejeição é registrado em internal_notes
    E o criador do pedido pode editar e re-submeter
    # rejeição é uma transição reversa explícita — diferente de cancelar

  Cenário: Aprovado avança para picking
    Dado um pedido em "approved"
    Quando o time operacional marca como "picking"
    Então o pedido fica em "picking"

  Cenário: Emitir invoice move o pedido para invoiced
    Dado um pedido em "picking"
    Quando uma invoice é emitida a partir do pedido
    Então o pedido passa para "invoiced"

  Cenário: Pedido em invoiced é estado terminal (MVP)
    Dado um pedido em "invoiced" com faturamento parcial
    Quando outras invoices são emitidas para completar o saldo
    Então o pedido permanece em "invoiced"
    # registro de entrega ("delivered") está fora do escopo do MVP

  Cenário: Cancelar pedido em draft ou awaiting_approval
    Dado um pedido em "draft" ou "awaiting_approval"
    Quando Cesar cancela o pedido
    Então o pedido passa para "cancelled" livremente
    E nenhum movimento é gerado

  Cenário: Cancelar pedido em approved ou picking exige confirmação
    Dado um pedido em "approved"
    Quando Cesar cancela
    Então o sistema pede confirmação antes de concluir o cancelamento

  Cenário: Pedido invoiced não pode ser cancelado
    Dado um pedido em "invoiced"
    Quando Cesar tenta cancelar
    Então a operação é rejeitada com a mensagem "Pedido já faturado — use processo de devolução"

  Cenário: Pedido cancelled é imutável
    Dado um pedido em "cancelled"
    Quando Cesar tenta editar qualquer campo ou emitir invoice
    Então a operação é rejeitada

  Esquema do Cenário: Transições inválidas são rejeitadas
    Dado um pedido em status "<origem>"
    Quando Cesar tenta forçar a transição para "<destino>"
    Então a operação é rejeitada com a mensagem "Transição inválida"

    Exemplos:
      | origem             | destino            |
      | draft              | invoiced           |
      | approved           | draft              |
      | approved           | awaiting_approval  |
      | invoiced           | approved           |
      | invoiced           | cancelled          |
      | cancelled          | draft              |
      | cancelled          | approved           |
      | picking            | draft              |
