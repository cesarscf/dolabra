# language: pt

Funcionalidade: Configurar um tax_group
  Tax groups concentram as regras fiscais (NCM, CFOP, origem, CSTs e
  alíquotas). Vários produtos podem compartilhar o mesmo grupo. É a única
  fonte de verdade fiscal — categorias e o próprio produto não carregam
  campos fiscais.

  Contexto:
    Dado a organization "Padaria do Cesar LTDA" com regime "Simples Nacional"

  Cenário: Cadastrar tax_group típico de padaria
    Quando Cesar cadastra o tax_group:
      | Campo                | Valor                  |
      | Nome                 | Alimento — padaria     |
      | NCM                  | 19059090               |
      | Origem               | 0 (doméstica)          |
      | CFOP mesmo estado    | 5102                   |
      | CFOP outro estado    | 6102                   |
      | Unidade fiscal       | un                     |
      | ICMS CST (CSOSN)     | 102                    |
      | ICMS rate            | 0,00                   |
      | PIS CST / rate       | 99 / 0,65              |
      | COFINS CST / rate    | 99 / 3,00              |
    Então o tax_group é criado e disponível para associação a produtos

  Cenário: Tax_group é compartilhado entre múltiplos produtos
    Dado o tax_group "Alimento — padaria"
    Quando 20 produtos são associados ao mesmo tax_group
    Então ao editar o tax_group, todos os 20 produtos passam a usar os valores novos em futuras invoices
    # invoices antigas ficam congeladas pelo snapshot

  Cenário: Produto com fiscal atípico ganha tax_group próprio
    Dado o produto "Kombucha Importada" com fiscalidade diferente do resto
    Quando Cesar cria um tax_group específico "Bebida importada — SP" e atribui ao produto
    Então apenas esse produto usa o tax_group próprio
    # barato e explícito

  Cenário: CEST é obrigatório em cenários de ICMS-ST
    Quando Cesar cadastra um tax_group com ICMS CST indicando substituição tributária
    E não informa CEST
    Então o cadastro é rejeitado com a mensagem "CEST é obrigatório quando há ICMS-ST"

  Cenário: Tax_group não vive em category nem em product
    Quando Cesar inspeciona os campos de um produto
    Então o produto aponta apenas tax_group_id (nenhum NCM, CFOP, origem ou unidade fiscal local)
    E a categoria do produto também não carrega campos fiscais
    # A2: tax_group é a única fonte de verdade fiscal
