# language: pt

Funcionalidade: Cadastrar um produto físico
  Um produto físico é o caso mais comum: um bem tangível, com estoque, peso
  e dimensões próprios. Todo produto tem ao menos um SKU (a unidade vendável)
  e um tax_group que define como ele é tributado.

  Contexto:
    Dado a organization "Padaria do Cesar LTDA"
    E o tax_group "Alimento — padaria" configurado
    E a tabela de preço default "Varejo"

  Cenário: Cadastrar produto simples (sem variação)
    Quando Cesar cadastra o produto:
      | Campo         | Valor               |
      | Nome          | Pão Francês         |
      | Tipo          | physical            |
      | Unidade       | un                  |
      | Grupo fiscal  | Alimento — padaria  |
    Então o produto "Pão Francês" é criado com status "draft"
    E o produto ganha automaticamente um SKU com código gerado automaticamente
    E o slug do produto é "pao-frances"

  Cenário: Cadastrar produto com variações (SKUs múltiplos)
    Dado os atributos da organization:
      | Atributo | Valores       |
      | Tamanho  | P, M, G       |
      | Sabor    | Doce, Salgado |
    Quando Cesar cadastra o produto "Croissant" com as combinações de atributos:
      | Tamanho | Sabor   |
      | P       | Doce    |
      | P       | Salgado |
      | M       | Doce    |
      | M       | Salgado |
      | G       | Doce    |
      | G       | Salgado |
    Então o produto "Croissant" tem 6 SKUs
    E cada SKU corresponde a uma combinação única dos atributos

  Cenário: Slug é único por organization
    Dado que já existe o produto "Pão Francês" com slug "pao-frances"
    Quando Cesar tenta cadastrar outro produto com o mesmo slug "pao-frances"
    Então o cadastro é rejeitado com a mensagem "Slug já está em uso"

  Cenário: Slug pode se repetir em organizations diferentes
    Dado a organization "Padaria do Cesar LTDA" com produto de slug "pao-frances"
    E a organization "Pão Artesanal LTDA"
    Quando a "Pão Artesanal LTDA" cadastra um produto com slug "pao-frances"
    Então o cadastro é aceito
    E cada organization mantém seu próprio "pao-frances"

  Cenário: Nome do produto pode se repetir dentro da mesma organization
    Dado que já existe o produto "Pão Francês" com slug "pao-frances"
    Quando Cesar cadastra outro produto "Pão Francês" com slug "pao-frances-tradicional"
    Então o cadastro é aceito
    E ambos os produtos coexistem

  Cenário: Produto exige um tax_group
    Quando Cesar tenta cadastrar o produto "Pão Francês" sem tax_group
    Então o cadastro é rejeitado com a mensagem "Grupo fiscal é obrigatório"

  Cenário: Produto nasce em draft e não aparece em listagens operacionais
    Quando Cesar cadastra o produto "Pão Francês"
    Então o produto aparece na listagem de administração de produtos
    Mas o produto não aparece ao montar um pedido de venda
    E o produto não aparece em relatórios de estoque
