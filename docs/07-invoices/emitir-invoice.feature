# language: pt

Funcionalidade: Emitir uma invoice (draft → issued)
  Emitir é o momento em que o draft vira um documento oficial e imutável.
  É quando todos os efeitos colaterais acontecem de uma vez: baixa de
  estoque, criação de CARs por parcela, snapshot fiscal (do tax_group) e
  snapshot do customer (dados fiscais).

  Contexto:
    Dado a loja "Padaria do Cesar LTDA" no estado "SP" com regime "Simples Nacional"
    E o customer "Restaurante Sabor" no estado "SP" com CNPJ e endereço de billing cadastrados
    E o tax_group "Alimento — padaria" do produto "Pão Francês":
      | Campo              | Valor       |
      | NCM                | 19059090    |
      | CFOP mesmo estado  | 5102        |
      | CFOP outro estado  | 6102        |
      | ICMS CST (CSOSN)   | 102         |
      | ICMS rate          | 0,00        |
      | PIS CST / rate     | 99 / 0,65   |
      | COFINS CST / rate  | 99 / 3,00   |
    E um pedido approved em R$ 129,00 com payment_term "30/60" (50% em 30 dias, 50% em 60 dias)
    E um draft de invoice preparado a partir do pedido, no total de R$ 129,00

  Cenário: Emissão dispara todos os efeitos colaterais atomicamente
    Dado saldo de estoque suficiente para todos os itens
    E o customer com endereço "billing" cadastrado
    Quando Cesar emite a invoice
    Então o status da invoice passa para "issued"
    E o campo "issued_at" é preenchido com o momento da emissão
    E a invoice recebe o número "INV-NNNNNN" da sequência da loja (atribuído lazy só agora)
    E um movimento de estoque "out" é gerado por SKU (reference_type "sales_invoice")
    E CARs são gerados (ver cenário de geração de CAR)
    E um snapshot fiscal é copiado para cada invoice_item
    E um customer_snapshot é armazenado na invoice
    # tudo na mesma transação — falha em qualquer passo desfaz os outros

  Cenário: Geração de CARs pela payment_term
    Dado payment_term "30/60" com 2 parcelas de 50% em 30 e 60 dias
    E a invoice emitida em 2026-04-23 com total R$ 129,00
    Quando os CARs são criados automaticamente
    Então existem 2 CARs:
      | installment | due_date   | amount   |
      | 1 de 2      | 2026-05-23 | R$ 64,50 |
      | 2 de 2      | 2026-06-22 | R$ 64,50 |
    E a soma exata dos CARs fecha em R$ 129,00 (última parcela absorve arredondamento quando necessário)
    # regra completa de arredondamento: docs/00-globais/arredondamento-monetario.feature

  Cenário: Snapshot fiscal por item — dentro do mesmo estado
    Dado que org.state = "SP" e customer.state = "SP"
    Quando a invoice é emitida
    Então cada invoice_item copia do tax_group os campos:
      | Campo       | Valor        |
      | NCM         | 19059090     |
      | CFOP        | 5102         |
      | ICMS CST    | 102 (CSOSN)  |
      | PIS CST     | 99           |
      | PIS rate    | 0,65         |
      | COFINS CST  | 99           |
      | COFINS rate | 3,00         |
    # CFOP copiado é o de mesmo estado, não o de outro estado

  Cenário: Snapshot fiscal por item — outro estado
    Dado que org.state = "SP" e customer.state = "RJ"
    Quando a invoice é emitida
    Então o CFOP copiado é 6102 (outro estado)

  Cenário: Snapshot do customer congela dados fiscais
    Dado o customer "Restaurante Sabor" com razão social, CNPJ, IE e endereço de billing
    Quando a invoice é emitida
    Então o customer_snapshot (jsonb) registra a estrutura:
      | Chave              | Origem                                       |
      | tax_id             | contact.tax_id                               |
      | person_type        | contact.person_type                          |
      | legal_name         | contact.legal_name (se company)              |
      | name               | contact.name (se individual)                 |
      | trade_name         | contact.trade_name                           |
      | state_registration | contact.state_registration                   |
      | email              | contact.email                                |
      | address            | objeto: {street, number, complement,         |
      |                    |  neighborhood, city, state, zip_code,        |
      |                    |  country} — copiado do address de billing    |
      |                    |  default no momento da emissão               |
    E edições subsequentes no contact ou no address não alteram esse snapshot

  Cenário: Editar tax_group após emissão não afeta invoice antiga
    Dado uma invoice issued com ICMS rate de 0,00 copiado do tax_group
    Quando um admin edita o tax_group para ICMS rate 12,00
    Então os itens da invoice antiga continuam com ICMS rate 0,00 (congelado)

  Cenário: Novas invoices emitidas após edição usam o tax_group atualizado
    Dado o tax_group editado para ICMS rate 12,00
    Quando uma nova invoice é emitida usando o mesmo tax_group
    Então o snapshot do item da nova invoice tem ICMS rate 12,00

  Cenário: Invoice issued é imutável
    Dado uma invoice em "issued"
    Quando Cesar tenta editar qualquer campo (itens, preços, totais)
    Então a operação é rejeitada

  Cenário: nf_number registrado depois da emissão é persistido
    Dado uma invoice "issued"
    Quando Cesar registra manualmente "0000999" como nf_number e a data de emissão da NF-e
    Então os campos são persistidos
    E o nf_number não colide com a sequência interna INV do Dolabra

  Cenário: Estoque insuficiente bloqueia a emissão
    Dado o saldo atual de PAO-UN é 30 unidades
    E o draft de invoice contém 50 unidades de PAO-UN
    Quando Cesar tenta emitir a invoice
    Então a emissão é rejeitada com a mensagem "Estoque insuficiente: PAO-UN tem 30, precisa de 50"
    E nenhum movimento "out" é gerado
    E nenhum CAR é criado
    E a invoice permanece em "draft"
    E o número da sequência INV não é consumido

  Cenário: Estoque insuficiente em apenas 1 item de N bloqueia tudo
    Dado o saldo de PAO-UN é 100 (ok) e o saldo de CAF-250G é 2 (precisa de 5)
    Quando Cesar tenta emitir a invoice contendo PAO-UN e CAF-250G
    Então a emissão é rejeitada citando apenas CAF-250G
    E nenhum movimento "out" é gerado para nenhum dos dois SKUs
    # atomicidade — falha parcial não persiste nada

  Cenário: Customer sem endereço de billing bloqueia a emissão
    Dado o customer sem endereço "billing" cadastrado
    Quando Cesar tenta emitir a invoice
    Então a emissão é rejeitada com a mensagem "Customer precisa de endereço de billing para emissão fiscal"
