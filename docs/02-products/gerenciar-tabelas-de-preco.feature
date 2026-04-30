# language: pt

Funcionalidade: Tabelas de preço
  Produtos são precificados via tabelas de preço (Varejo, Atacado, etc.).
  Cada organization tem suas tabelas; uma delas é a default. Customers podem
  ter uma tabela default própria que pré-preenche o pedido.

  Contexto:
    Dado a organization "Padaria do Cesar LTDA"
    E o SKU "PAO-UN" do produto "Pão Francês"

  Cenário: Criar múltiplas tabelas de preço
    Quando Cesar cria as tabelas:
      | Nome        | É default? |
      | Varejo      | sim        |
      | Atacado     | não        |
      | Revendedor  | não        |
    Então a organization tem 3 tabelas de preço
    E apenas "Varejo" é a default

  Cenário: Uma única tabela default por organization
    Dado que "Varejo" é a tabela default
    Quando Cesar marca "Atacado" como default
    Então "Atacado" vira default
    E "Varejo" deixa de ser default automaticamente
    # no máximo uma default por vez

  Cenário: Precificar o mesmo SKU em várias tabelas
    Dado as tabelas "Varejo" e "Atacado"
    Quando Cesar define:
      | Tabela  | SKU    | Preço (R$) |
      | Varejo  | PAO-UN | 1,00       |
      | Atacado | PAO-UN | 0,75       |
    Então o preço consultado depende da tabela usada no pedido
    # pedido em "Varejo" → R$ 1,00; pedido em "Atacado" → R$ 0,75

  Cenário: Customer com tabela default pré-preenche o pedido
    Dado o customer "Restaurante Sabor" com tabela default "Atacado"
    Quando Cesar cria um pedido de venda para "Restaurante Sabor"
    Então o campo de tabela de preço vem pré-preenchido com "Atacado"
    Mas Cesar pode trocar manualmente a tabela antes de salvar o pedido

  Cenário: SKU sem preço na tabela usada
    Dado o SKU "PAO-UN" sem preço cadastrado na tabela "Revendedor"
    Quando Cesar tenta adicionar "PAO-UN" a um pedido usando a tabela "Revendedor"
    Então o sistema emite erro "SKU PAO-UN não tem preço na tabela Revendedor"
    # sem fallback automático para outra tabela

  Cenário: Deletar tabela de preço sem uso é permitido
    Dado a tabela "Promo Antiga" sem nenhum sales_order, contact ou price_list_item apontando
    Quando Cesar deleta a tabela
    Então a tabela é removida

  Cenário: Deletar tabela de preço em uso é bloqueada
    Dado a tabela "Atacado" referenciada por 2 contacts (default_price_list) e 8 sales_orders
    Quando Cesar tenta deletar a tabela
    Então a operação é rejeitada com a mensagem "Tabela de preço em uso por 2 contact(s) e 8 sales_order(s) — reatribua antes de deletar"

  Cenário: Não pode deletar a tabela default
    Dado a tabela "Varejo" marcada como default
    Quando Cesar tenta deletar a tabela
    Então a operação é rejeitada com a mensagem "Tabela default — promova outra tabela a default antes de deletar"
