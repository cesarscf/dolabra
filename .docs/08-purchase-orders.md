# Pedidos de Compra

## Diagrama de arquitetura

```
╔══════════════════════════════════════════════════════════════════════╗
║                 PURCHASE ORDER — FLUXO COMPLETO                      ║
╚══════════════════════════════════════════════════════════════════════╝

  FLUXO DE STATUS:

    ┌───────┐    ┌───────────┐    ┌───────────────────┐    ┌──────────┐
    │ draft │───►│ confirmed │───►│partially_received │───►│ received │
    └───────┘    └─────┬─────┘    └───────────────────┘    └──────────┘
        │              │                    ▲
        │              │                    │ cada recebimento
        ▼              ▼                    │
    ┌───────────┐  ┌──────────────┐         │
    │ cancelled │  │    BILL      │  ┌──────────────────┐
    │ (só sem   │  │  (contas a   │  │ PURCHASE RECEIPT │
    │  receipt) │  │   pagar)     │  │  (parcial ok)    │
    └───────────┘  └──────────────┘  └────────┬─────────┘
                        ▲                     │
                        │ cancelado           │ por item recebido:
                        │ se PO cancelada     ▼
                                     ┌─────────────────────┐
                                     │    STOCK MOVEMENT   │
                                     │    type: in         │
                                     │    unit_cost =      │
                                     │    custo do item +  │
                                     │    despesas         │
                                     │    rateadas         │
                                     └──────────┬──────────┘
                                                │ atualiza
                                                ▼
                                     ┌─────────────────────┐
                                     │   STOCK BALANCE     │
                                     │   quantity  ▲       │
                                     │   avg_cost  ~       │
                                     └─────────────────────┘

  DESPESAS ACESSÓRIAS (rateadas ao custo de aquisição):

    PURCHASE ORDER
    └── expenses[]
        ├── freight    ─┐
        ├── insurance   ├── rateadas (proportional | equal | manual)
        ├── icms_st     │   sobre o unit_cost de cada item no recebimento
        └── other      ─┘

  ESTRUTURA DO PURCHASE ORDER:

    PURCHASE ORDER
    ├── supplier_id ──► CONTACT (type: supplier)
    └── items[]
        ├── sku_id   ──► SKU
        ├── quantity
        ├── unit_cost
        └── received_quantity (acumulada entre recebimentos)
```

Um purchase order registra a intenção de comprar produtos de um supplier. Dispara a entrada de estoque, atualização de custos e a geração de contas a pagar.

## Fluxo de status

```
draft → confirmed → partially_received → received → cancelled
```

| Status | Comportamento |
|---|---|
| `draft` | Em construção. Totalmente editável. Sem efeitos financeiros ou de estoque. |
| `confirmed` | Enviado ao supplier. Bill (contas a pagar) gerado. Read-only. |
| `partially_received` | Ao menos um recebimento registrado. Estoque incrementado dos itens recebidos. |
| `received` | Todos os itens totalmente recebidos. |
| `cancelled` | Anulado. Só permitido antes de qualquer recebimento. Bill é cancelado. Imutável. |

## Purchase order

| Campo | Tipo | Observações |
|---|---|---|
| `id` | uuid | |
| `organization_id` | uuid | Chave de tenancy |
| `number` | string | Número legível do pedido (ex.: `PO-000001`). Gerado via `document_sequence` — ver `01-foundation.md` |
| `status` | enum | Ver fluxo de status acima |
| `supplier_id` | uuid | FK → `contact` (type precisa incluir `supplier`) |
| `expected_date` | date | Data esperada de entrega. Nullable |
| `payment_term_id` | uuid | FK → `payment_term` (ver `09-financial.md`). Condição de pagamento ao fornecedor. Obrigatório |
| `subtotal` | decimal | Soma dos totais dos itens |
| `accessory_expenses_total` | decimal | Soma dos valores de todas as despesas acessórias |
| `total` | decimal | `subtotal + accessory_expenses_total` |
| `confirmed_at` | timestamp | Nullable. Preenchido na transição para `confirmed` — usado como base para cálculo dos `due_date` dos Bills gerados |
| `notes` | text | Nullable |
| `created_at` | timestamp | |
| `updated_at` | timestamp | |

## Itens do purchase order

| Campo | Tipo | Observações |
|---|---|---|
| `id` | uuid | |
| `purchase_order_id` | uuid | FK → `purchase_order` |
| `sku_id` | uuid | FK → `sku` |
| `quantity` | decimal | Quantidade pedida |
| `received_quantity` | decimal | Quantidade acumulada recebida em todos os receipts. Default `0` |
| `unit_cost` | decimal | Custo unitário acordado |
| `total` | decimal | Calculado: `quantity × unit_cost` |

## Despesas acessórias

Custos extras atrelados à compra (frete, seguro, ICMS-ST, etc.) que são rateados entre os itens para compor o custo de aquisição real por SKU.

**`purchase_order_expense`**

| Campo | Tipo | Observações |
|---|---|---|
| `id` | uuid | |
| `purchase_order_id` | uuid | |
| `type` | enum | `freight \| insurance \| icms_st \| other` |
| `description` | string | Nullable. Usado quando `type = other` |
| `amount` | decimal | |
| `apportionment` | enum | `proportional \| equal \| manual` — como o custo é distribuído entre os itens |

O custo rateado é somado ao `unit_cost` de cada item no cálculo da atualização do `average_cost` no momento do recebimento. Em recebimentos parciais, o rateio é **proporcional à fração recebida** (ver "Cálculo do unit_cost efetivo em receipts parciais" abaixo).

### Cálculo do unit_cost efetivo em receipts parciais

Para cada item em cada receipt:

```
qty_this_receipt   = purchase_receipt_item.quantity
qty_expected_total = purchase_order_item.quantity

Para cada purchase_order_expense:
  base_de_rateio conforme apportionment:
    proportional → (item.subtotal / sum(items.subtotal))
    equal        → 1 / count(items)
    manual       → pct definido pelo usuário por item

  expense_for_item_total   = expense.amount × base_de_rateio
  expense_for_this_receipt = expense_for_item_total × (qty_this_receipt / qty_expected_total)

unit_cost efetivo = item.unit_cost + sum(expense_for_this_receipt) / qty_this_receipt
```

Consequências:
- Custo médio fica coerente desde o primeiro receipt — sem re-cálculo retroativo nos seguintes.
- Se a PO nunca atingir 100% (supplier entregou menos), o delta de despesas não rateadas fica no limbo no MVP. Ajuste de custo no fechamento da PO fica para pós-MVP.

## Recebimentos

Recebimento parcial é suportado. Cada receipt registra o que realmente chegou.

**`purchase_receipt`**

| Campo | Tipo | Observações |
|---|---|---|
| `id` | uuid | |
| `organization_id` | uuid | |
| `purchase_order_id` | uuid | FK → `purchase_order` |
| `received_at` | timestamp | |
| `notes` | text | Nullable |

**`purchase_receipt_item`**

| Campo | Tipo | Observações |
|---|---|---|
| `id` | uuid | |
| `purchase_receipt_id` | uuid | |
| `purchase_order_item_id` | uuid | FK → `purchase_order_item` |
| `sku_id` | uuid | FK → `sku` |
| `quantity` | decimal | Quantidade recebida neste receipt |
| `unit_cost` | decimal | Custo unitário efetivo incluindo despesas rateadas |

## O que acontece na confirmação

1. **Bills gerados** — um Bill por `payment_term_installment` do `payment_term_id` do pedido, seguindo a mesma regra usada em sales_order/invoice:
   - `due_date` = `purchase_order.confirmed_at + days_offset`
   - `amount` = `purchase_order.total × pct / 100` (última parcela absorve o arredondamento)
   - `installment_number` = `sequence`
   - `installment_total` = total de parcelas no template

## O que acontece em cada recebimento

1. **Entrada de estoque** — um stock movement de `in` é gerado por SKU com `reference_type = purchase_receipt`.
2. **Custo médio atualizado** — `stock_balance.average_cost` é recalculado usando o custo unitário efetivo (incluindo despesas rateadas).
3. **`received_quantity` do item incrementado** — quando todos os itens atingem a quantidade total, o status do pedido vai para `received`.

## Regras de cancelamento

- Só é permitido quando o status é `draft` ou `confirmed` (sem nenhum recebimento).
- No cancelamento: o Bill associado é cancelado.
- Assim que existir qualquer receipt, o pedido não pode mais ser cancelado — é necessário um processo de devolução (pós-MVP).
