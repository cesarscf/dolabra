# language: pt

Funcionalidade: Precificar um kit conforme o kit_price_mode
  Kits têm três modos de precificação: somar o preço dos componentes,
  usar um preço fixo próprio, ou aplicar um desconto sobre a soma dos
  componentes. O modo é escolhido no cadastro e afeta o cálculo do preço
  no momento da venda.

  Contexto:
    Dado a organization "Padaria do Cesar LTDA"
    E a tabela de preço default "Varejo"
    E os SKUs físicos com preços na tabela "Varejo":
      | SKU       | Preço (R$) |
      | PAO-UN    | 1,00       |
      | MAN-200G  | 8,00       |
      | CAF-250G  | 15,00      |
    E o kit "Café da Manhã Completo" com componentes:
      | SKU       | Quantidade |
      | PAO-UN    | 2          |
      | MAN-200G  | 1          |
      | CAF-250G  | 1          |

  Cenário: Modo "sum" soma os preços dos componentes
    Dado que o kit está no modo "sum"
    Quando o preço do kit é calculado na tabela "Varejo"
    Então o preço é R$ 25,00
    # 2 × 1,00 + 1 × 8,00 + 1 × 15,00

  Cenário: Modo "discount" aplica desconto sobre a soma dos componentes
    Dado que o kit está no modo "discount" com desconto de 10%
    Quando o preço do kit é calculado na tabela "Varejo"
    Então o preço é R$ 22,50
    # 25,00 × (1 - 0,10)

  Cenário: Modo "fixed" lê o preço do SKU do kit na tabela
    Dado que o kit está no modo "fixed"
    E o SKU do kit tem preço R$ 19,90 na tabela "Varejo"
    Quando o preço do kit é calculado na tabela "Varejo"
    Então o preço é R$ 19,90
    # independente dos componentes

  Cenário: Modo "fixed" permite preços distintos por tabela de preço
    Dado que o kit está no modo "fixed"
    E existem as tabelas "Varejo" e "Atacado"
    E o SKU do kit tem preço R$ 19,90 em "Varejo" e R$ 15,00 em "Atacado"
    Quando um pedido usa a tabela "Atacado"
    Então o preço aplicado é R$ 15,00

  Cenário: Modo "fixed" sem preço cadastrado falha explicitamente
    Dado que o kit está no modo "fixed"
    E o SKU do kit não tem preço na tabela "Atacado"
    Quando um pedido usando a tabela "Atacado" tenta adicionar o kit
    Então o sistema emite o erro "Preço do kit não cadastrado na tabela Atacado"
    E o item não entra no pedido
    # não há fallback silencioso para outro modo

  Cenário: Modo "sum" recalcula se o preço de um componente mudar
    Dado que o kit está no modo "sum" e o preço atual é R$ 25,00
    Quando o preço do componente "CAF-250G" passa para R$ 18,00 na tabela "Varejo"
    Então um novo pedido calcula o kit a R$ 28,00
    Mas pedidos já emitidos continuam com o preço original (R$ 25,00) congelado no item do pedido
