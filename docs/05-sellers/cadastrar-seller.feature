# language: pt

Funcionalidade: Cadastrar seller (interno ou externo)
  Sellers podem ser internos (usuários do sistema com login) ou externos
  (representantes comerciais sem acesso ao ERP). Ambos são atribuídos a
  pedidos e recebem comissão; a diferença está apenas na autenticação.

  Contexto:
    Dado a organization "Padaria do Cesar LTDA"

  Cenário: Cadastrar seller interno ligado a um user do Better Auth
    Dado um user autenticado "Ana" no Better Auth
    Quando Cesar cadastra o seller:
      | Campo                   | Valor |
      | Vinculado ao user       | Ana   |
      | Comissão default (%)    | 5,00  |
      | Base de comissão        | net   |
    Então o seller "Ana" é criado e ligado ao user do Better Auth
    E os campos de e-mail e telefone do seller são ignorados (a fonte de verdade é o user do auth)

  Cenário: Cadastrar seller externo com e-mail e telefone
    Quando Cesar cadastra o seller:
      | Campo                | Valor                 |
      | Vinculado ao user    | (vazio)               |
      | Nome                 | Rafael Representante  |
      | E-mail               | rafael@reps.com       |
      | Telefone             | (11) 99999-1234       |
      | Comissão default (%) | 7,50                  |
      | Base de comissão     | gross                 |
    Então o seller "Rafael Representante" é criado sem vínculo com user
    E o e-mail e o telefone são usados como canais de contato

  Cenário: Seller precisa ter pelo menos um canal identificável
    Quando Cesar tenta cadastrar um seller sem user, sem e-mail e sem telefone
    Então o cadastro é rejeitado com a mensagem "Informe um user, e-mail ou telefone"

  Cenário: Um único seller por user por organization
    Dado que "Ana" já é seller da "Padaria do Cesar LTDA"
    Quando Cesar tenta cadastrar outro seller vinculado ao mesmo user "Ana" na mesma organization
    Então o cadastro é rejeitado com a mensagem "Este user já é seller nesta organization"

  Cenário: Seller inativo é oculto de novos pedidos
    Dado o seller "Rafael" em uso
    Quando Cesar desativa o seller
    Então "Rafael" não aparece em formulários de novo pedido
    Mas pedidos e comissões antigas associados a "Rafael" continuam acessíveis no histórico

  Cenário: User do Better Auth removido da organization preserva o seller
    Dado o seller "Ana" vinculado ao user "Ana" da Better Auth
    E "Ana" tem 10 sales_orders e 3 Bills de comissão
    Quando o user "Ana" é removido como membro da organization (via Better Auth)
    Então o seller "Ana" continua existindo
    E os sales_orders e Bills de comissão continuam ligados ao seller (auditoria preservada)
    Mas "Ana" não consegue mais logar para emitir pedidos
    # seller.user_id continua apontando para o user removido — não é cascata

  Cenário: Deletar seller sem documentos é permitido
    Dado o seller "Externo Teste" sem nenhum sales_order, Bill de comissão ou contact (default_seller) apontando
    Quando Cesar deleta o seller
    Então o seller é removido

  Cenário: Deletar seller em uso é bloqueado
    Dado o seller "Ana" referenciado por 10 sales_orders e 3 Bills
    Quando Cesar tenta deletar o seller
    Então a operação é rejeitada com a mensagem "Seller em uso por 10 sales_order(s) e 3 Bill(s) — desative em vez de deletar"
    # para "aposentar" sem deletar, marcar is_active = false
