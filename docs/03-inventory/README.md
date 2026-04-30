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
| `store_id` | uuid | Chave de tenancy |
| `sku_id` | uuid | FK → `sku` |
| `quantity` | decimal | Quantidade atual em mãos. Nunca editada diretamente — atualizada via movimentos |
| `average_cost` | decimal | Custo médio ponderado móvel. Recalculado a cada movimento de entrada |
| `minimum_stock` | decimal | Limite para alerta. Nullable |
| `reorder_point` | decimal | Gatilho sugerido para reposição. Nullable |
| `updated_at` | timestamp | |

Constraint: `UNIQUE (store_id, sku_id)` — garante 1 registro por SKU.

## Stock movements

Toda mudança de estoque é registrada como um movimento imutável. Os saldos são a soma corrente dos movimentos.

| Campo | Tipo | Observações |
|---|---|---|
| `id` | uuid | |
| `store_id` | uuid | |
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
| `store_id` | uuid | |
| `status` | enum | `draft \| in_progress \| completed` |
| `notes` | text | Nullable |
| `created_at` | timestamp | |
| `completed_at` | timestamp | Nullable |

Constraint: partial unique index em `(store_id)` onde `status = 'in_progress'` — uma org pode ter **no máximo um count em `in_progress`** por vez. Counts paralelos por escopo (categoria/filial) ficam para pós-MVP.

**`inventory_count_item`**

| Campo | Tipo | Observações |
|---|---|---|
| `id` | uuid | |
| `store_id` | uuid | Chave de tenancy (denormalizada do `inventory_count` pai, para consistência com a invariante de tenancy e facilitar RLS) |
| `inventory_count_id` | uuid | |
| `sku_id` | uuid | |
| `system_quantity` | decimal | Snapshot do saldo no início da contagem |
| `counted_quantity` | decimal | Contagem física real informada pelo usuário |
| `difference` | decimal | `counted - system`. Calculado |

Ao fechar a contagem, é gerado automaticamente um movimento de `adjustment_in` ou `adjustment_out` para cada item onde `difference ≠ 0`, conforme o sinal (ver D1 abaixo).

## Decisões arquiteturais

Esta seção registra **o porquê** por trás das escolhas que travam o schema/comportamento deste módulo. Cada item preserva opções consideradas e tradeoffs — não apenas a decisão final. Os IDs (`D1`, `D7`, `D9`, `C2`) são estáveis e podem ser referenciados de outras features. Decisões cujo impacto principal mora em outro módulo aparecem em **Referências cruzadas** com link para a feature dona.

### D1. Direção do movimento `adjustment`

**Onde**: o módulo dizia que `quantity` é sempre positiva e que a direção vinha de `type`. Funcionava para `in` (+) e `out` (−), mas `adjustment` podia ir para os dois lados (contagem pra mais/menos, cancelamento de invoice, correções manuais).

**Decisão**: **dois subtipos de adjustment**. `type` vira `in | out | adjustment_in | adjustment_out`.

- Mantém a invariante "quantity sempre positiva; direção pelo type".
- `adjustment_in`: invoice_cancellation, contagem onde `counted > system`, correção manual pra mais.
- `adjustment_out`: contagem onde `counted < system`, correção manual pra menos.
- Nenhum dos dois atualiza custo médio.

**Status**: `decided`

### D7. Unique em `stock_balance(sku_id)`

**Onde**: o módulo dizia "um registro por SKU" mas o schema não declarava unique constraint.

**Decisão**: **unique `(store_id, sku_id)` em `stock_balance`**. DB garante a invariante; sem constraint, race conditions em upsert podem criar duplicatas.

**Status**: `decided`

### D9. Inventory counts concorrentes

**Onde**: `inventory_count` tinha status `draft | in_progress | completed` mas não dizia se múltiplos counts podiam estar em progresso simultaneamente.

**Decisão**: **um count por vez por org**. Enquanto houver count em `in_progress`, não pode abrir outro.

- Constraint: partial unique index em `inventory_count (store_id)` onde `status = 'in_progress'`.
- Counts paralelos por escopo (categoria/filial) ficam para pós-MVP, junto com multi-filial.

**Status**: `decided`

### D10. Inventory count usa delta, não absoluto

**Onde**: o snapshot de `system_quantity` é tirado no início da contagem para "não perseguir alvo móvel". Mas se houver movimentos concorrentes durante a contagem (recebimento, venda), o ajuste no fechamento podia sobrescrever esses movimentos se aplicasse `counted_quantity` como valor absoluto.

**Decisão**: **ajustes do count são deltas (`counted - system_snapshot`), não absolutos**.

- O `adjustment_in/out` gerado no fechamento usa `|difference|` como quantidade.
- O saldo final = saldo atual ± delta. Movimentos concorrentes são preservados.
- Não há lock no SKU enquanto o count está em `in_progress` — outros movimentos passam normalmente.
- Se vários counts paralelos virem realidade pós-MVP (por escopo), a regra continua válida (cada count tem seu snapshot).

**Status**: `decided`

### C2. `inventory_count_item` sem `store_id`

**Onde**: `inventory_count_item` herdava tenancy via `inventory_count_id`, exigindo join para qualquer query — inconsistente com a invariante de "toda tabela de domínio tem `store_id`".

**Decisão**: **denormalizar `store_id` em `inventory_count_item`**. Consistente com o princípio do módulo Foundation e facilita RLS/queries.

**Status**: `decided`

### Referências cruzadas

- **A4** — Reversão de estoque no cancelamento de invoice usa `adjustment_in` com `reference_type = invoice_cancellation`. Decisão completa em [Invoices → A4](../07-invoices/README.md#a4-reversão-de-estoque-no-cancelamento-de-invoice).
