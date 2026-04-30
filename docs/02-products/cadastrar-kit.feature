# language: pt

Funcionalidade: Cadastrar um kit
  Um kit é um pacote virtual de SKUs físicos. Não tem estoque próprio — sua
  disponibilidade vem dos componentes. Mesmo assim, o kit tem um SKU próprio
  (o identificador de venda) e precisa ter pelo menos 1 componente.

  Contexto:
    Dado a loja "Padaria do Cesar LTDA"
    E o tax_group "Alimento — padaria" configurado
    E os produtos físicos já cadastrados e ativos:
      | Produto    | SKU       | Estoque atual |
      | Pão        | PAO-UN    | 100           |
      | Manteiga   | MAN-200G  | 40            |
      | Café       | CAF-250G  | 25            |

  Cenário: Criar kit com componentes
    Quando Cesar cadastra o kit:
      | Nome              | Tipo | Grupo fiscal        |
      | Café da Manhã Completo | kit  | Alimento — padaria  |
    E define os componentes:
      | SKU componente | Quantidade |
      | PAO-UN         | 2          |
      | MAN-200G       | 1          |
      | CAF-250G       | 1          |
    Então o kit "Café da Manhã Completo" é criado com status "draft"
    E o kit ganha um SKU próprio com seu próprio "sku_code"
    E o kit não tem estoque próprio

  Cenário: Disponibilidade do kit é derivada dos componentes
    Dado o kit "Café da Manhã Completo" com componentes:
      | SKU componente | Quantidade por kit |
      | PAO-UN         | 2                  |
      | MAN-200G       | 1                  |
      | CAF-250G       | 1                  |
    Quando o estoque dos componentes é:
      | SKU      | Em estoque |
      | PAO-UN   | 100        |
      | MAN-200G | 40         |
      | CAF-250G | 25         |
    Então a disponibilidade do kit é 25
    # limitante: CAF-250G (25 / 1 = 25), PAO-UN (100/2 = 50), MAN-200G (40/1 = 40)

  Cenário: Kit não pode conter outro kit
    Dado o kit "Café da Manhã Completo"
    E o kit "Cesta Deluxe"
    Quando Cesar tenta adicionar o SKU do "Café da Manhã Completo" como componente da "Cesta Deluxe"
    Então a operação é rejeitada com a mensagem "Componente de kit deve ser um produto físico"

  Cenário: Kit precisa de pelo menos 1 componente
    Quando Cesar tenta salvar um kit sem nenhum componente
    Então a operação é rejeitada com a mensagem "Kit deve ter ao menos um componente"

  Cenário: Campos físicos do SKU do kit não são obrigatórios
    Quando Cesar cadastra o kit "Café da Manhã Completo" sem preencher peso, dimensões ou supplier_ref no SKU
    Então o kit é criado com sucesso
    E o peso efetivo do kit é calculado em runtime como a soma dos pesos dos componentes
    E o custo efetivo do kit é calculado em runtime como a soma dos custos dos componentes
