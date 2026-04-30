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

  Esquema do Cenário: Validação de formato dos códigos fiscais
    Quando Cesar cadastra um tax_group com <campo> "<valor>"
    Então o cadastro é rejeitado com a mensagem "<mensagem>"

    Exemplos:
      | campo             | valor      | mensagem                          |
      | NCM               | 1905909    | NCM precisa ter 8 dígitos         |
      | NCM               | 190590901  | NCM precisa ter 8 dígitos         |
      | NCM               | 1905909A   | NCM precisa ter 8 dígitos         |
      | CFOP mesmo estado | 510        | CFOP precisa ter 4 dígitos        |
      | CFOP mesmo estado | 51020      | CFOP precisa ter 4 dígitos        |
      | CFOP outro estado | 510A       | CFOP precisa ter 4 dígitos        |

    # validação só de formato no MVP — sem checar contra tabela oficial.
    # Convenção em docs/00-globais/README.md.

  Cenário: Tax_group não vive em category nem em product
    Quando Cesar inspeciona os campos de um produto
    Então o produto aponta apenas tax_group_id (nenhum NCM, CFOP, origem ou unidade fiscal local)
    E a categoria do produto também não carrega campos fiscais
    # A2: tax_group é a única fonte de verdade fiscal

  Cenário: Editar tax_group em uso é sempre permitido
    Dado o tax_group "Alimento — padaria" associado a 20 produtos
    E 5 invoices issued usando esse tax_group
    Quando Cesar edita o ICMS rate do tax_group de 0,00 para 12,00
    Então a edição é aceita
    E novas invoices emitidas usam ICMS rate 12,00
    Mas as 5 invoices issued antigas continuam com o valor congelado no snapshot

  Cenário: Deletar tax_group em uso é bloqueado
    Dado o tax_group "Alimento — padaria" associado a 3 produtos
    Quando Cesar tenta deletar o tax_group
    Então a operação é rejeitada com a mensagem "Tax group em uso por 3 produto(s) — reatribua antes de deletar"
    E o tax_group permanece intacto

  Cenário: Deletar tax_group sem produtos associados é permitido
    Dado o tax_group "Antigo — sem uso" sem nenhum produto associado
    Quando Cesar deleta o tax_group
    Então o tax_group é removido
    # invoices antigas que usaram esse tax_group continuam intactas (têm o snapshot próprio)
