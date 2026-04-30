# language: pt

Funcionalidade: Regras de comissão do seller
  Cada seller tem uma taxa default de comissão. Pode ter overrides por
  categoria de produto, aplicados apenas a itens dessa categoria. Produtos
  sem categoria usam sempre a taxa default. A base de cálculo (gross vs net)
  define se o desconto do pedido entra ou não.

  Contexto:
    Dado a loja "Padaria do Cesar LTDA"
    E o seller "Ana" com comissão default de 5% e base "net"

  Cenário: Override por categoria tem precedência sobre o default
    Dado as categorias "Pães" e "Bolos"
    E o override do seller "Ana":
      | Categoria | Comissão (%) |
      | Pães      | 3,00         |
      | Bolos     | 8,00         |
    Quando o sistema pergunta a taxa de comissão para um produto da categoria "Pães"
    Então a taxa retornada é 3% (override)

    Quando o sistema pergunta a taxa de comissão para um produto da categoria "Bolos"
    Então a taxa retornada é 8% (override)

    Quando o sistema pergunta a taxa para um produto da categoria "Salgados" (sem override)
    Então a taxa retornada é 5% (default)

  Cenário: Produto sem categoria usa sempre o default
    Dado um produto "Item Avulso" sem categoria
    E o override do seller "Ana" para a categoria "Pães" em 3%
    Quando o sistema pergunta a taxa para "Item Avulso"
    Então a taxa retornada é 5% (default)
    # não há fallback de catch-all para produtos sem categoria

  Cenário: Base "gross" usa o total do item pós-desconto de item
    Dado um sales_order_item com unit_price R$ 10,00, quantidade 10 e desconto de item de 10%
    # total do item = 10 × 10 × 0,9 = 90
    E o seller com base "gross"
    Quando a comissão é calculada
    Então a base é R$ 90,00 (o total do item)

  Cenário: Base "net" aplica rateio do desconto do pedido
    Dado um sales_order com subtotal R$ 100,00 e discount_total R$ 10,00
    E um item desse pedido com total R$ 90,00
    E o seller com base "net"
    Quando a comissão é calculada sobre esse item
    Então a base é R$ 81,00
    # 90 × (1 - 10/100) = 81

  Cenário: Impostos não são descontados no MVP
    Quando a comissão é calculada em qualquer base
    Então nenhum imposto (ICMS/PIS/COFINS/IPI) é subtraído da base
    # ex-impostos (fiscal_net) fica para pós-MVP

  Cenário: Módulo de Sellers não escreve em tabelas de Financial
    Quando o CAR transita para "paid" e a comissão é calculada
    Então o cálculo e a geração do Bill acontecem no módulo Financial
    E o módulo Sellers apenas fornece as regras consultadas

  Cenário: Override em categoria pai não vale para produtos em categoria filha
    Dado a árvore de categorias "Padaria → Pães → Pães Doces"
    E o override do seller "Ana" para a categoria "Padaria" em 10%
    E nenhum override para "Pães" nem para "Pães Doces"
    Quando o sistema pergunta a taxa para um produto em "Pães Doces"
    Então a taxa retornada é 5% (default do seller)
    # match estrito: só conta se a categoria exata do produto tem override

  Cenário: Override em categoria filha não afeta produto em categoria pai
    Dado o override do seller "Ana" para "Pães Doces" em 12%
    E nenhum override para "Padaria"
    Quando o sistema pergunta a taxa para um produto na categoria "Padaria"
    Então a taxa retornada é 5% (default)

  Cenário: Para cobrir uma sub-árvore, cadastre overrides explícitos em cada categoria
    Dado a árvore "Padaria → Pães → Pães Doces"
    E o seller "Ana" com overrides:
      | Categoria   | Comissão (%) |
      | Padaria     | 6,00         |
      | Pães        | 6,00         |
      | Pães Doces  | 6,00         |
    Quando o sistema pergunta a taxa para um produto em qualquer uma das três categorias
    Então a taxa retornada é 6%

  Cenário: Seller desativado mantém comissão sobre pedidos existentes
    Dado o seller "Rafael" atribuído a um sales_order com invoice já emitida
    Quando Cesar desativa o seller "Rafael"
    E um CAR dessa invoice transita para "paid"
    Então um Bill de comissão é gerado normalmente para "Rafael"
    E o Bill aparece no relatório de comissões
    Mas "Rafael" não aparece em formulários de novos pedidos
