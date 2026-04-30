# language: pt

Funcionalidade: Arredondamento monetário e absorção de resíduo
  Toda vez que o sistema divide um valor total em parcelas proporcionais
  (parcelas de payment_term, rateio de despesas acessórias, comissão por CAR),
  aplica arredondamento HALF_UP em escala 2 e atribui o resíduo à última
  parte para garantir que a soma das partes bata exata com o total.

  Cenário: Modo HALF_UP arredonda 0,005 para cima
    Quando o sistema arredonda R$ 0,005 para escala 2
    Então o valor arredondado é R$ 0,01
    # diferente de banker's rounding (HALF_EVEN), que arredondaria para 0,00

  Cenário: Modo HALF_UP arredonda 0,004 para baixo
    Quando o sistema arredonda R$ 0,004 para escala 2
    Então o valor arredondado é R$ 0,00

  Cenário: Divisão de R$ 100,00 em 3 parcelas (33,33% / 33,33% / 33,34%)
    Quando o sistema divide R$ 100,00 conforme os percentuais 33,33% / 33,33% / 33,34%
    Então as parcelas geradas são:
      | sequence | pct   | amount   |
      | 1        | 33,33 | R$ 33,33 |
      | 2        | 33,33 | R$ 33,33 |
      | 3        | 33,34 | R$ 33,34 |
    E a soma das parcelas fecha exatamente em R$ 100,00

  Cenário: Última parcela absorve resíduo positivo
    Dado um valor total de R$ 1.000,00 a dividir em 7 parcelas iguais
    # 1.000 / 7 = 142,857142… → arredondando HALF_UP para cada parcela daria 142,86
    # 7 × 142,86 = 1.000,02 (sobra de R$ 0,02)
    Quando o sistema gera as parcelas
    Então 6 parcelas ficam em R$ 142,86 e a última em R$ 142,84
    E a soma fecha exatamente em R$ 1.000,00

  Cenário: Resíduo pode ser negativo (última parcela paga menos)
    Dado um valor total de R$ 0,01 a dividir em 3 parcelas iguais
    Quando o sistema gera as parcelas
    Então as 2 primeiras parcelas ficam em R$ 0,00
    E a última parcela fica em R$ 0,01
    # garantia: a soma sempre bate com o total, mesmo em centavos

  Cenário: Cálculo intermediário pode ter mais precisão; persistido respeita escala 2
    Dado um item com base "net" calculada como R$ 545,4545454…
    Quando a comissão de 5% é calculada e persistida
    Então o valor intermediário (em memória) é 27,272727…
    E o valor persistido no Bill é R$ 27,27
    # arredondamento HALF_UP só no momento de persistir

  Cenário: Bills de comissão por CAR somam exatamente a comissão total da invoice
    Dado uma invoice com comissão total de R$ 100,00
    E 3 CARs com proporções 33,33% / 33,33% / 33,34% (total R$ 1.000,00)
    Quando os 3 CARs são pagos em momentos distintos
    Então os Bills de comissão gerados são R$ 33,33 / R$ 33,33 / R$ 33,34
    E a soma dos Bills fecha exatamente em R$ 100,00

  Cenário: Rateio proporcional de despesa acessória respeita escala 2
    Dado um frete de R$ 228,00 a ratear sobre dois itens (subtotais R$ 1.800 e R$ 480; total R$ 2.280)
    Quando o sistema calcula o rateio proporcional
    Então o item 1 absorve R$ 180,00
    # 228 × (1.800 / 2.280) = 180,000…
    E o item 2 absorve R$ 48,00
    # 228 × (480 / 2.280) = 48,000…
    E a soma fecha em R$ 228,00 (sem resíduo neste exemplo)

  Cenário: Rateio com resíduo é absorvido no último item
    Dado um frete de R$ 100,00 a ratear igualmente entre 3 itens
    # 100 / 3 = 33,333… → 2 itens × 33,33 = 66,66; resta 33,34
    Quando o sistema calcula o rateio com apportionment "equal"
    Então 2 itens absorvem R$ 33,33 cada
    E o último item absorve R$ 33,34
    E a soma é exatamente R$ 100,00
