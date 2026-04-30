# language: pt

Funcionalidade: Fluxo de status do pedido de venda
  Um pedido passa por: draft → [awaiting_approval] → approved → picking →
  invoiced → delivered. A etapa "awaiting_approval" é opcional e
  configurável por organization — mas a verificação de credit_limit pode
  forçá-la mesmo quando desabilitada.

  Contexto:
    Dado a organization "Padaria do Cesar LTDA"
    E o customer "Restaurante Sabor" sem credit_limit definido

  Cenário: Pedido em draft é totalmente editável
    Dado um pedido "SO-000001" em status "draft"
    Quando Cesar edita qualquer campo (itens, descontos, seller, payment_term)
    Então todas as edições são aceitas
    E nenhum movimento de estoque ou financeiro é gerado

  Cenário: Organization sem etapa de aprovação: draft → approved
    Dado a organization com etapa de aprovação desabilitada
    E um pedido em "draft"
    Quando Cesar confirma o pedido
    Então o pedido vai direto para "approved"

  Cenário: Organization com etapa de aprovação: draft → awaiting_approval
    Dado a organization com etapa de aprovação habilitada
    E um pedido em "draft"
    Quando Cesar confirma o pedido
    Então o pedido vai para "awaiting_approval"
    E fica read-only para o criador
    E um admin precisa aprovar manualmente

  Cenário: Admin aprova pedido em awaiting_approval
    Dado um pedido em "awaiting_approval"
    Quando um admin aprova
    Então o pedido passa para "approved"

  Cenário: Avançar para picking e depois para invoiced
    Dado um pedido em "approved"
    Quando o time operacional marca como "picking"
    Então o pedido fica em "picking"

    Quando uma invoice é emitida a partir do pedido
    Então o pedido passa para "invoiced"

  Cenário: Pedido em invoiced permanece assim até entrega total
    Dado um pedido em "invoiced" com faturamento parcial
    Quando apenas parte dos itens foi entregue
    Então o pedido permanece em "invoiced"

    Quando todos os itens do pedido são confirmados como entregues
    Então o pedido passa para "delivered"

  Cenário: Cancelar pedido em draft ou awaiting_approval
    Dado um pedido em "draft" ou "awaiting_approval"
    Quando Cesar cancela o pedido
    Então o pedido passa para "cancelled" livremente
    E nenhum movimento é gerado

  Cenário: Cancelar pedido em approved ou picking exige confirmação
    Dado um pedido em "approved"
    Quando Cesar cancela
    Então o sistema pede confirmação antes de concluir o cancelamento

  Cenário: Pedido invoiced ou delivered não pode ser cancelado
    Dado um pedido em "invoiced"
    Quando Cesar tenta cancelar
    Então a operação é rejeitada com a mensagem "Pedido já faturado — use processo de devolução"

  Cenário: Pedido cancelled é imutável
    Dado um pedido em "cancelled"
    Quando Cesar tenta editar qualquer campo ou emitir invoice
    Então a operação é rejeitada
