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

  Cenário: Movimento durante a contagem afeta o saldo, não o snapshot do count
    Dado uma contagem em "in_progress" com PAO-UN com system_quantity = 50 (snapshot do início)
    E o usuário ainda não informou counted_quantity para PAO-UN
    Quando um purchase_receipt registra +10 unidades de PAO-UN durante a contagem
    Então o saldo atual de PAO-UN passa a 60
    Mas o system_quantity do inventory_count_item para PAO-UN continua em 50
    Quando o usuário informa counted_quantity = 48 e fecha a contagem
    Então a difference do count é -2 (relativa ao snapshot, não ao saldo atual)
    E é gerado um adjustment_out de 2 unidades para PAO-UN
    E o saldo final de PAO-UN é 58 (60 - 2)
    # ajustes do count são DELTAS (counted - system_snapshot), não absolutos.
    # Isso preserva movimentos concorrentes sem sobrescrevê-los.

  Cenário: Conferência simultânea de SKU contado é prevenida no fechamento
    Dado uma contagem em "in_progress" com counted_quantity informado para todos os itens
    E um operador tenta registrar um ajuste manual no mesmo SKU enquanto a contagem está aberta
    Então o ajuste manual é aceito normalmente
    # contagem não bloqueia outros movimentos — usa snapshot+delta (ver cenário acima)
