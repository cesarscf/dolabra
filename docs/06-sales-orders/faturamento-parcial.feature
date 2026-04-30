# language: pt

Funcionalidade: Faturamento parcial de um pedido
  Um pedido de venda pode gerar várias invoices. Isso atende cenários em
  que os itens saem em lotes ou são cobrados em datas diferentes. O pedido
  acompanha a quantidade acumulada faturada por item e só avança para
  "invoiced" quando todos os itens estão totalmente faturados.

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
    E o pedido continua em "invoiced" até a entrega ser concluída

  Cenário: Não é possível faturar mais do que foi pedido
    Dado a "quantidade faturada" de PAO-UN é 100 (igual ao pedido)
    Quando Cesar tenta emitir outra invoice com 10 unidades de PAO-UN
    Então a operação é rejeitada com a mensagem "Quantidade faturada excede o pedido"

  Cenário: Múltiplos drafts podem coexistir para o mesmo pedido
    Dado nenhuma invoice emitida ainda
    Quando Cesar prepara 2 drafts simultâneos para o mesmo pedido (cenários hipotéticos)
    Então os 2 drafts existem em paralelo sem conflito
    E nenhum efeito colateral (estoque, CAR) acontece enquanto são apenas drafts

  Cenário: Descartar draft de invoice não afeta o pedido
    Dado um draft de invoice preparado a partir do pedido
    Quando Cesar descarta o draft
    Então o draft é removido
    E o pedido continua em "approved" (ou onde estava)
    E nenhuma quantidade é marcada como faturada
