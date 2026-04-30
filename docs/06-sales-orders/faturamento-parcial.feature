# language: pt

Funcionalidade: Faturamento parcial de um pedido
  Um pedido de venda pode gerar várias invoices. Isso atende cenários em
  que os itens saem em lotes ou são cobrados em datas diferentes. O pedido
  acompanha a quantidade acumulada faturada por item. A soma de qty já
  faturada (issued) com qty em drafts abertos não pode exceder a qty
  pedida — defesa contra faturar mais do que o cliente pediu.

  Contexto:
    Dado a organization "Padaria do Cesar LTDA"
    E um pedido em "approved" com os itens:
      | SKU       | Qty pedida |
      | PAO-UN    | 100        |
      | CAF-250G  | 5          |
    E o pedido usa payment_term "À vista" (1 parcela, 0 dias)

  Cenário: Primeira invoice parcial cobre só parte dos itens
    Quando Cesar prepara e emite uma invoice contendo:
      | SKU      | Qty |
      | PAO-UN   | 60  |
      | CAF-250G | 0   |
    Então a invoice é emitida com sucesso
    E a "quantidade faturada" do pedido fica:
      | SKU      | Faturado | Faltando |
      | PAO-UN   | 60       | 40       |
      | CAF-250G | 0        | 5        |
    E o pedido passa para "invoiced" (basta a primeira invoice parcial)

  Cenário: Segunda invoice completa o restante
    Dado a primeira invoice parcial já emitida com 60 PAO-UN
    Quando Cesar emite outra invoice com:
      | SKU      | Qty |
      | PAO-UN   | 40  |
      | CAF-250G | 5   |
    Então a quantidade faturada do pedido fica completa:
      | SKU      | Faturado | Faltando |
      | PAO-UN   | 100      | 0        |
      | CAF-250G | 5        | 0        |
    E o pedido permanece em "invoiced" (estado terminal do MVP)

  Cenário: Não é possível faturar mais do que foi pedido
    Dado a "quantidade faturada" de PAO-UN é 100 (igual ao pedido)
    Quando Cesar tenta emitir outra invoice com 10 unidades de PAO-UN
    Então a operação é rejeitada com a mensagem "Quantidade faturada excede o pedido"

  Cenário: Drafts simultâneos consomem qty disponível conjuntamente
    Dado nenhuma invoice emitida ainda
    E o pedido tem 100 PAO-UN
    Quando Cesar prepara o draft A com 60 PAO-UN
    Então o draft A é aceito
    Quando Cesar prepara o draft B com 30 PAO-UN
    Então o draft B é aceito (60 + 30 = 90 ≤ 100)
    Quando Cesar tenta preparar um draft C com 20 PAO-UN
    Então o draft C é rejeitado com a mensagem "Quantidade comprometida em drafts excede o saldo do pedido"
    # 60 + 30 + 20 = 110 > 100

  Cenário: Editar draft aumenta a qty comprometida
    Dado o draft A com 60 PAO-UN e o draft B com 30 PAO-UN (90 de 100 comprometidos)
    Quando Cesar tenta editar o draft B para 50 PAO-UN
    Então a operação é rejeitada
    # 60 + 50 = 110 > 100

  Cenário: Descartar draft libera qty imediatamente
    Dado o draft A com 60 PAO-UN e o draft B com 30 PAO-UN
    Quando Cesar descarta o draft A
    Então a qty comprometida em drafts cai para 30
    E é possível preparar um novo draft com até 70 PAO-UN
    E o pedido continua em "approved" (ou onde estava)
    E nenhuma quantidade fica marcada como faturada

  Cenário: Defesa em profundidade — segundo draft a emitir falha se outro passou na frente
    Dado o draft A e o draft B, ambos com 60 PAO-UN (120 comprometidos somando, mas a checagem do draft permite porque cada um isolado cabe)
    # nota: a checagem do draft considera todos os drafts vivos. este cenário cobre o caso raro em que dois drafts são criados sob mesma transação e a checagem é burlada
    Quando o draft A é emitido (vira issued)
    E Cesar tenta emitir o draft B
    Então a emissão do draft B é rejeitada com a mensagem "Quantidade faturada excede o pedido"
