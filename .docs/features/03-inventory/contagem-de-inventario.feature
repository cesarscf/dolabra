# language: pt

Funcionalidade: Contagem de inventário
  A contagem física reconcilia o que está no sistema com o que existe no
  mundo real. O sistema snapshota o saldo no início (para não perseguir um
  alvo móvel) e, ao fechar, gera ajustes automáticos para cada item com
  diferença.

  Contexto:
    Dado a organization "Padaria do Cesar LTDA"
    E o SKU "PAO-UN" com saldo 50
    E o SKU "MAN-200G" com saldo 40
    E o SKU "CAF-250G" com saldo 25

  Cenário: Iniciar uma contagem snapshotando os saldos atuais
    Quando Cesar cria uma contagem e avança o status para "in_progress"
    Então o sistema registra para cada SKU o "system_quantity" atual como snapshot
    # PAO-UN=50, MAN-200G=40, CAF-250G=25

  Cenário: Registrar contagem física por SKU
    Dado uma contagem em "in_progress"
    Quando Cesar informa as quantidades contadas:
      | SKU      | Contado |
      | PAO-UN   | 48      |
      | MAN-200G | 42      |
      | CAF-250G | 25      |
    Então a diferença por item é calculada:
      | SKU      | Diferença |
      | PAO-UN   | -2        |
      | MAN-200G | +2        |
      | CAF-250G | 0         |

  Cenário: Fechar a contagem gera ajustes automáticos
    Dado uma contagem em "in_progress" com as diferenças:
      | SKU      | Diferença |
      | PAO-UN   | -2        |
      | MAN-200G | +2        |
      | CAF-250G | 0         |
    Quando Cesar finaliza a contagem
    Então o status da contagem fica "completed"
    E é gerado um movimento "adjustment_out" de 2 unidades para "PAO-UN"
    E é gerado um movimento "adjustment_in" de 2 unidades para "MAN-200G"
    E nenhum movimento é gerado para "CAF-250G" (diferença zero)
    E o saldo de "PAO-UN" passa a ser 48
    E o saldo de "MAN-200G" passa a ser 42

  Cenário: No máximo uma contagem em progresso por organization
    Dado que existe uma contagem com status "in_progress"
    Quando Cesar tenta iniciar outra contagem
    Então a operação é rejeitada com a mensagem "Já existe uma contagem em andamento"

  Cenário: Contagem em draft pode ser descartada
    Dado uma contagem com status "draft"
    Quando Cesar descarta a contagem
    Então a contagem é removida sem afetar saldos nem gerar movimentos

  Cenário: Contagem completed é imutável
    Dado uma contagem com status "completed"
    Quando Cesar tenta editar qualquer quantidade contada
    Então a operação é rejeitada
    E correções exigem uma nova contagem ou ajuste manual
