# language: pt

Funcionalidade: Endereços reutilizáveis por lojas e contacts
  Endereços vivem numa entidade própria, reutilizada por quem precisa de
  endereço físico (loja, contact, no futuro filiais etc.). Isso evita
  duplicação e mantém os campos do endereço (rua, cidade, UF, CEP) em um
  único lugar.

  Cenário: Vincular endereço à loja
    Dado a loja "Padaria do Cesar LTDA"
    Quando o endereço "Rua das Flores, 123 — Centro, São Paulo/SP — 01010-000" é cadastrado e vinculado à loja
    Então a loja passa a exibir esse endereço como endereço fiscal

  Cenário: Endereços também são escopados por loja
    Dado a loja "Padaria do Cesar LTDA" com um endereço cadastrado
    E a loja "Bicicletaria Express LTDA" sem nenhum endereço
    Quando se consulta endereços da "Bicicletaria Express LTDA"
    Então o endereço da padaria não aparece

  Cenário: Contact com múltiplos endereços classificados por tipo
    Dado o customer "Restaurante Sabor"
    Quando Cesar cadastra para o restaurante:
      | Tipo     | Endereço                                                  | Default? |
      | main     | Av. Principal, 100 — Centro, São Paulo/SP — 01000-000     | sim      |
      | billing  | Rua Contador, 50 — Centro, São Paulo/SP — 01000-500       | sim      |
      | shipping | Rua Entrega, 80 — Distrito Industrial, Guarulhos/SP        | sim      |
      | shipping | Rua Entrega 2, 15 — Distrito Norte, Guarulhos/SP           | não      |
    Então o restaurante tem 4 endereços vinculados
    E existe exatamente um endereço default por tipo
    E ao emitir uma nota, o sistema usa o endereço "billing" default para fiscal
    E ao despachar uma entrega, o sistema usa o endereço "shipping" default como sugestão

  Cenário: UF e CEP seguem o formato brasileiro
    Quando Cesar tenta cadastrar um endereço com UF "São Paulo"
    Então o cadastro é rejeitado com a mensagem "UF deve ter 2 letras (ex.: SP)"

    Quando Cesar cadastra um endereço com UF "SP" e CEP "01010-000"
    Então o endereço é aceito
    E o CEP é armazenado sem hífen como "01010000"
