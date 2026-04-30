# language: pt

Funcionalidade: Fluxo de caixa (realizado e projetado)
  O fluxo de caixa é calculado em tempo de consulta, sem tabela separada:
  o que já entrou/saiu vem dos pagamentos; o que vai entrar/sair vem dos
  CARs/Bills em aberto agrupados por due_date.

  Contexto:
    Dado a loja "Padaria do Cesar LTDA"
    E a data atual é 2026-04-23

  Cenário: Fluxo realizado vem dos pagamentos efetivados
    Dado os seguintes pagamentos até hoje:
      | Tipo | paid_at    | Amount     |
      | CAR  | 2026-04-10 | R$ 500,00  |
      | CAR  | 2026-04-15 | R$ 300,00  |
      | Bill | 2026-04-12 | -R$ 800,00 |
      | Bill | 2026-04-20 | -R$ 200,00 |
    Quando Cesar consulta o fluxo realizado de abril/2026
    Então entradas somam R$ 800,00
    E saídas somam R$ 1.000,00
    E o saldo realizado do período é -R$ 200,00

  Cenário: Fluxo projetado vem de CARs e Bills em aberto
    Dado os seguintes CARs e Bills em aberto:
      | Tipo | due_date   | Status  | Amount    |
      | CAR  | 2026-05-05 | pending | R$ 600,00 |
      | CAR  | 2026-05-20 | partial | R$ 400,00 |
      | Bill | 2026-05-10 | pending | R$ 250,00 |
      | Bill | 2026-05-30 | pending | R$ 350,00 |
    Quando Cesar consulta o projetado de maio/2026
    Então a tela mostra:
      | Data       | Entrada    | Saída      |
      | 2026-05-05 | R$ 600,00  |            |
      | 2026-05-10 |            | R$ 250,00  |
      | 2026-05-20 | R$ 400,00  |            |
      | 2026-05-30 |            | R$ 350,00  |

  Cenário: Vencidos aparecem como subcategoria do projetado
    Dado um CAR "pending" com due_date 2026-04-10 (no passado)
    Quando Cesar consulta o fluxo projetado
    Então o CAR aparece agrupado como "vencido" dentro do projetado
    # overdue é derivado: status IN (pending, partial) AND due_date < hoje

  Cenário: Filtrar fluxo por financial_category
    Dado os Bills em aberto:
      | Categoria | Amount     |
      | Aluguel   | R$ 3.500   |
      | Salários  | R$ 12.000  |
      | Comissões | R$ 800     |
    Quando Cesar filtra o fluxo por categoria "Salários"
    Então aparecem apenas R$ 12.000 na saída projetada

  Cenário: Filtrar por intervalo de datas
    Dado pagamentos em 2026-03, 2026-04 e 2026-05
    Quando Cesar filtra o fluxo de 2026-04-01 a 2026-04-30
    Então apenas os eventos de abril aparecem
    E pagamentos de março e maio ficam de fora

  Cenário: Fluxo é escopado por loja
    Dado a loja "Bicicletaria Express LTDA" com seus próprios pagamentos
    Quando Cesar, atuando na "Padaria do Cesar LTDA", consulta o fluxo de caixa
    Então apenas pagamentos da padaria aparecem
