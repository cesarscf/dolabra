# language: pt

Funcionalidade: Atributos globais e SKUs variantes
  Atributos (Cor, Tamanho, Voltagem, …) são definidos uma vez por
  organization e reutilizados entre vários produtos. Cada combinação
  vendável de valores de atributo vira um SKU. Um produto sem atributos
  tem exatamente um SKU.

  Contexto:
    Dado a organization "Padaria do Cesar LTDA"

  Cenário: Cadastrar um atributo e seus valores
    Quando Cesar cria o atributo "Tamanho" com valores "P", "M" e "G"
    Então a organization tem o atributo "Tamanho" com 3 valores possíveis

  Cenário: Atributos são reutilizáveis entre produtos
    Dado o atributo "Tamanho" com valores "P", "M", "G"
    Quando Cesar cadastra o produto "Camiseta Básica" com variações de "Tamanho"
    E Cesar cadastra o produto "Croissant" com variações de "Tamanho"
    Então os dois produtos apontam para os mesmos valores "P", "M", "G"
    E Cesar pode futuramente filtrar "todos os SKUs tamanho M" cruzando produtos

  Cenário: SKU representa uma combinação única de valores
    Dado os atributos "Cor" (Azul, Vermelho) e "Tamanho" (P, M)
    Quando Cesar cadastra o produto "Camiseta" com as combinações:
      | Cor      | Tamanho |
      | Azul     | P       |
      | Azul     | M       |
      | Vermelho | P       |
      | Vermelho | M       |
    Então o produto "Camiseta" tem 4 SKUs
    E cada SKU carrega exatamente um valor de "Cor" e um valor de "Tamanho"
    E não existem dois SKUs com a mesma combinação

  Cenário: SKU tem código único por organization
    Quando Cesar cadastra 3 produtos físicos simples
    Então cada SKU tem um "sku_code" distinto
    E Cesar pode editar manualmente o "sku_code" de um SKU desde que não colida com outro da mesma organization

  Cenário: Campos opcionais do SKU
    Dado o produto "Pão Francês"
    Quando Cesar preenche o SKU com:
      | Campo         | Valor            |
      | EAN/GTIN      | 7891234567890    |
      | Supplier ref  | FORN-PF-001      |
      | Cost price    | 0.35             |
      | Weight (kg)   | 0.05             |
      | Height (cm)   | 5                |
      | Width (cm)    | 10               |
      | Depth (cm)    | 3                |
    Então todos os campos ficam registrados

  Cenário: GTIN com dígito verificador inválido é rejeitado
    Quando Cesar tenta cadastrar um SKU com EAN/GTIN "7891234567891"
    Então o cadastro é rejeitado com a mensagem "GTIN inválido"
    # validação de DV — convenção em docs/00-globais/README.md
    # campo é opcional; rejeição só acontece quando preenchido

  Esquema do Cenário: Comprimentos válidos de GTIN
    Quando Cesar cadastra um SKU com GTIN "<gtin>"
    Então o cadastro é aceito

    Exemplos:
      | gtin           |
      | 12345670       |
      | 614141000418   |
      | 7891234567895  |
      | 17891234567892 |
    # GTIN-8, GTIN-12, GTIN-13, GTIN-14 — todos com DV correto

  Cenário: SKU pode ser desativado individualmente
    Dado o produto "Camiseta" (active) com SKUs "Azul P", "Azul M", "Vermelho P"
    Quando Cesar desativa apenas o SKU "Vermelho P"
    Então "Vermelho P" não aparece em novos pedidos
    Mas "Azul P" e "Azul M" continuam selecionáveis

  Cenário: Deletar attribute_value sem SKUs apontando é permitido
    Dado o attribute_value "Tamanho = XXG" sem nenhum SKU usando
    Quando Cesar deleta o attribute_value
    Então o valor é removido

  Cenário: Deletar attribute_value usado por SKUs é bloqueado
    Dado o attribute_value "Tamanho = M" usado por 5 SKUs
    Quando Cesar tenta deletar o attribute_value
    Então a operação é rejeitada com a mensagem "Valor em uso por 5 SKU(s) — desvincule antes de deletar"

  Cenário: Deletar attribute com valores em uso é bloqueado
    Dado o attribute "Tamanho" com valores P/M/G usados por SKUs ativos
    Quando Cesar tenta deletar o attribute "Tamanho"
    Então a operação é rejeitada com a mensagem "Atributo tem valores em uso — desvincule os SKUs antes"

  Cenário: cost_price do SKU pode ser editado livremente
    Dado o SKU "PAO-UN" com cost_price R$ 0,30 e custo médio (stock_balance.average_cost) R$ 0,34
    Quando Cesar edita o cost_price de "PAO-UN" para R$ 0,40
    Então o cost_price registrado fica em R$ 0,40
    E o custo médio do SKU permanece em R$ 0,34
    # cost_price é referência; média vem dos movimentos "in"
    E nenhum movimento de estoque é gerado pela edição
