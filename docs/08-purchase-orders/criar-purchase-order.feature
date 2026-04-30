# language: pt

Funcionalidade: Criar um pedido de compra
  Um pedido de compra registra o que a empresa vai comprar de um supplier.
  Itens, custos unitários negociados e despesas acessórias (frete, seguro,
  ICMS-ST) ficam no pedido para depois serem rateados ao custo de aquisição
  no momento do recebimento.

  Contexto:
    Dado a loja "Padaria do Cesar LTDA"
    E o supplier "Moinho Central"
    E os SKUs "FARINHA-25KG" e "ACUCAR-5KG"
    E o payment_term "À vista" (1 parcela, 0 dias, 100%)

  Cenário: Criar pedido com itens
    Quando Cesar cadastra o pedido de compra:
      | Supplier       | Expected date | Payment term |
      | Moinho Central | 2026-05-05    | À vista      |
    E adiciona os itens:
      | SKU          | Qty | Unit cost (R$) |
      | FARINHA-25KG | 20  | 90,00          |
      | ACUCAR-5KG   | 40  | 12,00          |
    Então o subtotal é R$ 2.280,00
    # 20 × 90 + 40 × 12 = 1.800 + 480 = 2.280
    E o total é R$ 2.280,00 (sem despesas acessórias ainda)

  Cenário: Adicionar despesas acessórias
    Dado o pedido com subtotal R$ 2.280,00
    Quando Cesar adiciona as despesas:
      | Tipo      | Descrição       | Amount | Apportionment |
      | freight   |                 | 150,00 | proportional  |
      | insurance |                 | 30,00  | equal         |
      | other     | Taxa de entrada | 20,00  | manual        |
    Então accessory_expenses_total é R$ 200,00
    E o total do pedido passa para R$ 2.480,00

  Cenário: Pedido recebe número sequencial PO
    Dado que 2 pedidos de compra já foram criados
    Quando Cesar salva um novo pedido de compra
    Então o número gerado é "PO-000003"

  Cenário: Supplier precisa ter type incluindo "supplier"
    Dado o contact "Restaurante Sabor" como customer puro
    Quando Cesar tenta criar um pedido de compra para "Restaurante Sabor"
    Então a operação é rejeitada com a mensagem "Contact não é supplier"

  Cenário: Purchase order exige payment_term
    Quando Cesar tenta salvar um pedido de compra sem payment_term
    Então a operação é rejeitada com a mensagem "Condição de pagamento é obrigatória"
