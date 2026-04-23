# language: pt

Funcionalidade: Rateio de despesas acessórias no custo do recebimento
  Frete, seguro, ICMS-ST e outras despesas são rateados entre os itens no
  momento do recebimento, somando ao unit_cost e alimentando o cálculo do
  custo médio. Em recebimentos parciais, o rateio vai proporcional à
  fração efetivamente recebida — evitando distorcer o custo médio com
  despesas "adiantadas".

  Contexto:
    Dado a organization "Padaria do Cesar LTDA"
    E um pedido de compra "PO-000001" em "confirmed" com os itens:
      | SKU          | Qty pedida | Unit cost | Subtotal  |
      | FARINHA-25KG | 20         | R$ 90,00  | R$ 1.800  |
      | ACUCAR-5KG   | 40         | R$ 12,00  | R$ 480,00 |
    E a despesa acessória:
      | Tipo    | Amount     | Apportionment |
      | freight | R$ 228,00  | proportional  |
    # subtotal total = 2.280. proporção: FARINHA = 1800/2280, ACUCAR = 480/2280

  Cenário: Rateio proporcional ao subtotal do item (PO total)
    Quando o sistema calcula quanto de frete cabe a cada item no PO completo
    Então FARINHA-25KG absorve R$ 180,00 do frete
    # 228 × (1800/2280) = 180
    E ACUCAR-5KG absorve R$ 48,00 do frete
    # 228 × (480/2280) = 48

  Cenário: Receipt parcial aplica fração recebida sobre o rateio do item
    Dado recebimento parcial de 10 unidades de FARINHA-25KG (50% do pedido de 20)
    Quando o sistema calcula o frete atribuído a este receipt
    Então o frete deste receipt para FARINHA-25KG é R$ 90,00
    # R$ 180 × (10 / 20) = 90
    E o unit_cost efetivo de FARINHA-25KG neste receipt é R$ 99,00
    # 90 (custo unitário) + 90 (frete rateado) / 10 (qty) = 99

  Cenário: Apportionment "equal" divide em partes iguais por item
    Dado uma despesa com apportionment "equal" no valor de R$ 200,00
    E o pedido tem 2 itens
    Quando o sistema calcula o rateio
    Então cada item recebe R$ 100,00 do total da despesa (para o PO completo)

  Cenário: Apportionment "manual" respeita percentuais definidos pelo usuário
    Dado uma despesa com apportionment "manual" no valor de R$ 200,00
    E o usuário informou: FARINHA-25KG 70%, ACUCAR-5KG 30%
    Quando o sistema calcula o rateio
    Então FARINHA-25KG absorve R$ 140,00 da despesa
    E ACUCAR-5KG absorve R$ 60,00 da despesa

  Cenário: Receipts sucessivos não re-rateiam retroativamente
    Dado que FARINHA-25KG já teve um receipt parcial que absorveu R$ 90 de frete
    Quando um segundo receipt chega com 5 unidades adicionais de FARINHA-25KG
    Então o frete atribuído a este receipt para FARINHA-25KG é proporcional às 5 unidades sobre o total pedido (20)
    # R$ 180 × (5 / 20) = 45
    E movimentos anteriores NÃO são alterados

  Cenário: PO encerrada abaixo do esperado deixa delta no limbo (MVP)
    Dado um PO com 20 unidades pedidas de FARINHA-25KG e R$ 180,00 rateados no total
    E apenas 10 unidades foram entregues e o PO é considerado encerrado
    Quando o fluxo atual termina sem re-rateio retroativo
    Então R$ 90,00 de frete "não rateado" fica no limbo
    # ajuste de custo no fechamento da PO é pós-MVP
