# language: pt

Funcionalidade: Criar uma loja
  Toda atividade no Dolabra acontece dentro de uma loja (uma empresa
  usando o ERP). Um mesmo usuário pode pertencer a várias lojas, mas
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
    Então a loja "Padaria do Cesar LTDA" é criada
    E Cesar é registrado como "owner" da loja
    E a loja já está pronta para emitir pedidos de venda, pedidos de compra e notas fiscais

  Cenário: Cadastrar empreendedor individual (MEI) com CPF
    Quando Cesar cadastra a empresa com os dados:
      | Campo             | Valor            |
      | CPF               | 123.456.789-00   |
      | Razão social      | Cesar Silva ME   |
      | Regime tributário | Simples Nacional |
    Então a loja "Cesar Silva ME" é criada
    E a loja fica classificada como pessoa física (MEI)

  Cenário: Recusar cadastro sem CNPJ e sem CPF
    Quando Cesar tenta cadastrar uma empresa sem CNPJ e sem CPF
    Então o cadastro é rejeitado com a mensagem "Informe CNPJ ou CPF"

  Cenário: Recusar CNPJ duplicado
    Dado que já existe uma loja com CNPJ "12.345.678/0001-90"
    Quando Cesar tenta cadastrar outra empresa com o mesmo CNPJ
    Então o cadastro é rejeitado com a mensagem "CNPJ já está em uso"

  Esquema do Cenário: tax_id armazenado apenas com dígitos (sem máscara)
    Quando Cesar cadastra uma loja com <documento> "<entrada>"
    Então a loja é criada com tax_id "<armazenado>"
    E a loja tem person_type "<tipo>"

    Exemplos:
      | documento | entrada            | armazenado     | tipo       |
      | CNPJ      | 12.345.678/0001-90 | 12345678000190 | company    |
      | CPF       | 123.456.789-00     | 12345678900    | individual |

  Cenário: CNPJ com dígito verificador inválido é rejeitado
    Quando Cesar tenta cadastrar uma empresa com CNPJ "12.345.678/0001-91"
    Então o cadastro é rejeitado com a mensagem "CNPJ inválido"
    # validação de DV — ver convenção em docs/00-globais/README.md

  Cenário: CPF com dígito verificador inválido é rejeitado
    Quando Cesar tenta cadastrar um MEI com CPF "123.456.789-01"
    Então o cadastro é rejeitado com a mensagem "CPF inválido"

  Cenário: Buscar loja por CNPJ ignora máscara digitada
    Dado uma loja com tax_id "12345678000190"
    Quando alguém busca por "12.345.678/0001-90"
    Então a loja é encontrada
    # a comparação é feita sobre o valor armazenado (só dígitos), independente da formatação digitada

  Esquema do Cenário: Regimes tributários aceitos
    Quando Cesar cadastra uma empresa com o regime tributário "<regime>"
    Então a loja é criada com o regime "<regime>"

    Exemplos:
      | regime            |
      | Simples Nacional  |
      | Lucro Presumido   |
      | Lucro Real        |

  Cenário: Um usuário pertencer a várias lojas
    Dado que Cesar já é "owner" da loja "Padaria do Cesar LTDA"
    Quando Cesar cadastra a nova loja "Bicicletaria Express LTDA"
    Então Cesar aparece como "owner" em ambas as lojas
    E ao atuar na "Padaria do Cesar LTDA", não enxerga nenhum dado da "Bicicletaria Express LTDA"

  Cenário: Convidar outro usuário para a loja
    Dado a loja "Padaria do Cesar LTDA" com Cesar como "owner"
    Quando Cesar convida "Ana" com o papel "admin"
    E Ana aceita o convite
    Então Ana passa a ser membro da "Padaria do Cesar LTDA" com papel "admin"
    E Ana enxerga os dados da padaria ao atuar nela

  Cenário: Owner troca a role de outro membro
    Dado a loja com Cesar como "owner" e Ana como "member"
    Quando Cesar muda a role de Ana para "admin"
    Então Ana passa a ter papel "admin" na loja

  Cenário: Member comum não pode trocar roles
    Dado a loja com Cesar como "owner", Ana como "admin" e Bruno como "member"
    Quando Bruno tenta mudar a role de Ana
    Então a operação é rejeitada com a mensagem "Apenas owner ou admin podem alterar membros"

  Cenário: Apenas owner pode promover outro a owner
    Dado a loja com Cesar como "owner" e Ana como "admin"
    Quando Ana tenta promover Bruno (member) para "owner"
    Então a operação é rejeitada com a mensagem "Apenas owner pode promover a owner"

    Quando Cesar promove Bruno para "owner"
    Então Bruno passa a ser "owner"

  Cenário: Remover membro preserva os documentos que ele criou
    Dado a loja com Cesar como "owner" e Ana como "admin"
    E Ana criou 5 sales_orders
    Quando Cesar remove Ana da loja
    Então Ana deixa de ser membro
    E os 5 sales_orders permanecem ligados ao user_id de Ana (auditoria preservada)
    E nenhum sales_order é cancelado em cascata

  Cenário: Membro sai voluntariamente da loja
    Dado a loja com Cesar como "owner" e Ana como "member"
    Quando Ana opta por sair da loja
    Então Ana deixa de ser membro
    E não enxerga mais os dados da loja

  Cenário: Não é possível sair se for o último owner
    Dado a loja "Padaria do Cesar LTDA" com Cesar como único "owner"
    Quando Cesar tenta sair da loja
    Então a operação é rejeitada com a mensagem "Loja precisa de ao menos um owner"

  Cenário: Não é possível remover o último owner
    Dado a loja com Cesar como único "owner" e Ana como "admin"
    Quando Ana tenta remover Cesar
    Então a operação é rejeitada com a mensagem "Loja precisa de ao menos um owner"
