# language: pt

Funcionalidade: Criar uma organization
  Toda atividade no Dolabra acontece dentro de uma organization (uma empresa
  usando o ERP). Um mesmo usuário pode pertencer a várias organizations, mas
  cada uma é um mundo isolado: dados de uma nunca vazam para outra.

  Contexto:
    Dado um usuário autenticado chamado "Cesar"

  Cenário: Cadastrar empresa (pessoa jurídica) com CNPJ
    Quando Cesar cadastra a empresa com os dados:
      | Campo             | Valor                 |
      | CNPJ              | 12.345.678/0001-90    |
      | Razão social      | Padaria do Cesar LTDA |
      | Nome fantasia     | Pão Quente            |
      | Regime tributário | Simples Nacional      |
      | E-mail fiscal     | fiscal@paoquente.com  |
    Então a organization "Padaria do Cesar LTDA" é criada
    E Cesar é registrado como "owner" da organization
    E a organization já está pronta para emitir pedidos de venda, pedidos de compra e notas fiscais

  Cenário: Cadastrar empreendedor individual (MEI) com CPF
    Quando Cesar cadastra a empresa com os dados:
      | Campo             | Valor            |
      | CPF               | 123.456.789-00   |
      | Razão social      | Cesar Silva ME   |
      | Regime tributário | Simples Nacional |
    Então a organization "Cesar Silva ME" é criada
    E a organization fica classificada como pessoa física (MEI)

  Cenário: Recusar cadastro sem CNPJ e sem CPF
    Quando Cesar tenta cadastrar uma empresa sem CNPJ e sem CPF
    Então o cadastro é rejeitado com a mensagem "Informe CNPJ ou CPF"

  Cenário: Recusar CNPJ duplicado
    Dado que já existe uma organization com CNPJ "12.345.678/0001-90"
    Quando Cesar tenta cadastrar outra empresa com o mesmo CNPJ
    Então o cadastro é rejeitado com a mensagem "CNPJ já está em uso"

  Cenário: tax_id é armazenado apenas com dígitos (sem máscara)
    Quando Cesar cadastra uma empresa com CNPJ "12.345.678/0001-90"
    Então a organization é criada com tax_id "12345678000190"
    E a organization tem person_type "company"

  Cenário: tax_id de MEI também é armazenado apenas com dígitos
    Quando Cesar cadastra um MEI com CPF "123.456.789-00"
    Então a organization é criada com tax_id "12345678900"
    E a organization tem person_type "individual"

  Cenário: Buscar organization por CNPJ ignora máscara digitada
    Dado uma organization com tax_id "12345678000190"
    Quando alguém busca por "12.345.678/0001-90"
    Então a organization é encontrada
    # a comparação é feita sobre o valor armazenado (só dígitos), independente da formatação digitada

  Esquema do Cenário: Regimes tributários aceitos
    Quando Cesar cadastra uma empresa com o regime tributário "<regime>"
    Então a organization é criada com o regime "<regime>"

    Exemplos:
      | regime            |
      | Simples Nacional  |
      | Lucro Presumido   |
      | Lucro Real        |

  Cenário: Um usuário pertencer a várias organizations
    Dado que Cesar já é "owner" da organization "Padaria do Cesar LTDA"
    Quando Cesar cadastra a nova organization "Bicicletaria Express LTDA"
    Então Cesar aparece como "owner" em ambas as organizations
    E ao atuar na "Padaria do Cesar LTDA", não enxerga nenhum dado da "Bicicletaria Express LTDA"

  Cenário: Convidar outro usuário para a organization
    Dado a organization "Padaria do Cesar LTDA" com Cesar como "owner"
    Quando Cesar convida "Ana" com o papel "admin"
    E Ana aceita o convite
    Então Ana passa a ser membro da "Padaria do Cesar LTDA" com papel "admin"
    E Ana enxerga os dados da padaria ao atuar nela

  Cenário: Owner troca a role de outro membro
    Dado a organization com Cesar como "owner" e Ana como "member"
    Quando Cesar muda a role de Ana para "admin"
    Então Ana passa a ter papel "admin" na organization

  Cenário: Member comum não pode trocar roles
    Dado a organization com Cesar como "owner", Ana como "admin" e Bruno como "member"
    Quando Bruno tenta mudar a role de Ana
    Então a operação é rejeitada com a mensagem "Apenas owner ou admin podem alterar membros"

  Cenário: Apenas owner pode promover outro a owner
    Dado a organization com Cesar como "owner" e Ana como "admin"
    Quando Ana tenta promover Bruno (member) para "owner"
    Então a operação é rejeitada com a mensagem "Apenas owner pode promover a owner"

    Quando Cesar promove Bruno para "owner"
    Então Bruno passa a ser "owner"

  Cenário: Remover membro preserva os documentos que ele criou
    Dado a organization com Cesar como "owner" e Ana como "admin"
    E Ana criou 5 sales_orders
    Quando Cesar remove Ana da organization
    Então Ana deixa de ser membro
    E os 5 sales_orders permanecem ligados ao user_id de Ana (auditoria preservada)
    E nenhum sales_order é cancelado em cascata

  Cenário: Membro sai voluntariamente da organization
    Dado a organization com Cesar como "owner" e Ana como "member"
    Quando Ana opta por sair da organization
    Então Ana deixa de ser membro
    E não enxerga mais os dados da organization

  Cenário: Não é possível sair se for o último owner
    Dado a organization "Padaria do Cesar LTDA" com Cesar como único "owner"
    Quando Cesar tenta sair da organization
    Então a operação é rejeitada com a mensagem "Organization precisa de ao menos um owner"

  Cenário: Não é possível remover o último owner
    Dado a organization com Cesar como único "owner" e Ana como "admin"
    Quando Ana tenta remover Cesar
    Então a operação é rejeitada com a mensagem "Organization precisa de ao menos um owner"
