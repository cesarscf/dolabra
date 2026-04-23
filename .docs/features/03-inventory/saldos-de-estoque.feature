# language: pt

Funcionalidade: Saldos de estoque por SKU
  O saldo de estoque de cada SKU é sempre derivado de movimentos imutáveis.
  Ninguém edita "a quantidade em mãos" diretamente: toda mudança passa por
  um movimento (entrada, saída ou ajuste). Isso preserva auditoria completa.

  Contexto:
    Dado a organization "Padaria do Cesar LTDA"
    E o SKU "PAO-UN" do produto "Pão Francês"

  Cenário: Cada SKU tem no máximo um saldo por organization
    Dado que "PAO-UN" já tem um registro de saldo
    Quando o sistema processa vários movimentos de entrada concorrentes para "PAO-UN"
    Então continua existindo apenas um registro de saldo para "PAO-UN"
    E a quantidade em mãos reflete a soma correta de todos os movimentos

  Cenário: Saldo nunca é editado diretamente
    Dado que o saldo de "PAO-UN" é 50 unidades
    Quando Cesar tenta alterar o saldo direto para 60
    Então a operação é rejeitada
    E a única forma aceita de subir o saldo é criar um movimento (recebimento, ajuste manual ou contagem)

  Cenário: Alerta por estoque mínimo
    Dado que o saldo de "PAO-UN" tem "minimum_stock" definido como 20
    Quando a quantidade em mãos cai para 15
    Então o SKU aparece na listagem "abaixo do mínimo"

  Cenário: Ponto de reposição sugere reposição
    Dado que "PAO-UN" tem "reorder_point" definido como 30
    Quando a quantidade em mãos cai para 25
    Então o SKU aparece na sugestão de reposição

  Cenário: SKUs de kit não têm saldo próprio
    Dado o kit "Café da Manhã Completo" com seu próprio SKU
    Quando Cesar consulta os registros de saldo da organization
    Então o SKU do kit não tem registro de saldo (é derivado dos componentes)
