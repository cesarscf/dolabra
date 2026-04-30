# language: pt

Funcionalidade: Status do contact
  Um contact pode estar "active", "inactive" ou "blocked". Mudar o status
  afeta apenas a criação de novos documentos — nada acontece em cascata
  com pedidos, invoices ou CARs já existentes. Um CAR é um direito real da
  empresa: não desaparece quando o cliente é bloqueado.

  Contexto:
    Dado a organization "Padaria do Cesar LTDA"
    E o customer "Restaurante Sabor" com status "active"

  Cenário: Contact active aparece em formulários
    Quando Cesar busca customers para um novo pedido de venda
    Então "Restaurante Sabor" aparece na lista

  Cenário: Contact inactive é oculto de novos pedidos
    Dado que Cesar muda o status do customer para "inactive"
    Quando Cesar busca customers para um novo pedido de venda
    Então "Restaurante Sabor" não aparece na lista
    Mas pedidos e invoices antigos do customer continuam visíveis no histórico

  Cenário: Contact blocked não pode ser usado em novos sales orders
    Dado que Cesar muda o status do customer para "blocked"
    Quando Cesar tenta criar um novo pedido de venda para "Restaurante Sabor"
    Então o sistema emite erro "Customer bloqueado"
    Mas "Restaurante Sabor" continua visível em listagens e relatórios

  Cenário: Bloquear customer não cancela CARs em aberto
    Dado o customer "Restaurante Sabor" com 3 CARs em status "pending" totalizando R$ 1.500,00
    Quando Cesar muda o status do customer para "blocked"
    Então os 3 CARs permanecem em "pending"
    E podem ser pagos normalmente
    E o fluxo de caixa continua projetando esses recebimentos

  Cenário: Bloquear customer não afeta sales orders em andamento
    Dado o customer "Restaurante Sabor" com um pedido em "picking"
    Quando Cesar muda o status do customer para "blocked"
    Então o pedido continua em "picking" e pode ser faturado
    E a invoice emitida a partir dele gera estoque e CARs normalmente
