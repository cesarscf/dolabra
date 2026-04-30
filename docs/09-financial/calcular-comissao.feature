# language: pt

Funcionalidade: Cálculo de comissão (disparado por CAR paid)
  Comissão é paga no ritmo em que o dinheiro entra. Cada CAR que atinge
  "paid" gera um Bill de comissão proporcional à fração da invoice que
  aquele CAR representa. Bills de comissão são imutáveis uma vez gerados.

  Contexto:
    Dado a organization "Padaria do Cesar LTDA"
    E o seller "Ana" com default_commission_pct 5% e commission_base "gross"
    E a categoria "Bolos" com override de comissão 8% para Ana
    E uma invoice emitida no valor total de R$ 1.000,00 ligada a um sales_order do seller "Ana"

  Cenário: Comissão total da invoice soma por item
    Dado os itens da invoice (e do sales_order originador):
      | Item       | Categoria | Item total | Taxa aplicada |
      | PAO-UN     | Pães      | R$ 600,00  | 5% (default)  |
      | BOLO-FUBA  | Bolos     | R$ 400,00  | 8% (override) |
    # Pães não tem override, usa default; Bolos tem override
    Quando a comissão total é calculada para a invoice
    Então a soma fica em R$ 62,00
    # 600 × 0,05 + 400 × 0,08 = 30 + 32 = 62

  Cenário: Bill de comissão por CAR é proporcional
    Dado a invoice gera 2 CARs (50/50) de R$ 500,00 cada
    E a comissão total da invoice é R$ 62,00
    Quando o CAR "1 de 2" vira "paid"
    Então um Bill de comissão é gerado:
      | origin     | amount   | seller_id | supplier_id |
      | commission | R$ 31,00 | Ana       | (vazio)     |
    # 31 = (500 / 1000) × 62

    Quando o CAR "2 de 2" vira "paid" mais tarde
    Então um novo Bill de comissão é gerado com mais R$ 31,00 para Ana
    E o total pago de comissão sobre esta invoice soma R$ 62,00

  Cenário: Base "net" inclui rateio do desconto do pedido
    Dado o sales_order origem tinha subtotal R$ 1.100,00 e discount_total R$ 100,00
    E o seller usa base "net"
    E um item do pedido/invoice tinha total R$ 600,00
    Quando a comissão do item é calculada
    Então a base do item é R$ 545,45
    # 600 × (1 - 100/1100) = 545,4545…
    E a comissão do item é 5% × 545,45 = R$ 27,27

  Cenário: Produto sem categoria usa sempre default
    Dado um item da invoice para um produto sem categoria (com total R$ 200,00)
    E a base do seller é "gross"
    Quando a comissão é calculada
    Então a taxa usada é 5% (default do seller)
    # não existe fallback de catch-all

  Cenário: Invoice cancelada após CARs pagos — Bills permanecem
    Dado 2 CARs paid, cada um tendo gerado R$ 31,00 de Bill de comissão
    Quando a invoice é cancelada
    Então os 2 Bills de comissão continuam devidos a Ana
    # dinheiro entrou; comissão é devida

  Cenário: CAR cancelado individualmente não gera Bill
    Dado um CAR "pending" ainda sem Bill de comissão
    Quando a invoice é cancelada (e o CAR vira "cancelled")
    Então nenhum Bill de comissão é gerado para esse CAR

  Cenário: Rateio de comissão arredonda com precisão controlada
    Dado a invoice gera 3 CARs (33,33% / 33,33% / 33,34%)
    E a comissão total é R$ 100,00
    Quando os 3 CARs são pagos em momentos diferentes
    Então os 3 Bills de comissão gerados somam exatamente R$ 100,00
    # o último absorve o arredondamento

  Cenário: Bill de comissão vence no mesmo dia em que é gerado (MVP)
    Dado um CAR pago em 2026-04-23
    Quando o Bill de comissão é gerado
    Então due_date do Bill é 2026-04-23
    # vencimento imediato no MVP, vira setting da org no futuro

  Cenário: Recebimento em excesso (juros) não infla a comissão
    Dado um CAR de R$ 500,00 e a comissão proporcional seria R$ 25,00
    E o cliente paga R$ 520,00 (R$ 20,00 de juros)
    Quando o CAR vira "paid"
    Então o paid_amount do CAR é R$ 520,00
    E o extra_amount do CAR é R$ 20,00
    E o Bill de comissão gerado é R$ 25,00 (calculado sobre o amount original, não sobre o pago)
