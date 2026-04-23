# Estoque

## Diagrama de arquitetura

```
╔══════════════════════════════════════════════════════════════════════╗
║                  INVENTORY — FLUXO DE MOVIMENTAÇÕES                  ║
╚══════════════════════════════════════════════════════════════════════╝

  DOCUMENTOS ORIGEM              TIPO DE MOVIMENTO     EFEITO NO SALDO

  ┌──────────────────┐
  │  Purchase Receipt│──── IN ───────────────────────► quantity  ▲
  │  (confirmado)    │                                 avg_cost recalculado
  └──────────────────┘
                                  ┌─────────────────┐
  ┌──────────────────┐            │  STOCK MOVEMENT │
  │  Sales Invoice   │──── OUT ──►│                 │► quantity  ▼
  │  (issued)        │            │  sku_id         │  avg_cost inalterado
  └──────────────────┘            │  type           │
                                  │  quantity       │
  ┌──────────────────┐            │  unit_cost      │
  │  Inventory Count │──ADJUST───►│  reference_type │► quantity ▲ ou ▼
  │  (completed)     │            │  reference_id   │  avg_cost inalterado
  └──────────────────┘            └────────┬────────┘
                                           │ atualiza
  ┌──────────────────┐                     ▼
  │  Manual Entry    │──ADJUST───► ┌───────────────────┐
  └──────────────────┘             │   STOCK BALANCE   │
                                   │                   │
                                   │  sku_id           │
                                   │  quantity         │
                                   │  average_cost     │
                                   │  minimum_stock    │
                                   │  reorder_point    │
                                   └───────────────────┘

  FÓRMULA DO CUSTO MÉDIO (em todo movimento IN):
  ┌──────────────────────────────────────────────────────────────┐
  │  new_avg = (curr_qty × curr_avg + in_qty × unit_cost)        │
  │            ─────────────────────────────────────────         │
  │                    (curr_qty + in_qty)                       │
  └──────────────────────────────────────────────────────────────┘

  FLUXO DO INVENTORY COUNT:
    draft ──► in_progress ──► completed
                                  │
                                  └──► gera automaticamente movimentos
                                       ADJUSTMENT para cada item
                                       onde counted ≠ system
```

Controla os níveis de estoque de cada SKU. Toda mudança de estoque — seja de uma venda, um recebimento de compra ou correção manual — gera um registro de movimento. Não há edição direta de saldo.

## Stock balance

Um registro por SKU representando a quantidade atualmente em mãos.

| Campo | Tipo | Observações |
|---|---|---|
| `id` | uuid | |
| `organization_id` | uuid | Chave de tenancy |
| `sku_id` | uuid | FK → `sku` |
| `quantity` | decimal | Quantidade atual em mãos. Nunca editada diretamente — atualizada via movimentos |
| `average_cost` | decimal | Custo médio ponderado móvel. Recalculado a cada movimento de entrada |
| `minimum_stock` | decimal | Limite para alerta. Nullable |
| `reorder_point` | decimal | Gatilho sugerido para reposição. Nullable |
| `updated_at` | timestamp | |

Constraint: `UNIQUE (organization_id, sku_id)` — garante 1 registro por SKU.

## Stock movements

Toda mudança de estoque é registrada como um movimento imutável. Os saldos são a soma corrente dos movimentos.

| Campo | Tipo | Observações |
|---|---|---|
| `id` | uuid | |
| `organization_id` | uuid | |
| `sku_id` | uuid | FK → `sku` |
| `type` | enum | `in \| out \| adjustment_in \| adjustment_out` |
| `quantity` | decimal | Sempre positiva. A direção é determinada pelo `type` (`in` e `adjustment_in` somam; `out` e `adjustment_out` subtraem) |
| `unit_cost` | decimal | Custo por unidade no momento do movimento. Usado no cálculo do custo médio em `in` |
| `reference_type` | string | Tipo do documento origem: `purchase_receipt`, `sales_invoice`, `inventory_count`, `invoice_cancellation`, `manual` |
| `reference_id` | uuid | FK para o documento origem. Nullable em lançamentos manuais |
| `notes` | text | Nullable |
| `created_at` | timestamp | |

### Tipos de movimento

| Tipo | Direção | Quando é gerado |
|---|---|---|
| `in` | + | Purchase receipt confirmado. **Atualiza o custo médio**. |
| `out` | − | Sales invoice emitida. Usa o custo médio atual. |
| `adjustment_in` | + | Contagem de inventário com `counted > system`, correção manual pra mais, ou cancelamento de invoice (`reference_type = invoice_cancellation`, `unit_cost` replica o do `out` original). Não atualiza custo médio. |
| `adjustment_out` | − | Contagem de inventário com `counted < system`, correção manual pra menos. Não atualiza custo médio. |

## Custo médio

O custo médio ponderado móvel é recalculado a cada movimento `in`:

```
new_average_cost = (current_quantity × current_average_cost + incoming_quantity × unit_cost)
                   / (current_quantity + incoming_quantity)
```

Movimentos `out` e `adjustment` não alteram o custo médio — eles usam o valor atual no momento do movimento.

## Inventory count

Contagem física que reconcilia o saldo do sistema com o estoque físico real.

| Campo | Tipo | Observações |
|---|---|---|
| `id` | uuid | |
| `organization_id` | uuid | |
| `status` | enum | `draft \| in_progress \| completed` |
| `notes` | text | Nullable |
| `created_at` | timestamp | |
| `completed_at` | timestamp | Nullable |

Constraint: partial unique index em `(organization_id)` onde `status = 'in_progress'` — uma org pode ter **no máximo um count em `in_progress`** por vez. Counts paralelos por escopo (categoria/filial) ficam para pós-MVP.

**`inventory_count_item`**

| Campo | Tipo | Observações |
|---|---|---|
| `id` | uuid | |
| `organization_id` | uuid | Chave de tenancy (denormalizada do `inventory_count` pai, para consistência com a invariante de tenancy e facilitar RLS) |
| `inventory_count_id` | uuid | |
| `sku_id` | uuid | |
| `system_quantity` | decimal | Snapshot do saldo no início da contagem |
| `counted_quantity` | decimal | Contagem física real informada pelo usuário |
| `difference` | decimal | `counted - system`. Calculado |

Ao fechar a contagem, é gerado automaticamente um movimento de `adjustment` para cada item onde `difference ≠ 0`.
