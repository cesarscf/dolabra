# Globais

Convenções e regras transversais que não têm dono único. Cada regra tem o seu detalhamento completo e cenários no módulo onde ela faz sentido — esta pasta serve como índice e definição mínima das convenções.

## Conteúdo

- **Arredondamento monetário** ([feature](./arredondamento-monetario.feature)) — escala, modo de arredondamento e absorção de resíduo. Aplica em geração de CARs, Bills, rateio de despesas e cálculo de comissão.
- **Convenção de delete** (seção abaixo) — quando entidades aceitam delete físico vs. apenas inativação.
- **Validação de documentos brasileiros** (seção abaixo) — CNPJ, CPF, GTIN, NCM, CFOP, UF, CEP.
- **Idempotência de eventos transacionais** (seção abaixo) — geração de CAR/Bill/comissão.

## Permissões (deferred)

A matriz de roles × operações fica fora deste documento até o core do MVP estar implementado. As features que mencionam "admin"/"owner" hoje (aprovar SO, encerrar PO manualmente, criar Bill manual) refletem o **mínimo já decidido** — o restante das operações ficará sem restrição até o módulo de permissões granulares ser desenhado em uma extensão futura.

---

## Arredondamento monetário

- **Escala**: 2 casas decimais para campos persistidos em R$ (`amount`, `total`, `paid_amount`, `extra_amount`, `unit_price`, `discount_total`, …).
- **Modo**: HALF_UP (5 arredonda para cima — diferente de banker's rounding).
- **Absorção de resíduo**: a última parte de uma divisão proporcional absorve o delta para que a soma das partes feche exatamente com o total.
- Cálculos intermediários (ex.: base "net" da comissão, custo unitário efetivo no recebimento) podem usar precisão maior internamente — apenas o **valor persistido** respeita escala 2.

Cenários canônicos em [arredondamento-monetario.feature](./arredondamento-monetario.feature). Cada feature que faz divisão proporcional referencia essa convenção em comentário inline.

## Convenção de delete

Padrão único do MVP:

> **Delete físico é bloqueado quando a entidade está em uso. Caso contrário, é permitido.**

- "Em uso" = existe ao menos um documento (sales_order, purchase_order, invoice, CAR, Bill, stock_movement, payment) ou outra entidade que referencia o registro.
- A mensagem de erro identifica o uso (`"X em uso por N produto(s)"`, `"em uso por 3 sales_orders"`) para o usuário decidir como reatribuir.
- Para "aposentar" entidades em uso sem deletar, cada módulo expõe inativação via status:
  - `product.status = archived` (irreversível) — ver [Products](../02-products/README.md).
  - `contact.status = inactive | blocked` — ver [Contacts](../04-contacts/README.md).
  - `seller.is_active = false` — ver [Sellers](../05-sellers/README.md).
- Documentos imutáveis (movimentos de estoque, snapshots fiscais) **não** aceitam delete — correções acontecem por movimento compensatório ou cancelamento.
- Pagamentos (`car_payment`, `bill_payment`) usam status `effective | cancelled` para estorno (ver [Financial → B20](../09-financial/README.md#b20-estorno-de-pagamento-via-cancelamento)).

Cada módulo documenta o cenário concreto de "deletar X em uso" e "deletar X sem uso" no seu próprio `.feature`.

**Sem `deleted_at` ou soft-delete genérico no MVP** — adiciona ruído em queries. Quando aparecer requisito real de restauração, vira extensão.

## Validação de documentos brasileiros

| Documento | Armazenamento | Validação MVP |
|---|---|---|
| **CNPJ** | 14 dígitos sem máscara | Comprimento + dígito verificador (DV) |
| **CPF** | 11 dígitos sem máscara | Comprimento + dígito verificador (DV) |
| **GTIN/EAN** | 8/12/13/14 dígitos | Comprimento + DV (apenas quando preenchido — campo opcional) |
| **NCM** | 8 dígitos | Comprimento (sem validar contra tabela oficial no MVP) |
| **CFOP** | 4 dígitos | Comprimento |
| **CSOSN** | 3 dígitos | Comprimento + coerência com `tax_regime` (ver [Tax Groups](../10-tax-groups/README.md)) |
| **CST** | 2 dígitos | Comprimento + coerência com `tax_regime` |
| **UF** | 2 letras | Lista oficial das 27 UFs (sigla) |
| **CEP** | 8 dígitos sem hífen | Comprimento |

A UI sempre aceita entrada com máscara/formatação — a normalização para "só dígitos" acontece antes da persistência.

Validação contra tabelas oficiais (NCMs válidos, CFOPs por operação, IE por UF) fica para pós-MVP, junto com emissão nativa de NF-e.

## Idempotência de eventos transacionais

O MVP não usa job scheduler nem outbox — efeitos colaterais acontecem **dentro da mesma transação** que dispara o evento.

| Disparo | Efeito | Garantia de não-duplicação |
|---|---|---|
| Emitir invoice (`draft → issued`) | N CARs (1 por parcela), N stock_movements (1 por SKU), snapshots fiscal e do customer | UNIQUE `(invoice_id, installment_number)` no CAR; transação atômica |
| Confirmar PO (`draft → confirmed`) | N Bills (1 por parcela) | UNIQUE `(purchase_order_id, installment_number)` no Bill |
| Registrar receipt | 1 stock_movement `in` por linha do receipt | Movimento referencia `purchase_receipt_item.id` (registro único) |
| CAR vira `paid` | 1 Bill com `origin = commission` | UNIQUE `(car_id)` no Bill onde `origin = commission` |

Falha em qualquer passo desfaz todos os anteriores. Não há retry automático no MVP — o usuário re-tenta a ação na UI.
