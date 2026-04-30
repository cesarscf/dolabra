# language: pt

Funcionalidade: Preparar uma invoice em draft
  Antes de emitir formalmente, o usuário monta uma invoice em "draft" a
  partir de um pedido. O draft é uma cópia editável dos itens, quantidades
  e preços do pedido. Ele NÃO gera estoque, NÃO gera CAR e NÃO congela
  snapshots — tudo isso acontece apenas na transição para "issued".

  Contexto:
    Dado a organization "Padaria do Cesar LTDA"
    E um pedido em status "approved" com os itens:
      | SKU      | Qty pedida | Unit price |
      | PAO-UN   | 100        | R$ 0,75    |
      | CAF-250G | 5          | R$ 12,00   |

  Cenário: Preparar invoice a partir de um pedido approved
    Quando Cesar dispara "preparar invoice" para o pedido
    Então uma invoice é criada em status "draft"
    E a invoice copia os itens, quantidades e unit_price do pedido
    E nenhum movimento de estoque é gerado
    E nenhum CAR é gerado
    E nenhum snapshot fiscal é copiado

  Cenário: Preparar invoice a partir de um pedido em picking
    Dado um pedido em "picking"
    Quando Cesar dispara "preparar invoice"
    Então a invoice é criada em "draft"
    # a preparação é permitida em approved OU picking

  Cenário: Faturamento parcial — escolher itens e quantidades
    Quando Cesar prepara a invoice escolhendo:
      | SKU      | Qty |
      | PAO-UN   | 60  |
    Então a invoice em draft tem apenas PAO-UN com quantidade 60
    # CAF-250G e os 40 PAO-UN restantes podem entrar num draft posterior

  Cenário: Editar draft antes de emitir
    Dado uma invoice em "draft" com PAO-UN qty 60
    Quando Cesar ajusta a quantidade para 50
    E Cesar ajusta o unit_price de R$ 0,75 para R$ 0,70
    E Cesar adiciona uma nota interna
    Então todas as edições são aceitas
    E o draft continua sem efeito colateral

  Cenário: Draft não recebe número da sequência INV
    Dado uma invoice em "draft"
    Quando Cesar consulta o número da invoice
    Então o campo "number" está vazio (numeração é lazy — só atribuída na emissão)

  Cenário: Descartar draft
    Dado uma invoice em "draft"
    Quando Cesar descarta o draft
    Então a invoice é removida completamente
    E nenhum número da sequência INV foi consumido

  Cenário: Pedido em status inválido não permite preparar
    Dado um pedido em "draft", "awaiting_approval" ou "cancelled"
    Quando Cesar tenta preparar uma invoice
    Então a operação é rejeitada com a mensagem "Pedido não está pronto para faturamento"
