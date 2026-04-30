# language: pt

Funcionalidade: Templates de condição de pagamento (payment_term)
  Em vez de texto livre "30/60/90", condições de pagamento são templates
  reutilizáveis. Cada template tem parcelas com dias de vencimento e
  percentuais que somam 100%. Isso permite gerar CARs e Bills automaticamente
  em vez de interpretar strings.

  Contexto:
    Dado a loja "Padaria do Cesar LTDA"

  Cenário: Criar payment_term "À vista"
    Quando Cesar cria o payment_term:
      | Name    | Is default | Parcelas                              |
      | À vista | sim        | [sequence=1, days_offset=0, pct=100]  |
    Então "À vista" é criado com 1 parcela
    E é a condição default da loja

  Cenário: Criar payment_term "30/60/90" (3 parcelas iguais)
    Quando Cesar cria o payment_term:
      | Name     | Parcelas                                                                           |
      | 30/60/90 | seq=1 days=30 pct=33,33 ; seq=2 days=60 pct=33,33 ; seq=3 days=90 pct=33,34         |
    Então "30/60/90" é criado com 3 parcelas
    E a soma dos percentuais das parcelas é exatamente 100

  Cenário: Criar payment_term "Entrada + 2x"
    Quando Cesar cria o payment_term:
      | Name         | Parcelas                                                                       |
      | Entrada + 2x | seq=1 days=0 pct=30 ; seq=2 days=30 pct=35 ; seq=3 days=60 pct=35              |
    Então "Entrada + 2x" é criado com 3 parcelas
    E a primeira parcela é à vista (days=0)

  Cenário: Soma de pct que não fecha 100 é rejeitada
    Quando Cesar tenta criar um payment_term cujas parcelas somam 99,00
    Então a operação é rejeitada com a mensagem "A soma dos percentuais precisa ser 100"

  Cenário: Uma única default por loja
    Dado que "À vista" é a default
    Quando Cesar marca "30/60/90" como default
    Então "30/60/90" vira default
    E "À vista" deixa de ser default automaticamente

  Cenário: payment_term é usado em contact, sales_order e purchase_order
    Dado o payment_term "30/60"
    Quando Cesar define-o como default_payment_term do customer "Restaurante Sabor"
    Então novos pedidos para "Restaurante Sabor" vêm pré-preenchidos com "30/60"

    Quando Cesar seleciona "30/60" num sales_order
    Então o pedido registra "30/60" e os CARs da invoice serão gerados a partir dele

    Quando Cesar seleciona "30/60" num purchase_order
    Então os Bills da confirmação serão gerados a partir de "30/60"

  Cenário: Editar payment_term em uso afeta apenas documentos futuros
    Dado o payment_term "30/60" usado em 5 sales_orders e 3 purchase_orders
    E uma invoice já emitida (com CARs gerados a partir dele)
    Quando Cesar edita o "30/60" para virar "30/60/90" (3 parcelas)
    Então a edição é aceita
    E os 5 sales_orders ainda em "draft" passam a usar a nova configuração ao gerar CARs
    Mas os CARs já gerados pela invoice anterior NÃO mudam (foram gerados na emissão)
    E os Bills já gerados pelos purchase_orders NÃO mudam
    # geração de CAR/Bill é snapshot do template no momento da emissão/confirmação

  Cenário: Deletar payment_term em uso é bloqueado
    Dado o payment_term "30/60" referenciado por 5 sales_orders ou 3 contacts
    Quando Cesar tenta deletar o payment_term
    Então a operação é rejeitada com a mensagem "Payment term em uso por 5 sales_order(s) e 3 contact(s) — reatribua antes de deletar"
    # convenção em docs/00-globais/README.md

  Cenário: Deletar payment_term sem uso é permitido
    Dado o payment_term "Antigo — 90 dias" sem nenhum contact, sales_order ou purchase_order apontando
    Quando Cesar deleta o payment_term
    Então o template é removido
    # CARs/Bills históricos continuam intactos (foram gerados como snapshot no momento da emissão/confirmação)
