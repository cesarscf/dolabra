# language: pt

Funcionalidade: Numerar documentos sequencialmente
  Pedidos de venda, pedidos de compra e notas fiscais recebem um número
  legível, único por organization, para que o time consiga se referir a eles
  sem ambiguidade. A geração precisa ser atômica: mesmo com vários operadores
  criando documentos ao mesmo tempo, dois documentos nunca compartilham o
  mesmo número.

  Contexto:
    Dado a organization "Padaria do Cesar LTDA"

  Cenário: Primeiro documento de cada tipo começa em 1
    Quando o primeiro pedido de venda da empresa é criado
    E o primeiro pedido de compra da empresa é criado
    E a primeira nota fiscal da empresa é emitida
    Então os números gerados são:
      | Documento        | Número     |
      | Pedido de venda  | SO-000001  |
      | Pedido de compra | PO-000001  |
      | Nota fiscal      | INV-000001 |

  Cenário: Sequências por tipo são independentes entre si
    Dado que já foram emitidos 3 pedidos de venda e 2 notas fiscais
    Quando um novo pedido de compra é criado
    Então o número do pedido de compra é "PO-000001"
    E o próximo pedido de venda continuará sendo "SO-000004"
    E a próxima nota fiscal continuará sendo "INV-000003"

  Cenário: Cada organization tem sua própria sequência
    Dado que a "Padaria do Cesar LTDA" já emitiu 10 notas fiscais
    E existe outra organization "Bicicletaria Express LTDA" que ainda não emitiu nenhuma
    Quando a "Bicicletaria Express LTDA" emite sua primeira nota fiscal
    Então o número dessa nota é "INV-000001"

  Cenário: Concorrência não gera números duplicados
    Quando 5 pedidos de venda são criados ao mesmo tempo por operadores diferentes da mesma organization
    Então cada pedido recebe um número distinto
    E os números formam a sequência contínua de "SO-000001" a "SO-000005"

  Cenário: Número interno da nota é distinto do número da NF-e emitida externamente
    Quando uma nota fiscal é emitida internamente como "INV-000042"
    E o usuário registra manualmente "0000999" como número da NF-e emitida externamente
    Então o número interno "INV-000042" identifica a nota no Dolabra
    E o número fiscal "0000999" identifica a nota no fisco
    E nenhum dos dois sobrescreve o outro

  Cenário: Numeração da invoice é lazy — só atribuída na emissão
    Dado que a próxima invoice da empresa seria "INV-000010"
    Quando Cesar prepara uma invoice em "draft" a partir de um pedido
    Então o draft existe sem número da sequência INV
    Quando Cesar emite a invoice (transição draft → issued)
    Então a invoice recebe o número "INV-000010"
    E a próxima invoice a ser emitida receberá "INV-000011"

  Cenário: Draft de invoice descartado não consome número da sequência
    Dado que a próxima invoice da empresa seria "INV-000010"
    Quando Cesar prepara um draft de invoice e logo descarta
    Então nenhum número INV foi consumido
    E a próxima invoice emitida ainda receberá "INV-000010"
