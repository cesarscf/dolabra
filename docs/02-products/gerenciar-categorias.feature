# language: pt

Funcionalidade: Árvore de categorias
  Categorias organizam o catálogo em uma árvore hierárquica de profundidade
  ilimitada (ex.: Vestuário → Camisas → Manga Curta). Servem apenas para
  navegação e para regras de comissão por categoria. Não carregam nenhum
  dado fiscal — tudo que é fiscal vive em tax_group.

  Contexto:
    Dado a organization "Padaria do Cesar LTDA"

  Cenário: Criar categoria raiz
    Quando Cesar cria a categoria "Padaria" sem pai
    Então "Padaria" existe como categoria raiz da organization

  Cenário: Criar subcategorias em profundidade
    Dado a categoria raiz "Padaria"
    Quando Cesar cria "Pães" como filha de "Padaria"
    E Cesar cria "Pães Doces" como filha de "Pães"
    E Cesar cria "Brioches" como filha de "Pães Doces"
    Então a árvore fica: "Padaria → Pães → Pães Doces → Brioches"

  Cenário: Associar produto a uma categoria
    Dado a categoria "Pães"
    E o produto "Pão Francês"
    Quando Cesar associa o produto à categoria "Pães"
    Então o produto aparece ao filtrar a categoria "Pães"
    E também aparece ao filtrar "Padaria" (categoria ancestral)

  Cenário: Produto sem categoria é permitido
    Quando Cesar cadastra o produto "Item Avulso" sem categoria
    Então o produto é criado com sucesso
    E ao calcular comissão desse produto, o sistema usa sempre a comissão default do vendedor (sem fallback de categoria)

  Cenário: Categoria não carrega dados fiscais
    Quando Cesar inspeciona os campos de uma categoria
    Então a categoria não tem NCM, CFOP, origem ou unidade fiscal
    E toda regra fiscal vem exclusivamente do tax_group do produto
