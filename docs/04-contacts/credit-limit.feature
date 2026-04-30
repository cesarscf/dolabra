# language: pt

Funcionalidade: Credit limit do customer
  Cada customer pode ter um limite de crédito opcional. Quando o saldo em
  aberto mais o novo pedido ultrapassa o limite, o pedido é forçado para
  "awaiting_approval" — mesmo em organizations que desabilitam a etapa de
  aprovação por default. Um admin precisa liberar manualmente.

  No MVP, "saldo em aberto" considera APENAS CARs em status pending/partial.
  Pedidos approved/picking ainda não faturados NÃO entram na conta. A regra
  prioriza simplicidade — quando aparecer demanda real (cliente comprando em
  pedidos paralelos sem faturar), entra como extensão (ver C8 no README).

  Contexto:
    Dado a organization "Padaria do Cesar LTDA" com a etapa de aprovação desabilitada por default
    E o customer "Restaurante Sabor" com credit_limit R$ 1.000,00

  Cenário: Saldo em aberto considera CARs pendentes e parciais
    Dado que "Restaurante Sabor" tem os seguintes CARs:
      | Status   | Amount    | Paid      |
      | paid     | R$ 300,00 | R$ 300,00 |
      | pending  | R$ 400,00 | R$ 0,00   |
      | partial  | R$ 200,00 | R$ 50,00  |
      | cancelled| R$ 500,00 | R$ 0,00   |
    Quando o sistema calcula o saldo em aberto do customer
    Então o saldo em aberto é R$ 550,00
    # soma de (amount - paid_amount) em status pending/partial. paid e cancelled ficam fora

  Cenário: Pedido dentro do limite passa direto para approved
    Dado que o saldo em aberto de "Restaurante Sabor" é R$ 200,00
    Quando Cesar cria um pedido de venda no valor de R$ 500,00 para o customer
    Então o pedido vai direto para "approved"
    # 200 + 500 = 700 ≤ 1000

  Cenário: Pedido que estoura o limite é forçado para awaiting_approval
    Dado que o saldo em aberto de "Restaurante Sabor" é R$ 700,00
    Quando Cesar cria um pedido de venda no valor de R$ 400,00 para o customer
    Então o pedido vai para "awaiting_approval"
    E o sistema exibe mensagem "Pedido excede o limite de crédito do customer"
    # 700 + 400 = 1.100 > 1.000

  Cenário: Customer sem limite nunca é barrado
    Dado o customer "Padaria Concorrente" com credit_limit vazio
    Quando Cesar cria um pedido de qualquer valor
    Então o pedido segue o fluxo normal (direto para approved, se a org permite)
    # credit_limit null = verificação desligada

  Cenário: Aprovar manualmente um pedido awaiting_approval
    Dado um pedido em "awaiting_approval" por estouro de limite
    Quando um admin aprova o pedido manualmente
    Então o pedido passa para "approved"
    E segue o fluxo normal a partir dali

  Cenário: Pedidos approved/picking não entram no saldo em aberto (MVP)
    Dado o customer "Restaurante Sabor" com credit_limit R$ 1.000,00
    E nenhum CAR em aberto
    E o cliente tem 2 sales_orders em "approved" totalizando R$ 800,00 (ainda não faturados)
    Quando Cesar cria um novo pedido de R$ 500,00 para o customer
    Então o pedido vai para "approved" sem disparar awaiting_approval
    # MVP só considera CARs (pending/partial). approved/picking não entram.
    # Quando os pedidos approved virarem invoices issued, os CARs gerados passam a contar.
