# language: pt

Funcionalidade: Cadastrar contacts (customers e suppliers)
  O Dolabra tem um cadastro único de contacts — a mesma pessoa ou empresa
  pode ser customer, supplier, ou os dois ("both"). Isso evita duplicação
  quando um fornecedor também é cliente.

  Contexto:
    Dado a organization "Padaria do Cesar LTDA"

  Cenário: Cadastrar customer pessoa jurídica
    Quando Cesar cadastra o contact:
      | Campo          | Valor                  |
      | Tipo           | customer               |
      | Tipo de pessoa | company                |
      | CNPJ           | 98.765.432/0001-10     |
      | Razão social   | Restaurante Sabor LTDA |
      | Nome fantasia  | Sabor                  |
      | IE             | 123.456.789.012        |
      | E-mail         | pedido@sabor.com       |
    Então o contact "Restaurante Sabor LTDA" é criado como customer
    E fica disponível para novos pedidos de venda
    E não fica disponível como supplier em pedidos de compra

  Cenário: Cadastrar supplier pessoa física
    Quando Cesar cadastra o contact:
      | Campo          | Valor           |
      | Tipo           | supplier        |
      | Tipo de pessoa | individual      |
      | CPF            | 111.222.333-44  |
      | Nome           | João da Farinha |
    Então o contact "João da Farinha" é criado como supplier
    E aparece em pedidos de compra
    E não aparece em pedidos de venda

  Cenário: Contact "both" atua nos dois papéis
    Quando Cesar cadastra o contact "Distribuidor X" com tipo "both"
    Então "Distribuidor X" aparece tanto em pedidos de venda quanto em pedidos de compra

  Cenário: Pessoa jurídica exige CNPJ
    Quando Cesar tenta cadastrar um contact company sem CNPJ
    Então o cadastro é rejeitado com a mensagem "CNPJ é obrigatório para pessoa jurídica"

  Cenário: Pessoa física exige CPF
    Quando Cesar tenta cadastrar um contact individual sem CPF
    Então o cadastro é rejeitado com a mensagem "CPF é obrigatório para pessoa física"

  Cenário: Usar trade_name como apelido
    Dado o contact company "Restaurante Sabor LTDA" com nome fantasia "Sabor"
    Quando Cesar busca o contact por "Sabor"
    Então o contact é encontrado
    # busca funciona tanto pelo legal_name quanto pelo trade_name

  Cenário: Default de seller e tabela de preço pré-preenchem pedidos
    Dado o seller "Ana"
    E a tabela de preço "Atacado"
    E o customer "Restaurante Sabor" com default_seller "Ana" e default_price_list "Atacado"
    Quando Cesar cria um pedido de venda para "Restaurante Sabor"
    Então o seller do pedido vem pré-preenchido com "Ana"
    E a tabela de preço do pedido vem pré-preenchida com "Atacado"
    Mas Cesar pode trocar ambos manualmente no pedido
