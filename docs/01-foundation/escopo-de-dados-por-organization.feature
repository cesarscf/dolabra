# language: pt

Funcionalidade: Isolamento de dados por organization
  O Dolabra é multi-empresa. A regra de ouro do sistema é: nenhum dado de
  uma organization pode aparecer em consultas de outra. Esta é a invariante
  mais importante do produto — se ela falhar, é um defeito crítico.

  Contexto:
    Dado a organization "Padaria do Cesar LTDA"
    E a organization "Bicicletaria Express LTDA"
    E Cesar é "owner" das duas organizations

  Cenário: Produtos não vazam entre organizations
    Dado que a "Padaria do Cesar LTDA" tem o produto "Pão Francês"
    E a "Bicicletaria Express LTDA" tem o produto "Pneu 29"
    Quando Cesar está atuando na "Padaria do Cesar LTDA"
    Então Cesar vê "Pão Francês"
    Mas Cesar não vê "Pneu 29"

  Cenário: Customers não vazam entre organizations
    Dado que a "Padaria do Cesar LTDA" tem como customer "Restaurante Sabor"
    E a "Bicicletaria Express LTDA" tem como customer "Academia Pedal"
    Quando Cesar está atuando na "Bicicletaria Express LTDA"
    Então Cesar vê "Academia Pedal"
    Mas Cesar não vê "Restaurante Sabor"

  Cenário: Documentos financeiros não vazam entre organizations
    Dado que a "Padaria do Cesar LTDA" tem 3 CARs em aberto
    E a "Bicicletaria Express LTDA" tem 1 CAR em aberto
    Quando Cesar consulta contas a receber atuando na "Bicicletaria Express LTDA"
    Então Cesar vê apenas 1 CAR

  Cenário: Mudar de organization ativa troca o escopo por completo
    Dado que Cesar está atuando na "Padaria do Cesar LTDA"
    Quando Cesar troca a organization ativa para "Bicicletaria Express LTDA"
    Então todas as listagens (produtos, customers, pedidos, financeiro) passam a mostrar apenas dados da "Bicicletaria Express LTDA"
