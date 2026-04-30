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
    E o CNPJ fica vazio na organization

  Cenário: Recusar cadastro sem CNPJ e sem CPF
    Quando Cesar tenta cadastrar uma empresa sem CNPJ e sem CPF
    Então o cadastro é rejeitado com a mensagem "Informe CNPJ ou CPF"

  Cenário: Recusar CNPJ duplicado
    Dado que já existe uma organization com CNPJ "12.345.678/0001-90"
    Quando Cesar tenta cadastrar outra empresa com o mesmo CNPJ
    Então o cadastro é rejeitado com a mensagem "CNPJ já está em uso"

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
