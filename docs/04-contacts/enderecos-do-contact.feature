# language: pt

Funcionalidade: Endereços do contact
  Um contact pode ter múltiplos endereços, cada um com uma finalidade:
  "main" (principal), "billing" (cobrança/fiscal) e "shipping" (entrega).
  Para cada tipo, um endereço pode ser marcado como default.

  Contexto:
    Dado a organization "Padaria do Cesar LTDA"
    E o customer "Restaurante Sabor"

  Cenário: Um contact pode ter vários endereços classificados
    Quando Cesar vincula ao customer:
      | Endereço                                          | Tipo     | Default? |
      | Av. Principal, 100 — Centro, SP                   | main     | sim      |
      | Rua Contador, 50 — Centro, SP                     | billing  | sim      |
      | Rua Entrega, 80 — Distrito Industrial, Guarulhos  | shipping | sim      |
      | Rua Entrega 2, 15 — Distrito Norte, Guarulhos     | shipping | não      |
    Então o customer passa a ter 4 endereços vinculados
    E existe exatamente 1 endereço default do tipo "main"
    E existe exatamente 1 endereço default do tipo "billing"
    E existe exatamente 1 endereço default do tipo "shipping"

  Cenário: Marcar outro endereço como default do mesmo tipo
    Dado o customer com 2 endereços "shipping": "Entrega" (default) e "Entrega 2" (não default)
    Quando Cesar marca "Entrega 2" como default
    Então "Entrega 2" vira default
    E "Entrega" deixa de ser default automaticamente

  Cenário: Endereço de billing default alimenta a nota fiscal
    Dado o customer com endereço "billing" default "Rua Contador, 50 — SP"
    Quando uma invoice é emitida para esse customer
    Então o customer_snapshot da invoice usa o endereço "billing" default

  Cenário: Endereço de shipping default sugere entrega no pedido
    Dado o customer com endereço "shipping" default "Rua Entrega, 80"
    Quando Cesar cria um pedido de venda para o customer
    Então o campo de endereço de entrega vem pré-preenchido com "Rua Entrega, 80"
    Mas Cesar pode selecionar outro endereço "shipping" do mesmo contact

  Cenário: Endereços compartilham a tabela global de endereços
    Dado o contact "Restaurante Sabor" com endereço "Av. Principal, 100"
    E a organization "Padaria do Cesar LTDA" também usando "Av. Principal, 100" como endereço fiscal
    Quando Cesar inspeciona os endereços cadastrados
    Então não existe duplicação nos campos street/city/state/zipCode — o mesmo endereço é referenciado pelos dois
